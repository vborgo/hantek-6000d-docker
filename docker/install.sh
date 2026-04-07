#!/bin/bash
# Runs during Docker build: bootstrap Wine, install Hantek software, register driver
set -e

Xvfb :1 -screen 0 1280x800x24 -ac &
XVFB_PID=$!
sleep 3

export DISPLAY=:1

# Init Wine prefix (win64)
wineboot --init
sleep 5

# Install required Windows runtime DLLs
winetricks -q mfc42

# Run the Hantek installer silently, kill it after 60s regardless of dialogs
timeout 60 wine /hantek/installer/Setup.EXE /S || true
sleep 5

# Copy AMD64 kernel driver to Wine's drivers directory
cp /hantek/installer/Driver/Win10/Hantek6000BAMD64.Sys \
   "$WINEPREFIX/drive_c/windows/system32/drivers/Hantek6000BAMD64.SYS"

# Stage driver in driverstore so Wine's PnP manager can auto-bind it on device plug-in
# (mirrors the state of the working host Wine prefix where the driver was installed with device connected)
DRIVERSTORE="$WINEPREFIX/drive_c/windows/system32/driverstore/filerepository/hantek6000b.inf_1"
mkdir -p "$DRIVERSTORE"
cp /hantek/installer/Driver/Win10/Hantek6000B.inf    "$DRIVERSTORE/"
cp /hantek/installer/Driver/Win10/Hantek6000BAMD64.Sys "$DRIVERSTORE/Hantek6000BAMD64.SYS"
cp /hantek/installer/Driver/Win10/Hantek6000B.cat    "$DRIVERSTORE/"

# Register the Oscilloscope kernel service (matches working host configuration)
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v DisplayName       /t REG_SZ       /d "Hantek6000B Scope Service"                              /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ErrorControl      /t REG_DWORD    /d 1                                                        /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ImagePath         /t REG_EXPAND_SZ /d "C:\\windows\\System32\\Drivers\\Hantek6000BAMD64.SYS" /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v ObjectName        /t REG_SZ       /d "LocalSystem"                                            /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v PreshutdownTimeout /t REG_DWORD   /d 180000                                                   /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v Start             /t REG_DWORD    /d 3                                                        /f
wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Oscilloscope" /v Type              /t REG_DWORD    /d 1                                                        /f

# Register the device class (matches working host configuration)
CLSKEY="HKLM\\SYSTEM\\CurrentControlSet\\Control\\Class\\{36FC9E60-C465-11CF-8056-445566778899}\\0000"
wine reg add "$CLSKEY" /v DevLoader   /t REG_SZ /d "*ntkern"                      /f
wine reg add "$CLSKEY" /v InfPath     /t REG_SZ /d "hantek6000b.inf"              /f
wine reg add "$CLSKEY" /v InfSection  /t REG_SZ /d "Oscilloscope.Dev.NTamd64"     /f
wine reg add "$CLSKEY" /v NTMPDriver  /t REG_SZ /d "Hantek6000BAMD64.SYS"        /f

wineserver --kill || true

echo "=== Installed EXEs ==="
find "$WINEPREFIX/drive_c" \
    -not -path "*/windows/*" \
    -not -path "*/Microsoft.NET/*" \
    -iname "*.exe" 2>/dev/null | sort

kill $XVFB_PID 2>/dev/null || true
