# Investigate: Nextcloud Deployment

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Determine the best approach for deploying Nextcloud as a UIS platform service

**Last Updated**: 2026-03-09

---

## Questions to Answer

1. What is Nextcloud and what does it provide?
2. Which existing UIS services can Nextcloud reuse?
3. What category and manifest number should it use?
4. What are the resource requirements — is it feasible on a developer laptop?
5. Should we use the Helm chart or custom manifests?
6. What does the initial setup look like (skip Authentik, keep it simple)?

---

## Background Research

### What is Nextcloud?

Nextcloud is a self-hosted content collaboration platform — a private cloud alternative to Google Drive, Dropbox, and Microsoft 365. It provides:

- **File sync and sharing** — store, access, and share files with desktop and mobile clients
- **Nextcloud Office** — collaborative document editing (based on LibreOffice)
- **Groupware** — Calendar, Contacts, and Mail
- **Nextcloud Talk** — audio/video calls and chat (WebRTC)
- **App ecosystem** — extensible via hundreds of apps
- **AI assistant** — local AI features for content generation, summarization, translation

Used by tens of millions of users, popular for organizations needing data sovereignty.

### Architecture

| Component | Role |
|---|---|
| **Nextcloud PHP app** | Core application — file management, APIs, web UI |
| **Web server** | Apache (bundled in Docker image) or nginx |
| **Database** | Stores metadata, users, shares, calendar/contacts |
| **Redis** | Memory cache for sessions and transactional file locking |
| **Storage** | Persistent storage for user files |
| **Cron job** | Background tasks (file scanning, cleanup, notifications) |
| **Optional: Collabora/OnlyOffice** | Document editing server (separate container) |
| **Optional: TURN/STUN server** | For Talk video calls behind NAT |

### Docker Image

- **Image**: `nextcloud` on Docker Hub (official, maintained by Nextcloud project)
- **Recommended variant**: `nextcloud:<version>-apache` — bundles Apache, simplest to deploy
- **Port**: 80
- **Key environment variables**:
  - `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` — initial admin account
  - `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — database connection
  - `REDIS_HOST`, `REDIS_HOST_PORT`, `REDIS_HOST_PASSWORD` — Redis connection
  - `NEXTCLOUD_TRUSTED_DOMAINS` — allowed access domains
  - All sensitive variables support a `_FILE` suffix for Kubernetes secrets

### Helm Chart

Community-maintained chart under the Nextcloud GitHub organization:

- **Repository**: https://github.com/nextcloud/helm
- **Chart repo URL**: `https://nextcloud.github.io/helm/`
- **Helm repo add**: `helm repo add nextcloud https://nextcloud.github.io/helm/`
- **Requires**: Helm 3.7.0+

The chart includes Bitnami sub-charts for PostgreSQL, MariaDB, and Redis — all can be **disabled** to use existing UIS services instead.

### Database Support

| Database | Supported Versions |
|---|---|
| **PostgreSQL** | 13, 14, 15, 16, 17 |
| **MySQL** | 8.0, 8.4 |
| **MariaDB** | 10.6, 10.11, 11.4 |
| **SQLite** | Testing only |

**PostgreSQL is fully supported** and is UIS's preferred database.

### Redis Usage

Redis is **strongly recommended** for:
1. **Transactional file locking** — prevents file corruption during concurrent access. Without Redis, locking falls back to the database (adds significant load).
2. **Memory caching** — sessions, distributed cache, general app cache.

Redis is the only supported backend for file locking (Memcached is not suitable).

### SSO / OIDC Support

Nextcloud supports OIDC via the "OpenID Connect user backend" app (`user_oidc`). Compatible with Authentik — official integration docs exist. **Skip for initial setup** — add later.

### Admin Interface

All administration is via the web UI at `nextcloud.localhost/settings/admin`. There is also an `occ` CLI tool inside the container for maintenance tasks:

```bash
kubectl exec -it <nextcloud-pod> -- su -s /bin/bash www-data -c "php occ status"
```

---

## Existing UIS Services That Nextcloud Can Reuse

