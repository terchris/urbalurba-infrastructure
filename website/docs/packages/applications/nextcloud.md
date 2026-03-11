---
title: Nextcloud
sidebar_label: Nextcloud
---

# Nextcloud

Self-hosted collaboration platform with file sync, sharing, and browser-based document editing via OnlyOffice.

| | |
|---|---|
| **Category** | Applications |
| **Deploy** | `./uis deploy nextcloud` |
| **Undeploy** | `./uis undeploy nextcloud` |
| **Verify** | `./uis verify nextcloud` |
| **Depends on** | PostgreSQL, Redis |
| **Helm chart** | `nextcloud/nextcloud` (pinned: 9.0.3) |
| **Default namespace** | `nextcloud` |

## What It Does

Nextcloud provides a self-hosted collaboration platform with:
- **File Sync and Sharing** -- upload, organize, and share files via browser or desktop client
- **Document Editing** -- browser-based editing of DOCX, XLSX, PPTX, and PDF via OnlyOffice Document Server
- **Calendar and Contacts** -- CalDAV and CardDAV support
- **Cron** -- background jobs run via sidecar container

OnlyOffice Document Server is deployed alongside Nextcloud in the same namespace, connected via JWT-authenticated API.

## Deploy

```bash
# Deploy dependencies first (if not already running)
./uis deploy postgresql
./uis deploy redis

# Deploy Nextcloud + OnlyOffice
./uis deploy nextcloud
```

First boot takes 1-5 minutes (database migrations, file copy). The playbook waits for readiness.

## Verify

```bash
# Run all 8 E2E tests
./uis verify nextcloud

# Manual checks
kubectl get pods -n nextcloud
curl -H "Host: nextcloud.localhost" http://nextcloud.localhost/status.php
```

The verify playbook tests:
- Health endpoint, admin WebDAV login, wrong credentials rejected
- Traefik routing, OnlyOffice health, JWT enforcement
- OnlyOffice editor endpoint (file handlers registered), config clean (no errors)

## Access

| URL | Description |
|-----|-------------|
| `http://nextcloud.localhost` | Nextcloud web UI |
| `http://onlyoffice.localhost` | OnlyOffice Document Server |

Login with `admin` and the password from `./uis secrets show` (look for `NEXTCLOUD_ADMIN_PASSWORD`).

## Configuration

Nextcloud configuration is in `manifests/620-nextcloud-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Image | `nextcloud:33-apache` | Pinned version |
| Database | PostgreSQL (existing UIS instance) | Database: `nextcloud` |
| Cache | Redis (existing UIS instance) | Session locking and caching |
| Document editing | OnlyOffice Document Server 9.3.1 | JWT-authenticated |
| Upload limit | 512M | PHP `upload_max_filesize` |
| Storage | 10Gi PVC (local-path) | File storage |
| Cron | Sidecar container | Runs `/cron.sh` alongside main container |
| Service port | 80 | Required for OnlyOffice connector compatibility |

### Secrets

| Variable | Source | Purpose |
|----------|--------|---------|
| `NEXTCLOUD_ADMIN_USER` | `admin` | Admin login username |
| `NEXTCLOUD_ADMIN_PASSWORD` | Generated | Admin login password |
| `NEXTCLOUD_DATABASE_USER` | `postgres` | PostgreSQL username |
| `NEXTCLOUD_DATABASE_PASSWORD` | `PGPASSWORD` | PostgreSQL password |
| `REDIS_PASSWORD` | `REDIS_PASSWORD` | Redis authentication |
| `ONLYOFFICE_JWT_SECRET` | Generated | Shared JWT secret for OnlyOffice |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/620-nextcloud-config.yaml` | Helm values (database, redis, probes, PHP) |
| `manifests/621-nextcloud-ingressroute.yaml` | Nextcloud IngressRoute |
| `manifests/622-onlyoffice-config.yaml` | OnlyOffice Deployment + Service |
| `manifests/623-onlyoffice-ingressroute.yaml` | OnlyOffice IngressRoute |
| `ansible/playbooks/620-setup-nextcloud.yml` | Deployment playbook |
| `ansible/playbooks/620-remove-nextcloud.yml` | Removal playbook |
| `ansible/playbooks/620-test-nextcloud.yml` | E2E verification (8 tests) |

## Undeploy

```bash
./uis undeploy nextcloud
```

Note: The PostgreSQL database `nextcloud` is NOT deleted. On redeploy, the setup playbook detects and drops any stale database automatically.

## Troubleshooting

**First boot is slow (1-5 minutes):**
Nextcloud runs database migrations and copies files on first boot. The startup probe allows up to 5 minutes. Check progress:
```bash
kubectl logs -n nextcloud -l app.kubernetes.io/name=nextcloud --tail=50
```

**OnlyOffice image pull takes several minutes:**
The OnlyOffice Document Server image is ~1.5 GB. First pull may take 3-5 minutes.

**Documents download instead of opening in OnlyOffice:**
File handlers may not be registered. Re-run deploy or visit `http://nextcloud.localhost/settings/admin/onlyoffice` and click Save.

**Database permission errors on redeploy:**
The deploy playbook handles this automatically by dropping stale databases. If you encounter `permission denied for table oc_migrations`, redeploy:
```bash
./uis undeploy nextcloud && ./uis deploy nextcloud
```

**Pod won't start:**
```bash
kubectl describe pod -n nextcloud -l app.kubernetes.io/name=nextcloud
kubectl logs -n nextcloud -l app.kubernetes.io/name=nextcloud --tail=50
```

## Learn More

- [Nextcloud documentation](https://docs.nextcloud.com)
- [Nextcloud Helm chart](https://github.com/nextcloud/helm)
- [OnlyOffice Document Server](https://helpcenter.onlyoffice.com/installation/docs-community-install-docker.aspx)
