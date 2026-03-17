---
title: pgAdmin
sidebar_label: pgAdmin
---

# pgAdmin

Web-based PostgreSQL database administration tool.

| | |
|---|---|
| **Category** | Management |
| **Deploy** | `./uis deploy pgadmin` |
| **Undeploy** | `./uis undeploy pgadmin` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Helm chart** | `runix/pgadmin4` (unpinned) |
| **Default namespace** | `default` |

## What It Does

pgAdmin provides a web-based interface for managing PostgreSQL databases. It comes pre-configured with a connection to the UIS PostgreSQL instance, so you can browse databases, run queries, and manage schemas immediately after deployment.

Key capabilities:
- **Pre-configured connection** — auto-connects to UIS PostgreSQL
- **SQL editor** — run queries with syntax highlighting
- **Visual schema browser** — explore tables, views, functions
- **10Gi persistent storage** — preserves settings across restarts

## Deploy

```bash
# Deploy dependency first
./uis deploy postgresql

# Deploy pgAdmin
./uis deploy pgadmin
```

## Verify

```bash
# Quick check
./uis verify pgadmin

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=pgadmin4

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://pgadmin.localhost
# Expected: 200 or 302
```

Access the interface at [http://pgadmin.localhost](http://pgadmin.localhost).

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `80` | Web UI |
| Storage | `10Gi` PVC | Persistent settings and queries |
| Security | UID 5050 | Runs as pgadmin user |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_ADMIN_EMAIL` | `.uis.secrets/secrets-config/default-secrets.env` | pgAdmin login email |
| `DEFAULT_PGADMIN_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | pgAdmin login password |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/641-adm-pgadmin.yml` | Deployment playbook |
| `ansible/playbooks/641-adm-remove-pgadmin.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy pgadmin
```

## Troubleshooting

**Pod won't start (OOM):**
pgAdmin needs at least 512Mi memory. Check:
```bash
kubectl describe pod -l app.kubernetes.io/name=pgadmin4
kubectl logs -l app.kubernetes.io/name=pgadmin4
```

**Login fails:**
Check the admin email and password in secrets. The email must be a valid format (e.g., `admin@example.com`):
```bash
./uis secrets status
```

**Cannot connect to PostgreSQL:**
Verify PostgreSQL is running and the server definition is correct:
```bash
kubectl get pods -l app.kubernetes.io/name=postgresql
```

## Learn More

- [Official pgAdmin documentation](https://www.pgadmin.org/docs/)
- [PostgreSQL service](../databases/postgresql.md)
