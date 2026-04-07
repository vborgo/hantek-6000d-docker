#!/bin/bash
# Launch the Hantek 6000D oscilloscope as a native-looking desktop application.
# Starts the Docker container, waits for the UI, then opens an app-mode browser window.
# Stops the container automatically when the window is closed.
set -e

IMAGE="hantek-6000bd"
PORT=6080
CONTAINER="hantek-live"
PROFILE="/tmp/hantek-scope-profile"

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Image '$IMAGE' not found. Run build-hantek6000d-docker.sh first."
    exit 1
fi

# Remove any leftover container from a previous run
docker rm -f "$CONTAINER" 2>/dev/null || true

echo "Starting Hantek 6000D..."
docker run --rm -d \
    --name "$CONTAINER" \
    -p "$PORT:6080" \
    -v /dev/bus/usb:/dev/bus/usb \
    --device-cgroup-rule='c 189:* rmw' \
    -v /sys/bus/usb:/sys/bus/usb:ro \
    -v /sys/devices:/sys/devices:ro \
    "$IMAGE" > /dev/null

# Wait up to 30s for noVNC to become ready
echo "Waiting for UI..."
for i in $(seq 1 30); do
    curl -sf "http://localhost:${PORT}/vnc.html" > /dev/null 2>&1 && break
    sleep 1
done

# autoconnect=true  — skips the Connect button
# resize=scale      — scales the oscilloscope display to fill the window
URL="http://localhost:${PORT}/vnc.html?autoconnect=true&resize=scale"

# --user-data-dir forces a separate Chrome process (not merged into existing browser window),
# which keeps this script alive until the window is closed so we can stop the container.
launch() {
    local flags=(
        --app="$URL"
        --window-size=1280,800
        --user-data-dir="$PROFILE"
        --no-first-run
        --disable-translate
        --class=Hantek6000D
    )
    if   command -v google-chrome      &>/dev/null; then google-chrome       "${flags[@]}"
    elif command -v google-chrome-stable &>/dev/null; then google-chrome-stable "${flags[@]}"
    elif command -v chromium-browser   &>/dev/null; then chromium-browser    "${flags[@]}"
    elif command -v chromium           &>/dev/null; then chromium             "${flags[@]}"
    elif command -v firefox            &>/dev/null; then firefox --kiosk "$URL"
    else
        echo "No browser found. Open manually: $URL"
        read -r -p "Press Enter when done to stop the container..."
    fi
}

launch

# Container cleanup when the window is closed
echo "Window closed — stopping container..."
docker stop "$CONTAINER" 2>/dev/null || true
rm -rf "$PROFILE"
