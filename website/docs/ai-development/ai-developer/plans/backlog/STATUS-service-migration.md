# PLAN-008: Service Migration Status & Remaining Work

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Track migration status of all 24 UIS services and complete remaining work for services that are not fully migrated.

**Last Updated**: 2026-02-01

**Priority**: Medium — core services work, remaining items are edge cases

---

## Service Migration Status

All 24 services have service scripts (`provision-host/uis/services/*/service-*.sh`) and deploy playbooks. The table below tracks full migration status including remove playbooks and verified deployment.

### Legend

- **Service script**: `provision-host/uis/services/<category>/service-<id>.sh` — metadata for `./uis list`, `./uis deploy`, etc.
- **Deploy playbook**: Ansible playbook for `./uis deploy <service>`
- **Remove playbook**: Ansible playbook for `./uis undeploy <service>`
- **Verified**: Service has been deployed and tested in the new UIS system

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
| **jupyterhub** | ✅ | ✅ `350-setup-jupyterhub.yml` | ✅ `350-remove-jupyterhub.yml` | ❌ | |

### Network (800+)

| Service | Service Script | Deploy | Remove | Verified | Notes |
|---------|:---:|:---:|:---:|:---:|-------|
| **tailscale-tunnel** | ✅ | ✅ `801-setup-network-tailscale-tunnel.yml` | ❌ Missing | ❌ | Only partial: `806-remove-tailscale-internal-ingress.yml` exists but doesn't remove the tunnel itself |
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
| Network | 2 | 0 | Both missing remove playbooks |
| **Total** | **24** | **21** | **3 need work** |

---

## Phase 1: Quick Fixes (metadata)

### Tasks

- [x] 1.1 Fix ArgoCD: set `SCRIPT_REMOVE_PLAYBOOK="220-remove-argocd.yml"` in `service-argocd.sh` ✓ (PLAN-argocd-migration)

---

## Phase 2: Missing Remove Playbooks

### Tasks

- [ ] 2.1 Create `801-remove-network-tailscale-tunnel.yml` — tear down Tailscale tunnel deployment and namespace
- [ ] 2.2 Create `820-remove-network-cloudflare-tunnel.yml` — tear down Cloudflare tunnel deployment and namespace
- [ ] 2.3 Update service scripts with `SCRIPT_REMOVE_PLAYBOOK` references

---

## Phase 3: Gravitee (New Setup)

Gravitee was not working before the migration. This is effectively a fresh setup, not a migration.

### Tasks

- [ ] 3.1 Investigate current state of `090-setup-gravitee.yml` — does it work at all?
- [ ] 3.2 If broken, rewrite the deploy playbook or disable the service
- [ ] 3.3 Create `090-remove-gravitee.yml`
- [ ] 3.4 Test deploy and remove cycle

---

## Phase 4: Deployment Verification

16 services have not been verified in the new UIS system. They have service scripts and playbooks, but haven't been deployed and tested.

### Tasks

- [ ] 4.1 Verify monitoring stack: prometheus, grafana, loki, tempo, otel-collector
- [ ] 4.2 Verify databases: mysql, mongodb, qdrant
- [ ] 4.3 Verify AI stack: openwebui, litellm
- [ ] 4.4 Verify data science stack: jupyterhub, spark, unity-catalog
- [ ] 4.5 Verify other: nginx, elasticsearch, rabbitmq
- [ ] 4.6 Verify network: tailscale-tunnel, cloudflare-tunnel (requires external accounts)

**Note**: Network services require external accounts (Tailscale auth key, Cloudflare token) and cannot be tested in a pure local setup.

---

## Files to Modify

| File | Change |
|------|--------|
| `provision-host/uis/services/management/service-argocd.sh` | Add `SCRIPT_REMOVE_PLAYBOOK` |
| `provision-host/uis/services/network/service-tailscale-tunnel.sh` | Add `SCRIPT_REMOVE_PLAYBOOK` |
| `provision-host/uis/services/network/service-cloudflare-tunnel.sh` | Add `SCRIPT_REMOVE_PLAYBOOK` |

## Files to Create

| File | Purpose |
|------|---------|
| `ansible/playbooks/801-remove-network-tailscale-tunnel.yml` | Tailscale tunnel removal |
| `ansible/playbooks/820-remove-network-cloudflare-tunnel.yml` | Cloudflare tunnel removal |
| `ansible/playbooks/090-remove-gravitee.yml` | Gravitee removal (if service is fixed) |
