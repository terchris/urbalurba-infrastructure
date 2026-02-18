# PLAN-008: Service Migration Status & Remaining Work

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Track migration status of all 24 UIS services and complete remaining work for services that are not fully migrated.

**Last Updated**: 2026-02-18

**Priority**: Medium — core services work, remaining items are edge cases

**Blocks**: [PLAN-004-secrets-cleanup](PLAN-004-secrets-cleanup.md) — old path references in playbooks must be fixed before backwards compatibility code can be removed

---

## Service Migration Status

All 24 services have service scripts (`provision-host/uis/services/*/service-*.sh`) and deploy playbooks. The table below tracks full migration status including remove playbooks, verified deployment, and legacy path dependencies.

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
| **nginx** | ✅ | ✅ `020-setup-nginx.yml` | ✅ `020-remove-nginx.yml` | ❌ | Not tested in new system |

### Monitoring (030-039)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **prometheus** | ✅ | ✅ `030-setup-prometheus.yml` | ✅ `030-remove-prometheus.yml` | ❌ | |
| **tempo** | ✅ | ✅ `031-setup-tempo.yml` | ✅ `031-remove-tempo.yml` | ❌ | |
| **loki** | ✅ | ✅ `032-setup-loki.yml` | ✅ `032-remove-loki.yml` | ❌ | |
| **otel-collector** | ✅ | ✅ `033-setup-otel-collector.yml` | ✅ `033-remove-otel-collector.yml` | ❌ | |
| **grafana** | ✅ | ✅ `034-setup-grafana.yml` | ✅ `034-remove-grafana.yml` | ❌ | |

### Databases (040-059)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **postgresql** | ✅ | ✅ `040-database-postgresql.yml` | ✅ `040-remove-database-postgresql.yml` | ✅ | Required by authentik |
| **mysql** | ✅ | ✅ `040-database-mysql.yml` | ✅ `040-remove-database-mysql.yml` | ❌ | |
| **mongodb** | ✅ | ✅ `040-setup-mongodb.yml` | ✅ `040-remove-database-mongodb.yml` | ❌ | |
| **qdrant** | ✅ | ✅ `044-setup-qdrant.yml` | ✅ `044-remove-qdrant.yml` | ❌ | |
| **redis** | ✅ | ✅ `050-setup-redis.yml` | ✅ `050-remove-redis.yml` | ✅ | Required by authentik |

### Search (060-069)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **elasticsearch** | ✅ | ✅ `060-setup-elasticsearch.yml` | ✅ `060-remove-elasticsearch.yml` | ❌ | Switched to official image in this branch |

### Authentication (070-079)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **authentik** | ✅ | ✅ `070-setup-authentik.yml` | ✅ `070-remove-authentik.yml` | ✅ | Fully tested with 5 E2E auth tests (PLAN-007) |

### Queues (080-089)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **rabbitmq** | ✅ | ✅ `080-setup-rabbitmq.yml` | ✅ `080-remove-rabbitmq.yml` | ❌ | |

### Management (090, 220+)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **gravitee** | ✅ | ✅ `090-setup-gravitee.yml` | ❌ Missing | ❌ | **Was not working before migration.** Needs new setup — deploy playbook may need rewrite |
| **argocd** | ✅ | ✅ `220-setup-argocd.yml` | ✅ `220-remove-argocd.yml` | ✅ | Metadata fixed and deploy/undeploy verified (PLAN-argocd-migration) |

### AI (200-219)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **openwebui** | ✅ | ✅ `200-setup-open-webui.yml` | ✅ `200-remove-open-webui.yml` | ❌ | |
| **litellm** | ✅ | ✅ `210-setup-litellm.yml` | ✅ `210-remove-litellm.yml` | ❌ | |

### Data Science (320-350)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **unity-catalog** | ✅ | ✅ `320-setup-unity-catalog.yml` | ✅ `320-remove-unity-catalog.yml` | ❌ | |
| **spark** | ✅ | ✅ `330-setup-spark.yml` | ✅ `330-remove-spark.yml` | ❌ | |
| **jupyterhub** | ✅ | ✅ `350-setup-jupyterhub.yml` | ✅ `350-remove-jupyterhub.yml` | ❌ | Old path fixed in PR #35 |

### Network (800+)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **tailscale-tunnel** | ✅ | ✅ `801-setup-network-tailscale-tunnel.yml` | ❌ Missing | ❌ | Missing remove playbook. Old path refs in error messages fixed in PR #35 |
| **cloudflare-tunnel** | ✅ | ✅ `820-setup-network-cloudflare-tunnel.yml` | ❌ Missing | ❌ | No remove playbook |

---

## Summary

| Category | Total | Fully Migrated | Issues |
|----------|:-----:|:--------------:|--------|
| Core | 2 | 2 | None |
| Monitoring | 5 | 5 | None — need deployment verification |
| Databases | 5 | 5 | None — postgresql and redis verified |
| Search | 1 | 1 | None |
| Authentication | 1 | 1 | Fully verified with E2E tests |
| Queues | 1 | 1 | None |
| Management | 2 | 1 | gravitee needs new setup; argocd fully migrated |
| AI | 2 | 2 | None |
| Data Science | 3 | 3 | None |
| Network | 2 | 1 | Both missing remove playbooks; cloudflare missing remove playbook |
| **Total** | **24** | **22** | **2 need work** (gravitee broken, network remove playbooks missing) |

### Playbooks with Old Path References (2026-02-18 scan)

Scanned all playbooks in `ansible/playbooks/` for references to `topsecret/`, `secrets/`, and `cloud-init/`:

| Playbook | Line | Reference | Impact | Fixed |
|----------|------|-----------|--------|:-----:|
| `01-configure_provision-host.yml` | 30 | `ansible/secrets/id_rsa_ansible.secret-key` | Hardcoded old SSH key path | ✅ PR #35 |
| `350-setup-jupyterhub.yml` | 65 | `topsecret/kubernetes/kubernetes-secrets.yml` | **Breaks if topsecret/ removed** | ✅ PR #35 |
| `802-deploy-network-tailscale-tunnel.yml` | 193-194 | `topsecret/kubernetes/kubernetes-secrets.yml` | Error message text only | ✅ PR #35 |

All old path references in playbooks are now fixed. Also fixed: `ansible/ansible.cfg` and `provision-host/provision-host-vm-create.sh` (PR #35).

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

## Phase 5: Deployment Verification

16 services have not been verified in the new UIS system. They have service scripts and playbooks, but haven't been deployed and tested.

### Tasks

- [ ] 5.1 Verify monitoring stack: prometheus, grafana, loki, tempo, otel-collector
- [ ] 5.2 Verify databases: mysql, mongodb, qdrant
- [ ] 5.3 Verify AI stack: openwebui, litellm
- [ ] 5.4 Verify data science stack: jupyterhub, spark, unity-catalog
- [ ] 5.5 Verify other: nginx, elasticsearch, rabbitmq
- [ ] 5.6 Verify network: tailscale-tunnel, cloudflare-tunnel (requires external accounts)

**Note**: Network services require external accounts (Tailscale auth key, Cloudflare token) and cannot be tested in a pure local setup.

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
