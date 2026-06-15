# container-debian-desktop 🖥️

A persistent Debian Trixie XFCE desktop container with TigerVNC, noVNC, and a Helm chart for Kubernetes deployment.

## Overview

This repository packages a lightweight, persistent Linux desktop environment for the browser. It runs as a non-root user (`admin`, UID 1000) and avoids the permission headaches typical of PVC-bound desktop containers.

## Features ✨

- **Debian Trixie** — modern, stable base (`debian:trixie-slim`)
- **XFCE Desktop** — lightweight and efficient
- **TigerVNC** — robust VNC server with reliable session management
- **noVNC** — browser-based VNC client via WebSocket (`websockify`)
- **Persistence-ready** — mount a PVC at `/home/admin` and desktop state survives pod restarts
- **Non-root user** — runs strictly as `admin` (UID 1000) with passwordless `sudo`
- **Self-signed HTTPS** — noVNC served over HTTPS/WSS on port 6901

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
  - `fix-permissions` initContainer — `chown -R 1000:1000 /home/admin` on PVC mount
  - nginx sidecar — proxies `http://localhost:6901` on port 8080 (handles WebSocket upgrade)
  - desktop container — runs `vncserver` + `websockify`
- **PersistentVolumeClaim** — 5Gi default, mounted at `/home/admin`
- **Service** — exposes port 8080 (nginx)
- **Ingress** — nginx ingress controller with oauth2-proxy auth
- **oauth2-proxy** — optional SSO subchart

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
                                       │                           websockify + cert
                                       │                                  │
                                                                     TigerVNC (:5901)
```

The nginx sidecar sits inside the pod and proxies HTTP to the desktop container's HTTPS endpoint, handling WebSocket upgrades for noVNC. The Ingress terminates external HTTPS and delegates auth to oauth2-proxy.

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
