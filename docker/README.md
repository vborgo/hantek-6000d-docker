# Hantek 6000D — Docker / Wine Setup

Runs the official Hantek 6000D Windows software (`Scope.exe`) inside Wine on Ubuntu 24.04, accessible from any browser via noVNC.

## Requirements

- Docker
- The installer directory at `references/Hantek-6000_Ver2.2.7_D20220325/` (relative to project root)

## Quick Start

```bash
# 1. Build the image (once)
./build-hantek6000d-docker.sh

# 2. Run
./run-hantek6000d-docker.sh

# 3. Open in browser
http://localhost:6080/vnc.html
```

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Ubuntu 24.04 + WineHQ stable + desktop stack + Hantek install |
| `docker/install.sh` | Runs at build time: inits Wine prefix, installs MFC42, runs `Setup.EXE` |
| `docker/start.sh` | Runtime entrypoint: starts supervisord |
| `docker/supervisord.conf` | Process manager: Xvfb → Fluxbox → x11vnc → noVNC → Scope.exe |
| `build-hantek6000d-docker.sh` | Convenience build script |
| `run-hantek6000d-docker.sh` | Convenience run script |

## Desktop Stack

```
Browser → noVNC (:6080) → x11vnc (:5900) → Xvfb (:1) → Fluxbox + Wine/Scope.exe
```

- **Xvfb** — headless X11 display
- **Fluxbox** — minimal window manager
- **x11vnc** — exposes the display over VNC
- **noVNC** — serves VNC over WebSocket so any browser can connect, no VNC client needed

## USB Device Passthrough

To connect the oscilloscope to the container:

```bash
# Find the device
lsusb | grep -i 04b5  # Hantek VID

# Pass through all USB (run-hantek6000d-docker.sh already does this)
docker run --rm -p 6080:6080 --device /dev/bus/usb hantek-6000bd
```

> Note: `Scope.exe` may show a "device not found" error inside Wine — this is expected. The USB kernel driver (`USBD.SYS` / `CyUSB.dll`) does not load under Wine. The UI is still fully usable for protocol observation.

## Install System-Wide

To run `build-hantek6000d-docker` and `run-hantek6000d-docker` from anywhere:

```bash
sudo ln -s $(pwd)/build-hantek6000d-docker.sh /usr/local/bin/build-hantek6000d-docker
sudo ln -s $(pwd)/run-hantek6000d-docker.sh   /usr/local/bin/run-hantek6000d-docker
```

## Build Notes

- `MFC42u.DLL` (Microsoft Foundation Classes) is installed via `winetricks -q mfc42` — required by `Scope.exe`
- The Wise installer (`Setup.EXE /S`) is killed after 60 seconds to avoid hanging on a completion dialog
- Installed to `C:\Program Files\Hantek6000\Scope.exe` inside the Wine prefix
