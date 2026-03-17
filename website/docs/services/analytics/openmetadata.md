---
title: OpenMetadata
sidebar_label: OpenMetadata
---

# OpenMetadata

Open-source data governance and metadata platform for data discovery, observability, and quality.

| | |
|---|---|
| **Category** | Analytics |
| **Deploy** | `./uis deploy openmetadata` |
| **Undeploy** | `./uis undeploy openmetadata` |
| **Verify** | `./uis verify openmetadata` |
| **Depends on** | PostgreSQL, Elasticsearch |
| **Helm chart** | `open-metadata/openmetadata` (pinned: 1.12.1) |
| **Default namespace** | `openmetadata` |

## What It Does

OpenMetadata provides a unified metadata platform with:
- **Data Discovery** — search across databases, dashboards, pipelines, ML models
- **Data Lineage** — column-level lineage tracking across systems
- **Data Quality** — profiling and quality checks
- **Data Governance** — policies, glossaries, classification, ownership
- **100+ Connectors** — integrates with databases, warehouses, BI tools

Uses the Kubernetes native orchestrator for ingestion (no Airflow required).

## Deploy

```bash
# Deploy dependencies first (if not already running)
./uis deploy postgresql
./uis deploy elasticsearch

# Deploy OpenMetadata
./uis deploy openmetadata
```

The setup playbook creates the `openmetadata_db` database on the existing PostgreSQL instance.

## Verify

```bash
# Run all 6 E2E tests
./uis verify openmetadata

# Manual checks
kubectl get pods -n openmetadata
curl http://openmetadata.localhost/api/v1/system/health
curl http://openmetadata.localhost/api/v1/system/version
```

## Configuration

OpenMetadata configuration is in `manifests/340-openmetadata-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Image | `docker.getcollate.io/openmetadata/server:1.12.1` | Pinned version |
| Database | PostgreSQL (existing UIS instance) | Database: `openmetadata_db` |
| Search | Elasticsearch 9.3.0 (existing UIS instance) | HTTP, no auth |
| Orchestrator | K8s Jobs | No Airflow needed |
| CPU request | 500m | Dev-appropriate |
| Memory request | 1.5Gi | Dev-appropriate |
| UI/API port | 8585 | Served by single process |

### Admin Credentials

OpenMetadata ships with a hardcoded default admin account (`admin@open-metadata.org` / `admin`). The Helm chart provides no way to override this.

During deployment, the setup playbook automatically changes the admin password to match `DEFAULT_ADMIN_PASSWORD` from the UIS secrets system. The process:

1. The playbook waits for OpenMetadata to be ready
2. Logs in with the default credentials (`admin@open-metadata.org` / `admin`) via `POST /api/v1/users/login`
3. Changes the password to `DEFAULT_ADMIN_PASSWORD` via `PUT /api/v1/users/changePassword`
4. On redeploy, the playbook detects the password is already changed and skips the update

**Admin email**: The login email is fixed at `admin@open-metadata.org`. OpenMetadata does not support changing the login email via API — the PATCH endpoint only updates the profile display name, not the login credential.

**Password requirements**: OpenMetadata enforces 8-56 characters with uppercase, lowercase, digit, AND a special character. The default `DEFAULT_ADMIN_PASSWORD` (`LocalDev@123`) meets this requirement.

### Secrets

| Variable | Source | Purpose |
|----------|--------|---------|
| `OPENMETADATA_DATABASE_PASSWORD` | `DEFAULT_DATABASE_PASSWORD` | PostgreSQL password |
| `OPENMETADATA_ADMIN_EMAIL` | `admin@open-metadata.org` (fixed) | Admin login email — cannot be changed |
| `OPENMETADATA_ADMIN_PASSWORD` | `DEFAULT_ADMIN_PASSWORD` | Admin login password (changed post-deploy via API) |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/340-openmetadata-config.yaml` | Helm values (database, search, resources) |
| `manifests/341-openmetadata-ingressroute.yaml` | Traefik IngressRoute |
| `ansible/playbooks/340-setup-openmetadata.yml` | Deployment playbook |
| `ansible/playbooks/340-remove-openmetadata.yml` | Removal playbook |
| `ansible/playbooks/340-test-openmetadata.yml` | E2E verification (6 tests) |

## Undeploy

```bash
./uis undeploy openmetadata
```

Note: The PostgreSQL database `openmetadata_db` is NOT deleted. To remove it manually:
```bash
kubectl exec -n default postgresql-0 -- bash -c 'PGPASSWORD=$(cat /opt/bitnami/postgresql/secrets/postgres-password) psql -U postgres -c "DROP DATABASE IF EXISTS openmetadata_db;"'
```

## Troubleshooting

**Pod won't start (OOM or Java errors):**
```bash
kubectl describe pod -n openmetadata -l app.kubernetes.io/name=openmetadata
kubectl logs -n openmetadata -l app.kubernetes.io/name=openmetadata --tail=50
```

**Database connection failed:**
```bash
# Check PostgreSQL is running
kubectl get pods -n default -l app.kubernetes.io/name=postgresql
# Check database exists
kubectl exec -n default postgresql-0 -- psql -U postgres -c "\l" | grep openmetadata
```

**Elasticsearch connection failed:**
```bash
# Check Elasticsearch is running
kubectl get pods -n default -l app=elasticsearch-master
# Check ES responds
kubectl exec elasticsearch-master-0 -- curl -s http://localhost:9200/_cluster/health
```

**Authentication failed:**
```bash
# Check credentials in secrets
kubectl get secret urbalurba-secrets -n openmetadata -o jsonpath='{.data.OPENMETADATA_ADMIN_EMAIL}' | base64 -d
kubectl get secret urbalurba-secrets -n openmetadata -o jsonpath='{.data.OPENMETADATA_ADMIN_PASSWORD}' | base64 -d
```

## Learn More

- [OpenMetadata documentation](https://docs.open-metadata.org)
- [OpenMetadata GitHub](https://github.com/open-metadata/OpenMetadata)
