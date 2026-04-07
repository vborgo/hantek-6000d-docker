#!/bin/bash
# Install WineHQ stable on Ubuntu 24.04 (Noble) - run with sudo
set -e

echo "=== Adding i386 architecture ==="
dpkg --add-architecture i386

echo "=== Installing prerequisites ==="
apt-get update
apt-get install -y --no-install-recommends \
    wget gnupg2 ca-certificates \
    winetricks cabextract \
    libusb-1.0-0 libusb-1.0-0:i386 \
    usbutils \
    xvfb

echo "=== Adding WineHQ repository ==="
mkdir -p /etc/apt/keyrings
wget -qO /etc/apt/keyrings/winehq.key https://dl.winehq.org/wine-builds/winehq.key
echo "deb [signed-by=/etc/apt/keyrings/winehq.key] https://dl.winehq.org/wine-builds/ubuntu/ noble main" \
    > /etc/apt/sources.list.d/winehq.list

echo "=== Installing WineHQ stable ==="
apt-get update
apt-get install -y --install-recommends winehq-stable

echo ""
echo "=== Done ==="
wine --version
echo ""
echo "Next step: run ./install-hantek.sh as your regular user (not root)"
