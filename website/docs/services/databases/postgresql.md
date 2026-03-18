---
title: PostgreSQL
sidebar_label: PostgreSQL
---

# PostgreSQL

Open-source relational database with pre-built AI and geospatial extensions.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy postgresql` |
| **Undeploy** | `./uis undeploy postgresql` |
| **Depends on** | None |
| **Required by** | authentik, openwebui, litellm, unity-catalog, pgadmin |
| **Helm chart** | `bitnami/postgresql` (pinned by digest) |
| **Default namespace** | `default` |

## What It Does

PostgreSQL is the primary database in UIS. It powers Authentik (identity), Open WebUI (AI chat), LiteLLM (API gateway), Unity Catalog (data governance), and pgAdmin (database management).

UIS deploys the official Bitnami PostgreSQL 18.3 image (pinned by digest), which includes 8 pre-built extensions:

| Extension | Version | Purpose |
|-----------|---------|---------|
| **pgvector** | 0.8.2 | Vector similarity search for AI embeddings |
| **PostGIS** | 3.6.2 | Geospatial data types and queries |
| **hstore** | 1.8 | Key-value pairs within a single column |
| **ltree** | 1.3 | Hierarchical tree-like data |
| **uuid-ossp** | built-in | UUID generation |
| **pg_trgm** | 1.6 | Fuzzy text search and trigram matching |
| **btree_gin** | 1.3 | Additional indexing strategies |
| **pgcrypto** | 1.4 | Cryptographic functions |

All extensions are enabled automatically at first deploy via the `initdb` SQL script in the Helm values.

## Deploy

```bash
./uis deploy postgresql
```

No dependencies. PostgreSQL is typically one of the first services deployed.

## Verify

```bash
# Quick check
./uis verify postgresql

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=postgresql

# Test readiness
kubectl exec -it postgresql-0 -- pg_isready -U postgres

# List installed extensions
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT extname, extversion FROM pg_extension ORDER BY extname;"
```

## Configuration

PostgreSQL configuration is in `manifests/042-database-postgresql-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Image | `bitnami/postgresql` (pinned by digest) | PostgreSQL 18.3 with extensions |
| Storage | `8Gi` PVC | Persistent data across restarts |
| Port | `5432` | Standard PostgreSQL port |
| Memory | `240Mi` request, `512Mi` limit | |
| CPU | `250m` request, `500m` limit | |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_POSTGRES_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | PostgreSQL admin password |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/042-database-postgresql-config.yaml` | Helm values (image, resources, storage) |
| `ansible/playbooks/040-database-postgresql.yml` | Deployment playbook |
| `ansible/playbooks/040-remove-database-postgresql.yml` | Removal playbook |
| `ansible/playbooks/utility/u02-verify-postgres.yml` | Extension and CRUD verification |

## Undeploy

```bash
./uis undeploy postgresql
```

This removes the Helm release and pods. Services that depend on PostgreSQL (authentik, openwebui, litellm, unity-catalog, pgadmin) should be undeployed first.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app.kubernetes.io/name=postgresql
kubectl logs -l app.kubernetes.io/name=postgresql
```

**Image pull fails:**
```bash
kubectl get pod postgresql-0 -o yaml | grep -A 3 "image:"
```

**Extension not available:**
```bash
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT * FROM pg_available_extensions WHERE name='vector';"
```

**Connection refused from other services:**
```bash
kubectl get svc postgresql
kubectl get endpoints postgresql
```

## Learn More

- [Official PostgreSQL documentation](https://www.postgresql.org/docs/)
- [Bitnami PostgreSQL on Docker Hub](https://hub.docker.com/r/bitnami/postgresql)
- [pgAdmin management tool](../management/pgadmin.md)
