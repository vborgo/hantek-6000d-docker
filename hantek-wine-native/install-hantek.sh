#!/bin/bash
# Bootstrap a Wine prefix and install Hantek 6000D software natively on Ubuntu 24.
# Run as your regular user (not root), with a graphical session active.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_DIR="$SCRIPT_DIR/Hantek-6000_Ver2.2.7_D20220325"
DRIVER_DIR="$INSTALLER_DIR/Driver/Win10"

export WINEARCH=win64
export WINEPREFIX="$HOME/.wine-hantek"
export WINEDLLOVERRIDES="mscoree,mshtml="

echo "=== Wine prefix: $WINEPREFIX ==="

# Start a headless X display if we don't have one
if [ -z "$DISPLAY" ]; then
    echo "=== No DISPLAY set, starting Xvfb :99 ==="
    Xvfb :99 -screen 0 1280x800x24 -ac &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 2
fi

echo "=== Initialising Wine prefix (win64) ==="
wineboot --init
sleep 5

echo "=== Installing MFC42 (required by Scope.exe) ==="
winetricks -q mfc42

echo "=== Running Hantek installer (silent, 60s timeout) ==="
timeout 60 wine "$INSTALLER_DIR/Setup.EXE" /S || true
sleep 5

echo "=== Copying AMD64 kernel driver ==="
cp "$DRIVER_DIR/Hantek6000BAMD64.Sys" \
   "$WINEPREFIX/drive_c/windows/system32/drivers/Hantek6000BAMD64.SYS"

echo "=== Staging driver in driverstore (for Wine PnP auto-load) ==="
DRIVERSTORE="$WINEPREFIX/drive_c/windows/system32/driverstore/filerepository/hantek6000b.inf_1"
mkdir -p "$DRIVERSTORE"
cp "$DRIVER_DIR/Hantek6000B.inf"        "$DRIVERSTORE/"
cp "$DRIVER_DIR/Hantek6000BAMD64.Sys"   "$DRIVERSTORE/Hantek6000BAMD64.SYS"
cp "$DRIVER_DIR/Hantek6000B.cat"        "$DRIVERSTORE/"

echo "=== Registering Oscilloscope kernel service ==="
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v DisplayName        /t REG_SZ        /d "Hantek6000B Scope Service"                              /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ErrorControl       /t REG_DWORD     /d 1                                                        /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ImagePath          /t REG_EXPAND_SZ /d "C:\\windows\\System32\\Drivers\\Hantek6000BAMD64.SYS"  /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ObjectName         /t REG_SZ        /d "LocalSystem"                                            /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v PreshutdownTimeout /t REG_DWORD     /d 180000                                                   /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v Start              /t REG_DWORD     /d 3                                                        /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v Type               /t REG_DWORD     /d 1                                                        /f

echo "=== Registering device class GUID ==="
CLSKEY="HKLM\\SYSTEM\\CurrentControlSet\\Control\\Class\\{36FC9E60-C465-11CF-8056-445566778899}\\0000"
wine reg add "$CLSKEY" /v DevLoader  /t REG_SZ /d "*ntkern"                   /f
wine reg add "$CLSKEY" /v InfPath    /t REG_SZ /d "hantek6000b.inf"           /f
wine reg add "$CLSKEY" /v InfSection /t REG_SZ /d "Oscilloscope.Dev.NTamd64"  /f
wine reg add "$CLSKEY" /v NTMPDriver /t REG_SZ /d "Hantek6000BAMD64.SYS"     /f

wineserver --kill || true

echo ""
echo "=== Installed EXEs in prefix ==="
find "$WINEPREFIX/drive_c" \
    -not -path "*/windows/*" \
    -not -path "*/Microsoft.NET/*" \
    -iname "*.exe" 2>/dev/null | sort

[ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true

echo ""
echo "=== Done. Run ./start-scope.sh to launch the oscilloscope software ==="
