---
title: Tailscale Tunnel
sidebar_label: Tailscale Tunnel
---

# Tailscale Tunnel

Secure mesh VPN tunnel for exposing services via Tailscale Funnel.

| | |
|---|---|
| **Category** | Networking |
| **Deploy** | `./uis deploy tailscale-tunnel` |
| **Undeploy** | `./uis undeploy tailscale-tunnel` |
| **Depends on** | nginx |
| **Required by** | None |
| **Helm chart** | `tailscale/tailscale-operator` (unpinned) |
| **Default namespace** | `tailscale` |

## What It Does

Tailscale Tunnel creates a secure mesh VPN connection between your local cluster and the Tailscale network. Once connected, you can expose services to the internet via Tailscale Funnel without opening firewall ports or configuring DNS manually.

Key capabilities:
- **Zero-config networking** — no port forwarding or firewall rules needed
- **Tailscale Funnel** — expose services to the internet with HTTPS
- **Per-service exposure** — choose which services to make accessible
- **Built-in TLS** — automatic HTTPS certificates via Tailscale

:::warning Requires Tailscale Account
This service requires a Tailscale account and API credentials. Configure them via `./uis secrets edit` before deploying.
:::

## Deploy

```bash
# Deploy dependency first
./uis deploy nginx

# Deploy Tailscale Tunnel
./uis deploy tailscale-tunnel
```

## Verify

```bash
# Quick check
./uis verify tailscale-tunnel

# Or use the service-specific command
./uis tailscale verify
```

## Configuration

### Tailscale-Specific Commands

| Command | Description |
|---------|-------------|
| `./uis tailscale expose <service-id>` | Expose a service via Tailscale Funnel |
| `./uis tailscale unexpose <service-id>` | Remove a service from Tailscale Funnel |
| `./uis tailscale verify` | Check secrets, API, devices, and operator |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `TAILSCALE_CLIENT_ID` | `.uis.secrets/secrets-config/default-secrets.env` | OAuth client ID |
| `TAILSCALE_CLIENT_SECRET` | `.uis.secrets/secrets-config/default-secrets.env` | OAuth client secret |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml` | Deployment playbook |
| `ansible/playbooks/802-remove-network-tailscale-tunnel.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy tailscale-tunnel
```

## Troubleshooting

**Operator pod won't start:**
```bash
kubectl describe pod -n tailscale -l app.kubernetes.io/name=tailscale-operator
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
```

**Funnel not working:**
Check that the Tailscale node is registered:
```bash
./uis tailscale verify
```

**Authentication errors:**
Tailscale OAuth requires token exchange, not basic auth. Verify secrets:
```bash
./uis secrets status
```

## Learn More

- [Official Tailscale documentation](https://tailscale.com/kb/)
- [Tailscale Funnel docs](https://tailscale.com/kb/1223/funnel)
