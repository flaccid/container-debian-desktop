# oauth2-proxy

A subchart for the `debian-desktop` Helm chart that deploys [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) as an SSO sidecar.

Deployed as a separate `Deployment` in the same namespace, it authenticates users via Google OAuth before they reach the noVNC desktop. The parent chart's `Ingress` routes `/oauth2/` to this service.

## Configuration

All values live under the `.oauth2-proxy` key in the parent chart's values.

| Key | Default | Description |
|---|---|---|
| `enabled` | `true` | Enable or disable the subchart |
| `replicaCount` | `1` | Number of replicas |
| `image.repository` | `quay.io/oauth2-proxy/oauth2-proxy` | oauth2-proxy image |
| `image.tag` | `latest` | Image tag |
| `config.provider` | `google` | OAuth provider |
| `config.redirectUrl` | `""` | OAuth redirect URL (**required**) |
| `config.clientId` | `""` | OAuth client ID (**required**, stored in Secret) |
| `config.clientSecret` | `""` | OAuth client secret (**required**, stored in Secret) |
| `config.cookieSecret` | `""` | Cookie encryption secret (**required**, stored in Secret) |
| `config.cookieSecure` | `true` | Set `Secure` flag on cookies |
| `config.httpAddress` | `0.0.0.0:4180` | Internal listen address |
| `config.authenticatedEmails` | `[]` | List of allowed email addresses |
| `config.setAuthorizationHeader` | `true` | Forward user info via `Authorization` header |
| `config.passBasicAuth` | `true` | Pass basic auth to upstream |
| `config.basicAuthPassword` | `password` | Basic auth password sent upstream |

## Resources

Values under `.oauth2-proxy.resources` follow the standard Kubernetes resource spec. Defaults:

```yaml
requests:
  memory: 64Mi
  cpu: 50m
limits:
  memory: 256Mi
  cpu: 200m
```

## Templates

| Template | Description |
|---|---|
| `secret.yaml` | Opaque Secret with `client-id`, `client-secret`, `cookie-secret` |
| `emails-configmap.yaml` | ConfigMap with `emails.txt` listing authenticated email addresses |
| `deployment.yaml` | Deployment with env vars from Secret and volume-mounted emails |
| `service.yaml` | ClusterIP service on port 80 → 4180 |

## Dependencies

This subchart is a file-based dependency of the parent `debian-desktop` chart, referenced as `file://./charts/oauth2-proxy` in the parent's `Chart.yaml`.