| Nextcloud needs | UIS already has | Reusable? |
|---|---|---|
| **PostgreSQL 13+** | PostgreSQL in `default` namespace (manifest 042) | Yes — create `nextcloud` database on existing instance |
| **Redis** | Redis in `default` namespace (manifest 050) | Yes — shared instance, authentication enabled |

No new backing services needed. Nextcloud only adds the Nextcloud application pod itself.

### PostgreSQL reuse

Create a `nextcloud` database on the existing PostgreSQL instance. The setup playbook creates the database, same pattern as Unity Catalog and OpenMetadata.

### Redis reuse

Nextcloud connects to the existing Redis via `REDIS_HOST` and `REDIS_HOST_PASSWORD` environment variables. Redis is already shared by other services.

---

## Deployment Approach

### Recommendation: Official Helm chart

Use the `nextcloud/nextcloud` Helm chart with sub-charts disabled, pointing to existing UIS services:

```yaml
# Disable bundled sub-charts — use existing UIS services
internalDatabase:
  enabled: false
postgresql:
  enabled: false
mariadb:
  enabled: false
redis:
  enabled: false

# Point to existing PostgreSQL
externalDatabase:
  enabled: true
  type: postgresql
  host: postgresql.default.svc.cluster.local
  database: nextcloud
  # user and password via secretKeyRef — see Secrets Integration section

# Point to existing Redis
# Configured via environment variables in the pod spec

# Persistence
persistence:
  enabled: true
  size: 10Gi

# Initial admin account — from secrets
nextcloud:
  host: nextcloud.localhost
```

---

## Category and Manifest Number

Nextcloud is a collaboration/productivity platform. There is no COLLABORATION category in UIS. The closest existing category is **MANAGEMENT** (600-799), which contains admin and utility tools (pgAdmin, RedisInsight, ArgoCD).

Existing MANAGEMENT manifests: 641, 651, 741, 751.

**Proposed: 620** for Nextcloud.

---

## Ingress

Following the UIS pattern: `HostRegexp(`nextcloud\..+`)` routing to port 80.

Access at `http://nextcloud.localhost`.

---

## Resource Requirements

Nextcloud is lightweight compared to OpenMetadata or Enonic:

| Component | CPU request | Memory request |
|---|---|---|
| Nextcloud (Apache + PHP) | 250m | 512Mi |
| OnlyOffice Document Server | 500m | 2Gi |
| (PostgreSQL — shared, already running) | — | — |
| (Redis — shared, already running) | — | — |
| **Total new resources** | **~750m** | **~2.5Gi** |

Moderate for a developer laptop. OnlyOffice is the heavier component.

---

## Secrets Integration

Following the UIS secrets pattern (same as Unity Catalog, OpenMetadata):

**1. Variables in `00-common-values.env.template`:**

```bash
# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=NextcloudAdmin123
NEXTCLOUD_DB_PASSWORD=${DEFAULT_DATABASE_PASSWORD}
```

**2. Secret block in `00-master-secrets.yml.template`:**

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: nextcloud
---
apiVersion: v1
kind: Secret
metadata:
  name: urbalurba-secrets
  namespace: nextcloud
type: Opaque
stringData:
  NEXTCLOUD_ADMIN_USER: "${NEXTCLOUD_ADMIN_USER}"
  NEXTCLOUD_ADMIN_PASSWORD: "${NEXTCLOUD_ADMIN_PASSWORD}"
  NEXTCLOUD_DATABASE_URL: "postgresql://postgres:${PGPASSWORD}@${PGHOST}:5432/nextcloud"
  NEXTCLOUD_DATABASE_USER: "postgres"
  NEXTCLOUD_DATABASE_PASSWORD: "${PGPASSWORD}"
```

**3. Setup playbook** retrieves credentials from secrets, creates the database on PostgreSQL, passes credentials to Helm via `secretKeyRef`.

### Password restrictions

Do NOT use `!`, `$`, `` ` ``, `\`, or `"` in passwords.

---

## Dependencies

```
SCRIPT_REQUIRES="postgresql redis"
```

The setup playbook should:
1. Verify PostgreSQL and Redis are running
2. Create the `nextcloud` database on the existing PostgreSQL
3. Deploy the Nextcloud Helm chart
4. Deploy the IngressRoute
5. Wait for the server to be ready

---

## Proposed Files

