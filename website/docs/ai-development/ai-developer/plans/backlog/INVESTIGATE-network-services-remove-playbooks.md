# INVESTIGATE: Network Services Remove Playbooks

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Investigate the full state of tailscale-tunnel and cloudflare-tunnel services — verify deploy works, create remove playbooks, and test the full deploy/undeploy cycle.

**Last Updated**: 2026-02-22

**Priority**: Low — these services require external accounts (Tailscale auth key, Cloudflare token) and cannot be tested locally.

**Parent**: [STATUS-service-migration.md](STATUS-service-migration.md) — Phase 3 and Phase 5

---

## Context

All 26 UIS services have deploy playbooks. 24 of 26 have been verified working. The two unverified services are:

| Service | Deploy Playbook | Remove Playbook | External Requirement |
|---------|----------------|-----------------|---------------------|
| **tailscale-tunnel** | `801-setup-network-tailscale-tunnel.yml` | Missing | Tailscale auth key |
| **cloudflare-tunnel** | `820-setup-network-cloudflare-tunnel.yml` | Missing | Cloudflare API token |

**Important**: The deploy playbooks have NOT been verified since the UIS migration. They may or may not work. This investigation must verify both deploy AND remove.

These cannot be tested without live external accounts because:
- Tailscale requires an auth key to register the node with Tailscale's coordination server
- Cloudflare requires an API token and a configured tunnel in the Cloudflare dashboard

## Prerequisites

Before starting this work:

1. **Tailscale account** with an auth key configured in `.uis.secrets/`
2. **Cloudflare account** with a tunnel token configured in `.uis.secrets/`
3. A running Kubernetes cluster (Rancher Desktop or Azure AKS)

## Investigation Questions

### Tailscale — Deploy
- [ ] Does `./uis deploy tailscale-tunnel` work?
- [ ] If not, what needs fixing in `801-setup-network-tailscale-tunnel.yml`?
- [ ] Does the deployed service successfully connect to the Tailscale network?

### Tailscale — Remove
- [ ] What Kubernetes resources does the deploy create? (namespace, deployments, secrets, configmaps, services)
- [ ] Are there any external Tailscale resources (registered nodes) that need cleanup?
- [ ] Does the existing `806-remove-tailscale-internal-ingress.yml` handle part of the teardown?
- [ ] What is the correct teardown order?

### Cloudflare — Deploy
- [ ] Does `./uis deploy cloudflare-tunnel` work?
- [ ] If not, what needs fixing in `820-setup-network-cloudflare-tunnel.yml`?
- [ ] Does the deployed tunnel successfully register with Cloudflare?

### Cloudflare — Remove
- [ ] What Kubernetes resources does the deploy create?
- [ ] Are there Cloudflare-side resources (tunnel routes, DNS records) that need cleanup?
- [ ] What is the correct teardown order?

## Expected Deliverables

1. Verify or fix `./uis deploy tailscale-tunnel`
2. Verify or fix `./uis deploy cloudflare-tunnel`
3. Create `ansible/playbooks/801-remove-network-tailscale-tunnel.yml` — tested with a live deployment
4. Create `ansible/playbooks/820-remove-network-cloudflare-tunnel.yml` — tested with a live deployment
5. Update `service-tailscale-tunnel.sh`: set `SCRIPT_REMOVE_PLAYBOOK="801-remove-network-tailscale-tunnel.yml"`
6. Update `service-cloudflare-tunnel.sh`: set `SCRIPT_REMOVE_PLAYBOOK="820-remove-network-cloudflare-tunnel.yml"`
7. Verify full `./uis deploy` and `./uis undeploy` cycle works for both services

## Related Files

| File | Role |
|------|------|
| `provision-host/uis/services/network/service-tailscale-tunnel.sh` | Service metadata (needs `SCRIPT_REMOVE_PLAYBOOK`) |
| `provision-host/uis/services/network/service-cloudflare-tunnel.sh` | Service metadata (needs `SCRIPT_REMOVE_PLAYBOOK`) |
| `ansible/playbooks/801-setup-network-tailscale-tunnel.yml` | Deploy playbook (reference for resources created) |
| `ansible/playbooks/820-setup-network-cloudflare-tunnel.yml` | Deploy playbook (reference for resources created) |
| `ansible/playbooks/806-remove-tailscale-internal-ingress.yml` | Existing partial removal (ingress only) |
| `networking/tailscale/802-tailscale-tunnel-deploy.sh` | Legacy deploy script (reference) |
| `networking/cloudflare/820-cloudflare-tunnel-setup.sh` | Legacy setup script (reference) |
| `website/docs/networking/tailscale-setup.md` | User docs: Tailscale setup guide |
| `website/docs/networking/tailscale-internal-ingress.md` | User docs: Tailscale internal ingress |
| `website/docs/networking/tailscale-network-isolation.md` | User docs: Tailscale network isolation |
| `website/docs/networking/cloudflare-setup.md` | User docs: Cloudflare setup guide |
