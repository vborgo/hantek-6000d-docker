#!/bin/bash
# Bind the Oscilloscope driver to the Hantek USB device in Wine's registry.
# Runs at container startup (supervisord priority 45) after Xvfb is up but
# before Scope.exe starts. Wine's wineusb.sys enumerates the USB device when
# the first Wine process starts; this script writes the Service/ClassGUID
# bindings that HTHardDll.dll needs to find the device.

export DISPLAY=:1
export WINEPREFIX=/root/.wine
export WINEARCH=win64

# Wait for wineusb.sys to enumerate USB (triggered by first Wine call below)
wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB" > /dev/null 2>&1 || true
sleep 2

# Find all Hantek device instance paths
INSTANCES=$(wine reg query "HKLM\\SYSTEM\\CurrentControlSet\\Enum\\USB\\VID_04B5&PID_6CDE" 2>/dev/null \
    | tr -d '\r' \
    | grep -v "^[0-9a-f]" \
    | grep -v "^$" \
    | sed 's|HKEY_LOCAL_MACHINE|HKLM|g')

if [ -z "$INSTANCES" ]; then
    echo "bind-hantek: Hantek USB device not found — is it plugged in?"
    exit 0
fi

while IFS= read -r INSTANCE; do
    [ -z "$INSTANCE" ] && continue
    echo "bind-hantek: binding driver to $INSTANCE"
    wine reg add "$INSTANCE" /v Class      /t REG_SZ /d "Hantek6000B"                                       /f
    wine reg add "$INSTANCE" /v ClassGUID  /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}"            /f
    wine reg add "$INSTANCE" /v DeviceDesc /t REG_SZ /d "Hantek6000B"                                       /f
    wine reg add "$INSTANCE" /v Driver     /t REG_SZ /d "{36FC9E60-C465-11CF-8056-445566778899}\\0000"      /f
    wine reg add "$INSTANCE" /v Service    /t REG_SZ /d "Oscilloscope"                                      /f
done <<< "$INSTANCES"

echo "bind-hantek: done"

# Kill the Wine server so Scope.exe starts a fresh session with the binding in place.
# Without this, wineusb.sys may have already enumerated the device without a Service
# binding and won't retry loading the driver for the same session.
wineserver -k || true
sleep 1
