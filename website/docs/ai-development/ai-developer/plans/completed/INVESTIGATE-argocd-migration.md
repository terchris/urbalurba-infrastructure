# INVESTIGATE: ArgoCD Migration & Cleanup

**Status:** Completed
**Created:** 2026-01-31
**Completed:** 2026-02-18
**Related to:** [STATUS-service-migration](STATUS-service-migration.md)
**Implementation:** [PLAN-argocd-migration](PLAN-argocd-migration.md)

---

## Summary

ArgoCD is well implemented with functional deploy/remove playbooks and a unique application management feature (register/remove GitHub repos). The migration to the new UIS system is nearly complete — only a metadata fix, some cleanup, and deployment verification remain.

---

## Current File Inventory

### Core Deployment (Current — Working)

| File | Purpose | Status |
|------|---------|--------|
| `ansible/playbooks/220-setup-argocd.yml` | Main deploy playbook — Helm install, bcrypt password, pod readiness, IngressRoute | ✅ Complete |
| `ansible/playbooks/220-remove-argocd.yml` | Remove playbook — Helm uninstall, preserves urbalurba-secrets, optional PVC cleanup | ✅ Complete |
| `manifests/220-argocd-config.yaml` | Helm values — chart v7.8.26, image v2.14.10, optimized for dev (minimal resources) | ✅ Complete |
| `manifests/221-argocd-ingressroute.yaml` | Traefik IngressRoute — `argocd\..+` pattern for multi-domain | ✅ Complete |

### Application Management (Current — Working)

This is a feature unique to ArgoCD among UIS services. It allows users to register GitHub repos as ArgoCD Applications with automated sync.

| File | Purpose | Status |
|------|---------|--------|
| `ansible/playbooks/argocd-register-app.yml` | Registers GitHub repo as ArgoCD app — creates namespace, stores credentials, enables auto-sync, waits for health | ✅ Complete |
| `ansible/playbooks/argocd-remove-app.yml` | Removes registered app — deletes app, secret, namespace | ✅ Complete |
| `scripts/argocd/argocd-register-app.sh` | Shell wrapper — validates params (GITHUB_USERNAME, REPO_NAME, GITHUB_PAT), calls playbook | ✅ Complete |
| `scripts/argocd/argocd-remove-app.sh` | Shell wrapper — validates REPO_NAME, calls playbook | ✅ Complete |

### UIS Service Metadata

| File | Purpose | Status |
|------|---------|--------|
| `provision-host/uis/services/management/service-argocd.sh` | Service metadata for `./uis list`, `./uis deploy` | ⚠️ `SCRIPT_REMOVE_PLAYBOOK` is empty |

### Documentation

| File | Purpose | Status |
|------|---------|--------|
| `website/docs/packages/development/argocd.md` | User docs — access, login, app registration workflow, troubleshooting | ✅ Complete |

### Previous Deployment System

The `not-in-use/` folder is part of the previous deployment system. Scripts in the parent folder (`08-development/`) ran automatically on boot. Moving a script to `not-in-use/` disabled it without deleting it.

| File | Purpose | Status |
|------|---------|--------|
| `provision-host/kubernetes/08-development/not-in-use/02-setup-argocd.sh` | Shell wrapper that called Ansible playbook | Disabled (in not-in-use/) |
| `provision-host/kubernetes/08-development/not-in-use/02-remove-argocd.sh` | Shell removal wrapper | Disabled (in not-in-use/) |

### Secret Artifacts (topsecret)

| File | Purpose | Status |
|------|---------|--------|
| `topsecret/kubernetes/argocd-urbalurba-secrets.yml` | bcrypt hash artifacts | 🗑️ Debugging leftovers |
| `topsecret/kubernetes/argocd-secret-fixed.yml` | bcrypt hash artifacts | 🗑️ Debugging leftovers |
| `topsecret/kubernetes/argocd-secret-correct.yml` | bcrypt hash artifacts | 🗑️ Debugging leftovers |
| `topsecret/kubernetes/argocd-secret-fix.yml` | bcrypt hash artifacts | 🗑️ Debugging leftovers |

### Testing Notes

| File | Purpose | Status |
|------|---------|--------|
| `terchris/testing/argocd/argocd-install-notes.md` | Historical install notes from 2025-04-15 | 📝 Reference only |

---

## Architecture

```
UIS System
    └─> service-argocd.sh
            ├─> 220-setup-argocd.yml (deploy)
            └─> 220-remove-argocd.yml (remove — NOT LINKED)

Application Management (separate from deploy/remove)
    ├─> scripts/argocd/argocd-register-app.sh
    │       └─> argocd-register-app.yml
    └─> scripts/argocd/argocd-remove-app.sh
            └─> argocd-remove-app.yml

Helm Configuration
    ├─> 220-argocd-config.yaml (values)
    └─> 221-argocd-ingressroute.yaml (routing)
```

---

## Technical Details

