#!/bin/bash
# Runs during Docker build: bootstrap Wine, install Hantek software, find the main exe
set -e

Xvfb :1 -screen 0 1280x800x24 -ac &
XVFB_PID=$!
sleep 3

export DISPLAY=:1

# Init Wine prefix
wineboot --init
sleep 5

# Install required Windows runtime DLLs
winetricks -q mfc42

# Run the Hantek installer silently, kill it after 60s regardless of dialogs
timeout 60 wine /hantek/installer/Setup.EXE /S || true
sleep 5

wineserver --kill || true

echo "=== Installed EXEs ==="
find "$WINEPREFIX/drive_c" \
    -not -path "*/windows/*" \
    -not -path "*/Microsoft.NET/*" \
    -iname "*.exe" 2>/dev/null | sort

kill $XVFB_PID 2>/dev/null || true
