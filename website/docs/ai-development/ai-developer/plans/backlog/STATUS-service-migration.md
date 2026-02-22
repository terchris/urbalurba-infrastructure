# PLAN-008: Service Migration Status & Remaining Work

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Track migration status of all 26 UIS services and complete remaining work for services that are not fully migrated.

**Last Updated**: 2026-02-22 (talk11)

**Priority**: Medium — core services work, remaining items are edge cases

**Blocks**: [PLAN-004-secrets-cleanup](../completed/PLAN-004-secrets-cleanup.md) — old path references in playbooks must be fixed before backwards compatibility code can be removed

---

## Service Migration Status

All 26 services have service scripts (`provision-host/uis/services/*/service-*.sh`) and deploy playbooks. The table below tracks full migration status including remove playbooks, verified deployment, and legacy path dependencies.

### Legend

- **Service script**: `provision-host/uis/services/<category>/service-<id>.sh` — metadata for `./uis list`, `./uis deploy`, etc.
- **Deploy playbook**: Ansible playbook for `./uis deploy <service>`
- **Remove playbook**: Ansible playbook for `./uis undeploy <service>`
- **Verified**: Service has been deployed and tested in the new UIS system
- **Old paths**: ⚠️ = playbook still references `topsecret/`, `secrets/`, or `cloud-init/`

### Core (000-029)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **whoami** | ✅ | ✅ `025-setup-whoami-testpod.yml` | ✅ via `-e operation=delete` | ✅ | Same playbook handles both deploy and remove via operation parameter |
| **nginx** | ✅ | ✅ `020-setup-nginx.yml` | ✅ `020-remove-nginx.yml` | ✅ | Verified in talk9.md |

### Monitoring (030-039)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **prometheus** | ✅ | ✅ `030-setup-prometheus.yml` | ✅ `030-remove-prometheus.yml` | ✅ | Verified in talk9.md |
| **tempo** | ✅ | ✅ `031-setup-tempo.yml` | ✅ `031-remove-tempo.yml` | ✅ | Verified in talk9.md |
| **loki** | ✅ | ✅ `032-setup-loki.yml` | ✅ `032-remove-loki.yml` | ✅ | Verified in talk9.md |
| **otel-collector** | ✅ | ✅ `033-setup-otel-collector.yml` | ✅ `033-remove-otel-collector.yml` | ✅ | Verified in talk9.md |
| **grafana** | ✅ | ✅ `034-setup-grafana.yml` | ✅ `034-remove-grafana.yml` | ✅ | Verified in talk9.md |

### Databases (040-059)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **postgresql** | ✅ | ✅ `040-database-postgresql.yml` | ✅ `040-remove-database-postgresql.yml` | ✅ | Required by authentik |
| **mysql** | ✅ | ✅ `040-database-mysql.yml` | ✅ `040-remove-database-mysql.yml` | ✅ | Verified in talk9.md |
| **mongodb** | ✅ | ✅ `040-setup-mongodb.yml` | ✅ `040-remove-database-mongodb.yml` | ✅ | Verified in talk9.md |
| **qdrant** | ✅ | ✅ `044-setup-qdrant.yml` | ✅ `044-remove-qdrant.yml` | ✅ | Verified in talk9.md |
| **redis** | ✅ | ✅ `050-setup-redis.yml` | ✅ `050-remove-redis.yml` | ✅ | Required by authentik |

### Search (060-069)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **elasticsearch** | ✅ | ✅ `060-setup-elasticsearch.yml` | ✅ `060-remove-elasticsearch.yml` | ✅ | Verified in talk9.md |

### Authentication (070-079)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **authentik** | ✅ | ✅ `070-setup-authentik.yml` | ✅ `070-remove-authentik.yml` | ✅ | Fully tested with 5 E2E auth tests (PLAN-007) |

### Queues (080-089)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **rabbitmq** | ✅ | ✅ `080-setup-rabbitmq.yml` | ✅ `080-remove-rabbitmq.yml` | ✅ | Verified in talk9.md |

### Management (090, 220+)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **gravitee** | ✅ | ✅ `090-setup-gravitee.yml` | ❌ Missing | ❌ | **Was not working before migration.** Needs new setup — deploy playbook may need rewrite |
| **argocd** | ✅ | ✅ `220-setup-argocd.yml` | ✅ `220-remove-argocd.yml` | ✅ | Verified in talk9.md |
| **pgadmin** | ✅ | ✅ `641-adm-pgadmin.yml` | ✅ `641-remove-pgadmin.yml` | ✅ | Verified in talk10.md. Auto-login TODO (pgpass works but pgAdmin ignores it) |
| **redisinsight** | ✅ | ✅ `651-adm-redisinsight.yml` | ✅ `651-remove-redisinsight.yml` | ✅ | Verified in talk10.md |

