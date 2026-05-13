---
title: Networking
sidebar_label: Overview
sidebar_position: 1
---

# Networking

UIS targets **multiple networking providers** from a single command interface. Cloudflare tunnels expose services on a domain you own. Tailscale Funnel + Tailscale internal ingress give you tunnel-style or VPN-style access without a public domain. All of them speak the same `uis network ...` vocabulary, so swapping the path your services take to the internet is a CLI flag away.

## See what you have

`uis network list` shows every provider UIS knows about and its current state:

```
$ uis network list
PROVIDER     STATUS                                  HINT
cloudflare   ✓ running                               1/1 cloudflared pods up
tailscale    · pending CLI port                      use legacy verbs: ./uis tailscale ...
```

The status column uses the same four-state vocabulary as `uis platform list`:

| State | Meaning | Typical hint |
|---|---|---|
| `✓ running` | Provider is deployed and at least one pod is in the `Running` phase | provider-specific (e.g. `1/1 cloudflared pods up`) |
| `· configured, not running` | `init` has been run (env file exists), no provider deployment in the cluster | `run './uis network up <provider>' to deploy` |
| `· not initialized` | UIS has no configuration for this provider yet | `run './uis network init <provider>' to set up` |
| `✗ unreachable` | Deployment exists but no pods are Running | `check 'kubectl -n default logs -l app=<provider>'` |

The list emits no probes against external services — it inspects the local secrets file and the in-cluster deployment only.

## Vocabulary

Every provider supports the same five verbs:

| Verb | What it does |
|---|---|
| `uis network init <provider>` | Interactive wizard that writes `.uis.secrets/service-keys/<provider>.env` and patches `secrets-config/00-common-values.env.template` so `uis secrets generate` picks up the value. |
| `uis network up <provider>` | Runs `uis secrets generate` + `uis secrets apply` (pushes credentials into the `urbalurba-secrets` k8s Secret), then deploys the in-cluster manifest for the provider. |
| `uis network status <provider>` | Shows config + pod state for the provider. `--summary` flag emits the tab-separated `<state>\t<hint>` line consumed by `uis network list`. |
| `uis network verify <provider>` | End-to-end checks: secrets, DNS, port reachability, pod logs, HTTPS probe through the tunnel. |
| `uis network down <provider>` | Removes the in-cluster deployment. The provider-side configuration (e.g. the tunnel in the Cloudflare dashboard) is preserved. |

The wizard never deploys anything. Init writes config; up deploys.

## Provider status

| Provider | CLI port | Deploy path | Notes |
|---|---|---|---|
| **Cloudflare** | ✅ `uis network ... cloudflare` | In-cluster `cloudflared` pods, token-based | Verified on rancher-desktop with `*.skryter.no`. See [Cloudflare tunnel](./cloudflare.md). |
| **Tailscale** | ⏳ pending | Legacy verbs: `uis tailscale ...`, `uis deploy tailscale-tunnel` | Funnel + internal ingress both work today via legacy CLI. Port to `uis network ... tailscale` is tracked in `INVESTIGATE-tailscale-architecture-cleanup.md`. |

## How traffic reaches your services

Cluster services are matched by Traefik `HostRegexp` ingress rules (e.g. `whoami\..+`). The same IngressRoute resolves three different paths to the same backend pod:

- `whoami.localhost` — direct on the developer laptop
- `whoami.<device>.ts.net` — through Tailscale Funnel
- `whoami.skryter.no` — through Cloudflare tunnel

You don't change the ingress to switch providers — you add or remove the network path. See [Traefik](../services/networking/traefik.md) for the ingress controller details and [Traefik ingress rules](../contributors/rules/ingress-traefik.md) for the `HostRegexp` pattern.

## Pages in this section

- **[Cloudflare tunnel](./cloudflare.md)** — set up `cloudflared` in-cluster, point a domain at it. Token-based, no inbound ports.
- **[Cloudflare setup (deep dive)](./cloudflare-setup.md)** — historical setup guide. Covers DNS, dashboard config, multiple environments.
- **[Tailscale Funnel setup](./tailscale-setup.md)** — public `*.ts.net` exposure with Tailscale Funnel.
- **[Tailscale network isolation](./tailscale-network-isolation.md)** — ACL patterns for restricting who reaches what.
