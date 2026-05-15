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

## Tunnel providers

Cloudflare and Tailscale tunnels are managed through the unified network CLI, not `uis deploy`:

```bash
./uis network init cloudflare    # set up Cloudflare
./uis network up cloudflare      # deploy
./uis network init tailscale     # set up Tailscale
./uis network up tailscale       # deploy
./uis network list               # see all providers
```

See **[Networking → Cloudflare](/docs/networking/cloudflare)** and **[Networking → Tailscale](/docs/networking/tailscale)** for the full walkthroughs.
