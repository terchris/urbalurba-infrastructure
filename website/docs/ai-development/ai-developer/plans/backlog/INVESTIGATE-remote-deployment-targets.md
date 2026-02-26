# INVESTIGATE: Remote Deployment Targets & Target Management

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Related**: [INVESTIGATE-topsecret-cleanup](../completed/INVESTIGATE-topsecret-cleanup.md), [STATUS-service-migration](STATUS-service-migration.md)
**Created**: 2026-02-22 (merged with PLAN-006-target-host-management on 2026-02-26)
**Status**: INVESTIGATION COMPLETE

## Background

The UIS system currently targets local Rancher Desktop. However, the codebase also contains scripts for provisioning remote servers and edge devices. These scripts predate the UIS system and still reference `topsecret/` for secrets. They require separate planning and real infrastructure testing before their secrets paths can be migrated.

Additionally, users have no easy way to see which cluster they're deploying to or switch between targets.

---

## Part 1: Target Management UX (from PLAN-006)

### Problem

Users have no easy way to:
1. See which Kubernetes cluster they're deploying to
2. Switch between different targets (rancher-desktop, azure-aks, etc.)
3. Understand the relationship between UIS hosts and kubectl context

Currently:
- Target defaults to `rancher-desktop`
- User must manually manage kubectl context
- `./uis host list` shows configured hosts but not the active target
- No synchronization between UIS and kubectl context

### Quick Fix Already Implemented

Added target cluster display to `./uis status`:
```
Target cluster: rancher-desktop
```

### Proposed New Commands

1. `./uis target` - Show current target cluster
2. `./uis target list` - List available targets
3. `./uis target set <name>` - Switch to a different target

### Implementation Requirements

1. **Track active target** in `.uis.extend/active-target`
2. **Sync kubectl context** when target changes
3. **Validate target exists** before switching
4. **Show target in commands** that deploy/interact with cluster
5. **Handle multiple kubeconfigs** for different clusters

### User Flow

```bash
# See current target
./uis target
# Output: Current target: rancher-desktop

# List available targets
./uis target list
# Output:
#   rancher-desktop (active)
#   azure-aks-prod
#   raspberry-pi-cluster

# Switch target
./uis target set azure-aks-prod
# Output: Switched to azure-aks-prod
```

### Files to Modify

- `provision-host/uis/manage/uis-cli.sh` - Add target commands
- `provision-host/uis/lib/uis-hosts.sh` - Target management logic
- `uis` wrapper - Pass target commands through

### Dependencies

- Requires kubeconfig files for each target in `.uis.secrets/generated/kubeconfig/`
- Host templates should generate appropriate kubeconfig entries

---

## Part 2: Deployment Targets Inventory

### 1. Rancher Desktop (local development) — DEFAULT

- **Scripts**: `hosts/install-rancher-kubernetes.sh`
- **Purpose**: Local Kubernetes via Rancher Desktop — the standard UIS development environment
- **Secrets**: Uses `paths.sh` with `topsecret/` fallback
- **Status**: Actively maintained (Jan 2026)
- **Cloud-init**: No

### 2. Azure AKS (managed Kubernetes)

- **Scripts**: `hosts/install-azure-aks.sh`, `hosts/azure-aks/01-azure-aks-create.sh`, `02-azure-aks-setup.sh`, `03-azure-aks-cleanup.sh`, `manage-aks-cluster.sh`, `check-aks-quota.sh`
- **Purpose**: Production-grade managed Kubernetes on Azure
- **Secrets**: Git-ignored `azure-aks-config.sh` with Azure tenant/subscription IDs. Uses `paths.sh` for kubernetes secrets path (with `topsecret/` fallback in `02-azure-aks-setup.sh`)
- **Status**: Production ready — documented as "Version 4.0 - All components tested and working"
- **Cloud-init**: No
- **Docs**: `website/docs/hosts/azure-aks.md`

### 3. Azure MicroK8s (VMs on Azure)

