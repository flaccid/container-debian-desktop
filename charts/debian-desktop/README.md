# debian-desktop

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![AppVersion: 1.19.0](https://img.shields.io/badge/AppVersion-1.19.0-informational?style=flat-square)

A Helm chart to deploy a persistent, web-based Linux desktop environment.

## 🚀 TL;DR

```console
helm install my-desktop ./charts/debian-desktop --namespace desktop-webvnc --create-namespace
```

## 📖 Introduction

This chart bootstraps a Debian desktop environment on a [Kubernetes](https://kubernetes.io) cluster using the Helm package manager. It is designed for maximum stability and security, specifically focusing on:

*   **True Persistence**: Safely mounts user directories via PersistentVolumeClaims.
*   **Seamless OAuth Integration**: Uses an Nginx sidecar container to transparently inject Basic Authentication headers, allowing you to secure the desktop behind tools like `oauth2-proxy` without forcing the user to log in twice.
*   **Kubernetes-Native Design**: Manages file ownership and UI components using Kubernetes native features like `initContainers` for maximum stability.

## 📋 Prerequisites

*   Kubernetes 1.23+
*   Helm 3.0+
*   PV provisioner support in the underlying infrastructure (e.g., Longhorn, EBS, EFS) for persistence.
*   An Ingress Controller (e.g., ingress-nginx) if exposing externally.

## 📦 Installing the Chart

To install the chart with the release name `my-desktop`:

```console
helm install my-desktop ./charts/debian-desktop -n desktop-webvnc --create-namespace
```

The command deploys the desktop on the Kubernetes cluster in the default configuration.

## 🗑️ Uninstalling the Chart

To uninstall/delete the `my-desktop` deployment:

```console
helm uninstall my-desktop -n desktop-webvnc
```

The command removes all the Kubernetes components associated with the chart and deletes the release. By default, PersistentVolumeClaims may be retained depending on your cluster's reclaim policy.

## 🏗️ Architecture & Quirks

This chart employs a specific architecture to provide a stable, persistent desktop experience:

1.  **StatefulSet over Deployment**: Guarantees stable mounting and detachment of `ReadWriteOnce` Persistent Volumes, eliminating "Multi-Attach" errors during pod recreation.
2.  **`fix-permissions-and-ui` (InitContainer)**: 
    *   Fixes the permissions of the dynamically provisioned PVC to ensure the admin user has read/write access.
    *   Modifies the web UI to fix UI bugs and force default behaviors like "Automatic Reconnect".
3.  **`nginx-auth-injector` (Sidecar)**: Nginx intercepts incoming traffic on port `8080`, injects the hardcoded HTTP Basic Authentication credentials, and proxies traffic locally.
4.  **Passwordless Sudo**: Mounts a custom `sudoers` file via ConfigMap to grant the internal admin user passwordless root access for installing packages.

## ⚙️ Configuration Parameters

The following table lists the configurable parameters of the `debian-desktop` chart.

### Image Configuration
| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Debian desktop image repository | `flaccid/debian-desktop` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `nginx.image.repository` | Nginx sidecar image repository | `nginx` |
| `nginx.image.tag` | Nginx sidecar image tag | `alpine` |

### Environment Variables
| Parameter | Description | Default |
|-----------|-------------|---------|
| `env.tz` | Timezone of the desktop container | `Australia/Sydney` |

### Resources & Persistence
| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.requests.memory`| Memory request | `1Gi` |
| `resources.limits.cpu` | CPU limit | `2000m` |
| `resources.limits.memory` | Memory limit | `4Gi` |
| `persistence.enabled` | Enable Persistent Volume Claim | `true` |
| `persistence.size` | Size of the PVC | `5Gi` |
| `persistence.storageClass` | Storage class to use (empty string uses cluster default) | `""` |
| `persistence.accessMode` | PVC Access Mode | `ReadWriteOnce` |

### Networking
| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.clusterIP.port` | Internal ClusterIP service port | `8080` |
| `service.loadBalancer.enabled`| Deploy an external LoadBalancer | `true` |
| `service.loadBalancer.port` | LoadBalancer external port | `80` |

### Ingress & Authentication
| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable Nginx Ingress resource | `true` |
| `ingress.className` | Ingress controller class | `nginx` |
| `ingress.host` | Hostname for the desktop access | `desktop.domain.com` |
| `ingress.authUrl` | URL to the oauth2-proxy authentication endpoint | `http://oauth2-proxy.../oauth2/auth` |
| `ingress.authSignin`| URL to redirect unauthenticated users | `https://desktop.../oauth2/start?...` |
| `oauth2Proxy.ingress.enabled` | Deploy an ingress rule specifically for the oauth2-proxy | `true` |
| `oauth2Proxy.ingress.host`| Hostname for the oauth2-proxy ingress | `desktop.domain.com` |
| `oauth2Proxy.ingress.path`| Path for the oauth2-proxy ingress | `/oauth2` |
