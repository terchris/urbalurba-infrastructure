# PLAN-007: Authentik Automatic Secrets Application

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: In Progress

**Goal**: Make Authentik deployment fully automatic by applying secrets at the start of the playbook, eliminating the need for manual `kubectl apply` before deployment.

**Last Updated**: 2026-01-28

**Branch**: `feature/secrets-migration`

**Prerequisites**: None - this is a standalone fix

**Related**: [INVESTIGATE-authentik-automation.md](../backlog/INVESTIGATE-authentik-automation.md)

---

## Contributor/Tester Workflow

This plan is implemented by a **contributor** (Claude Code) with a separate **tester** (UIS-USER1).

**Communication**: Via `talk.md` file in the tester's environment (`/Users/terje.christensen/learn/projects-2026/testing/uis1/talk/talk.md`)

**Workflow**:
1. Contributor writes test instructions to `talk.md`
2. Tester executes tests and reports results back in `talk.md`
3. Contributor reads results and iterates

**Before starting implementation**:
- Rename current `talk.md` to `talk5.md` (archive previous session)
- Create new empty `talk.md` for this session

---

## Problem Statement

Currently, deploying Authentik requires a manual step:
```bash
kubectl apply -f .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
```

Without this, the playbook fails because:
1. The `authentik` namespace doesn't exist
2. The `urbalurba-secrets` secret doesn't exist in the namespace
3. The database utility can't read the password
4. Helm deployment fails (pods crash)

The generated `kubernetes-secrets.yml` already contains the namespace and secrets - the playbook just needs to apply it.

---

## Solution

Add an early step to `070-setup-authentik.yml` that applies the secrets file before checking for prerequisites.

### Before (fails)
```
1. Check namespace exists → FAIL
2. Check secrets exist → FAIL
3. ...
```

### After (works)
```
1. Apply secrets file (creates namespace + secrets)
2. Check namespace exists → PASS
3. Check secrets exist → PASS
4. ...
```

---

## Phase 0: Setup — COMPLETE

### Tasks

- [x] 0.1 Rename `talk.md` to `talk5.md` (archive previous session)
- [x] 0.2 Create new empty `talk.md` with session header for PLAN-007

---

## Phase 1: Update Playbook — COMPLETE

### Tasks

- [x] 1.1 Add new task to apply secrets file early in `070-setup-authentik.yml`

  **Implementation note:** Changed from `kubernetes.core.k8s` module to `kubectl apply` command because the k8s module has issues with multi-document YAML files.

  ```yaml
  - name: "1.5. Apply secrets file to create namespace and credentials"
    ansible.builtin.command: >
      kubectl apply -f {{ secrets_file }}
    environment:
      KUBECONFIG: "{{ merged_kubeconf_file }}"
    register: secrets_apply_result

  - name: "1.6. Display secrets application status"
    ansible.builtin.debug:
      msg: |
        ✅ Secrets applied successfully
        📁 Source: {{ secrets_file }}
        🔧 Created: authentik namespace and urbalurba-secrets
  ```

- [x] 1.2 Update the playbook header comment to reflect that secrets are auto-applied

- [x] 1.3 Test deployment with `./uis deploy authentik`
  - Fresh cluster (no authentik namespace) ✅
  - Succeeded without manual steps ✅

- [x] 1.4 Test removal with `./uis undeploy authentik`
  - Works as before ✅

---

## Phase 2: Update Documentation — COMPLETE

### Tasks

- [x] 2.1 Update `INVESTIGATE-authentik-automation.md` to mark Goal 1 complete

- [x] 2.2 Test results documented in `talk.md`

---

## Phase 3: Fix Authentik Redirect URL — COMPLETE

### Problem

When authenticating via Authentik forward auth, the redirect URL goes to `http://authentik-server.authentik.svc.cluster.local` (internal Kubernetes URL) instead of `http://authentik.localhost`.

**Root Cause:** Authentik bug #5922 - the embedded outpost **ignores `authentik_host_browser`** for OAuth redirects. It uses `authentik_host` for all browser-facing redirects.

