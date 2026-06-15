# AGENTS.md

## Overview
- Debian Trixie XFCE desktop container + Helm chart. Non-root `admin` (UID 1000).
- Serves noVNC via HTTPS/WSS on `:6901` (self-signed cert at `/home/admin/.vnc/self.pem`).
- VNC auth disabled (`-SecurityTypes None --I-KNOW-THIS-IS-INSECURE`).

## Build & Run
- `make docker-build` — builds `flaccid/debian-desktop:latest`
- `make docker-run` — runs locally on `:6901` (add `--entrypoint bash` if TTY issues)
- CI: `.github/workflows/container_image.yml` — on push to `main`, builds & pushes to Docker Hub

## Helm Chart (`charts/debian-desktop/`)
- **Release flow:** after any chart change, run:
  ```
  make helm-package && make helm-index
  ```
  Commit the new `.tgz` and `index.yaml` both.
- `helm lint charts/debian-desktop` — validate chart
- `helm-values.yaml` is gitignored — copy from `values.yaml` and fill in oauth2-proxy secrets before `make helm-install` / `make helm-upgrade`
- StatefulSet runs `privileged: true`; has an initContainer (`fix-permissions`) that `chown -R 1000:1000 /home/admin` on PVC mount
- nginx sidecar container proxies `:6901` → `:8080` (handles WebSocket upgrade)
- oauth2-proxy is a subchart dependency — configure via `oauth2-proxy.*` values
- Helm repo hosted via GitHub Pages at `https://flaccid.github.io/container-debian-desktop/`
