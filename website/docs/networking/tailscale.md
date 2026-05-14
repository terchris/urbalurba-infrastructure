---
title: Tailscale Funnel
sidebar_label: Tailscale
sidebar_position: 3
---

# Tailscale Funnel

Expose services on the public internet through Tailscale's edge — no domain, no DNS provider, no inbound ports. The cluster runs the Tailscale Kubernetes operator, which holds an outbound-only connection and registers one device per exposed service under your `<your-tailnet>.ts.net` domain.

The novice path — from a fresh provision-host container to a service reachable on the public internet — is **two CLI commands plus a one-time dashboard setup**.

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
./uis deploy tailscale-tunnel       # 1. install operator + cluster Funnel ingress
./uis tailscale expose whoami       # 2. expose a service on https://whoami.<your-tailnet>.ts.net
./uis tailscale verify              # 3. confirm secrets + API + operator state
```

The sections below walk through what each command does and what output to expect.

### 1. Set up Tailscale (one-time dashboard work)

Before the CLI works, you need four things from the Tailscale admin console:

1. **An OAuth client** with `Devices Core (write)` + `Auth Keys (write)` scopes, both tagged `tag:k8s-operator`. Capture the Client ID and Client Secret.
2. **An ACL rule** granting `funnel` capability to devices with `tag:k8s-operator`. Without this, devices register but Funnel doesn't activate.
3. **MagicDNS enabled** at `/admin/dns`. Capture your `<words>.ts.net` MagicDNS domain (e.g. `dog-pence.ts.net`).
4. **A reusable auth key** tagged `tag:k8s-operator` (only needed if you also want to provision external Ubuntu VMs into the tailnet via cloud-init).

For the click-by-click walk-through of these dashboard steps — JSON for the ACL, exact scope checkboxes for the OAuth client — see [Tailscale setup (deep dive)](./tailscale-setup.md) Steps 2–5.

### 2. Configure secrets

UIS doesn't have a Tailscale wizard yet (that's coming in the next CLI port). For now, edit the secrets file directly:

```bash
vi .uis.secrets/secrets-config/00-common-values.env.template
# Or, from inside the provision-host container:
./uis secrets edit
```

Set these values:

```bash
TAILSCALE_TAILNET=dog-pence.ts.net            # Your MagicDNS domain from step 1
TAILSCALE_OWNER_ID=k8s-yourname               # Per-developer identity on the tailnet
TAILSCALE_CLIENTID=YOUR-OAUTH-CLIENT-ID       # From the OAuth client
TAILSCALE_CLIENTSECRET=tskey-client-...       # From the OAuth client
```

About `TAILSCALE_OWNER_ID`: this is your identity on the (potentially shared) tailnet. It becomes the prefix for every Tailscale device this cluster creates:

- `<owner_id>-tailscale-operator.<tailnet>.ts.net` — the operator pod
- `<owner_id>.<tailnet>.ts.net` — the cluster Funnel ingress
- `<service>.<tailnet>.ts.net` — each per-service Funnel device (no owner_id prefix on these — see Step 4 below)

If you're solo, use your name (`terje`, `alice`). If you're a team sharing one tailnet, use machine-distinctive names (`terje-imac`, `alice-laptop`, `bob-mbp`). The bare default `k8s` collides if two developers deploy against the same tailnet.

Then push the values into the cluster Secret:

```bash
./uis secrets generate
./uis secrets apply
```

### 3. Deploy the operator

```bash
./uis deploy tailscale-tunnel
```

What happens:

1. Helm install `tailscale-operator` in namespace `tailscale`
2. The operator pod registers as `<owner_id>-tailscale-operator.<tailnet>.ts.net`
3. A cluster Funnel `Ingress` is applied, which creates a second device named `<owner_id>.<tailnet>.ts.net` pointing at Traefik's default backend
4. An end-to-end HTTPS probe — for fresh OWNER_IDs this can take 90–120s for cert provisioning + DNS propagation; the playbook waits up to 240s before reporting failure

Confirm the two devices show up in the Tailscale admin console at [/admin/machines](https://login.tailscale.com/admin/machines).

### 4. Expose a service

```bash
./uis tailscale expose whoami
# Result: https://whoami.<your-tailnet>.ts.net
```

What happens:

1. A per-service Tailscale `Ingress` is created in the `default` namespace
2. The operator spawns a proxy pod that registers as `<service>.<tailnet>.ts.net` — note no `<owner_id>` prefix, the device name is just the service name
3. Funnel is enabled on that device; the cert provisions in ~30–60s
4. The proxy forwards directly to the backend `Service` on port 80

Repeat for any service you want public:

```bash
./uis tailscale expose grafana
./uis tailscale expose authentik-server
./uis tailscale expose open-webui
```

There's a Let's Encrypt rate limit of **5 certs per exact hostname per 7 days**. If you deploy/undeploy the same name repeatedly during testing, you'll hit it and the cert will fail. The fix is either to wait, or to change `TAILSCALE_OWNER_ID` (for the cluster device) / use a different service name (for per-service devices).

### 5. Verify

```bash
./uis tailscale verify
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
./uis tailscale expose <service>     # add a service to Funnel
./uis tailscale unexpose <service>   # remove a service from Funnel (deletes Ingress + tailnet device)
./uis tailscale verify               # health checks
./uis undeploy tailscale-tunnel      # tear down operator + cluster ingress + all per-service devices
```

`undeploy` cleans up tailnet devices via the API as well as the in-cluster state. After `undeploy`, the admin console should show no `<owner_id>-*` or `*-tailscale-operator` devices.

The `.uis.secrets/secrets-config/00-common-values.env.template` file is preserved across `undeploy` / `deploy` cycles, so you don't have to re-enter the OAuth credentials. Delete it manually for a full reset.

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

The bypass-Traefik part is the key difference from Cloudflare. Each `./uis tailscale expose` creates its own proxy pod, which is why the device name is the service name (no owner_id prefix) — each expose is functionally a separate Tailscale device.

## Troubleshooting

**`./uis deploy tailscale-tunnel` reports `❌ Tailscale Funnel connectivity test FAILED!`**

On a fresh `OWNER_ID`, cert + DNS propagation can take 90–120s. The playbook waits up to 240s (`retries: 24, delay: 10`) before failing. If you still hit a fail, wait another minute and `curl https://<owner_id>.<tailnet>.ts.net` manually — the system is usually working by then. The fail banner is a verification probe, not a deploy hard-error.

