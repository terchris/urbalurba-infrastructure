# Investigate: Fix Gravitee Deployment

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Get Gravitee working and aligned with UIS patterns — it was broken before the service migration and has never been verified

**Last Updated**: 2026-03-09

**Related**:
- [STATUS-service-migration.md](../completed/STATUS-service-migration.md) — Gravitee is the only unverified service (Phase 4)
- [INVESTIGATE-elasticsearch-upgrade.md](../completed/INVESTIGATE-elasticsearch-upgrade.md) — Gravitee supports ES 9.x (9.2.x+)

---

## Current State

Gravitee has a deploy playbook and manifests but was **never verified working**. The service migration status file notes: "Was not working before migration. Needs new setup — deploy playbook may need rewrite."

### What exists

| File | Status |
|------|--------|
| `provision-host/uis/services/integration/service-gravitee.sh` | Exists — has metadata but `SCRIPT_REMOVE_PLAYBOOK` and `SCRIPT_REQUIRES` are empty |
| `ansible/playbooks/090-setup-gravitee.yml` | Exists — verbose (465 lines), hardcoded values, may not work |
| `manifests/090-gravitee-config.yaml` | Exists — hardcoded credentials, version pinned at 4.8.4 |
| `manifests/091-gravitee-ingress.yaml` | Exists — uses `Host()` instead of `HostRegexp()` |
| `ansible/playbooks/090-remove-gravitee.yml` | **Missing** |

---

## Issues Found

### 1. Hardcoded credentials in config

`090-gravitee-config.yaml` has MongoDB credentials inline:

```yaml
mongo:
  uri: mongodb://gravitee_user:SecretPassword1@mongodb.default.svc.cluster.local:27017/graviteedb?authSource=admin
```

And again in the rate limit section:

```yaml
ratelimit:
  mongodb:
    uri: mongodb://gravitee_user:SecretPassword1@mongodb.default.svc.cluster.local:27017/graviteedb?authSource=admin
```

This must use the UIS secrets system (`urbalurba-secrets` in the Gravitee namespace).

### 2. Deploys in `default` namespace

The Helm config sets `gravitee_namespace: "default"`. All other non-core services deploy in their own namespace. Gravitee should use a `gravitee` namespace.

### 3. Ingress uses `Host()` instead of `HostRegexp()`

`091-gravitee-ingress.yaml` uses `Host(`gravitee.localhost`)` instead of the UIS standard `HostRegexp(`gravitee\..+`)`. This means it only works on localhost, not on Tailscale or Cloudflare domains.

### 4. Generic hostname conflicts

Gravitee uses 4 hostnames:

| Hostname | Component |
|----------|-----------|
| `api.localhost` | API Gateway |
| `portal.localhost` | Developer Portal |
| `gravitee.localhost` | Management Console |
| `gravitee-api.localhost` | Management API |

`api.localhost` and `portal.localhost` are too generic — they could conflict with other services. These should be prefixed: `gravitee-gw.localhost` and `gravitee-portal.localhost` (or similar).

### 5. Missing remove playbook

No `090-remove-gravitee.yml` exists. `SCRIPT_REMOVE_PLAYBOOK` is empty in the service script.

### 6. Missing `SCRIPT_REQUIRES`

`SCRIPT_REQUIRES=""` — but Gravitee depends on MongoDB and Elasticsearch. Should be:

```bash
SCRIPT_REQUIRES="mongodb elasticsearch"
```

### 7. Hardcoded Tailscale hostname in playbook

The setup playbook final output contains:

```
"These are accessible via your Tailscale funnel hostname: rancher-traefik.dog-pence.ts.net"
```

This is a developer-specific hostname that should not be in the playbook.

### 8. Playbook is overly verbose

At 465 lines, the setup playbook is much longer than comparable services. It has extensive debugging output, manual connectivity checks, and hardcoded values. Other service playbooks (e.g. Unity Catalog at ~100 lines) are much simpler.

---

## Dependencies

Gravitee requires:

| Dependency | UIS service | How Gravitee uses it |
|------------|------------|---------------------|
| **MongoDB** | manifest 040, `default` namespace | Metadata store — API definitions, policies, analytics config |
| **Elasticsearch** | manifest 060, `default` namespace | Analytics — request logs, metrics, dashboards |

Both are already deployed in UIS.

