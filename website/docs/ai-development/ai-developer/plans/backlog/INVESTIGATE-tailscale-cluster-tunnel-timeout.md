# INVESTIGATE: Tailscale Cluster-Wide Tunnel Connectivity Timeout

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Diagnose and fix the cluster-wide Tailscale tunnel connectivity timeout (`k8s.dog-pence.ts.net`).

**Last Updated**: 2026-02-22

**Priority**: Medium — per-service Funnel works perfectly, but the cluster-wide tunnel (used for centralized access via Traefik) does not.

**Parent**: Observed during PLAN-009 and PLAN-010 testing.

---

## Problem Description

The cluster-wide Tailscale tunnel (`k8s.dog-pence.ts.net`) consistently times out during the deploy connectivity test. The TLS handshake fails after 12 retries. Tailscale proxy pod logs show `Drop: TCP ... no rules matched`.

Meanwhile, per-service Tailscale Funnel works perfectly — `whoami.dog-pence.ts.net` is accessible via HTTPS from the public internet (HTTP 200).

This has been observed across all PLAN-009 and PLAN-010 test rounds (at least 12 rounds total). Initially it was suspected to be caused by stale devices, but after PLAN-010 cleaned up all stale devices (from 17 down to 5), the issue persists.

## Symptoms

- `https://k8s.dog-pence.ts.net` — TLS handshake timeout
- Tailscale proxy pod logs: `Drop: TCP ... no rules matched`
- Per-service ingress (`whoami.dog-pence.ts.net`) — works fine (HTTP 200)
- Operator pod is running and healthy
- Deploy playbook `802-deploy-network-tailscale-tunnel.yml` connectivity test fails consistently

## Key Differences

| Aspect | Cluster Tunnel | Per-Service Funnel |
|--------|---------------|-------------------|
| Hostname | `k8s.dog-pence.ts.net` | `whoami.dog-pence.ts.net` |
| Ingress Type | Cluster ingress in `kube-system` | Per-service ingress in `default` |
| Backend | Traefik (all services) | Direct to service |
| Status | Timeout | Working (HTTP 200) |

## Investigation Areas

1. **ACL/Funnel configuration**: Does the Tailscale ACL policy allow Funnel for the cluster hostname? Per-service Funnel works, so the general Funnel config is correct, but the cluster-wide hostname may need specific ACL entries.

2. **Ingress configuration**: The cluster ingress is in `kube-system` namespace while per-service ingresses are in `default`. Could namespace differences affect Tailscale operator behavior?

3. **Traefik routing**: The cluster tunnel routes through Traefik. Is Traefik correctly accepting connections from the Tailscale proxy pod?

4. **Stale state in Tailscale control plane**: Even though devices were cleaned up, there may be stale DNS or routing entries in the Tailscale control plane that need time to expire.

5. **Tailscale operator version**: Check if the operator version has known issues with cluster-wide ingresses vs per-service ingresses.

6. **Firewall rules**: The `no rules matched` log suggests Tailscale's internal firewall is dropping the traffic. Check if the operator is correctly configuring firewall rules for the cluster ingress.

## Data to Collect

- [ ] Full Tailscale proxy pod logs for the cluster ingress
- [ ] `kubectl describe ingress traefik-ingress -n kube-system` output
- [ ] Tailscale ACL policy (from Tailscale admin console)
- [ ] `kubectl get pods -n tailscale` — list all Tailscale pods and their states
- [ ] Tailscale operator pod logs
- [ ] Compare ingress specs between working per-service and failing cluster-wide

## Possible Fixes

1. ACL policy update to explicitly allow Funnel for the cluster hostname
2. Move cluster ingress to `default` namespace (same as working per-service ingresses)
3. Update Tailscale operator Helm chart configuration
4. Change cluster ingress to use same pattern as per-service ingresses (direct backend instead of Traefik)
