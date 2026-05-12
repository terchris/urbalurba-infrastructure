---
status: backlog
created: 2026-05-12
related:
  - INVESTIGATE-networking-restructure-and-cloudflare-in-cluster.md
  - PLAN-cloudflare-network-port-and-docs-lift-up.md
---

# INVESTIGATE: Tailscale architecture cleanup

Tailscale is out of scope for the cloudflare-network-port-and-docs-lift-up round
(rancher-desktop + `*.skryter.no` only). This file captures the issues found
while surveying the networking codebase so a future round can pick them up
without re-doing the discovery.

The cloudflare CLI port (`uis network ... cloudflare`) leaves Tailscale alone:
the legacy verbs (`uis tailscale ...`, `uis deploy tailscale-tunnel`) still work
and `tailscale-tunnel` stays as a `services.json` entry.

---

## Problem 1 — Helm release name collision between 802 and 805

Two different playbooks both install the same Helm release:

- `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml:29`
  `operator_release_name: "tailscale-operator"` in namespace `tailscale`
- `ansible/playbooks/805-deploy-tailscale-internal-ingress.yml:31`
  `operator_release_name: "tailscale-operator"` in namespace `tailscale`

The chart reference and values differ but the release name + namespace are
identical, so whichever playbook runs second overwrites the first's release.

The intended split (per the surrounding code + 800-tailscale-operator-config
template) is:

- 802 = public Funnel device for outbound exposure
- 805 = internal-only ingress for tailnet-private services

They are not meant to be the same Helm release. The fix is either:

1. **Distinct release names** (e.g. `tailscale-operator-funnel` for 802,
   `tailscale-operator-ingress` for 805) and document that they coexist, or
2. **One canonical operator install** with values that cover both use cases —
   then 802 and 805 become pure-data playbooks (Service / Ingress objects) that
   reference the shared operator.

Option 2 is closer to Tailscale's own intended model. It is the larger lift.

---

## Problem 2 — Five different variable names for the same concept

`grep -E '^TAILSCALE_' .uis.secrets/secrets-config/00-common-values.env.template`
shows the current shape:

```
TAILSCALE_SECRET=
TAILSCALE_TAILNET=
TAILSCALE_DOMAIN=
TAILSCALE_PUBLIC_HOSTNAME=k8s
TAILSCALE_CLIENTID=
TAILSCALE_CLIENTSECRET=
TAILSCALE_OPERATOR_PREFIX=k8s
```

The two auth paths (`SECRET` = legacy auth key; `CLIENTID`+`CLIENTSECRET` =
OAuth client) are both wired up. Different playbooks read different subsets:

- 801 reads `TAILSCALE_SECRET` + `TAILSCALE_DOMAIN`
- 805 reads `TAILSCALE_CLIENTID`/`CLIENTSECRET`/`DOMAIN`/`OPERATOR_PREFIX`

`TAILSCALE_TAILNET` exists in the template but no playbook reads it. The
integration test config (`provision-host/uis/lib/integration-testing.sh:28`)
gates on `CLIENTID,CLIENTSECRET,DOMAIN`, not `SECRET` — so the legacy auth-key
path is silently untested.

Investigation should answer:

- Which auth path is the supported one going forward (OAuth client vs auth key)?
- Can we delete the unused vars from `00-common-values.env.template` and the
  paths that read them, or do we need to keep both for back-compat?
- If keeping both: document which playbook needs which, and make the
  integration-test gate cover the chosen path.

---

## Problem 3 — `tailscale-tunnel` service abstraction is misleading

`website/src/data/services.json` registers `tailscale-tunnel` as a deployable
"service" the same way `cloudflare-tunnel` was. The PLAN to lift networking out
of services.json (executed for Cloudflare) treats this as a category error:
a tunnel is a networking provider, not a service.

After the Tailscale port to `uis network <verb> tailscale`, the
`tailscale-tunnel` entry should be removed from services.json and replaced by:

- `provision-host/uis/services/networking/service-tailscale-tunnel.sh` →
  delete (currently the legacy `uis deploy` path's metadata)
- `networking/tailscale/scripts/{init,up,down,status,verify}.sh` → new

That mirrors the Cloudflare port and unblocks the symmetric `uis network list`
table emitting real per-provider state.

---

## Out of scope for this investigation

- Cloudflare changes — shipped via PLAN-cloudflare-network-port-and-docs-lift-up
- AKS / non-rancher-desktop clusters — Tailscale Funnel works the same shape
  regardless of cluster, but verification should happen on rancher-desktop first
- DNS automation — `CLOUDFLARE_DNS_TOKEN` and Tailscale DNS provisioning are a
  separate follow-up; this investigation is about the operator + auth surface
