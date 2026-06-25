# Security

This document outlines security considerations for the `container-debian-desktop` project. It covers the threat model, known risks, and recommendations for safe deployment.

## Threat Model

This project provides a full Linux desktop environment accessible via a web browser. The primary threat is an attacker gaining access to the desktop session — either through the network (VNC, noVNC, audio WebSocket) or through a compromised application inside the container (browser exploit, malicious file). Once inside the desktop session, the attacker has access to:

- The user's home directory and any files on the PVC
- Cloud credentials that the user has configured (AWS CLI, gcloud, kubectl, etc.)
- The ability to run commands as `admin` with passwordless `sudo` (full root escalation)
- ~~The container's `privileged` security context (potential host escape)~~ **FIXED** — container now runs with `privileged: false` and all capabilities dropped

## Current Security Posture

### Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 2 |
| HIGH     | 4 |
| MEDIUM   | 18 |
| LOW      | 11 |

### Critical Findings

#### 1. Privileged container (statefulset.yaml:53) — **FIXED**

~~The desktop container runs with `privileged: true`, granting all Linux capabilities and unrestricted host device access. An attacker who escapes the `admin` user can use this to escape the container to the host node.~~

**Remediation**: Changed to `privileged: false` with `allowPrivilegeEscalation: false` and all capabilities dropped. The container no longer has access to the host cgroup tree, devices, or kernel capabilities. All core functionality (VNC, noVNC, PulseAudio, audio proxy, Chrome, XFCE) operates correctly without privileged mode.

If PulseAudio real-time scheduling warnings are observed, explicit `SYS_NICE` and `SYS_RESOURCE` capabilities can be added.

#### 2. VNC authentication disabled (start-desktop.sh:22)

TigerVNC starts with `-SecurityTypes None --I-KNOW-THIS-IS-INSECURE`. Anyone who can reach the VNC port (5901) can connect to the desktop with no credentials.

In Helm deployments this is partially mitigated by:
- The nginx sidecar on port 8080 (HTTP, no TLS)
- The oauth2-proxy at the Ingress level (when configured)
- VNC port 5901 is not exposed outside the pod

However, any pod in the cluster can reach port 5901 directly.

#### 3. VNC listens on all interfaces (start-desktop.sh:21)

`-localhost no` binds TigerVNC to `0.0.0.0:5901` instead of `127.0.0.1`. Combined with finding #2, any pod in the Kubernetes cluster can connect and control the desktop session without going through the oauth2-proxy.

### High Findings

#### 4. Passwordless sudo (Dockerfile:182)

The `admin` user has `NOPASSWD: ALL` in sudoers. Any process running as `admin` (including a compromised Chrome renderer) can trivially escalate to root inside the container.

#### 5. Shadow password sync to PVC (entrypoint.sh:46-75)

Password hashes are copied from `/etc/shadow` to a file on the PVC every 2 minutes and restored on container startup. The PVC file is owned by `admin`, meaning the non-root desktop user can read and write the password hash. An attacker with access to the PVC can overwrite the hash with a known value.

#### 6. Container runs as root (Dockerfile:260)

The image default user is `root`. The entrypoint drops privileges to `admin` via `gosu`, but processes start as root before the drop occurs.

#### 7. --no-sandbox browser wrappers (Dockerfile:156-169)

Chrome, Signal, and VS Code all run with `--no-sandbox`. The browser sandbox is the primary security boundary between web content and the OS. Without it, a malicious website or compromised web app has easier access to the container environment.

### Medium Findings

#### Network

- **No NetworkPolicy** — In a multi-tenant cluster, any pod can reach the desktop's VNC and audio ports.
- **No securityContext on nginx sidecar** — Runs with no restrictions, no read-only filesystem.
- **No securityContext on oauth2-proxy** — Runs as default container user with no capability restrictions.
- **LoadBalancer exposes port 6902** — The audio WebSocket has no authentication.
- **Template injection risk** — Ingress auth annotations use `tpl` with user-configurable values.
- **No Content-Security-Policy headers** — nginx serves noVNC without CSP, increasing XSS risk.

