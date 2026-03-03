# PLAN: ArgoCD Register Command Redesign

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

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

## Phase 1: Update the Ansible Register Playbook

Rewrite `ansible/playbooks/argocd-register-app.yml` to accept `app_name` and `repo_url` instead of `github_username` and `repo_name`.

### Tasks

- [ ] 1.1 Change the required variables from `github_username`/`repo_name` to `app_name`/`repo_url`
- [ ] 1.2 Add a task to parse `repo_url` into `github_owner` and `repo_name` using Ansible filters (e.g., `repo_url | urlsplit` or regex)
- [ ] 1.3 Add a task to validate that `repo_url` starts with `https://` and contains an owner and repo path
- [ ] 1.4 Add a pre-flight check that ArgoCD server pods are running before attempting registration
- [ ] 1.5 Replace all uses of `repo_name` (for namespace/app name) with `app_name` throughout the playbook
- [ ] 1.6 Use `repo_url` directly for the ArgoCD Application source URL (instead of constructing it from `github_username` + `repo_name`)
- [ ] 1.7 Use parsed `github_owner` and `repo_name` for GitHub API pre-flight checks (repo exists, manifests/ directory exists)
- [ ] 1.8 Update the credentials secret to use parsed `github_owner` and `repo_name`
- [ ] 1.9 Update the cleanup/rescue block to use `app_name` for resource names
- [ ] 1.10 Update all display messages and error messages to reflect new variable names

### Validation

Run the playbook directly with `-e` variables to verify it works:
```bash
ansible-playbook argocd-register-app.yml \
  -e "app_name=hello-world" \
  -e "repo_url=https://github.com/terchris/urb-dev-typescript-hello-world"
```

User confirms playbook runs correctly.

---

## Phase 2: Update the Ansible Remove Playbook

Update `ansible/playbooks/argocd-remove-app.yml` to use `app_name` instead of `repo_name` for consistency.

### Tasks

- [ ] 2.1 Rename `repo_name` variable to `app_name` throughout the playbook
- [ ] 2.2 Update the GitHub secret name pattern to use `app_name`
- [ ] 2.3 Update all display messages and error messages

### Validation

User confirms playbook structure looks correct.

---

## Phase 3: Update the CLI

Rewrite the ArgoCD commands in `provision-host/uis/manage/uis-cli.sh`.

### Tasks

- [ ] 3.1 Rewrite `cmd_argocd_register()`:
  - Require two arguments: `<name>` and `<repo-url>`
  - Validate `<name>` is DNS-compatible (lowercase alphanumeric and hyphens, max 63 chars)
  - Validate `<name>` is not already in use as a Kubernetes namespace (kubectl check)
  - Validate `<repo-url>` starts with `https://`
  - Pass `app_name` and `repo_url` to the playbook
  - Optionally pass `github_pat` from secrets (if configured, for private repos)
  - Show clear error messages with usage examples on validation failure
- [ ] 3.2 Update `cmd_argocd_remove()`:
  - Update help text (the parameter is now called `<name>`, not `<repo>`)
  - Pass `app_name` instead of `repo_name` to the playbook
- [ ] 3.3 Update the help text in the main help section (around line 103-107):
  - `argocd register <name> <repo-url>` with updated description
  - `argocd remove <name>` with updated description
- [ ] 3.4 Update the examples section (around line 141-143) with new syntax

### Validation

```bash
# Should show usage with examples
UIS_IMAGE=uis-provision-host:local ./uis argocd register

# Should fail: missing repo-url
UIS_IMAGE=uis-provision-host:local ./uis argocd register hello-world

# Should fail: name not DNS-compatible
UIS_IMAGE=uis-provision-host:local ./uis argocd register Hello_World https://github.com/terchris/urb-dev-typescript-hello-world

# Should fail: not https URL
UIS_IMAGE=uis-provision-host:local ./uis argocd register hello-world git@github.com:terchris/urb-dev-typescript-hello-world.git
```

User confirms validation errors are clear and helpful.

---

## Phase 4: Improve Error Diagnostics in Register Playbook

Add better error messages when deployment fails instead of generic timeouts.

### Tasks

- [ ] 4.1 On pod timeout: add a task that checks pod status for `ImagePullBackOff`, `ErrImagePull`, `CrashLoopBackOff`, or `Pending` and shows a specific diagnostic message:
  - `ImagePullBackOff` / `ErrImagePull` → "Container image not found. Check image name and tag in your manifests."
  - `CrashLoopBackOff` → "Container starts but crashes. Check application logs with: kubectl logs -n <name> <pod>"
  - `Pending` → "Pod cannot be scheduled. Check cluster resources (CPU/memory)."
- [ ] 4.2 On sync timeout: query the ArgoCD Application's `.status.operationState.message` or `.status.conditions` to show the actual sync error
- [ ] 4.3 Include the diagnostic info in the cleanup/rescue block output so the user sees it before cleanup runs

### Validation

User confirms error messages are specific and actionable.

---

## Phase 5: Build and Test End-to-End

Rebuild the container and test the full flow.

### Tasks

- [ ] 5.1 Rebuild the container image: `./uis build` (with `--no-cache` if needed)
- [ ] 5.2 Restart with local image: `UIS_IMAGE=uis-provision-host:local ./uis restart`
- [ ] 5.3 Verify help output shows new syntax: `UIS_IMAGE=uis-provision-host:local ./uis argocd`
- [ ] 5.4 Test full register flow (requires ArgoCD deployed in cluster):
  ```bash
  UIS_IMAGE=uis-provision-host:local ./uis argocd register hello-world https://github.com/terchris/urb-dev-typescript-hello-world
  ```
- [ ] 5.5 Test list: `UIS_IMAGE=uis-provision-host:local ./uis argocd list`
- [ ] 5.6 Test remove: `UIS_IMAGE=uis-provision-host:local ./uis argocd remove hello-world`

### Validation

User confirms full register → list → remove cycle works correctly.

---

## Acceptance Criteria

- [ ] `uis argocd register` requires exactly two arguments: `<name>` and `<repo-url>`
- [ ] `<name>` is validated as DNS-compatible and not already in use
- [ ] `<repo-url>` must be a full HTTPS URL
- [ ] Public repos work without any secrets configured
- [ ] Private repos work when a GitHub PAT is configured in secrets
- [ ] `uis argocd remove <name>` removes the application by name
- [ ] ArgoCD pre-flight check fails fast if ArgoCD is not deployed
- [ ] Pod failure diagnostics show specific error messages (ImagePullBackOff, CrashLoopBackOff, Pending)
- [ ] Sync failure diagnostics show the actual ArgoCD sync error
- [ ] Help text and examples reflect the new two-parameter syntax
- [ ] No dependency on `GITHUB_USERNAME` in secrets for registration

---

## Files to Modify

| File | Change |
|------|--------|
| `ansible/playbooks/argocd-register-app.yml` | Accept `app_name`/`repo_url`, parse URL in playbook, add ArgoCD pre-flight check, improve error diagnostics |
| `ansible/playbooks/argocd-remove-app.yml` | Rename `repo_name` to `app_name` |
| `provision-host/uis/manage/uis-cli.sh` | Rewrite `cmd_argocd_register()` for two-param syntax with validation, update `cmd_argocd_remove()`, update help text and examples |
