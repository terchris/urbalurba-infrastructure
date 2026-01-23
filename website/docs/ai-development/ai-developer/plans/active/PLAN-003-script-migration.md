# PLAN-003: Migrate Scripts to New Secrets Paths

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Update all scripts in the repo that reference `topsecret/` or `secrets/` to use the new `.uis.secrets/` paths, while maintaining backwards compatibility.

**Last Updated**: 2026-01-23

**Branch**: `feature/secrets-migration`

**Prerequisites**: PLAN-001 ✓ and PLAN-002 ✓ complete

**Related**: [INVESTIGATE-secrets-consolidation.md](../backlog/INVESTIGATE-secrets-consolidation.md)

**Note**: PLAN-002 created `paths.sh` with base path detection functions. This plan extends that with backwards-compatible path resolution and deprecation warnings for topsecret/ paths.

---

## Context: Contributor vs User

**We are contributors** - we update scripts in the repo to use new path conventions.

**At runtime**, these scripts run inside the container and access:
- `/mnt/urbalurbadisk/.uis.secrets/` (user's secrets, mounted)
- `/mnt/urbalurbadisk/.uis.extend/` (user's config, mounted)
- `/mnt/urbalurbadisk/topsecret/` (old path, mounted for backwards compat)

The scripts we update need to:
1. Prefer new paths when available
2. Fall back to old paths for backwards compatibility
3. Warn users when old paths are detected

---

## Overview

The investigation identified 24 scripts that reference the old paths:

**cloud-init (1):**
- `cloud-init/create-cloud-init.sh`

**hosts (8):**
- `hosts/azure-aks/02-azure-aks-setup.sh`
- `hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh`
- `hosts/azure-microk8s/02-azure-ansible-inventory-v2.sh`
- `hosts/raspberry-microk8s/install-raspberry.sh`
- `hosts/install-azure-aks.sh`
- `hosts/install-azure-microk8s-v2.sh`
- `hosts/install-multipass-microk8s.sh`
- `hosts/install-rancher-kubernetes.sh`

**topsecret (3) - to be deprecated:**
- `topsecret/update-kubernetes-secrets-rancher.sh`
- `topsecret/kubeconf-copy2local.sh`
- `topsecret/copy-secrets2host.sh`

**networking (4):**
- `networking/tailscale/802-tailscale-tunnel-deploy.sh`
- `networking/cloudflare/820-cloudflare-tunnel-setup.sh`
- `networking/cloudflare/821-cloudflare-tunnel-deploy.sh`
- `networking/cloudflare/822-cloudflare-tunnel-delete.sh`

**provision-host (6):**
- `provision-host/provision-host-02-kubetools.sh`
- `provision-host/provision-host-vm-create.sh`
- `provision-host/provision-host-sshconf.sh`
- `provision-host/uis/lib/secrets-management.sh`
- `provision-host/uis/tests/unit/test-phase6-secrets.sh`

**other (3):**
- `copy2provisionhost.sh`
- `install-rancher.sh`
- `provision-host-rancher/provision-host-container-create.sh`

---

## Phase 1: Create Path Resolution Library — ✅ DONE

### Tasks

- [x] 1.1 Extended `provision-host/uis/lib/paths.sh` with backwards-compatible path resolution:
  ```bash
  # Base paths inside container
  NEW_SECRETS_BASE="/mnt/urbalurbadisk/.uis.secrets"
  OLD_SECRETS_BASE="/mnt/urbalurbadisk/topsecret"
  OLD_SSH_BASE="/mnt/urbalurbadisk/secrets"

  # Returns path to use, preferring new location
  get_secrets_base_path() {
    if [ -d "$NEW_SECRETS_BASE" ]; then
      echo "$NEW_SECRETS_BASE"
    elif [ -d "$OLD_SECRETS_BASE" ]; then
      warn_deprecated_path "$OLD_SECRETS_BASE" "$NEW_SECRETS_BASE"
      echo "$OLD_SECRETS_BASE"
    else
      echo "$NEW_SECRETS_BASE"  # Default to new
    fi
  }

  get_ssh_key_path() {
    # New: .uis.secrets/ssh/
    # Old: secrets/
  }

  get_kubernetes_secrets_path() {
    # New: .uis.secrets/generated/kubernetes/
    # Old: topsecret/kubernetes/
  }

  get_cloud_init_output_path() {
    # New: .uis.secrets/generated/ubuntu-cloud-init/
    # Old: cloud-init/
  }

  get_kubeconfig_path() {
    # New: .uis.secrets/generated/kubeconfig/
    # Old: (various locations)
  }

  get_tailscale_key() {
    # New: .uis.secrets/service-keys/tailscale.env
    # Old: topsecret/kubernetes/kubernetes-secrets.yml
  }

  get_cloudflare_token() {
    # New: .uis.secrets/service-keys/cloudflare.env
    # Old: topsecret/...
  }
  ```

- [x] 1.2 Add deprecation warning function ✓ (warn_deprecated_path in paths.sh)

- [x] 1.3 Add unit tests for path resolution ✓ (63 tests in test-paths.sh)

### Validation

✓ Path resolution correctly prefers new paths and warns on old.
✓ All 63 tests pass for paths.sh functions.

---

## Phase 2: Update Cloud-Init Script — ✅ DONE

### Tasks

- [x] 2.1 Update `cloud-init/create-cloud-init.sh` ✓
  - Sources paths.sh and uses `get_kubernetes_secrets_path()` and `get_ssh_key_path()`
  - Falls back to hardcoded legacy paths if library not found

- [x] 2.2 Test cloud-init generation works with both path structures

### Validation

✓ Cloud-init script updated with backwards-compatible path resolution.

---

## Phase 3: Update Host Scripts — ✅ DONE

### Tasks

- [x] 3.1 Update Azure AKS scripts:
  - `hosts/azure-aks/02-azure-aks-setup.sh` ✓
  - `hosts/install-azure-aks.sh` ✓ (no changes needed - calls other scripts)

- [x] 3.2 Update Azure MicroK8s scripts:
  - `hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh` ✓
  - `hosts/azure-microk8s/02-azure-ansible-inventory-v2.sh` ✓
  - `hosts/install-azure-microk8s-v2.sh` ✓ (no changes needed - calls topsecret scripts that will be deprecated)

- [x] 3.3 Update Raspberry Pi scripts:
  - `hosts/raspberry-microk8s/install-raspberry.sh` ✓ (no changes needed - calls other scripts)

- [x] 3.4 Update other host scripts:
  - `hosts/install-multipass-microk8s.sh` ✓ (no changes needed - calls topsecret scripts)
  - `hosts/install-rancher-kubernetes.sh` ✓ (updated secrets file check to support both paths)

### Validation

✓ Host scripts updated with backwards-compatible path resolution.

---

## Phase 4: Update Networking Scripts — ✅ DONE

### Tasks

- [x] 4.1 Update Tailscale script:
  - `networking/tailscale/802-tailscale-tunnel-deploy.sh` ✓
  - Sources paths.sh and checks both new and legacy paths

- [x] 4.2 Update Cloudflare scripts:
  - `networking/cloudflare/820-cloudflare-tunnel-setup.sh` ✓
  - `networking/cloudflare/821-cloudflare-tunnel-deploy.sh` ✓
  - `networking/cloudflare/822-cloudflare-tunnel-delete.sh` ✓
  - All source paths.sh and use `get_kubernetes_secrets_path()`

### Validation

✓ Networking scripts updated with backwards-compatible path resolution.

---

## Phase 5: Update Provision-Host Scripts — ✅ DONE

### Tasks

- [x] 5.1 Update core provision-host scripts:
  - `provision-host/provision-host-02-kubetools.sh` ✓ (ansible.cfg uses dynamic SSH key path)
  - `provision-host/provision-host-vm-create.sh` ✓ (checks both new and legacy SSH key paths, copies both secret directories)
  - `provision-host/provision-host-sshconf.sh` ✓ (checks both new and legacy SSH key paths)

- [ ] 5.2 Update or replace `provision-host/uis/lib/secrets-management.sh`:
  - May be superseded by new `uis-secrets.sh` from PLAN-002
  - Deferred to Phase 7 as part of deprecation

- [ ] 5.3 Update tests:
  - `provision-host/uis/tests/unit/test-phase6-secrets.sh`
  - Deferred - tests may need rewrite after secrets-management.sh update

### Validation

✓ Core provision-host scripts updated with backwards-compatible path resolution.

---

## Phase 6: Update Root Scripts — ✅ DONE

### Tasks

- [x] 6.1 Update `copy2provisionhost.sh` ✓
  - Backs up from both new and legacy paths
  - Copies both .uis.secrets and topsecret directories

- [x] 6.2 Update `install-rancher.sh` ✓
  - Checks for both .uis.secrets and topsecret directories
  - Checks for SSH keys in both new and legacy paths

- [x] 6.3 Update `provision-host-rancher/provision-host-container-create.sh` ✓
  - Checks for secrets in both new and legacy paths
  - Copies .uis.secrets, secrets, and topsecret directories

### Validation

✓ Root scripts updated with backwards-compatible path resolution.

---

## Phase 7: Deprecate topsecret Scripts

Mark scripts in `topsecret/` as deprecated with clear alternatives.

### Tasks

- [ ] 7.1 Add deprecation notice to `topsecret/update-kubernetes-secrets-rancher.sh`:
  ```bash
  #!/bin/bash
  echo "⚠️  DEPRECATED: This script is deprecated."
  echo "   Use './uis secrets generate' instead."
  echo ""
  echo "   To migrate, run './uis' to set up the new structure."
  exit 1
  ```

- [ ] 7.2 Add deprecation notice to `topsecret/kubeconf-copy2local.sh`:
  - Point to new kubeconfig location

- [ ] 7.3 Add deprecation notice to `topsecret/copy-secrets2host.sh`:
  - This functionality now handled by container mounts

- [ ] 7.4 Create `topsecret/DEPRECATED.md` explaining migration

### Validation

Deprecated scripts show clear messages and alternatives.

---

## Phase 8: Update UIS Wrapper Mounts

### Tasks

- [ ] 8.1 Verify `uis` wrapper mounts both old and new paths:
  - New paths mounted when folders exist
  - Old `topsecret/` mounted read-only for backwards compat

- [ ] 8.2 Update kubeconfig handling:
  - Update `ansible/playbooks/04-merge-kubeconf.yml` to use new path
  - Support both old and new locations during transition

### Validation

Container starts correctly with appropriate mounts.

---

## Acceptance Criteria

- [ ] `uis-paths.sh` library created with all path functions
- [ ] All 24 scripts updated to source `uis-paths.sh`
- [ ] Scripts work with new paths (`.uis.secrets/`)
- [ ] Scripts fall back to old paths (`topsecret/`) with warning
- [ ] Deprecated scripts show clear migration messages
- [ ] Unit tests pass for path resolution
- [ ] Kubeconfig merge playbook updated
- [ ] No functionality broken during transition

---

## Files Created/Modified

**Phase 1 (Complete):**
- `provision-host/uis/lib/paths.sh` ✓ Extended (not uis-paths.sh - reused existing library)
- `provision-host/uis/tests/unit/test-paths.sh` ✓ Extended (63 tests)

**Future Phases:**
- `topsecret/DEPRECATED.md` (Phase 7)

## Files to Modify

- All 24 scripts listed in Overview
- `ansible/playbooks/04-merge-kubeconf.yml`

---

## Testing Strategy

For each script:
1. Test with new paths only (fresh setup)
2. Test with old paths only (legacy setup)
3. Test with both (migration in progress)

Use mock folders in test environment to simulate both scenarios.
