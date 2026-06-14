# AGENTS.md - Repository Instructions

## Overview
- Project: Debian-based desktop container (Debian Trixie) + Helm chart.
- Image is optimized for persistence and runs as a non-root user (`admin`).

## Development Commands
- **Build Image:** `make docker-build`
- **Run Image Locally:** `make docker-run` 
  - *Note:* If `make docker-run` fails due to TTY constraints, run the `docker run` command directly as defined in the `Makefile`.

## Helm Chart
- Located in: `./charts/debian-desktop/`
- Verify with: `helm lint charts/debian-desktop`

## Quirks & Conventions
- **VNC Authentication:** Currently disabled (`-SecurityTypes None`) for ease of access over HTTPS/WSS.
- **User:** Container runs as user `admin` (UID 1000).
- **Certificate:** Auto-generated at `/home/admin/.vnc/self.pem`.
- **NoVNC:** Served at `:6901` (HTTPS).
- **Style:** Adwaita icon theme and gnome-themes-extra are installed to support alternative themes in XFCE.
