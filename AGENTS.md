# AGENTS.md

## Overview
- Debian Trixie XFCE desktop container + Helm chart. Non-root `admin` (UID 1000).
- Serves noVNC via HTTPS/WSS on `:6901` (self-signed cert at `/home/admin/.vnc/self.pem`).
- VNC auth disabled (`-SecurityTypes None --I-KNOW-THIS-IS-INSECURE`).

## Build
- `make docker-build` — builds `flaccid/debian-desktop:<Makefile version>`
- `make docker-build-clean` — builds with `--no-cache`
- `make docker-run` — runs locally on `:6901` (use `OPTS="--entrypoint bash"` if TTY issues)
- CI auto-tags images from git refs; `Makefile` IMAGE_VERSION is **local-only**

## Release flow
```
git tag v0.x.y && git push origin v0.x.y
```
CI builds + pushes `flaccid/debian-desktop` to Docker Hub with `latest`, `sha-<short>`, and `v0.x.y` tags.

After any Helm chart change:
```
make helm-package && make helm-index
git add <new .tgz> index.yaml && git commit
```
Helm repo served via GitHub Pages at `https://flaccid.github.io/container-debian-desktop/`.

## ArgoCD
- App definition lives in a **separate repo**: `~/src/github/flaccid/infrastructure/argocd/reddwarf/applications/debian-desktop.yaml`
- References Helm chart version (`targetRevision`) and image tag (`image.tag`). Both must be bumped on release.

## Config management
- All XFCE config is seeded via XML files in `/etc/skel/admin/.config/xfce4/xfconf/xfce-perchannel-xml/`
- `entrypoint.sh` detects first-run by checking for `~/.config/xfce4`; populates `/home/admin` from `/etc/skel/admin/` if absent
- On existing PVCs, run `reset-xfce4` to pick up new skeleton config. When exec'd as root, requires `HOME=/home/admin`:
  ```
  kubectl exec <pod> -c desktop -- bash -c 'HOME=/home/admin /usr/local/bin/reset-xfce4'
  ```
- Pod restart after `reset-xfce4` is often needed because restarting XFCE from outside the session is unreliable

## Key gotchas
- `librsvg2-common` must be listed explicitly in Dockerfile (it's only a Recommends of `papirus-icon-theme`; `--no-install-recommends` skips it)
- XFCE autostart `.desktop` files **must be executable** (`chmod +x`) or XFCE ignores them
- `--no-sandbox` apps (Chrome, Signal, VS Code) use wrapper scripts at `/usr/local/bin/`; menu `.desktop` files are `sed`'d to point at wrappers
- `--test-type` in Chrome wrapper suppresses the unsupported-flag banner (Chrome 149+ may still show it)
- Keyboard shortcuts: `xfwm4` requires `override=true` in XML; all conflicting defaults must be masked with empty properties
- Ubuntu font installed from Debian Bookworm's `non-free` pool (not packaged in Trixie)
- `docker exec` from outside VNC has no D-Bus session; `xfconf-query` and `xfdesktop --restart` won't affect the running session
- `--no-install-recommends` means any transitive dep (icon engines, font renderers, etc.) must be listed explicitly
- nginx sidecar `try_files` serves `index.html` first, then proxies to websockify (handles WebSocket upgrade)