#### Container

- **No PodSecurityContext** — No seccomp profile, no `fsGroup`, no `runAsNonRoot` at the pod level.
- **Init container runs as root** — Necessary for `chown` on PVC, but should be the only root process.
- **Build/developer tools in production image** — Go, C/C++ compilers, Python pip, network tools increase attack surface.
- **Third-party apt repos without GPG fingerprint verification** — Keys are accepted without known-good fingerprint checks.
- **Ubuntu font downloaded over HTTP** — MITM could substitute a malicious `.deb`.
- **Self-signed TLS certificate** — 10-year validity, no passphrase, key is world-readable in the image.

#### Authentication & Secrets

- **OAuth basic auth password visible in pod spec** — Passed as CLI argument, visible via `kubectl describe` and `/proc`.
- **OAuth credentials default to empty** — Empty `clientId`/`clientSecret`/`cookieSecret` may cause unexpected behaviour if deployed without values.
- **Skeleton config overwrites user customizations** — `xfce4-panel.xml` and `xfce4-screensaver.xml` are restored from skeleton on every container start.
- **reset-xfce4 uses SIGKILL** — Processes are killed with `-9`, potentially corrupting configuration files.

#### Audio

- **PulseAudio TCP listener** — On localhost, but has no authentication (low risk due to localhost binding).
- **Audio proxy secret is optional and does not encrypt** — The `-s` flag is not used in the default invocation.

### Low Findings

- Network tools (netcat, telnet) in the image
- Cloud CLI tools (awscli, gcloud, kubectl, terraform) in the image
- Screensaver auto-lock disabled by default
- Service worker uses network-first cache strategy
- Long proxy timeout (86400s) for WebSocket connections
- Audio WebSocket exposed externally without auth
- Audio secret exposed in client-side JavaScript
- WebSocket encryption defaults to page protocol
- No container image signing in CI
- CI tools downloaded without cryptographic verification
- vncconfig clipboard daemon runs in background

## Recommendations for Production Deployments

### Required

1. **Use the secure Helm install** with oauth2-proxy and a TLS certificate. Never expose port 6901 or 6902 directly to the internet without authentication.

2. **Set resource limits** on both the desktop and nginx containers to prevent resource exhaustion.

3. **Use a dedicated namespace** with network isolation. Apply a NetworkPolicy that restricts ingress to only the Ingress controller and oauth2-proxy.

4. **Set a desktop password** immediately after deployment:
   ```bash
   kubectl exec <pod> -c desktop -- passwd admin
   ```

### Recommended

1. **Drop `privileged: true`** — **IMPLEMENTED** (see finding #1). The default chart now sets `privileged: false` with `allowPrivilegeEscalation: false` and all capabilities dropped.

2. **Add a PodSecurityContext**:
   ```yaml
   spec:
     securityContext:
       seccompProfile:
         type: RuntimeDefault
       runAsUser: 1000
       runAsGroup: 1000
       fsGroup: 1000
   ```

3. **Bind VNC to localhost only** (`-localhost yes`) and rely on the websockify proxy for network access.

4. **Add securityContext to the nginx sidecar**:
   ```yaml
   securityContext:
     runAsNonRoot: true
     readOnlyRootFilesystem: true
     allowPrivilegeEscalation: false
     capabilities:
       drop:
         - ALL
   ```

5. **Add securityContext to the oauth2-proxy** similarly.

6. **Set a Content-Security-Policy** in the nginx config.

7. **Use HTTPS for all external downloads** in the Dockerfile (Ubuntu font).

8. **Reduce the image footprint** by removing compilers and network tools from the final image.

## Reporting a Vulnerability

Open an issue on the [GitHub repository](https://github.com/flaccid/container-debian-desktop/issues) for any security concerns.

## Disclaimer

This container is designed for convenience and developer productivity. It trades some security hardening for usability (passwordless sudo, --no-sandbox browsers, VNC without auth behind oauth2-proxy). Deploy with awareness of these trade-offs and apply the recommendations above for any production-facing installation.
