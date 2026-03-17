---
title: Cloudflare Tunnel
sidebar_label: Cloudflare Tunnel
---

# Cloudflare Tunnel

Secure tunnel to expose services via Cloudflare's network.

| | |
|---|---|
| **Category** | Networking |
| **Deploy** | `./uis deploy cloudflare-tunnel` |
| **Undeploy** | `./uis undeploy cloudflare-tunnel` |
| **Depends on** | nginx |
| **Required by** | None |
| **Image** | `cloudflare/cloudflared` |
| **Default namespace** | `default` |

## What It Does

Cloudflare Tunnel creates an outbound-only connection from your cluster to Cloudflare's edge network. This lets you expose services on a custom domain (e.g., `service.yourdomain.com`) without opening inbound ports or managing TLS certificates.

Key capabilities:
- **Outbound-only** — no inbound firewall rules needed
- **Custom domain** — services available on your own domain
- **Automatic TLS** — Cloudflare handles HTTPS certificates
- **DDoS protection** — Cloudflare's edge network shields your services

:::warning Requires Cloudflare Account
This service requires a Cloudflare account with a registered domain and tunnel token. Configure them via `./uis secrets edit` before deploying.
:::

## Deploy

```bash
# Deploy dependency first
./uis deploy nginx

# Deploy Cloudflare Tunnel
./uis deploy cloudflare-tunnel
```

## Verify

```bash
# Quick check
./uis verify cloudflare-tunnel

# Or use the service-specific command
./uis cloudflare verify
```

## Configuration

### Cloudflare-Specific Commands

| Command | Description |
|---------|-------------|
| `./uis cloudflare verify` | Check tunnel network and pod status |
| `./uis cloudflare teardown` | Remove tunnel (shows manual dashboard steps) |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `CLOUDFLARE_TUNNEL_TOKEN` | `.uis.secrets/secrets-config/default-secrets.env` | Tunnel authentication token |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/820-deploy-network-cloudflare-tunnel.yml` | Deployment playbook |
| `ansible/playbooks/820-remove-network-cloudflare-tunnel.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy cloudflare-tunnel
```

Services will no longer be accessible via the custom domain. The tunnel configuration in the Cloudflare dashboard may need manual cleanup.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app=cloudflare-tunnel
kubectl logs -l app=cloudflare-tunnel
```

**Tunnel shows "inactive" in Cloudflare dashboard:**
Check that the tunnel token is correct:
```bash
./uis secrets status
./uis cloudflare verify
```

**Custom domain returns 502:**
The backend service (usually nginx) may not be running:
```bash
kubectl get pods -l app=nginx
```

## Learn More

- [Official Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
