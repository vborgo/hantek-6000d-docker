#!/bin/bash
# Launch Hantek Scope.exe natively under Wine.
# Must have run install-hantek.sh first.
# Connect the Hantek USB device before running this script for best results.

export WINEARCH=win64
export WINEPREFIX="$HOME/.wine-hantek"
export WINEDEBUG=trace+ntoskrnl,warn+usb
export DISPLAY="${DISPLAY:-:0}"

echo "=== Wine prefix: $WINEPREFIX ==="
echo "=== DISPLAY: $DISPLAY ==="

# Touch the USB registry tree to wake up wineusb.sys
wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true

echo "=== Waiting for Hantek USB device in Wine (up to 30s)... ==="
for i in $(seq 1 30); do
    INSTANCES=$(wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\\VID_04B5&PID_6CDE" 2>/dev/null \
        | tr -d '\r' | grep -v "^[0-9a-f]" | grep -v "^$" \
        | sed 's|HKEY_LOCAL_MACHINE|HKLM|g')
    [ -n "$INSTANCES" ] && break
    sleep 1
done

if [ -n "$INSTANCES" ]; then
    echo "=== Hantek device found — binding driver in Wine registry ==="
    while IFS= read -r INSTANCE; do
        [ -z "$INSTANCE" ] && continue
        wine reg add "$INSTANCE" /v Class      /t REG_SZ /d "Hantek6000B"                                  /f 2>/dev/null
        wine reg add "$INSTANCE" /v ClassGUID  /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}"       /f 2>/dev/null
        wine reg add "$INSTANCE" /v DeviceDesc /t REG_SZ /d "Hantek6000B"                                  /f 2>/dev/null
        wine reg add "$INSTANCE" /v Driver     /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}\\0000" /f 2>/dev/null
        wine reg add "$INSTANCE" /v Service    /t REG_SZ /d "Oscilloscope"                                 /f 2>/dev/null
    done <<< "$INSTANCES"
    echo "=== Driver bound ==="

    # Kill wineserver so that on next Wine startup, wineusb.sys re-enumerates USB
    # with the Service= binding already in the registry — allowing plugplay.exe to
    # call AddDevice on the Oscilloscope driver with a real USB PDO (not an orphan).
    echo "=== Restarting wineserver to trigger fresh PnP enumeration ==="
    wineserver -k 2>/dev/null || true
    sleep 3
else
    echo "=== WARNING: Hantek USB device not found in Wine after 30s ==="
    echo "    (device not connected, or udev permissions issue)"
    echo "    Continuing — Scope.exe may open but report 'no device'"
fi

# Touch USB registry again — this restarts wineserver and triggers fresh enumeration.
# Now that Service=Oscilloscope is in the registry, plugplay.exe will auto-load the driver.
wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true

# Wait for the Oscilloscope service (PnP auto-load — should succeed this time)
echo "=== Waiting for Oscilloscope service (PnP auto-load, up to 30s)... ==="
for i in $(seq 1 30); do
    STATE=$(wine sc query Oscilloscope 2>/dev/null | grep STATE | awk '{print $3}')
    [ "$STATE" = "4" ] && break
    sleep 1
done

if [ "$STATE" = "4" ]; then
    echo "=== Oscilloscope service RUNNING (PnP auto-loaded) ==="
else
    echo "=== PnP still did not auto-load — falling back to sc start ==="
    wine sc start Oscilloscope 2>&1 || true
    sleep 2
fi

# Find and launch Scope.exe
SCOPE=$(find "$WINEPREFIX/drive_c" -iname "Scope.exe" \
    -not -path "*/windows/*" \
    -not -path "*/Microsoft.NET/*" \
    2>/dev/null | head -1)

if [ -z "$SCOPE" ]; then
    echo "ERROR: Scope.exe not found in $WINEPREFIX" >&2
    echo "Did install-hantek.sh complete successfully?" >&2
    exit 1
fi

WIN_PATH=$(echo "$SCOPE" | sed "s|$WINEPREFIX/drive_c|C:|" | sed 's|/|\\|g')
echo "=== Launching: $WIN_PATH ==="
exec wine "$WIN_PATH"
