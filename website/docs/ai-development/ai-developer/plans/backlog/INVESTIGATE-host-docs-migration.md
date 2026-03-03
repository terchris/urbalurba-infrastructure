# INVESTIGATE: Migrate Host Documentation to UIS CLI

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Related**: [INVESTIGATE-remote-deployment-targets](INVESTIGATE-remote-deployment-targets.md)
**Created**: 2026-03-02
**Status**: BACKLOG

## Background

The host documentation pages still describe the legacy deployment approach using manual scripts (`provision-kubernetes.sh`, `install-*.sh`, cloud-init templates). These pages have not been updated for the `./uis` CLI workflow. A caution banner has been added to each page to warn readers.

## Pages to Migrate

| Page | Path | Notes |
|------|------|-------|
| Azure AKS | `docs/hosts/azure-aks.md` | Full AKS deployment guide with az CLI |
| Azure MicroK8s | `docs/hosts/azure-microk8s.md` | Azure VM + MicroK8s via CAF |
| Multipass MicroK8s | `docs/hosts/multipass-microk8s.md` | Legacy — may be removed entirely |
| Raspberry Pi | `docs/hosts/raspberry-microk8s.md` | Edge/IoT with Tailscale |
| Cloud-Init | `docs/hosts/cloud-init/index.md` | Cloud-init templates |
| Cloud-Init Secrets | `docs/hosts/cloud-init/secrets.md` | SSH key setup for cloud-init |

## Questions to Answer

1. **Which hosts does UIS actually support today?** Rancher Desktop works. Which others have been tested?
2. **Should Multipass be removed?** It's already marked as legacy with "USE RANCHER DESKTOP INSTEAD".
3. **What's the UIS workflow for remote targets?** Does `./uis` support targeting a remote cluster, or is it still local-only? See INVESTIGATE-remote-deployment-targets.
4. **Cloud-init relevance?** Is cloud-init still the approach for provisioning remote hosts, or has that changed?
5. **Per-host pages or single page?** Should each host type keep its own page, or should they be consolidated?

## Dependencies

- Remote deployment target support (INVESTIGATE-remote-deployment-targets) should be resolved first — the docs should reflect what actually works.