- **Helm**: chart `argo/argo-cd` v7.8.26, image v2.14.10
- **Namespace**: `argocd`
- **Auth**: bcrypt-hashed admin password from urbalurba-secrets
- **Access**: `argocd.localhost` (dev), `argocd.urbalurba.no` (external via tunnel)
- **Resources**: Minimal — 100m CPU, 128Mi memory for server (dev-optimized)
- **Insecure mode**: Enabled (HTTP for localhost development)

---

## Issues Found

### 1. Missing SCRIPT_REMOVE_PLAYBOOK (quick fix)

`service-argocd.sh` has `SCRIPT_REMOVE_PLAYBOOK=""` but `220-remove-argocd.yml` exists and works. One-line fix.

### 2. Docs path mismatch

Service script references `/docs/packages/management/argocd` but the actual docs are at `website/docs/packages/development/argocd.md`. Either the docs should be moved or the service metadata updated.

### 3. Old deployment scripts in not-in-use/

`02-setup-argocd.sh` and `02-remove-argocd.sh` are in `not-in-use/` (disabled in the previous deployment system). They contain hardcoded password "SecretPassword2" which doesn't match the current system. The new UIS system has replaced this boot-script pattern with service scripts and `./uis deploy`.

### 4. Secret artifacts in topsecret/

Four bcrypt hash files from debugging sessions. Not used by anything — safe to delete during topsecret cleanup (PLAN-004).

### 5. Not deployment-verified

ArgoCD has not been deployed and tested in the new UIS system. The playbooks are well-written but need a verification run.

### 6. App management commands belong in devcontainer-toolbox

The `scripts/argocd/` wrappers (register/remove GitHub repos) are **developer-facing** commands, not infrastructure management. They should be exposed through the [devcontainer-toolbox](https://github.com/terchris/devcontainer-toolbox) project, not `./uis`.

#### Two different audiences

| System | Audience | Purpose | Example |
|--------|----------|---------|---------|
| `./uis` (infrastructure) | Platform admin | Deploy/remove ArgoCD itself | `./uis deploy argocd` |
| `dev-argocd` (devcontainer-toolbox) | Developer | Register/remove apps in ArgoCD | `dev-argocd register my-repo` |

#### How devcontainer-toolbox works

The devcontainer-toolbox uses a pattern of auto-discovered commands:

- **Manage commands**: `.devcontainer/manage/dev-*.sh` — developer-facing CLI commands (e.g., `dev-services`, `dev-setup`)
- **Tool installers**: `.devcontainer/additions/install-*.sh` — install kubectl, helm, k9s, etc.
- **Metadata**: `SCRIPT_*` variables in each script (name, description, category) — parsed by `component-scanner.sh`
- **Auto-discovery**: `dev-help` scans for all `dev-*.sh` files and lists them

#### Proposed integration

Create `dev-argocd` in the devcontainer-toolbox that wraps the infrastructure project's Ansible playbooks:

```
Developer's VS Code devcontainer
    └─> dev-argocd register <github-user> <repo-name> <pat>
            └─> docker exec provision-host \
                  ansible-playbook argocd-register-app.yml \
                    -e github_username=<user> \
                    -e repo_name=<repo> \
                    -e github_pat=<pat>
```

The infrastructure project keeps the Ansible playbooks (business logic). The devcontainer-toolbox provides the developer-friendly CLI wrapper.

#### What stays where

| Component | Lives in | Reason |
|-----------|----------|--------|
| `argocd-register-app.yml` | urbalurba-infrastructure | Ansible playbook — infrastructure logic |
| `argocd-remove-app.yml` | urbalurba-infrastructure | Ansible playbook — infrastructure logic |
| `scripts/argocd/*.sh` | urbalurba-infrastructure | Shell wrappers for direct provision-host use |
| `dev-argocd.sh` (new) | devcontainer-toolbox | Developer CLI — calls provision-host via docker exec |

#### Open question

Should `scripts/argocd/*.sh` be removed once `dev-argocd` exists, or kept as a fallback for running directly inside the provision-host container? The scripts are simple validation wrappers — the real logic is in the Ansible playbooks.

---

## Recommended Actions

| Priority | Action | Effort |
|----------|--------|--------|
| **1** | Set `SCRIPT_REMOVE_PLAYBOOK="220-remove-argocd.yml"` in service-argocd.sh | 1 line |
| **2** | Deploy and verify ArgoCD works with `./uis deploy argocd` | Test run |
| **3** | Fix docs path — either move docs or update SCRIPT_DOCS in service metadata | Small |
| **4** | Old boot scripts in not-in-use/ — part of previous deployment system, no action needed | None |
| **5** | Secret artifacts — clean up with topsecret removal | Deferred |
| **6** | Create `dev-argocd` command in devcontainer-toolbox project | New feature (separate repo) |

---

## Conclusion

ArgoCD is fully migrated. All issues identified in this investigation were resolved in [PLAN-argocd-migration](PLAN-argocd-migration.md), including the SCRIPT_REMOVE_PLAYBOOK fix, deployment verification with E2E tests, bcrypt password handling, and secrets cleanup.

The app management commands (`scripts/argocd/`) are developer-facing and should be exposed through the devcontainer-toolbox project as a `dev-argocd` manage command, keeping the Ansible playbooks in this infrastructure repo as the backend.
