# container-debian-desktop

## Overview
- This repository contains the Dockerfile for building a persistent Debian Trixie desktop environment.
- It is designed as a lightweight, flexible, and fully controllable replacement for opinionated desktop images when deploying within a Kubernetes cluster.

## Key Features:

*   **Debian Trixie Base:** Provides a stable and modern desktop OS built from `debian:trixie-slim`.
*   **XFCE Desktop Environment:** A lightweight and efficient graphical interface.
*   **TigerVNC Server:** A robust, standard VNC implementation that reliably handles session management without dropping connections in multi-client setups.
*   **noVNC:** An open-source, web-based VNC client that uses WebSockets for browser access (served via `websockify`).
*   **Persistence-Ready:** Specifically designed to work flawlessly with Kubernetes PersistentVolumeClaims (PVCs). Mounting a PVC to `/home/admin` will inherently persist all application settings, browser profiles, and desktop configurations.
*   **Security:**
    *   Runs strictly as a non-root user (`admin`, UID 1000) for better container security practices, neatly side-stepping permission issues with PVCs.
    *   Includes a pre-configured `sudoers` file allowing passwordless `sudo` access for the user, providing full administrative control without requiring root entrypoints.
    *   Automatically generates and utilizes self-signed SSL certificates to encrypt the noVNC WebSocket traffic (`HTTPS`/`WSS`) on port 6901.

## Build Process:

To build the Docker image:

```bash
docker build -t flaccid/debian-desktop:latest .
```

*(You can tag and push this to your preferred container registry such as Docker Hub, GHCR, or a private registry)*

## Usage

This image exposes port `6901` (HTTPS). You can run it locally with Docker:

```bash
docker run -p 6901:6901 -v desktop_data:/home/admin flaccid/debian-desktop:latest
```
Then navigate to `https://localhost:6901` in your web browser. 

**Default Credentials:**
*   Username: `admin`
*   Password: No authentication is required for VNC (traffic is served over HTTPS/WSS via noVNC).

### Kubernetes Deployment
This image acts as a seamless drop-in replacement for desktop deployments. Because it natively runs as UID 1000, it avoids the "permission denied" loops often seen with other images trying to force `chown` operations on bound PVCs. Furthermore, `TigerVNC` and `websockify` have exceptional resilience against reverse-proxy connection drops (like Cloudflare), inherently fixing the "Connecting..." hang bug encountered when sharing sessions across multiple computers.
