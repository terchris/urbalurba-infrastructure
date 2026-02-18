# PLAN-004: Secrets Migration Cleanup & Finalization

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Complete the secrets consolidation by removing backwards compatibility code, cleaning up deprecated files, and updating documentation.

**Last Updated**: 2025-01-23

**Branch**: `feature/secrets-migration`

**Prerequisites**: PLAN-001, PLAN-002, and PLAN-003 must be complete and validated

**Related**: [INVESTIGATE-secrets-consolidation](../completed/INVESTIGATE-secrets-consolidation.md) (completed), [INVESTIGATE-passwords](INVESTIGATE-passwords.md) (password architecture mismatch)

---

## Context: Contributor vs User

**We are contributors** - we clean up the codebase and finalize the migration.

This plan:
1. Removes backwards compatibility code from scripts
2. Removes deprecated files and folders from the repo
3. Updates documentation to reflect the new structure
4. Does NOT affect user folders (`.uis.extend/`, `.uis.secrets/` - those are created at runtime)

**Important**: Only execute this plan after users have had time to migrate from old `topsecret/` setup.

---

## Phase 1: Validate Migration Complete

Before removing backwards compatibility, verify everything works.

### Tasks

- [ ] 1.1 Test full workflow with new structure:
  - Clone repo fresh
  - Run `./uis` (should create user folders)
  - Run `./uis host add azure-aks`
  - Configure secrets in `.uis.secrets/`
  - Run `./uis deploy`

- [ ] 1.2 Verify no users are still using old paths:
  - Announce deprecation timeline
  - Check for issues/feedback
  - Confirm migration period is sufficient

- [ ] 1.3 Document rollback procedure (in case issues found)

### Validation

User confirms new system works end-to-end.

---

## Phase 2: Remove Backwards Compatibility Code

### Tasks

- [ ] 2.1 Update `provision-host/uis/lib/uis-paths.sh`:
  - Remove fallback to old paths (`topsecret/`, `secrets/`)
  - Remove deprecation warning functions
  - Simplify to only use new paths:
    ```bash
    SECRETS_BASE="/mnt/urbalurbadisk/.uis.secrets"
    EXTEND_BASE="/mnt/urbalurbadisk/.uis.extend"

    get_ssh_key_path() {
      echo "$SECRETS_BASE/ssh"
    }
    # etc.
    ```

- [ ] 2.2 Update all 24 scripts to remove old path handling:
  - Remove conditional checks for `topsecret/`
  - Remove conditional checks for old `secrets/`
  - Simplify path logic

- [ ] 2.3 Update `uis` wrapper to remove old mounts:
  ```bash
  # Remove this line:
  # -v "$PWD/topsecret:/mnt/urbalurbadisk/topsecret:ro"

  # Keep only:
  -v "$PWD/.uis.extend:/mnt/urbalurbadisk/.uis.extend"
  -v "$PWD/.uis.secrets:/mnt/urbalurbadisk/.uis.secrets"
  ```

### Validation

System works without any old path support.

---

## Phase 3: Remove Deprecated Files from Repo

### Tasks

- [ ] 3.1 Delete `topsecret/` folder entirely:
  - `topsecret/secrets-templates/`
  - `topsecret/secrets-config/`
  - `topsecret/secrets-generated/`
  - `topsecret/kubernetes/`
  - `topsecret/config/`
  - `topsecret/*.sh` (all scripts)
  - `topsecret/DEPRECATED.md`

- [ ] 3.2 Delete `secrets/` folder:
  - `secrets/create-secrets.sh`
  - The folder itself

- [ ] 3.3 Clean up `cloud-init/` folder:
  - Keep templates if they're still referenced from `provision-host/uis/templates/`
  - Or delete if templates were moved in PLAN-001
  - Remove `create-cloud-init.sh` if functionality moved to `./uis host generate`

- [ ] 3.4 Remove old host config examples from `hosts/`:
  - `hosts/azure-aks/azure-aks-config.sh` (template now in container)
  - `hosts/azure-microk8s/azure-vm-config-*.sh` (templates now in container)
  - Keep the actual scripts, just remove example config files