### AI (200-219)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **openwebui** | ✅ | ✅ `200-setup-open-webui.yml` | ✅ `200-remove-open-webui.yml` | ✅ | Verified in talk9.md |
| **litellm** | ✅ | ✅ `210-setup-litellm.yml` | ✅ `210-remove-litellm.yml` | ✅ | Verified in talk9.md |

### Data Science (320-350)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **unity-catalog** | ✅ | ✅ `320-setup-unity-catalog.yml` | ✅ `320-remove-unity-catalog.yml` | ✅ | Verified in talk9.md. Fixed: wrong image, security context, API version, no curl |
| **spark** | ✅ | ✅ `330-setup-spark.yml` | ✅ `330-remove-spark.yml` | ✅ | Verified in talk9.md |
| **jupyterhub** | ✅ | ✅ `350-setup-jupyterhub.yml` | ✅ `350-remove-jupyterhub.yml` | ✅ | Verified in talk9.md |

### Network (800+)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **tailscale-tunnel** | ✅ | ✅ `801-setup-network-tailscale-tunnel.yml` | ❌ Missing | ❌ | Missing remove playbook. Old path refs in error messages fixed in PR #35 |
| **cloudflare-tunnel** | ✅ | ✅ `820-setup-network-cloudflare-tunnel.yml` | ❌ Missing | ❌ | No remove playbook |

---

## Summary

| Category | Total | Verified | Issues |
|----------|:-----:|:--------:|--------|
| Core | 2 | 2 | None |
| Monitoring | 5 | 5 | None |
| Databases | 5 | 5 | None |
| Search | 1 | 1 | None |
| Authentication | 1 | 1 | None |
| Queues | 1 | 1 | None |
| Management | 4 | 3 | gravitee broken before migration |
| AI | 2 | 2 | None |
| Data Science | 3 | 3 | None |
| Network | 2 | 0 | Both missing remove playbooks; require external accounts |
| **Total** | **26** | **23** | **3 not verified** (gravitee broken, tailscale/cloudflare need auth keys) |

### Playbooks with Old Path References (2026-02-18 scan)

Scanned all playbooks in `ansible/playbooks/` for references to `topsecret/`, `secrets/`, and `cloud-init/`:

| Playbook | Line | Reference | Impact | Fixed |
|----------|------|-----------|--------|:-----:|
| `01-configure_provision-host.yml` | 30 | `ansible/secrets/id_rsa_ansible.secret-key` | Hardcoded old SSH key path | ✅ PR #35 |
| `350-setup-jupyterhub.yml` | 65 | `topsecret/kubernetes/kubernetes-secrets.yml` | **Breaks if topsecret/ removed** | ✅ PR #35 |
| `802-deploy-network-tailscale-tunnel.yml` | 193-194 | `topsecret/kubernetes/kubernetes-secrets.yml` | Error message text only | ✅ PR #35 |