### MongoDB setup

Gravitee needs a database and user on the existing MongoDB. The setup playbook should create these (same pattern as OpenMetadata creating a database on PostgreSQL).

### Elasticsearch compatibility

Gravitee supports ES 7.17.x, 8.16.x, and 9.2.x. Works with both current ES 8.5.1 and the planned upgrade to 9.3.0.

---

## Secrets Integration

Following the UIS secrets pattern:

**1. Variables in `00-common-values.env.template`:**

```bash
# Gravitee
GRAVITEE_MONGODB_USER=gravitee_user
GRAVITEE_MONGODB_PASSWORD=${DEFAULT_DATABASE_PASSWORD}
GRAVITEE_MONGODB_DATABASE=graviteedb
```

**2. Secret block in `00-master-secrets.yml.template`:**

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: gravitee
---
apiVersion: v1
kind: Secret
metadata:
  name: urbalurba-secrets
  namespace: gravitee
type: Opaque
stringData:
  GRAVITEE_MONGODB_USER: "${GRAVITEE_MONGODB_USER}"
  GRAVITEE_MONGODB_PASSWORD: "${GRAVITEE_MONGODB_PASSWORD}"
  GRAVITEE_MONGODB_DATABASE: "${GRAVITEE_MONGODB_DATABASE}"
  GRAVITEE_MONGODB_URI: "mongodb://${GRAVITEE_MONGODB_USER}:${GRAVITEE_MONGODB_PASSWORD}@mongodb.default.svc.cluster.local:27017/${GRAVITEE_MONGODB_DATABASE}?authSource=admin"
```

The Helm values would reference these via environment variables or `secretKeyRef`.

### Password restrictions

Do NOT use `!`, `$`, `` ` ``, `\`, or `"` in passwords.

---

## Proposed Hostname Strategy

| Component | Hostname pattern | Access |
|-----------|-----------------|--------|
| Management Console | `gravitee.localhost` | Admin UI |
| Management API | `gravitee-api.localhost` | Admin API |
| API Gateway | `gravitee-gw.localhost` | Developer gateway |
| Developer Portal | `gravitee-portal.localhost` | Developer portal |

All using `HostRegexp()` for multi-domain support.

---

## What Needs to Happen

1. Move Gravitee to its own `gravitee` namespace
2. Replace hardcoded credentials with UIS secrets system
3. Add secrets variables to templates
4. Switch ingress from `Host()` to `HostRegexp()` pattern
5. Rename generic hostnames (`api`, `portal`) to Gravitee-prefixed names
6. Create `090-remove-gravitee.yml`
7. Update `service-gravitee.sh` — set `SCRIPT_REMOVE_PLAYBOOK` and `SCRIPT_REQUIRES`
8. Simplify the setup playbook (remove debugging output, hardcoded Tailscale hostname)
9. Test deploy and undeploy cycle

---

## Resource Requirements

Gravitee deploys 4 components (API server, Gateway, Management UI, Portal UI). Estimated:

| Component | CPU request | Memory request |
|-----------|------------|---------------|
| Management API | 250m | 512Mi |
| Gateway | 250m | 512Mi |
| Management UI | 100m | 128Mi |
| Portal UI | 100m | 128Mi |
| **Total** | **~700m** | **~1.3Gi** |

MongoDB and Elasticsearch are shared (already running).

---

## Proposed Files

| Piece | Change |
|-------|--------|
| `provision-host/uis/services/integration/service-gravitee.sh` | Update `SCRIPT_REMOVE_PLAYBOOK`, `SCRIPT_REQUIRES`, `SCRIPT_NAMESPACE` |
| `ansible/playbooks/090-setup-gravitee.yml` | Rewrite — simpler, secrets-based, `gravitee` namespace |
| `ansible/playbooks/090-remove-gravitee.yml` | **Create** — tear down Gravitee deployment |
| `manifests/090-gravitee-config.yaml` | Replace hardcoded credentials, move to `gravitee` namespace |
| `manifests/091-gravitee-ingress.yaml` | Switch to `HostRegexp()`, rename generic hostnames |
| Secrets templates | Add Gravitee variables and namespace block |

---

## Next Steps

- [ ] Verify Gravitee actually deploys (test current playbook on a running cluster)
- [ ] Create PLAN-gravitee-fix.md with implementation phases
