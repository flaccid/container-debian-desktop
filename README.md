# container-debian-desktop 🖥️

A persistent Debian Trixie XFCE desktop container with TigerVNC, noVNC, and a Helm chart for Kubernetes deployment.

## Overview

This repository packages a lightweight, persistent Linux desktop environment for the browser. It runs as a non-root user (`admin`, UID 1000) and avoids the permission headaches typical of PVC-bound desktop containers.

## Features ✨

- **Debian Trixie** — modern, stable base (`debian:trixie-slim`)
- **XFCE Desktop** — lightweight and efficient
- **TigerVNC** — robust VNC server with reliable session management
- **noVNC** — browser-based VNC client via WebSocket (`websockify`)
- **Automatic Scaling** — patched to default to "Remote resizing" mode
- **Persistence-ready** — uses a skeleton directory and entrypoint script to populate fresh PVCs at `/home/admin`
- **Non-root user** — runs strictly as `admin` (UID 1000) with passwordless `sudo` (uses `gosu` for clean privilege dropping)
- **Self-signed HTTPS** — noVNC served over HTTPS/WSS on port 6901

## Pre-installed Applications 📦

The image comes with several productivity tools ready to use:

- **Google Chrome** — with `--no-sandbox` patches for container compatibility
- **Signal Desktop** — secure messaging
- **Visual Studio Code** — full-featured IDE
- **Guake** — drop-down terminal (toggled with `F12`)
- **XFCE Utilities** — including Thunar file manager and XFCE terminal

## Customizations 🎨

- **Dark Theme** — Adwaita-dark set as the default system theme
- **Custom Wallpaper** — persistent, modern background pre-configured
- **Clean Layout** — single-panel configuration (bloat removed)
- **Desktop Icons** — launchers for main apps pre-placed on the desktop

## Quick Start 🚀

### Build the image

```bash
make docker-build
```

### Run locally

```bash
make docker-run
```

Then open **https://localhost:6901** in a browser (accept the self-signed cert warning).

> If you get TTY issues, use `make docker-run OPTS="--entrypoint bash"` or just:
> ```bash
> docker run -it --rm -p 6901:6901 flaccid/debian-desktop:latest
> ```

### Run with a persistent volume

```bash
docker run -p 6901:6901 -v desktop_data:/home/admin flaccid/debian-desktop:latest
```

No password is required — VNC authentication is disabled.

## Kubernetes Deployment ☸️

### Using the Helm chart

The chart at `charts/debian-desktop/` deploys everything:

- **StatefulSet** — desktop container + nginx sidecar
  - `entrypoint.sh` — populates fresh PVCs from `/etc/skel/admin` on first boot
  - `fix-permissions` initContainer — `chown -R 1000:1000 /home/admin` on PVC mount
  - nginx sidecar — proxies `http://localhost:6901` on port 8080 (handles WebSocket upgrade and serves `index.html`)
  - desktop container — runs `vncserver` + `websockify` as `admin` (via `gosu`)
- **PersistentVolumeClaim** — 5Gi default (upgradable), mounted at `/home/admin`
- **Service** — exposes port 8080 (nginx)
- **Ingress** — nginx ingress controller with oauth2-proxy auth
- **oauth2-proxy** — optional SSO subchart

### Image Tagging & Caching 🏷️

To avoid stale image issues in Kubernetes, the CI/CD pipeline tags each build with the Git commit SHA in addition to `latest`. When deploying via ArgoCD, it is highly recommended to use the specific Git SHA as the `image.tag` to ensure the correct version is pulled.

#### Install

```bash
# 1. Copy values and fill in oauth2-proxy secrets
cp charts/debian-desktop/values.yaml helm-values.yaml
# Edit helm-values.yaml with your secrets

# 2. Install
make helm-install
```

#### Upgrade

```bash
make helm-upgrade
```

#### Render templates

```bash
make helm-render
```

### Architecture

```
Browser ──HTTPS──> Ingress ──HTTP──> nginx sidecar (:8080) ──HTTP──> desktop (:6901)
                                       │                                  │
                                       │ (serves index.html)       websockify + cert
                                       │                                  │
                                                                     TigerVNC (:5901)
```

The nginx sidecar sits inside the pod and proxies HTTP to the desktop container's HTTPS endpoint, handling WebSocket upgrades for noVNC. It also ensures the custom `index.html` is served to initialize the browser settings (like scaling mode). The Ingress terminates external HTTPS and delegates auth to oauth2-proxy.

### Publishing chart updates

After any chart change:

```bash
make helm-package && make helm-index
```

Commit the new `.tgz` and `index.yaml` — the Helm repo is served via GitHub Pages at `https://flaccid.github.io/container-debian-desktop/`.

## CI/CD 🔄

On push to `main`, GitHub Actions builds and pushes `flaccid/debian-desktop:latest` to Docker Hub. Chart version bumps and `index.yaml` updates are done manually.

## Build & Make Targets 🛠️

| Target | Description |
|---|---|
| `make docker-build` | Build the Docker image |
| `make docker-build-clean` | Build with `--no-cache` |
| `make docker-run` | Run container locally |
| `make docker-push` | Push to Docker Hub |
| `make docker-exec-shell` | Open a shell in running container |
| `make helm-lint` | Validate the chart |
| `make helm-install` | Install from local chart |
| `make helm-upgrade` | Upgrade deployed release |
| `make helm-package` | Package chart into `.tgz` |
| `make helm-index` | Update Helm repo index |
