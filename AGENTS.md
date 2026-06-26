# AGENTS.md

## Overview
- Debian Trixie XFCE desktop container + Helm chart (oauth2-proxy subchart). Non-root `admin` (UID 1000) with passwordless sudo.
- Serves noVNC via nginx sidecar on `:8080` (Helm) or direct websockify on `:6901` (Docker). Self-signed cert at `/home/admin/.vnc/self.pem`.
- VNC auth disabled (`-SecurityTypes None --I-KNOW-THIS-IS-INSECURE`).
- Audio: PulseAudio null-sink → GStreamer WebM/Opus → websockify `:6902` → noVNC plugin. LoadBalancer service exposes ports 80, 6901, 6902.

## Build & Run
- `make docker-build` — builds `flaccid/debian-desktop:<Makefile version>`
- `make docker-build-clean` — builds with `--no-cache`
- `make docker-run` — runs locally on `:6901` (use `OPTS=""` or `ARGS=""` if TTY issues)
- `make docker-exec-shell` — exec into running `debian-desktop` container
- `make docker-run-shell` — runs with `/bin/sh` as entrypoint

## Release flow
```
git tag v0.x.y && git push origin v0.x.y
```
CI tags images with `latest`, `sha-<short>`, and `v0.x.y`. After any Helm chart change:
```
make helm-package && make helm-index
git add <new .tgz> index.yaml && git commit
```
Helm repo served via GitHub Pages at `https://flaccid.github.io/container-debian-desktop/`.

## ArgoCD
- App definition in separate repo: `~/src/github/flaccid/infrastructure/argocd/reddwarf/applications/debian-desktop.yaml`
- References Helm chart `targetRevision` AND image `image.tag` — both must be bumped on release.

## Config management
- XFCE config seeded via XML files in `/etc/skel/admin/.config/xfce4/xfconf/xfce-perchannel-xml/`
- `entrypoint.sh` detects first-run by checking `~/.config/xfce4`; populates `/home/admin` from `/etc/skel/admin/` if absent
- On existing PVCs, `ensure_config()` copies specific files: xstartup, self.pem, guake.desktop, disable-x11-screensaver.desktop, session-timer.desktop, xfce4-panel.xml, genmon-12.rc, genmon-14.rc, xfce4-screensaver.xml
- To restore defaults on a PVC: `kubectl exec <pod> -c desktop -- bash -c 'HOME=/home/admin /usr/local/bin/reset-xfce4'` then restart pod (restarting XFCE externally is unreliable)
- `/etc/shadow` synced to PVC-backed `/home/admin/.shadow` every 2 minutes so `passwd admin` survives restarts

## Testing
Four layers, run in CI after every push (`make test` runs all):
- **`make test-structure`** (92 assertions) — Google `container-structure-test`. No container runtime needed.
- **`make test-bats`** (32 tests across 3 files) — Bats unit tests for `entrypoint.sh`, `reset-xfce4`, `start-desktop.sh`, `fix-audio`, `session-timer.sh`, `memmon.sh`, `test-audio`. No Docker required.
- **`make test-smoke`** — Runtime integration test. Starts container, waits for VNC+websockify, validates config values, wrapper scripts, audio plugin, PWA artifacts, favicon.
- **`make test-helm`** — `helm lint` on the chart.

CI flow: build → structure test → bats → smoke test → push (build uses `docker/build-push-action` v7 with GHA cache).

## K8s / Helm
- StatefulSet: desktop container + nginx sidecar + `fix-permissions` initContainer (chown 1000:1000 on PVC)
- Desktop container securityContext: **not privileged**. Capabilities added: CHOWN, DAC_OVERRIDE, SETUID, SETGID. `allowPrivilegeEscalation: false`.
- Nginx sidecar: serves `vnc.html` (not `vnc_auto.html` — lacks audio plugin `<script>` tag). Redirects `/` → `/vnc.html?resize=remote` and `/index.html` → same. Injects a Sign Out button via `sub_filter`. Disables cache for `.html/.js/.json`.
- Resources (Helm default): requests 1Gi/500m, limits 4Gi/2000m
- `/dev/shm` is an in-memory emptyDir (sizeLimit: 1Gi) — needed by Chrome
- Service: ClusterIP + LoadBalancer (optional) exposing 80, 6901, 6902
- oauth2-proxy is a local subchart (`charts/oauth2-proxy/`), listed as a Chart.yaml dependency
- `helm-values.yaml` in repo root is a **placeholder** — copy `charts/debian-desktop/values.yaml` to customize
- Logout page served at `/logout` by nginx ConfigMap — only available in Helm deployments, not Docker

## Key gotchas
- `librsvg2-common` must be listed explicitly in Dockerfile (Recommends of `papirus-icon-theme`; `--no-install-recommends` skips it)
- XFCE autostart `.desktop` files **must be executable** (`chmod +x`) or XFCE ignores them — both `entrypoint.sh` and `reset-xfce4` do this
- Screensaver: `saver/enabled=false` (prevents idle auto-lock when no password set). `lock/enabled=true` (manual lock + `Ctrl+Alt+L` work after setting password via `passwd admin`). Idle timeout is 3600s if re-enabled. Without setting a password, lock screen is **denied** (PAM `nullok` absent).
- `--no-sandbox` apps (Chrome, Signal, VS Code) use wrapper scripts at `/usr/local/bin/`; menu `.desktop` files `sed`'d to point at wrappers
- `docker exec` from outside VNC has no D-Bus session — `xfconf-query` and `xfdesktop --restart` won't affect the running session
- All transitive deps must be listed explicitly in Dockerfile due to `--no-install-recommends`
- Keyboard shortcuts: `xfwm4` requires `override=true` in XML; conflicting defaults masked as empty properties
- `pactl` commands may fail on first attempt (PulseAudio not yet ready); `start-desktop.sh` has a 10s retry loop
- Custom `xflock4` at `/usr/local/bin/xflock4` calls `xfce4-screensaver-command --lock` directly (stock `xflock4` uses D-Bus session manager Lock method, unreliable in TigerVNC)
- Clipboard sync: `vncconfig -nowin` runs from `~/.vnc/xstartup`; `xclip` installed in image. Both required for noVNC clipboard panel to work.
- `free` is overridden by `config/free-wrapper.sh` — reads cgroup v2 memory limit so `free` shows the container limit, not host total. The real `free` is at `/bin/free`.
- CI uses Docker build cache (`cache-from: type=gha`); the push step after tests rebuilds nearly instantly from cache
- PWA: noVNC has a service worker (`sw.js`), manifest (`manifest.json`), and Debian-branded icons at 192×192 and 512×512
