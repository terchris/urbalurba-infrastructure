# PLAN: ArgoCD Register Command Redesign

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Active

**Goal**: Redesign `uis argocd register` to accept two required parameters (`<name>` and `<repo-url>`) instead of a single bare repo name, eliminating the GitHub username secrets dependency and preventing invalid namespace names.

**Last Updated**: 2026-03-03

**Parent**: [INVESTIGATE-argocd-register-url-parsing.md](./INVESTIGATE-argocd-register-url-parsing.md)

---

## Problem Summary

The current `uis argocd register <repo_name>` command has two critical issues:

1. **Users pass full GitHub URLs** but the command only accepts bare repo names. The bare name is used directly as the Kubernetes namespace — passing a URL creates an invalid namespace name.
2. **Requires `GITHUB_USERNAME` in secrets** even for public repos. The playbook constructs the repo URL from `github_username` + `repo_name`, so registration fails before it starts if secrets aren't configured.

### New design

```bash
uis argocd register <name> <repo-url>
```

- `<name>` — Application name (Kubernetes namespace + ArgoCD app name). Must be DNS-compatible and not already in use.
- `<repo-url>` — Full GitHub HTTPS URL. Must start with `https://`.
- CLI does basic validation only. Playbook handles all URL parsing and heavy lifting.
- No backward compatibility needed — system is not yet released.

---

## Phase 1: Update the Ansible Register Playbook — ✅ DONE

Rewrite `ansible/playbooks/argocd-register-app.yml` to accept `app_name` and `repo_url` instead of `github_username` and `repo_name`.

### Tasks

- [x] 1.1 Change the required variables from `github_username`/`repo_name` to `app_name`/`repo_url` ✓
- [x] 1.2 Add a task to parse `repo_url` into `github_owner` and `repo_name` using Ansible filters (e.g., `repo_url | urlsplit` or regex) ✓
- [x] 1.3 Add a task to validate that `repo_url` starts with `https://` and contains an owner and repo path ✓
- [x] 1.4 Add a pre-flight check that ArgoCD server pods are running before attempting registration ✓
- [x] 1.5 Replace all uses of `repo_name` (for namespace/app name) with `app_name` throughout the playbook ✓
- [x] 1.6 Use `repo_url` directly for the ArgoCD Application source URL (instead of constructing it from `github_username` + `repo_name`) ✓
- [x] 1.7 Use parsed `github_owner` and `repo_name` for GitHub API pre-flight checks (repo exists, manifests/ directory exists) ✓
- [x] 1.8 Update the credentials secret to use parsed `github_owner` and `repo_name` ✓
- [x] 1.9 Update the cleanup/rescue block to use `app_name` for resource names ✓
- [x] 1.10 Update all display messages and error messages to reflect new variable names ✓

### Validation

User confirms playbook structure looks correct.

---

## Phase 2: Update the Ansible Remove Playbook — ✅ DONE

Update `ansible/playbooks/argocd-remove-app.yml` to use `app_name` instead of `repo_name` for consistency.

### Tasks

- [x] 2.1 Rename `repo_name` variable to `app_name` throughout the playbook ✓
- [x] 2.2 Update the GitHub secret name pattern to use `app_name` ✓
- [x] 2.3 Update all display messages and error messages ✓

### Validation

User confirms playbook structure looks correct.

---

## Phase 3: Update the CLI — ✅ DONE

Rewrite the ArgoCD commands in `provision-host/uis/manage/uis-cli.sh`.

### Tasks

- [x] 3.1 Rewrite `cmd_argocd_register()`: two required args, DNS validation, namespace-in-use check, HTTPS validation, pass `app_name`/`repo_url` to playbook, optional PAT from secrets ✓
- [x] 3.2 Update `cmd_argocd_remove()`: parameter is `<name>`, passes `app_name` to playbook ✓
- [x] 3.3 Update help text in main help section and `cmd_argocd()` subcommand help ✓
- [x] 3.4 Update examples section with new syntax ✓