- [ ] 3.5 Update `.gitignore`:
  - Remove entries for deleted paths
  - Ensure `.uis.secrets/` and `.uis.extend/` are still ignored (for local testing)
  - Clean up any obsolete patterns

### Validation

Repo is clean with no deprecated files.

---

## Phase 4: Update Documentation

### Tasks

- [ ] 4.1 Update `CLAUDE.md`:
  - Remove "Current Work" section about secrets migration
  - Update folder structure description
  - Remove references to `topsecret/` and old `secrets/`

- [ ] 4.2 Update host documentation:
  - `website/docs/hosts/cloud-init/secrets.md` - new SSH key location
  - `website/docs/hosts/cloud-init/index.md` - new workflow with `./uis host generate`
  - `website/docs/hosts/index.md` - overview of host types

- [ ] 4.3 Create/update getting started guide:
  - Document first-run experience
  - Explain `.uis.extend/` vs `.uis.secrets/`
  - Provide quick start examples

- [ ] 4.4 Update README.md if it references old paths

- [ ] 4.5 Create migration guide (for users with old setup):
  - `website/docs/guides/migrate-from-topsecret.md`
  - Step-by-step instructions
  - Mapping from old paths to new paths
  - What to copy, what to regenerate

### Validation

Documentation accurately reflects the new structure.

---

## Phase 5: Finalize Plans

### Tasks

- [ ] 5.1 Move investigation to completed:
  ```bash
  mv website/docs/ai-development/ai-developer/plans/backlog/INVESTIGATE-secrets-consolidation.md \
     website/docs/ai-development/ai-developer/plans/completed/
  ```

- [ ] 5.2 Move all PLAN files to completed:
  - PLAN-001, PLAN-002, PLAN-003, PLAN-004

- [ ] 5.3 Update status in all files to `Completed`

- [ ] 5.4 Add completion date to all files

- [ ] 5.5 Update CLAUDE.md to remove reference to this work

### Validation

All plan files in `completed/` folder with correct status.

---

## Phase 6: Final Verification

### Tasks

- [ ] 6.1 Run full test suite:
  - All unit tests pass
  - Integration tests pass

- [ ] 6.2 Test scenarios:
  - **Fresh user**: Clone, run `./uis`, should work immediately
  - **Old user without migration**: Should fail gracefully with clear error

- [ ] 6.3 Verify container builds correctly:
  - Templates included
  - No broken references to deleted files

- [ ] 6.4 Create release notes documenting the change

### Validation

System ready for release.

---

## Acceptance Criteria

- [ ] No references to `topsecret/` in codebase (except migration guide)
- [ ] No references to old `secrets/` folder in codebase
- [ ] `topsecret/` folder deleted from repo
- [ ] `secrets/` folder deleted from repo
- [ ] `uis` wrapper only mounts new paths
- [ ] All documentation updated
- [ ] Migration guide available
- [ ] All plan files moved to `completed/`
- [ ] Fresh setup works without configuration
- [ ] Tests pass

---

## Files to Delete

**Folders:**
- `topsecret/` (entire folder)
- `secrets/` (entire folder)
- `cloud-init/` (if templates moved to container)

**Files:**
- Old config examples in `hosts/azure-*/`

---

## Files to Modify

**Documentation:**
- `CLAUDE.md`
- `README.md`
- `website/docs/hosts/cloud-init/secrets.md`
- `website/docs/hosts/cloud-init/index.md`

**Code:**
- `provision-host/uis/lib/uis-paths.sh`
- All 24 scripts (simplify path logic)
- `uis` wrapper

**Plans:**
- All PLAN and INVESTIGATE files (move to completed)

---

## Risk Mitigation

### Before executing this plan:

1. **Announce timeline** - Give users 2+ weeks notice
2. **Tag release** - Create git tag before cleanup for easy rollback
3. **Document rollback** - How to restore old functionality if needed
4. **Test extensively** - All scenarios covered

### If issues found after cleanup:

1. Revert to tagged release
2. Investigate root cause
3. Fix in a new branch
4. Re-attempt cleanup