All old path references in playbooks are now fixed. Also fixed: `ansible/ansible.cfg` and `provision-host/provision-host-vm-create.sh` (PR #35).

### Topsecret Cleanup Beyond Playbooks (talk11)

In addition to the playbook fixes above (PR #35), a full topsecret cleanup was completed across the codebase:

| Category | Files Changed | What Changed |
|----------|:---:|--------|
| Legacy scripts | 7 | Removed `topsecret/` and `secrets/` fallback paths from networking scripts and provision-host container creation |
| Config files | 3 | `.github/workflows/build-uis-container.yml`, `.dockerignore`, `manifests/220-litellm-config.yaml` |
| Documentation | 17 | All docs updated from `topsecret/kubernetes/kubernetes-secrets.yml` to `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml` |
| Deleted obsolete scripts | 2 | `install-rancher.sh` and `copy2provisionhost.sh` — fully replaced by `./uis` CLI |
| Docs updated for script removal | 15+ | All references to deleted scripts replaced with `./uis start`, `./uis provision`, `./uis shell` |

**Remaining topsecret references**: Only in 7 remote deployment target scripts (`provision-host/provision-host-vm-create.sh`, `hosts/azure-aks/` scripts). These are deferred until remote deployment targets are tested with real infrastructure.

### New Reference Documentation (talk11)

- Created `website/docs/reference/factory-reset.md` — user-facing runbook for factory reset, recovery, service deployment order, and verification checklist. Extracted from INVESTIGATE-rancher-reset findings.

### Completed Investigations Closed (talk11)

- `INVESTIGATE-rancher-reset-and-full-verification.md` → moved to `completed/`
- `INVESTIGATE-unity-catalog-crashloop.md` → moved to `completed/`

---

## Phase 1: Quick Fixes (metadata)

### Tasks

- [x] 1.1 Fix ArgoCD: set `SCRIPT_REMOVE_PLAYBOOK="220-remove-argocd.yml"` in `service-argocd.sh` ✓ (PLAN-argocd-migration)

---

## Phase 2: Fix Old Path References in Playbooks

These must be fixed before PLAN-004-secrets-cleanup can remove backwards compatibility.

### Tasks

- [x] 2.1 Fix `350-setup-jupyterhub.yml` line 65: replace `topsecret/kubernetes/kubernetes-secrets.yml` with new `.uis.secrets/` path ✓ (PR #35)
- [x] 2.2 Fix `01-configure_provision-host.yml` line 30: replace `ansible/secrets/id_rsa_ansible.secret-key` with new path ✓ (PR #35)
- [x] 2.3 Fix `802-deploy-network-tailscale-tunnel.yml` lines 193-194: update error message text to reference `.uis.secrets/` ✓ (PR #35)
- [x] 2.4 Fix `ansible/ansible.cfg`: update `private_key_file` to new `.uis.secrets/` path ✓ (PR #35)
- [x] 2.5 Fix `provision-host/provision-host-vm-create.sh`: update SSH key copy destination, remove legacy fallback ✓ (PR #35)

---

## Phase 3: Missing Remove Playbooks

### Tasks

- [ ] 3.1 Create `801-remove-network-tailscale-tunnel.yml` — tear down Tailscale tunnel deployment and namespace
- [ ] 3.2 Create `820-remove-network-cloudflare-tunnel.yml` — tear down Cloudflare tunnel deployment and namespace
- [ ] 3.3 Update service scripts with `SCRIPT_REMOVE_PLAYBOOK` references

---

## Phase 4: Gravitee (New Setup)

Gravitee was not working before the migration. This is effectively a fresh setup, not a migration.

### Tasks

- [ ] 4.1 Investigate current state of `090-setup-gravitee.yml` — does it work at all?
- [ ] 4.2 If broken, rewrite the deploy playbook or disable the service
- [ ] 4.3 Create `090-remove-gravitee.yml`
- [ ] 4.4 Test deploy and remove cycle

---

## Phase 5: Deployment Verification — COMPLETE

23/26 services verified. All deploy and undeploy cleanly from a factory-reset clean slate (talk9.md, talk10.md).

### Tasks

- [x] 5.1 Verify monitoring stack: prometheus, grafana, loki, tempo, otel-collector ✓ (talk9.md)
- [x] 5.2 Verify databases: mysql, mongodb, qdrant ✓ (talk9.md)
- [x] 5.3 Verify AI stack: openwebui, litellm ✓ (talk9.md)
- [x] 5.4 Verify data science stack: jupyterhub, spark, unity-catalog ✓ (talk9.md)
- [x] 5.5 Verify other: nginx, elasticsearch, rabbitmq ✓ (talk9.md)
- [x] 5.6 Verify management: pgadmin, redisinsight ✓ (talk10.md)
- [ ] 5.7 Verify network: tailscale-tunnel, cloudflare-tunnel (requires external accounts)

**Skipped**: gravitee (broken before migration), tailscale-tunnel (requires auth key), cloudflare-tunnel (requires token).

---

## Files to Modify

| File | Change |
|------|--------|
| `provision-host/uis/services/management/service-argocd.sh` | ✅ Done — Add `SCRIPT_REMOVE_PLAYBOOK` |
| `provision-host/uis/services/network/service-tailscale-tunnel.sh` | Add `SCRIPT_REMOVE_PLAYBOOK` |
| `provision-host/uis/services/network/service-cloudflare-tunnel.sh` | Add `SCRIPT_REMOVE_PLAYBOOK` |
| `ansible/playbooks/350-setup-jupyterhub.yml` | ✅ Done — Replace hardcoded `topsecret/` path (PR #35) |
| `ansible/playbooks/01-configure_provision-host.yml` | ✅ Done — Replace hardcoded `secrets/` SSH key path (PR #35) |
| `ansible/playbooks/802-deploy-network-tailscale-tunnel.yml` | ✅ Done — Update error message text (PR #35) |

## Files to Create

| File | Purpose |
|------|---------|
| `ansible/playbooks/801-remove-network-tailscale-tunnel.yml` | Tailscale tunnel removal |
| `ansible/playbooks/820-remove-network-cloudflare-tunnel.yml` | Cloudflare tunnel removal |
| `ansible/playbooks/090-remove-gravitee.yml` | Gravitee removal (if service is fixed) |