**OAuth `403 forbidden` errors during deploy or expose**

The OAuth client likely doesn't have `tag:k8s-operator` listed under one of the required scopes. Both `Devices → Core (write)` and `Keys → Auth Keys (write)` need the tag added explicitly. Regenerate the client secret after the change and update `TAILSCALE_CLIENTSECRET`.

**TLS handshake timeout / `429 rateLimited` in the operator pod logs**

You hit the Let's Encrypt 5-cert-per-7-day limit on this exact hostname. Wait for the reset window, or change the hostname (different `OWNER_ID` for cluster Funnel, different service name for per-service). Avoid repeated deploy/undeploy cycles with the same name during testing.

**Device gets a `-N` suffix (e.g. `whoami-1`) after expose**

Tailscale appended a suffix because a stale device with the same name still existed. `./uis tailscale verify` flags this under "Stale Devices". Clean up via `./uis tailscale unexpose <svc>` followed by `./uis tailscale expose <svc>`, or delete the stale device manually in the admin console.

## Cost

Tailscale's free Personal plan covers up to 100 devices and unlimited Funnel exposure — plenty for development and small-team demo work. You pay only if you outgrow the personal plan or want enterprise features (SAML, audit logging, SCIM). The Funnel feature itself has no usage cost.

## Learn more

- [Tailscale Kubernetes operator official docs](https://tailscale.com/kb/1236/kubernetes-operator) — operator architecture, ACL patterns, advanced configuration
- [Tailscale Funnel official docs](https://tailscale.com/kb/1223/funnel) — what Funnel does, limitations, security model
- [Tailscale setup (deep dive)](./tailscale-setup.md) — click-by-click dashboard walk-through for the OAuth/ACL/MagicDNS prerequisites
- [Tailscale network isolation](./tailscale-network-isolation.md) — design proposal for host-network-isolation hardening on top of Funnel (not implemented; design reference)