| Piece | File |
|-------|------|
| Service definition | `provision-host/uis/services/management/service-nextcloud.sh` (must include website metadata — `uis-docs.sh` generates JSON from these for the docs website) |
| Setup playbook | `ansible/playbooks/620-setup-nextcloud.yml` |
| Remove playbook | `ansible/playbooks/620-remove-nextcloud.yml` |
| Config / Helm values | `manifests/620-nextcloud-config.yaml` |
| IngressRoute | `manifests/621-nextcloud-ingressroute.yaml` |
| Secrets variables | Add to `provision-host/uis/templates/secrets-templates/00-common-values.env.template` |
| Secrets manifest | Add `nextcloud` namespace block to `provision-host/uis/templates/secrets-templates/00-master-secrets.yml.template` |
| Documentation | `website/docs/packages/management/nextcloud.md` |

---

## Helm Repository

The Nextcloud Helm repo (`https://nextcloud.github.io/helm/`) is not currently registered in UIS. Add it dynamically in the setup playbook (same pattern as Elasticsearch).

---

## OnlyOffice — document editing

Nextcloud alone can store and share files but cannot edit documents in the browser. A separate document editing server is needed.

**Decision: OnlyOffice** — chosen over Collabora because the user base is familiar with Microsoft Office. OnlyOffice uses a modern ribbon UI (Microsoft Office-like) and uses OOXML (DOCX, XLSX, PPTX) as its native format, providing the best MS Office compatibility among open-source options.

### OnlyOffice licensing

OnlyOffice has two editions:

| | Community Edition | Enterprise Edition |
|---|---|---|
| **License** | AGPL v3 (open source) | Proprietary (paid) |
| **Editing features** | All — docs, spreadsheets, presentations, PDF, forms | Same |
| **Real-time collaboration** | Yes | Yes |
| **Simultaneous connections** | **Up to 20** | Thousands |
| **White label** | No | Yes |
| **Private Rooms (E2E encryption)** | No | Yes |
| **Support** | GitHub / forum | Priority support tiers |

**For UIS (local dev): Community Edition is fine.** The 20 connection limit is not a concern. All editing features are identical. If this moves to production with more than 20 concurrent users, an Enterprise license would be needed.

### OnlyOffice details

- **Docker image**: `onlyoffice/documentserver` (Community Edition)
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Resource requirements**: ~2-4 GiB RAM (heavier than Collabora)
- **No database needed** — OnlyOffice Document Server is stateless, it processes documents sent by Nextcloud
- **Helm chart**: `onlyoffice/docs` — official chart at https://github.com/ONLYOFFICE/Kubernetes-Docs
- **Integration**: Nextcloud connects to OnlyOffice via the "ONLYOFFICE" app (install from Nextcloud App Store), configured with the OnlyOffice server URL

### OnlyOffice ingress

Separate hostname: `HostRegexp(`onlyoffice\..+`)` routing to port 80.

Access at `http://onlyoffice.localhost`. Nextcloud connects to it internally via `http://onlyoffice-service.nextcloud.svc.cluster.local` (or similar).

### OnlyOffice resource estimate

| Component | CPU request | Memory request |
|---|---|---|
| OnlyOffice Document Server | 500m | 2Gi |

This is significant for a laptop. Combined with Nextcloud itself (~250m CPU, 512Mi), the total is ~750m CPU and ~2.5Gi RAM for the Nextcloud + OnlyOffice stack.

### Proposed OnlyOffice files

| Piece | File |
|-------|------|
| Config / Helm values | `manifests/622-onlyoffice-config.yaml` |
| IngressRoute | `manifests/623-onlyoffice-ingressroute.yaml` |

OnlyOffice is deployed as part of the Nextcloud setup playbook (`620-setup-nextcloud.yml`) — not a separate UIS service.

---

## What we skip for initial setup

- **Authentik SSO** — use Nextcloud's built-in admin account. Add OIDC later.
- **TURN/STUN server** — only needed for Talk video calls behind NAT.
- **SMTP** — email notifications. Not needed for local dev.

---

## Next Steps

- [ ] Verify Nextcloud Helm chart works with external PostgreSQL and Redis
- [ ] Create PLAN-nextcloud-deployment.md with implementation phases
