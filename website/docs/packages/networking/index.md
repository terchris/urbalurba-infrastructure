---
title: Networking
sidebar_label: Networking
---

# Networking

VPN tunnels and network access. Deploy the services your application needs.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [Cloudflare Tunnel](./cloudflare-tunnel.md) | Secure tunnel to Cloudflare network | `./uis deploy cloudflare-tunnel` |
| [Tailscale Tunnel](./tailscale-tunnel.md) | Secure mesh VPN tunnel | `./uis deploy tailscale-tunnel` |

## Quick Start

Deploy the services you need:

```bash
./uis deploy cloudflare-tunnel
./uis deploy tailscale-tunnel
```