**Status:** Bug was closed as "not planned" (won't fix) by Authentik team.

### Tasks

- [x] 3.1 Investigate where `authentik_host_browser` should be configured
  - Initial finding: Added `config` section with `authentik_host_browser` to blueprint
  - Issue: Template rendered correctly but redirect still wrong

- [x] 3.2 Deep debugging of embedded outpost behavior
  - Verified outpost database config shows correct `authentik_host_browser`
  - Tested with `AUTHENTIK_HOST_BROWSER` environment variable - no effect
  - Discovered Authentik bug #5922: embedded outpost ignores `authentik_host_browser`

- [x] 3.3 Implement workaround for Authentik bug #5922
  - Set `authentik_host` (not just `authentik_host_browser`) to external URL
  - Embedded outpost can still reach server locally (same pod)
  - Tested manually - redirect now goes to `http://authentik.localhost`

- [x] 3.4 Update blueprint template with permanent fix
  - Updated `manifests/073-authentik-service-protection-blueprint.yaml.j2`
  - Changed outpost config:
    ```yaml
    config:
      authentik_host: {{ domains.localhost.protocol }}://authentik.{{ domains.localhost.base_domain }}
      authentik_host_browser: {{ domains.localhost.protocol }}://authentik.{{ domains.localhost.base_domain }}
    ```

- [ ] 3.5 Rebuild container and verify fix persists after redeploy

### Technical Details

**Authentik Bug #5922**: https://github.com/goauthentik/authentik/issues/5922
- Title: "Embedded proxy redirects to authentik_host, not authentik_host_browser"
- Status: Closed as "not planned" (won't fix)
- Workaround: Set `authentik_host` to external URL (embedded outpost runs in same pod)

### Limitation

The redirect URL uses the localhost domain configuration. External domains (e.g., `authentik.urbalurba.no`) would need separate outpost configuration or a standalone outpost deployment.

---

## Phase 4: End-to-End Auth Testing in Playbook — NOT STARTED

### Problem

The playbook tests public and protected URLs using cluster-internal curl pods (via Traefik's internal service). These tests verify HTTP status codes (200 for public, 302 for protected) but do NOT verify:

1. The redirect URL points to `authentik.localhost` (not `0.0.0.0:9000` or an internal URL)
2. A test user can actually log in through the full OAuth flow
3. The authenticated response contains the expected auth headers

All of these were tested manually by the tester. They should be automated in the playbook.

### Solution

Extend the existing playbook tests with three levels:

**Level 1 — Redirect URL verification:** Check that the protected URL's `Location` header contains the correct Authentik domain (not `0.0.0.0:9000`). This runs from a cluster-internal curl pod (same as existing tests).

**Level 2 — Full login flow:** From a curl pod inside the cluster, perform the complete OAuth authentication:
1. GET protected URL → capture 302 redirect Location
2. Follow redirect to Authentik login page → extract CSRF token / flow execution URL
3. POST test user credentials (`it1@urbalurba.no` / `Password123`)
4. Follow redirects back to protected URL
5. Verify response contains whoami output with Authentik auth headers (`X-authentik-username`, etc.)

**Level 3 — Public URL content verification:** Confirm public URL returns actual whoami content (not just HTTP 200).

### Tasks

- [ ] 4.1 Add redirect URL content check to existing protected URL test
  - After task 50 (which checks for 302), add a task that extracts the `Location` header
  - Verify it contains `authentik.localhost` (or the configured domain)
  - Fail with clear message if it contains `0.0.0.0:9000` or internal cluster URL

- [ ] 4.2 Add full login flow test
  - Use a curl pod with cookie jar support (`-b` / `-c` flags)
  - Step through the OAuth flow with test user credentials
  - Verify final response contains `X-authentik-username` header
  - This test runs AFTER Authentik has had time to process blueprints (after task 33 pause)

- [ ] 4.3 Add public URL content verification
  - Extend task 21 to check response body contains `Hostname:` (whoami output)
  - Verify no auth headers are present (public route should not have them)

- [ ] 4.4 Handle test failures gracefully
  - Login flow test should be `failed_when: false` with clear diagnostic output
  - Blueprint processing may not be complete on first deploy — test should retry or warn
  - Document which tests are critical (must pass) vs advisory (may fail on slow clusters)

---

## Verification Checklist

- [x] `./uis deploy authentik` works on fresh cluster without manual steps
- [x] `./uis undeploy authentik` still works
- [x] Authentik pods start successfully
- [x] Test users are created (blueprint processed)
- [x] Forward auth middleware works
- [x] Authentication redirect goes to `authentik.localhost` (verified Test 14)
- [x] Authentication redirect fix persists after container rebuild (verified Test 14)
- [x] Task 28 database setup succeeds (exit code 0, verified Test 14)
- [x] Fail-fast stops playbook on database failure (verified Test 13)
- [ ] Playbook verifies redirect URL content (not just status code)
- [ ] Playbook performs full login flow test with test user
- [ ] Playbook verifies public URL returns content without auth

---

## Rollback

If issues occur, remove the added tasks (1.5 and 1.6) from the playbook. The manual workaround still works.

---

## Implementation Notes

- This is Goal 1 from INVESTIGATE-authentik-automation
- Quick fix that can be done independently of Goal 2 (config architecture)
- The secrets file path is hardcoded to the new `.uis.secrets/` location
- Backwards compatibility with `topsecret/` is handled by the secrets generation, not this playbook

### Issues Encountered During Implementation

1. **kubernetes.core.k8s module issue**: The Ansible k8s module couldn't handle multi-document YAML files with namespace + secrets. Error: "Namespace is required for v1.Secret". **Fix**: Changed to `kubectl apply` command.

2. **Task ordering bug**: The playbook tested UI accessibility (task 35) BEFORE deploying IngressRoutes (task 38-40). **Fix**: Reordered tasks so IngressRoutes deploy first (tasks 34-36), then UI test (tasks 37-39).

3. **Duplicate task numbering**: Two tasks were numbered "45". **Fix**: Renumbered tasks 46-59.

4. **Secrets not applied after factory reset**: After a Rancher Desktop factory reset, host files (`.uis.extend/`, `.uis.secrets/`) survive but Kubernetes is wiped. The `check_first_run()` function only checks if `enabled-services.conf` exists on the host, so it skips initialization (including `apply_kubernetes_secrets()`). **Fix**: Added `ensure_secrets_applied()` function in `first-run.sh` that is called from `cmd_deploy()` on every deploy. It generates secrets if the file doesn't exist, then always applies with `kubectl apply` (idempotent).

5. **pg_hba.conf md5 vs scram-sha-256 mismatch**: Bitnami PostgreSQL chart v18+ generates `pg_hba.conf` with `md5` auth, but PostgreSQL 16 defaults to `scram-sha-256` password encryption. Password set during init is stored as scram-sha-256 hash, but md5 auth can't verify it. **Fix**: Added `pgHbaConfiguration` with `scram-sha-256` to `042-database-postgresql-config.yaml`.

6. **Bash escaping `!` in passwords**: Bitnami init script passes passwords through bash, which escapes `!` (history expansion) to `\!`. Password `LocalDevDB456!` was stored as `LocalDevDB456\!` in PostgreSQL. **Fix**: Removed `!` from all default passwords. Documented password restriction (no `!  $  \`  \  "`) in three files.

7. **Helm chart not version-pinned**: `helm install postgresql bitnami/postgresql` with no `--version` flag caused unpredictable behavior after factory reset. **Fix**: Pinned to `--version 18.2.3`.

8. **Playbook continues after database failure**: Task 28 had `failed_when: false` with no subsequent failure check, so Authentik deployed even when the database didn't exist (pods crash-loop). **Fix**: Added task 29.1 with `ansible.builtin.fail` when `postgres_setup_result.rc != 0`.

9. **Sub-playbook exit code 4**: Task 28 called `u09-authentik-create-postgres.yml` via `ansible.builtin.command` with `chdir: /mnt/urbalurbadisk/ansible`. This made the child process find `ansible/ansible.cfg` which sets `collections_path` to a directory where collections aren't installed. The global `/etc/ansible/ansible.cfg` uses default paths where they are. **Fix**: Removed `args: chdir:` from tasks 28 and 44 (all paths are absolute).

---

## Future Ideas (Out of Scope)

The tester suggested a feature idea during testing:

- **Authentik CLI** - `./uis authentik users list` etc. (added to [INVESTIGATE-authentik-automation.md](../backlog/INVESTIGATE-authentik-automation.md))
