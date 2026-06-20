# AGENTS.md

## Overview
- Debian Trixie XFCE desktop container + Helm chart. Non-root `admin` (UID 1000).
- Serves noVNC via HTTPS/WSS on `:6901` (self-signed cert at `/home/admin/.vnc/self.pem`).
- VNC auth disabled (`-SecurityTypes None --I-KNOW-THIS-IS-INSECURE`).
- Panel tray has an action button: Lock Screen. Log Out was removed since it kills the XFCE session with no display manager to restart it.

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

## Testing
Four layers of tests, run in CI after every push:
- **`make test-structure`** (82 assertions) — Google `container-structure-test` against the built image. Checks packages, files, permissions, wrapper scripts, config XML values, PulseAudio config, audio plugin files. No container runtime needed.
- **`make test-bats`** (22 tests) — Bats unit tests for `entrypoint.sh`, `reset-xfce4`, and `start-desktop.sh` logic. Runs in temp directories, no Docker required.
- **`make test-smoke`** — Runtime integration test. Starts the container, waits for VNC+websockify, reads xsettings.xml/xfce4-panel.xml, verifies audio plugin files and config.
- **`make test-helm`** — Helm chart lint.

Run all locally:
```
make docker-build && make test IMAGE_VERSION=<tag>
```
Individual targets: `make test-structure test-bats test-smoke test-helm`

CI flow: build → structure test → bats → smoke test → push. Cache layer means the push rebuild is near-instant.

## Whitelabelling / Theming
- noVNC logos are replaced with Debian branding via CSS background images:
  - **Sidebar** (`#noVNC_control_bar .noVNC_logo`): 36×36px Debian swirl (`openlogo-debianV2.svg`)
  - **Connect dialog** (`#noVNC_connect_dlg .noVNC_logo`): 280×200px full Debian logo (`Debian-OpenLogo.svg`)
  - Text is hidden with `font-size: 0`; logos are added as `background-image` in `novnc-dark.css`
- Dark theme lives in `config/novnc-dark.css`, loaded last in `vnc.html` and `vnc_auto.html`
- SVG logo files (`openlogo-debianV2.svg`, `Debian-OpenLogo.svg`) are copied into `/usr/share/novnc/` via Dockerfile COPY

## Key gotchas
- `librsvg2-common` must be listed explicitly in Dockerfile (it's only a Recommends of `papirus-icon-theme`; `--no-install-recommends` skips it)
- XFCE autostart `.desktop` files **must be executable** (`chmod +x`) or XFCE ignores them
- **Screensaver and lock screen are disabled by default** (`saver/enabled=false`, `lock/enabled=false`). This prevents the user from getting locked out when no password is set (see below). The idle-timeout value is still configured at 1 hour (`/saver/timeout = 3600`) so if the user re-enables via the GUI the timeout is already sensible.
- **To enable screensaver + lock screen via the GUI:**
  1. Open the XFCE menu → **Settings** → **Screensaver**
  2. Check **"Enable Screensaver"** and set your desired idle timeout
  3. Check **"Lock screen"** (under the Lock tab) to enable automatic locking when the screensaver activates
  4. Close the dialog — changes take effect immediately
- **Setting a password** (required for lock screen to actually prevent access):
  1. Exec into the pod as root: `kubectl exec <pod> -c desktop -- bash -c 'passwd admin'`
  2. Enter and confirm the password
  3. The password hash is synced to the PVC-backed `/home/admin/.shadow` every 2 minutes, so it survives pod restarts and image updates
  4. No need to restart the session — the lock screen uses PAM under the hood and picks up the new password immediately
  - **Important**: Debian's PAM does NOT permit empty passwords (`nullok` is absent from `pam_unix.so`). Without setting `passwd admin`, any lock screen attempt will be **denied** and the user will be stuck. This is why screensaver + lock are disabled by default.
- The X server's built-in screen saver is disabled via an XFCE autostart entry (`disable-x11-screensaver.desktop`) that runs `xset s 3600 3600` after the session is fully initialised, so it doesn't interfere with xfce4-screensaver's timeout. The wrapper script also sets GSettings `org.gnome.desktop.session idle-delay` to 3600 because the preferences GUI reads from GSettings, not xfconf.
- `--no-sandbox` apps (Chrome, Signal, VS Code) use wrapper scripts at `/usr/local/bin/`; menu `.desktop` files are `sed`'d to point at wrappers
- `--test-type` in Chrome wrapper suppresses the unsupported-flag banner (Chrome 149+ may still show it)
- Keyboard shortcuts: `xfwm4` requires `override=true` in XML; all conflicting defaults must be masked with empty properties
- Ubuntu font installed from Debian Bookworm's `non-free` pool (not packaged in Trixie)
- `docker exec` from outside VNC has no D-Bus session; `xfconf-query` and `xfdesktop --restart` won't affect the running session
- `--no-install-recommends` means any transitive dep (icon engines, font renderers, etc.) must be listed explicitly
- nginx sidecar `try_files` serves `index.html` first, then proxies to websockify (handles WebSocket upgrade)
- Audio streaming uses `module-simple-protocol-tcp` in PulseAudio; the PulseAudio config is at `/etc/pulse/default.pa.d/` and loaded automatically on startup
- `audio-proxy.sh` requires `socat` and `gstreamer1.0-tools + plugins` — all installed explicitly via Dockerfile
- The audio plugin (`audio-plugin.js`) is loaded as an ES module in `vnc.html` and defaults to auto-enabled with path `/audio/`
- The audio WebSocket runs on port `6902` (separate from VNC's `6901`); nginx sidecar routes `/audio/` → `127.0.0.1:6902`
- `start-desktop.sh` replaces the old inline CMD; it starts PulseAudio → VNC → audio-proxy → websockify×2; failures in audio services are non-fatal (the desktop still works without audio)
- Browser autoplay policy: audio starts on first user click in the session (handled by the plugin)
- `pactl` commands may fail on first attempt if PulseAudio hasn't finished initializing; `start-desktop.sh` has a retry loop (up to 10s wait)
- **Clipboard sync** requires `xclip` and `vncconfig -nowin`:
  - `xclip` is installed in the image and provides the `xclip` binary that programs (including opencode) use to write to the X11 CLIPBOARD selection
  - `vncconfig -nowin` runs from `~/.vnc/xstartup` as a background daemon to relay CLIPBOARD content to the noVNC client's clipboard panel
  - Without either, the noVNC clipboard panel won't show copied text
