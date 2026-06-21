# Getting Started

This guide walks through deploying the Debian desktop, either on Kubernetes with Helm or locally with Docker.

## Kubernetes (Helm)

Deploying on Kubernetes gives you a persistent, remotely accessible desktop that survives pod restarts and can be exposed securely with OAuth authentication.

### Prerequisites

- A Kubernetes cluster (v1.26+)
- `kubectl` configured with cluster access
- `helm` v3.8+ installed
- An Ingress controller (this guide assumes [ingress-nginx](https://kubernetes.github.io/ingress-nginx/))
- [cert-manager](https://cert-manager.io/) or another TLS certificate solution (recommended for production)

### Add the Helm repository

```bash
helm repo add debian-desktop https://flaccid.github.io/container-debian-desktop
helm repo update
```

### Quick install (no auth)

For internal or test clusters where you control network access:

```bash
helm install my-desktop debian-desktop/debian-desktop \
  --set ingress.enabled=false \
  --set service.loadBalancer.enabled=true
```

This creates a LoadBalancer Service on port 80. Access the desktop by finding the external IP:

```bash
kubectl get svc my-desktop-debian-desktop
```

Open `http://<EXTERNAL-IP>` in a browser.

> **⚠️ Warning**: Exposing the desktop without authentication means anyone who reaches the address can access your desktop. Only use this on networks you fully trust, or pair with network-level access controls (firewall rules, private subnet, VPN). For any public or semi-public endpoint, follow the secure install below.

### Secure install (recommended — with OAuth)

The Helm chart includes [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) as a subchart. This guide uses Google as the identity provider — the same pattern works with GitHub, Microsoft, or any OpenID Connect provider.

#### 1. Create an OAuth application

**For Google:**

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project or select an existing one.
3. Navigate to **APIs & Services** → **Credentials**.
4. Click **Create Credentials** → **OAuth client ID**.
5. Set **Application type** to **Web application**.
6. Under **Authorized redirect URIs**, add:
   ```
   https://desktop.your-domain.com/oauth2/callback
   ```
7. Click **Create**. Note the **Client ID** and **Client Secret**.

Generate a random cookie secret for oauth2-proxy:

```bash
python3 -c "import secrets; print(secrets.token_hex(16))"
```

#### 2. Create a values file

```yaml
# helm-values.yaml
ingress:
  host: desktop.your-domain.com

oauth2Proxy:
  ingress:
    host: desktop.your-domain.com

oauth2-proxy:
  enabled: true
  config:
    redirectUrl: "https://desktop.your-domain.com/oauth2/callback"
    clientId: "<YOUR_CLIENT_ID>"
    clientSecret: "<YOUR_CLIENT_SECRET>"
    cookieSecret: "<YOUR_COOKIE_SECRET>"
    authenticatedEmails:
      - your@email.com

persistence:
  size: 20Gi
```

#### 3. Install

```bash
helm install my-desktop debian-desktop/debian-desktop -f helm-values.yaml
```

After a minute, your desktop should be available at `https://desktop.your-domain.com`. The first visit will redirect to Google's sign-in page, then back to the desktop.

> TLS termination is handled by your Ingress controller (typically via cert-manager + Let's Encrypt). The nginx sidecar inside the pod serves plain HTTP — the Ingress handles HTTPS.

### Upgrading

```bash
# Pull latest chart and update your values file if needed
helm repo update

# Upgrade the release
helm upgrade my-desktop debian-desktop/debian-desktop -f helm-values.yaml

# Roll back if something goes wrong
helm rollback my-desktop <REVISION>
```

### Ports reference

| Port | Container | Purpose |
|------|-----------|---------|
| 6901 | desktop   | noVNC (HTTPS/WSS) |
| 6902 | desktop   | Audio WebSocket |
| 8080 | nginx     | Reverse proxy to 6901 + audio |

### Architecture

```
Browser ──HTTPS──> Ingress ──HTTP──> nginx sidecar (:8080)
  / ──────────────────────────────────> websockify (:6901) ──TCP──> TigerVNC (:5901)
  /audio/ ────────────────────────────> websockify (:6902) ──TCP──> audio-proxy (:5711)
  /oauth2 ────────────────────────────> oauth2-proxy
```

### Setting a password (for lock screen)

```bash
kubectl exec <pod-name> -c desktop -- passwd admin
```

The password is synced to persistent storage every 2 minutes and survives pod restarts. See the [lock screen and screensaver guide](getting-started.md#lock-screen-and-screensaver) below for details.

---

## Docker

Running locally is ideal for testing, development, or using the desktop as an ad-hoc environment.

### Prerequisites

- Docker installed (20.10+)
- At least 2 GB of available RAM

### Quick start

```bash
docker run -d --name my-desktop -p 6901:6901 flaccid/debian-desktop:latest
```

Open **https://localhost:6901** in a browser and accept the self-signed certificate warning.

### With persistent home directory

```bash
docker run -d --name my-desktop \
  -p 6901:6901 \
  -v desktop-data:/home/admin \
  flaccid/debian-desktop:latest
```

Your home directory, config, and installed files survive container restarts.

### With audio streaming

To expose the audio WebSocket (needed for direct Docker access — the nginx sidecar is only present in Helm deployments):

```bash
docker run -d --name my-desktop \
  -p 6901:6901 \
  -p 6902:6902 \
  flaccid/debian-desktop:latest
```

The noVNC audio plugin on port 6901 connects to the audio websockify on port 6902 automatically when both are mapped.

### Using a specific version

```bash
docker run -d --name my-desktop -p 6901:6901 flaccid/debian-desktop:v0.12.0
```

Available tags: `latest`, `v0.x.y`, and `sha-<commit>` — see [Docker Hub](https://hub.docker.com/r/flaccid/debian-desktop).

### Tips

- **Screen resolution**: The default is 1024×768. Override with the `GEOMETRY` env var:
  ```bash
  docker run -e GEOMETRY=1920x1080 ...
  ```
- **Time zone**: Set via the `TZ` env var:
  ```bash
  docker run -e TZ=America/New_York ...
  ```
- **Cleanup**: Remove the container when done:
  ```bash
  docker rm -f my-desktop
  ```

---

## Lock screen and screensaver

The desktop ships with the screensaver disabled and manual lock screen enabled. To set a password (required for the lock to actually prevent access):

```bash
# Kubernetes
kubectl exec <pod> -c desktop -- passwd admin

# Docker
docker exec <container> passwd admin
```

To enable the screensaver, open the XFCE menu → **Settings** → **Screensaver**. The idle timeout is pre-configured to 1 hour.

## Signing out

When deployed via Helm with oauth2-proxy, a **Sign Out** button appears in the noVNC control bar. Click it to revoke the OAuth session and return to the sign-in page.

## Troubleshooting

### Desktop won't load in browser

- Check the pod is running: `kubectl get pods`
- Check the service endpoints: `kubectl get svc`
- Verify the Ingress is configured and the DNS record points to your cluster

### Audio not working

- Click anywhere on the noVNC page to satisfy the browser autoplay policy
- Open the noVNC Settings panel → **Audio Plugin** → confirm **Enabled** is checked
- In the container, verify PulseAudio is running:
  ```bash
  kubectl exec <pod> -c desktop -- su admin -c 'pactl info'
  ```

### Can't connect to audio stream (Docker)

Ensure port 6902 is published:
```bash
docker run -p 6901:6901 -p 6902:6902 ...
```

### Lock screen denies access

No password is set. Run `passwd admin` inside the container. Debian's PAM rejects empty passwords.
