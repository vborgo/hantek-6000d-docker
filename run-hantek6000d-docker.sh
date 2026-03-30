#!/bin/bash
set -e

IMAGE="hantek-6000bd"
PORT=6080

if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Image '$IMAGE' not found. Run build-hantek6000d-docker.sh first."
    exit 1
fi

echo "Starting Hantek 6000D..."
echo "Open in browser: http://localhost:$PORT/vnc.html"

docker run --rm \
    -p "$PORT:6080" \
    --device /dev/bus/usb \
    "$IMAGE"
