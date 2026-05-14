---
title: Tailscale Funnel
sidebar_label: Tailscale
sidebar_position: 3
---

# Tailscale Funnel

Expose services on the public internet through Tailscale's edge — no domain, no DNS provider, no inbound ports. The cluster runs the Tailscale Kubernetes operator, which holds an outbound-only connection and registers one device per exposed service under your `<your-tailnet>.ts.net` domain.

The novice path — from a fresh provision-host container to a service reachable on the public internet — is **three CLI commands plus a one-time dashboard setup**.

:::tip Which provider should I use?
This page is for **Tailscale Funnel** (good for showing a colleague a service running on your laptop). If you own a domain and want a permanent setup with WAF + DDoS, see [Cloudflare tunnel](./cloudflare.md). The [Networking overview](./index.md) has a side-by-side comparison.
:::

## Prerequisites

| Local | Tailscale |
|---|---|
| The UIS provision-host container running (`./uis start`) | An account with a tailnet — sign up at [tailscale.com](https://tailscale.com) (free for personal use, 100 devices) |
| A cluster active (`uis platform list` shows one as `✓ running (active)`) — rancher-desktop works | MagicDNS enabled, Funnel `nodeAttrs` rule in the ACL, and an OAuth client with the right scopes — see [Tailscale setup (deep dive)](./tailscale-setup.md) Steps 2–5 for the dashboard walk-through |

The dashboard prerequisites are a one-time setup. After that, redeploying takes seconds.

:::warning Tailscale Funnel bypasses Traefik
The Tailscale operator's per-service proxy routes directly to the backend Kubernetes Service. Traefik IngressRoutes, Authentik forward-auth middleware, and HostRegexp matching **do not apply** on Tailscale-exposed URLs. If the service needs authentication, the service itself has to enforce it. This is different from Cloudflare, where traffic still flows through Traefik.
:::

## Quick start

```bash
./uis network init tailscale          # 1. wizard prompts for tailnet + OAuth + owner-id
./uis network up tailscale            # 2. install the Tailscale operator in-cluster
./uis network expose tailscale whoami # 3. publish whoami at https://whoami.<your-tailnet>.ts.net
```

The sections below walk through what each command does and what output to expect.

### 1. Set up Tailscale (one-time dashboard work)

Before the CLI works, you need four things from the Tailscale admin console:

1. **An OAuth client** with `Devices Core (write)` + `Auth Keys (write)` scopes, both tagged `tag:k8s-operator`. Capture the Client ID and Client Secret.
2. **An ACL rule** granting `funnel` capability to devices with `tag:k8s-operator`. Without this, devices register but Funnel doesn't activate.
3. **MagicDNS enabled** at `/admin/dns`. Capture your `<words>.ts.net` MagicDNS domain (e.g. `dog-pence.ts.net`).
4. **A reusable auth key** tagged `tag:k8s-operator` (optional — only needed if you also want to provision external Ubuntu VMs into the tailnet via cloud-init).

For the click-by-click walk-through of these dashboard steps — JSON for the ACL, exact scope checkboxes for the OAuth client — see [Tailscale setup (deep dive)](./tailscale-setup.md) Steps 2–5.

### 2. Run the init wizard

```bash
./uis network init tailscale
```

The wizard prompts for four values in order:

1. `TAILSCALE_TAILNET` — your MagicDNS domain from step 1 (e.g. `dog-pence.ts.net`)
2. `TAILSCALE_CLIENTID` — OAuth client ID
3. `TAILSCALE_CLIENTSECRET` — OAuth client secret (input hidden)
4. `TAILSCALE_OWNER_ID` — your identity on the (potentially shared) tailnet (validated as a hostname segment; max 32 chars)

It writes two files:

| File | Used by |
|---|---|
| `.uis.secrets/service-keys/tailscale.env` | `uis network status tailscale` — for the "configured / running" detection |
| `.uis.secrets/secrets-config/00-common-values.env.template` (patched) | `uis secrets generate` — feeds the credentials into the cluster's `urbalurba-secrets` k8s Secret |

If the file already exists, the wizard offers three options: **Skip** (keep existing), **Re-prompt** (overwrite), or **Show** (print current values + path and exit).

About `TAILSCALE_OWNER_ID`: this is your identity on the tailnet. It becomes the prefix for the operator device and (optionally) the cluster Funnel device:

- `<owner_id>-tailscale-operator.<tailnet>.ts.net` — the operator pod
- `<owner_id>.<tailnet>.ts.net` — the cluster Funnel ingress (opt-in via `--with-cluster-funnel`)
- `<service>.<tailnet>.ts.net` — each per-service Funnel device (no owner_id prefix on these)

If you're solo, use your name (`terje`, `alice`). If you're a team sharing one tailnet, use machine-distinctive names (`terje-imac`, `alice-laptop`, `bob-mbp`). The bare default `k8s` collides if two developers deploy against the same tailnet.

### 3. Deploy the operator

```bash
./uis network up tailscale
```

Two stages:

1. **`uis secrets generate` + `uis secrets apply`** — pushes the credentials from the local env file into the `urbalurba-secrets` Secret in the cluster.
2. **`ansible-playbook 800-tailscale-operator-install.yml`** — idempotent Helm install of `tailscale-operator` in the `tailscale` namespace. Waits for the pod to reach `Running`. Cleans up stale operator devices on the tailnet via API pre-install.

The operator registers as `<owner_id>-tailscale-operator.<tailnet>.ts.net`.

**Opt-in cluster Funnel**: if you also want a wildcard cluster ingress at `https://<owner_id>.<tailnet>.ts.net` (Traefik-backed, useful when you have a lot of services and don't want to expose each one individually):

```bash
./uis network up tailscale --with-cluster-funnel
```

The wildcard ingress is **opt-in** because per-service Funnel devices are the canonical exposure model (see step 4) — most users don't need both. The cluster device also consumes Let's Encrypt cert allowance on a hostname that's not always needed.

### 4. Expose a service

```bash
./uis network expose tailscale whoami
# Result: https://whoami.<your-tailnet>.ts.net
```

The first time you expose a per-service Funnel on this cluster, the CLI surfaces a confirmation prompt explaining the Traefik-bypass fact. Use `--yes` to skip it on subsequent calls or in scripts.

What happens:

1. A per-service Tailscale `Ingress` is created in the `default` namespace
2. The operator spawns a proxy pod that registers as `<service>.<tailnet>.ts.net` — note **no owner_id prefix**; the device name is just the service name
3. Funnel is enabled on that device; the cert provisions in ~30–60s
4. The proxy forwards directly to the backend `Service` on port 80

Repeat for any service you want public:

```bash
./uis network expose tailscale grafana
./uis network expose tailscale authentik-server
./uis network expose tailscale open-webui
```

There's a Let's Encrypt rate limit of **5 certs per exact hostname per 7 days**. If you deploy/undeploy the same name repeatedly during testing, you'll hit it and the cert will fail. The fix is either to wait, or to use a different service name.

### 5. Verify

```bash
./uis network verify tailscale
```

Runs four checks:

| # | Check | What it confirms |
|---|---|---|
| 1 | Secrets | `TAILSCALE_CLIENTID`/`CLIENTSECRET`/`TAILNET` are set and not placeholders |
| 2 | API connectivity | OAuth credentials authenticate against the Tailscale API |
| 3 | Stale devices | No leftover `-N`-suffixed devices from prior deploys |
| 4 | Operator | The operator pod is in `Running` state |

A `PASS` on all four means the path is healthy.

### 6. Day-2 commands

```bash
./uis network expose tailscale <service>     # add a service to Funnel
./uis network unexpose tailscale <service>   # remove a service from Funnel (deletes Ingress + tailnet device)
./uis network status tailscale               # operator state + list of exposed services
./uis network list                           # one-line state across all providers
./uis network down tailscale                 # tear down operator + cluster ingress + all per-service devices
```

`down` cleans up tailnet devices via the API as well as the in-cluster state. After `down`, the admin console should show no `<owner_id>-*` or `*-tailscale-operator` devices.

The `.uis.secrets/service-keys/tailscale.env` and patched `00-common-values.env.template` are preserved across `down` / `up` cycles, so you don't have to re-enter the OAuth credentials. Re-run the init wizard for a full reset (or `rm .uis.secrets/service-keys/tailscale.env`).

## How traffic flows

```
internet user
  ↓
Tailscale Funnel edge (terminates TLS, anycast IPs)
  ↓
Tailscale operator proxy pod (outbound-only)
  ↓
backend Kubernetes Service (direct — no Traefik)
  ↓
your service pod
```

The bypass-Traefik part is the key difference from Cloudflare. Each `./uis network expose tailscale ...` creates its own proxy pod, which is why the device name is the service name (no owner_id prefix) — each expose is functionally a separate Tailscale device.

## Team sharing — `TAILSCALE_OWNER_ID`

Five developers on the same tailnet, all running UIS locally, all want to demo their services to each other. The `OWNER_ID` keeps them from colliding:

| Developer | `TAILSCALE_OWNER_ID` | Operator device | Cluster Funnel device |
|---|---|---|---|
| Terje (iMac) | `terje-imac` | `terje-imac-tailscale-operator.dog-pence.ts.net` | `terje-imac.dog-pence.ts.net` |
| Alice (laptop) | `alice-laptop` | `alice-laptop-tailscale-operator.dog-pence.ts.net` | `alice-laptop.dog-pence.ts.net` |
| Bob (MBP) | `bob-mbp` | `bob-mbp-tailscale-operator.dog-pence.ts.net` | `bob-mbp.dog-pence.ts.net` |

Per-service devices are named just `<service>.<tailnet>.ts.net` — those would collide between developers if two of them `expose tailscale whoami` simultaneously. Tailscale resolves the collision by appending `-1`, `-2`, etc. to whoever registered second. For team demos, agree ahead of time who's exposing what.

## Troubleshooting

**`./uis network up tailscale` reports `⚠ Cluster Funnel probe did not return 200 within 240s.` (only with `--with-cluster-funnel`)**

On a fresh `OWNER_ID`, cert + DNS propagation can take 90–120s. The playbook waits up to 240s (`retries: 24, delay: 10`) before reporting the probe as inconclusive. The cluster ingress was applied successfully — just `curl https://<owner_id>.<tailnet>.ts.net` again after a minute or two and you should see Traefik's response.

**OAuth `403 forbidden` errors during `up` or `expose`**

The OAuth client likely doesn't have `tag:k8s-operator` listed under one of the required scopes. Both `Devices → Core (write)` and `Keys → Auth Keys (write)` need the tag added explicitly. Regenerate the client secret after the change, then re-run `./uis network init tailscale` to update the credentials.

**TLS handshake timeout / `429 rateLimited` in the operator pod logs**

You hit the Let's Encrypt 5-cert-per-7-day limit on this exact hostname. Wait for the reset window, or change the hostname (different `OWNER_ID` for cluster Funnel, different service name for per-service). Avoid repeated `up` / `down` cycles with the same name during testing.

**Device gets a `-N` suffix (e.g. `whoami-1`) after expose**

Tailscale appended a suffix because a stale device with the same name still existed. `./uis network verify tailscale` flags this under "Stale Devices". Clean up via `./uis network unexpose tailscale <svc>` followed by `./uis network expose tailscale <svc>`, or delete the stale device manually in the admin console.

**`./uis network up tailscale` refuses with "Owner-id mismatch detected"**

You changed `TAILSCALE_OWNER_ID` in the env file but the operator is still running with the previous value. Tear down first: `./uis network down tailscale`, then re-run `./uis network up tailscale`.

## Cost

Tailscale's free Personal plan covers up to 100 devices and unlimited Funnel exposure — plenty for development and small-team demo work. You pay only if you outgrow the personal plan or want enterprise features (SAML, audit logging, SCIM). The Funnel feature itself has no usage cost.

## Learn more

- [Tailscale Kubernetes operator official docs](https://tailscale.com/kb/1236/kubernetes-operator) — operator architecture, ACL patterns, advanced configuration
- [Tailscale Funnel official docs](https://tailscale.com/kb/1223/funnel) — what Funnel does, limitations, security model
- [Tailscale setup (deep dive)](./tailscale-setup.md) — click-by-click dashboard walk-through for the OAuth/ACL/MagicDNS prerequisites
- [Tailscale network isolation](./tailscale-network-isolation.md) — design proposal for host-network-isolation hardening on top of Funnel (not implemented; design reference)
