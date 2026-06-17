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
- **Guake** — drop-down terminal (toggled with `F12`; autostarts via `~/.config/autostart/guake.desktop`)
- **Git** — version control (`git version`)
- **OpenCode** — open source AI coding agent (`opencode`)
- **GitHub CLI** — GitHub from the terminal (`gh`)
- **XFCE Utilities** — including Thunar file manager and XFCE terminal

## Customizations 🎨

- **Dark Theme** — Adwaita-dark set as the default system theme
- **Custom Wallpaper** — persistent, modern background pre-configured
- **Clean Layout** — single-panel configuration (bloat removed)
- **Desktop Icons** — launchers for main apps pre-placed on the desktop
- **Keyboard Shortcuts** — custom tiling and system shortcuts (see [keyboard-shortcuts.md](docs/keyboard-shortcuts.md))
- **Icon Theme** — Papirus-Dark for modern, consistent application icons
- **Fonts** — Ubuntu font family for UI text, JetBrains Mono for monospace (terminal/code), Cantarell also available

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

> If you get TTY issues, use `make docker-run OPTS=""` or run without `-it`:
> ```bash
> docker run --rm -p 6901:6901 flaccid/debian-desktop:latest
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

To avoid stale image caching on cluster nodes, CI tags each build with a semantic version tag (`v0.x.y`) and `latest`. The `imagePullPolicy: Always` alone is insufficient when the `:latest` tag resolves to the same digest — always use a specific version tag in production.
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

The nginx sidecar sits inside the pod, serves the custom `index.html`, and proxies `/` to websockify on `localhost:6901` (plain HTTP — TLS is handled by the Ingress). WebSocket upgrades for noVNC are passed through transparently. The Ingress terminates external HTTPS and delegates auth to oauth2-proxy.

### Publishing chart updates

After any chart change:

```bash
make helm-package && make helm-index
```

Commit the new `.tgz` and `index.yaml` — the Helm repo is served via GitHub Pages at `https://flaccid.github.io/container-debian-desktop/`.

## Configuration Management ⚙️

### Entrypoint (`entrypoint.sh`)

On container start, the entrypoint detects whether it is running as `root` or as the `admin` user:

1. **First-run detection** — checks if `~/.config/xfce4` exists. If missing, it copies the entire skeleton (`/etc/skel/admin/`) into `/home/admin`, making autostart `.desktop` files executable.
2. **Privilege drop** — when running as `root`, it uses `gosu` to re-execute the container command as `admin`.
3. **Pass-through** — already running as `admin`, it executes the command directly.

This approach means fresh PVCs are populated automatically, while existing PVCs (post first-run) preserve user data across pod restarts.

### Reset Script (`reset-xfce4`)

If you need to restore the default XFCE configuration from the skeleton on an existing PVC (e.g., after a config change or to pick up new shortcuts/autostart entries):

```bash
# Exec into the pod and run with the correct HOME
kubectl exec -n <namespace> <pod> -c desktop -- bash -c 'HOME=/home/admin /usr/local/bin/reset-xfce4'
```

The script backs up the current `~/.config/xfce4`, restores all XFCE settings, autostart entries, and VNC startup files from the skeleton, then restarts the XFCE components.

## CI/CD 🔄

On push to `main` or a semver tag (`v*`), GitHub Actions builds and pushes `flaccid/debian-desktop` to Docker Hub with the following tags:

- `latest` — most recent build on `main`
- `sha-<short>` — exact commit SHA for traceability
- `v0.x.y` — semver release tags (pushed only when a matching `git tag` exists)

Chart version bumps and `index.yaml` updates are done manually.

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
| `make test` | Run all tests |
| `make test-structure` | Container structure tests (~47 assertions) |
| `make test-bats` | Shell script unit tests (bats) |
| `make test-smoke` | Runtime integration smoke test |
| `make test-helm` | Helm chart lint |
| `make helm-package` | Package chart into `.tgz` |
| `make helm-index` | Update Helm repo index |

## License and Authors

- Author: Chris Fordham (<chris@fordham.id.au>)

```text
Copyright 2026, Chris Fordham

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
