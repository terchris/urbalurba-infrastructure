---
title: Networking
sidebar_label: Networking
---

# Networking services

This page lists networking services that are deployed as in-cluster pods via the standard `uis deploy` pipeline. For tunnel providers (Cloudflare, Tailscale), see the top-level [Networking](/docs/networking/) section — those use the `uis network <verb> <provider>` family.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [Traefik](./traefik.md) | IngressRoute controller — terminates HTTP/HTTPS and routes by hostname | `./uis deploy traefik` |
| [Tailscale Tunnel](./tailscale-tunnel.md) | Tailscale Funnel + operator (legacy CLI — port to `uis network` pending) | `./uis deploy tailscale-tunnel` |

## Tunnel providers

For Cloudflare and Tailscale tunnels, use the unified network CLI:

```bash
./uis network init cloudflare    # set up Cloudflare
./uis network up cloudflare      # deploy
./uis network list               # see all providers
```

See **[Networking → Cloudflare](/docs/networking/cloudflare)** for the full walkthrough.
