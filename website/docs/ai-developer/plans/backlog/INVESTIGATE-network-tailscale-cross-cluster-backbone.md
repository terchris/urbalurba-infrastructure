---
status: backlog
created: 2026-05-13
related:
  - INVESTIGATE-tailscale-architecture-cleanup.md
---

# INVESTIGATE: Tailscale as cross-cluster backbone

**Parked — distinct from `INVESTIGATE-tailscale-architecture-cleanup.md`.** That one is about per-service Funnel exposure of services from one cluster. **This** is about cross-cluster connectivity: making multiple UIS clusters mesh through a shared tailnet so workloads on different clusters can reach each other directly.

## The use case

Workloads that need to talk between clusters without going through the public internet:

- **Postgres replication** — primary on AKS, read replicas on rancher-desktop or a second cluster
- **File sync** — Nextcloud / OnlyOffice / object storage across clusters
- **Redis / RabbitMQ** — message bus or shared cache across clusters
- **Backup pipelines** — primary cluster writes to a backup cluster's storage
- **Multi-cluster ArgoCD** — control-plane on one cluster manages apps on others

The headline value: cluster-to-cluster traffic stays inside the tailnet, encrypted and identity-authenticated. No public IPs, no firewall holes, no port-blocking surface (Tailscale uses UDP 41641 with TLS 443 DERP fallback, same as the user-facing Tailscale mode).

## Why Tailscale fits

Tailscale's Kubernetes operator already supports the pieces needed:

- **`Connector` CRD** — exposes cluster CIDR ranges or specific Services as subnet routes / exit nodes on the tailnet. Other clusters' nodes can route to the exposed CIDRs.
- **`tailscale.com/expose` annotation on Service** — makes the Service reachable on the tailnet by hostname.
- **Cross-cluster ingress** — listed as a supported capability in the operator docs.
- **`ProxyGroup` CRD (beta)** — HA proxies for the API-server-proxy use case, which extends to multi-cluster operator-managed setups.

The operator handles all of this from a single Helm install per cluster. Cross-cluster routing is configured via tailnet ACLs + Connector CRDs, not per-Service ingress objects.

## Code I'll watch for in the cleanup round

During `INVESTIGATE-tailscale-architecture-cleanup.md` implementation, anything that hints at cross-cluster patterns gets flagged and preserved:

- **`TAILSCALE_OPERATOR_PREFIX`** is multi-cluster-aware by design (`k8s-terje`, `k8s-imac`, `k8s-tecmacdev` — each cluster gets a distinct operator device on the same tailnet). This naming convention is the foundation a backbone investigation builds on.
- **`803-tailscale-device-cleanup.yml`** uses the Tailscale API to delete stale devices — this matters for multi-cluster setups where devices accumulate across rebuilds. Keep.
- **The OAuth scopes (`Devices Core`, `Auth Keys`, `Services`)** already support what cross-cluster needs. No new auth path required.

The cleanup round won't *add* cross-cluster support, but it shouldn't *remove* the multi-cluster awareness that's already in the codebase. If I see anything that looks like cross-cluster scaffolding (subnet routers, app connectors, multi-cluster Connector resources, etc.), I'll note it and leave it intact.

## Deleted in the cleanup — recoverable from git history

The cleanup (Decision 15 in `INVESTIGATE-tailscale-architecture-cleanup.md`) deletes the internal-mode (805) implementation, which exposed Traefik to the tailnet only (no public Funnel). The pattern is **not** what current Tailscale operator docs recommend for tailnet-only exposure (the modern pattern is `tailscale.com/expose: "true"` annotation on the existing Service, or `Connector` CRD for cluster-scope egress) — but the 805 code is worth knowing about if a future cross-cluster investigation revisits "tailnet-only access to in-cluster services":

| File | What it implemented |
|---|---|
| `ansible/playbooks/805-deploy-tailscale-internal-ingress.yml` | Deploys the operator + creates a `Service` of `type: LoadBalancer, loadBalancerClass: tailscale` exposing Traefik on the tailnet. URL: `<owner_id>.<tailnet>.ts.net`. |
| `ansible/playbooks/806-remove-tailscale-internal-ingress.yml` | Removes the above (was broken — resource-name mismatch; deleted in the cleanup) |
| `manifests/805-tailscale-internal-ingress.yaml.j2` | The j2 template — `Service` with `loadBalancerClass: tailscale` pattern |
| `website/docs/networking/tailscale-internal-ingress.md` | User-facing setup guide |

To recover, search git history for those file paths after the cleanup PR ships — the deletion commit will be referenced from the merged PR. The implementation can be diffed against the modern annotation-based pattern to inform a future investigation.

**Why deletion is safe:** no `cmd_*` CLI verb invoked 805, it wasn't in `services.json`, the 806 removal was silently broken, and no tester or user surfaced an issue across 50+ talk rounds. Modern Tailscale operator patterns for the same use case (`tailscale.com/expose` annotation, `Connector` CRD) look fundamentally different from 805, so re-implementing later would build new code rather than restore old code.

## What this investigation needs to answer (when it's picked up)

1. **Topology — full mesh or hub-and-spoke?** Every cluster reaches every other directly (mesh), or one designated cluster is the routing hub (hub-and-spoke)? Mesh is simpler; hub-and-spoke gives a central control point for traffic auditing.
2. **What's the entry point — `Connector` CRD or subnet router pod?** The operator supports both. `Connector` is the newer CRD-driven path.
3. **ACLs — per-cluster tags or per-service tags?** Tailscale ACLs gate who can reach what. Tag every device with its cluster name (`tag:cluster-aks-prod`), tag with role (`tag:db-primary`), or both?
4. **DNS — MagicDNS for inter-cluster hostnames, or external DNS?** MagicDNS resolves `<device>.<tailnet>.ts.net` automatically; cross-cluster Postgres connection strings could use these. Alternative: register external DNS pointing at tailnet IPs.
5. **Workloads first** — which UIS service is the most compelling first cross-cluster workload? Postgres logical replication is the obvious candidate (clear value, narrow blast radius). Or Nextcloud (multi-tenant file storage across clusters).
6. **Failure modes** — what happens when one cluster's tailnet device flaps, or when the operator pod restarts mid-replication? Tailscale's connection model is forgiving but stateful workloads (Postgres replication slots) are not.

## Out of scope

- **AKS-specific networking.** Each cluster has its own platform-side networking (VPCs, service meshes); this investigation is about the Tailscale layer on top, not the cluster's underlay.
- **Service mesh comparison.** Linkerd / Istio / Cilium could also do cross-cluster networking. Tailscale's value is operational simplicity, not feature parity with full service meshes.
- **Active-active workloads.** Postgres logical replication is async; this investigation doesn't tackle distributed-consensus protocols (Raft, Paxos) for active-active state.

## When to revisit

After the user-facing Tailscale cleanup ships (per `INVESTIGATE-tailscale-architecture-cleanup.md` + its PLAN), AND once we have at least two real UIS clusters running (e.g., rancher-desktop + AKS, or two different physical machines on the user's setup). Without a real second cluster, this is theoretical work.
