#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE="hantek-6000bd"

echo "Building $IMAGE from $SCRIPT_DIR..."
docker build -t "$IMAGE" "$SCRIPT_DIR"
echo "Done. Run with: run-hantek6000d-docker.sh"
