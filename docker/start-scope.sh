#!/bin/bash
# Launch Scope.exe, with or without the Hantek device connected.
# - Device connected: full PnP driver binding so Wine can communicate with the hardware.
# - Device not connected: skips all driver steps and launches immediately (demo mode).

sleep 2  # Wait for Xvfb

# Fast pre-check: is the Hantek physically present on the USB bus?
# lsusb is instant and avoids two 30s Wine polling loops when there is no device.
if lsusb 2>/dev/null | grep -qi "04b5:6cde"; then

    # --- DEVICE CONNECTED: full Wine USB driver binding flow ---

    # Start wineserver by touching the USB registry tree
    wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true

    # Wait for wineusb.sys to enumerate the Hantek and create its instance subkey.
    # Use /s to recursively list — subkey paths have a backslash AFTER PID_6CDE (parent key does not).
    # Without /s, reg query only returns the parent container key which cannot receive value writes.
    echo "start-scope: Hantek detected — waiting for Wine USB enumeration..."
    INSTANCE=""
    for i in $(seq 1 30); do
        INSTANCE=$(wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\\VID_04B5&PID_6CDE" /s 2>/dev/null \
            | tr -d '\r' \
            | grep "^HKEY" \
            | grep -i "PID_6CDE\\\\" \
            | head -1 \
            | sed 's/HKEY_LOCAL_MACHINE/HKLM/')
        [ -n "$INSTANCE" ] && break
        sleep 1
    done

    if [ -n "$INSTANCE" ]; then
        echo "start-scope: Hantek device instance: $INSTANCE"
        # Write registry bindings so Wine's PnP knows which driver to use
        wine reg add "$INSTANCE" /v Class      /t REG_SZ /d "Hantek6000B"                                  /f
        wine reg add "$INSTANCE" /v ClassGUID  /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}"       /f
        wine reg add "$INSTANCE" /v DeviceDesc /t REG_SZ /d "Hantek6000B"                                  /f
        wine reg add "$INSTANCE" /v Driver     /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}\\0000" /f
        wine reg add "$INSTANCE" /v Service    /t REG_SZ /d "Oscilloscope"                                 /f
        echo "start-scope: Hantek device bound in Wine registry"

        # Kill wineserver so the next Wine call starts fresh.
        # On restart, wineusb.sys re-enumerates USB and plugplay.exe finds Service=Oscilloscope
        # already in the registry — allowing it to call AddDevice with the real USB PDO instead
        # of the orphan device that sc start alone would create.
        wineserver -k 2>/dev/null || true
        sleep 3
    else
        echo "start-scope: WARNING — device visible in lsusb but not enumerated by Wine after 30s"
    fi

    # Re-touch USB registry — restarts wineserver with bindings in place so PnP auto-loads the driver.
    wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true

    # Wait for Wine's PnP (plugplay.exe) to auto-load the Oscilloscope driver via the driverstore.
    # With hantek6000b.inf_1 in the driverstore, PnP calls AddDevice with the real USB PDO.
    # This wires the driver to the hardware — unlike sc start alone which creates an orphan device.
    echo "start-scope: waiting for Oscilloscope service to start (PnP auto-load)..."
    STATE=""
    for i in $(seq 1 30); do
        STATE=$(wine sc query Oscilloscope 2>/dev/null | grep STATE | awk '{print $3}')
        [ "$STATE" = "4" ] && break
        sleep 1
    done

    if [ "$STATE" = "4" ]; then
        echo "start-scope: Oscilloscope service RUNNING (PnP auto-loaded)"
    else
        echo "start-scope: PnP did not auto-load driver, falling back to sc start..."
        wine sc start Oscilloscope 2>&1 || true
        sleep 2
    fi

else

    # --- NO DEVICE: launch immediately in demo mode ---
    echo "start-scope: Hantek not connected — launching Scope.exe in demo mode"
    # Start wineserver so Wine is ready for Scope.exe
    wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true

fi

# Find Scope.exe (win64 prefix installs 32-bit apps to "Program Files (x86)")
SCOPE=$(find /root/.wine/drive_c -iname "Scope.exe" \
    -not -path "*/windows/*" \
    -not -path "*/Microsoft.NET/*" \
    2>/dev/null | head -1)

if [ -z "$SCOPE" ]; then
    echo "ERROR: Scope.exe not found in Wine prefix" >&2
    exit 1
fi

WIN_PATH=$(echo "$SCOPE" | sed 's|/root/.wine/drive_c|C:|' | sed 's|/|\\|g')
echo "start-scope: launching $WIN_PATH"
exec wine "$WIN_PATH"
