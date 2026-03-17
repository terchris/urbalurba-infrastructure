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
| **Helm chart** | `bitnami/postgresql` (unpinned) |
| **Default namespace** | `default` |

## What It Does

PostgreSQL is the primary database in UIS. It powers Authentik (identity), Open WebUI (AI chat), LiteLLM (API gateway), Unity Catalog (data governance), and pgAdmin (database management).

UIS deploys a custom PostgreSQL container (`ghcr.io/terchris/urbalurba-postgresql`) that includes 8 pre-built extensions:

- **pgvector** — vector similarity search for AI embeddings
- **PostGIS** — geospatial data types and queries
- **hstore** — key-value pairs within a single column
- **ltree** — hierarchical tree-like data
- **uuid-ossp** — UUID generation
- **pg_trgm** — fuzzy text search and trigram matching
- **btree_gin** — additional indexing strategies
- **pgcrypto** — cryptographic functions

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
| Image | `ghcr.io/terchris/urbalurba-postgresql` | Custom container with extensions |
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
| `manifests/042-database-postgresql-config.yaml` | Helm values (custom image, resources, storage) |
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

**Custom image pull fails:**
The custom container is pulled from `ghcr.io/terchris/urbalurba-postgresql`. Check that the image is accessible:
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
- [Custom container details](./postgresql-container.md)
- [pgAdmin management tool](../management/pgadmin.md)