- **Scripts**: `hosts/install-azure-microk8s-v2.sh`, `hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh`, `02-azure-ansible-inventory-v2.sh`, `azure-vm-cleanup-redcross-v2.sh`, `hosts/03-setup-microk8s-v2.sh`
- **Purpose**: Self-managed Kubernetes on Azure VMs via MicroK8s + cloud-init
- **Secrets**: Uses `paths.sh` with `topsecret/` fallback. SSH keys from `get_ssh_key_path()`
- **Status**: Actively maintained (Jan 2026)
- **Cloud-init**: Yes (`azure-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/azure-microk8s.md`

### 4. Multipass MicroK8s (local VMs)

- **Scripts**: `hosts/install-multipass-microk8s.sh`, `hosts/multipass-microk8s/01-create-multipass-microk8s.sh`, `02-inventory-multipass-microk8s.sh`
- **Purpose**: Local development alternative to Rancher Desktop, closer to production MicroK8s
- **Secrets**: Still references `topsecret/` directly — NOT migrated to `paths.sh`
- **Status**: Last updated Sep 2025 — moderate activity
- **Cloud-init**: Yes (`multipass-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/multipass-microk8s.md`

### 5. Raspberry Pi MicroK8s (edge/IoT)

- **Scripts**: `hosts/raspberry-microk8s/install-raspberry.sh`, `02-raspberry-ansible-inventory.sh`, `03-raspberry-setup-microk8s.sh`
- **Purpose**: Edge computing on Raspberry Pi 4 (ARM)
- **Secrets**: Commented-out topsecret references. Note in script: "secrets are pushed from the local mac-- fix this"
- **Status**: Experimental — manual setup only, automation TODO
- **Cloud-init**: Yes (`raspberry-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/raspberry-microk8s.md` (limited)

### 6. GCP (Google Cloud) — DORMANT

- **Scripts**: None (cloud-init template only)
- **Purpose**: Google Cloud VMs with MicroK8s
- **Status**: Template exists (`gcp-cloud-init-template.yml`) but no active scripts
- **Cloud-init**: Yes (template only)

### 7. Oracle Cloud (OCI) — DORMANT

- **Scripts**: None (cloud-init template only)
- **Purpose**: Oracle Cloud VMs with MicroK8s
- **Status**: Template exists (`oci-cloud-init-template.yml`) but no active scripts
- **Cloud-init**: Yes (template only)

---

## Cloud-Init System

**Script**: `cloud-init/create-cloud-init.sh`

Generates cloud-init YAML files from templates by substituting `URB_*` placeholders with actual values (SSH keys, hostnames, Tailscale keys, etc.).

**Supported targets**: Azure, Multipass, Raspberry Pi, Provision Host, GCP, OCI

**Secrets path**: Uses `paths.sh` with fallback to `../topsecret/kubernetes/kubernetes-secrets.yml`

---

## VM Provisioning

**Script**: `provision-host/provision-host-vm-create.sh`

Creates the provision-host VM in Multipass and copies repo files to it. Currently only syncs `.uis.secrets/` (topsecret rsync already removed in PLAN-004).

---

## Migration Status

| Target | paths.sh integrated | topsecret fallback | Needs testing on real infra |
|--------|:-------------------:|:------------------:|:---------------------------:|
| Rancher Desktop | Yes | Yes | No (local) |
| Azure AKS | Yes | Yes | Yes (Azure subscription) |
| Azure MicroK8s | Yes | Yes | Yes (Azure subscription) |
| Multipass MicroK8s | No | Hardcoded | Yes (local VM) |
| Raspberry Pi | No | Commented out | Yes (physical device) |
| cloud-init/create-cloud-init.sh | Yes | Yes | Tested via targets above |

---

## Files Referencing `topsecret/`

| File | Line(s) | Reference Type |
|------|:-------:|----------------|
| `hosts/install-rancher-kubernetes.sh` | 110-134 | Fallback path check and script call |
| `hosts/azure-aks/02-azure-aks-setup.sh` | 132 | Hardcoded secrets file path |
| `hosts/install-azure-microk8s-v2.sh` | 216 | Topsecret directory reference |
| `hosts/install-azure-aks.sh` | 12 | Comment only |
| `hosts/install-multipass-microk8s.sh` | 83, 89 | Direct topsecret script calls |
| `hosts/raspberry-microk8s/install-raspberry.sh` | 97-102 | Commented-out topsecret calls |
| `cloud-init/create-cloud-init.sh` | 27 | Fallback secrets file path |

---

## Open Questions

1. Are the Azure targets (AKS, MicroK8s) still actively used for Red Cross deployments?
2. Is the Multipass target worth maintaining, or is Rancher Desktop the preferred local option?
3. Should the Raspberry Pi target be kept as experimental or removed?
4. Should the dormant GCP and OCI cloud-init templates be removed?
5. What testing infrastructure is available for validating changes to Azure scripts?

## Proposed Approach

This investigation documents the current state. A separate implementation plan should be created when there is time and infrastructure to test these changes. The work involves:

1. Implement `./uis target` commands (Part 1)
2. Remove `topsecret/` fallback paths — use `.uis.secrets/` only
3. Ensure `paths.sh` is sourced in scripts that don't yet use it (Multipass, Raspberry Pi)
4. Test the full deployment cycle on each target platform
5. Update documentation in `website/docs/hosts/`
