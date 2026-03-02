---
title: Nginx
sidebar_label: Nginx
---

# Nginx

Catch-all web server that serves as the default backend for unmatched routes.

| | |
|---|---|
| **Category** | Management |
| **Deploy** | `./uis deploy nginx` |
| **Undeploy** | `./uis undeploy nginx` |
| **Depends on** | None |
| **Required by** | tailscale-tunnel, cloudflare-tunnel |
| **Image** | `nginx:alpine` |
| **Default namespace** | `default` |

## What It Does

Nginx serves as the catch-all web server in UIS. It has the lowest-priority Traefik IngressRoute (priority 1), meaning any request that doesn't match a specific service route gets routed to Nginx. This provides a friendly "Hello World" landing page instead of a Traefik 404 error.

Key roles:
- **Default backend** — catches all unmatched HTTP requests
- **Landing page** — serves content from `testdata/website/` directory
- **Tunnel endpoint** — Tailscale and Cloudflare tunnels route through Nginx
- **Health check target** — verifies that Traefik routing works

## Deploy

```bash
./uis deploy nginx
```

No dependencies. Nginx is typically deployed early in the setup process.

## Verify

```bash
# Quick check
./uis verify nginx

# Manual check
kubectl get pods -n default -l app=nginx

# Test the catch-all (any unregistered hostname works)
curl http://localhost
```

## Configuration

Nginx has minimal configuration. Content is served from a PVC populated with `testdata/website/index.html`.

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `80` | HTTP |
| Priority | `1` | Lowest Traefik IngressRoute priority |
| Content | PVC | From `testdata/website/` |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/020-setup-nginx.yml` | Deployment playbook |
| `ansible/playbooks/020-remove-nginx.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy nginx
```

Tailscale and Cloudflare tunnels depend on Nginx and should be removed first. Without Nginx, unmatched routes will return Traefik's default 404 page.

## Troubleshooting

**Getting Nginx page instead of expected service:**
The service's IngressRoute priority must be higher than 1. Check:
```bash
kubectl get ingressroute -A
```

**Pod won't start:**
```bash
kubectl describe pod -l app=nginx
kubectl logs -l app=nginx
```

## Learn More

- [Official Nginx documentation](https://nginx.org/en/docs/)