### Validation — ✅ PASS

Tested by UIS-USER1 in two rounds:

**Round 1** (7 tests): All PASS — help output, no-args, missing repo-url, invalid name, invalid URL, remove help all work correctly.

**Round 2** (3 tests): Ordering fixes confirmed PASS. Duplicate output investigated — confirmed as display artifact from `docker exec` stderr/stdout handling, not actual duplication (`cat -n` showed single copy).

Acceptance criteria met:
- [x] Two-parameter syntax shown in help
- [x] Missing arguments show usage with examples
- [x] Invalid DNS name rejected with clear error
- [x] Non-HTTPS URL rejected with clear error
- [x] `✗` marker consistently appears first in all error messages

---

## Phase 4: Improve Error Diagnostics in Register Playbook — ✅ DONE

Implemented as part of Phase 1 playbook rewrite.

### Tasks

- [x] 4.1 Pod timeout diagnostics (task 25a): checks for `ImagePullBackOff`/`ErrImagePull`, `CrashLoopBackOff`, and `Pending` with specific error messages ✓
- [x] 4.2 Sync/health timeout diagnostics (tasks 16, 18, 21): queries `operationState.message` for actual ArgoCD errors ✓
- [x] 4.3 Diagnostics run before cleanup — failure triggers rescue block which shows the error ✓

### Validation

Will be validated during end-to-end testing in Phase 5.

---

## Phase 5: Build and Test End-to-End — ✅ DONE

Rebuild the container and test the full flow.

### Tasks

- [x] 5.1 Rebuild the container image: `./uis build` (with `--no-cache` if needed) ✓
- [x] 5.2 Restart with local image: `UIS_IMAGE=uis-provision-host:local ./uis restart` ✓
- [x] 5.3 Verify help output shows new syntax: `UIS_IMAGE=uis-provision-host:local ./uis argocd` ✓
- [x] 5.4 Test full register flow ✓
- [x] 5.5 Test list ✓
- [x] 5.6 Test remove ✓
- [x] 5.7 Fix stale hint in `argocd-list-apps.yml` (was showing old `<repo_name>` syntax) ✓

### Validation — ✅ PASS

Tested by UIS-USER1 in Round 3. Full register → list → verify → duplicate-check → remove → cleanup cycle works correctly. All 7 steps PASS.

---

## Acceptance Criteria

- [x] `uis argocd register` requires exactly two arguments: `<name>` and `<repo-url>` ✓
- [x] `<name>` is validated as DNS-compatible and not already in use ✓
- [x] `<repo-url>` must be a full HTTPS URL ✓
- [x] Public repos work without any secrets configured ✓
- [ ] Private repos work when a GitHub PAT is configured in secrets (not tested — requires private repo)
- [x] `uis argocd remove <name>` removes the application by name ✓
- [x] ArgoCD pre-flight check fails fast if ArgoCD is not deployed ✓ (code verified, not runtime tested — ArgoCD was already deployed)
- [ ] Pod failure diagnostics show specific error messages (ImagePullBackOff, CrashLoopBackOff, Pending) (not tested — requires broken repo)
- [ ] Sync failure diagnostics show the actual ArgoCD sync error (not tested — requires broken manifests)
- [x] Help text and examples reflect the new two-parameter syntax ✓
- [x] No dependency on `GITHUB_USERNAME` in secrets for registration ✓

---

## Files to Modify

| File | Change |
|------|--------|
| `ansible/playbooks/argocd-register-app.yml` | Accept `app_name`/`repo_url`, parse URL in playbook, add ArgoCD pre-flight check, improve error diagnostics |
| `ansible/playbooks/argocd-remove-app.yml` | Rename `repo_name` to `app_name` |
| `provision-host/uis/manage/uis-cli.sh` | Rewrite `cmd_argocd_register()` for two-param syntax with validation, update `cmd_argocd_remove()`, update help text and examples |
