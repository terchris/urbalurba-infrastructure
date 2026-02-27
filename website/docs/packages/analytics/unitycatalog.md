---
title: Unity Catalog
sidebar_label: Unity Catalog
---

# Unity Catalog

Open-source data catalog and governance platform.

| | |
|---|---|
| **Category** | Analytics |
| **Deploy** | `./uis deploy unity-catalog` |
| **Undeploy** | `./uis undeploy unity-catalog` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Image** | `unitycatalog/unitycatalog:latest` |
| **Default namespace** | `unity-catalog` |

## What It Does

Unity Catalog provides data governance, metadata management, and a three-level namespace (catalog.schema.table) for organizing data assets. It integrates with Spark for governed data access.

:::warning Known Issue
Unity Catalog container images have permission issues that cause crashes in Kubernetes. The service deploys but may not be fully functional. See troubleshooting below.
:::

Key capabilities:
- **Three-level namespace** — catalog.schema.table organization
- **Metadata management** — centralized schema registry
- **Access control** — fine-grained permissions on data assets
- **Spark integration** — governed table access from Spark jobs
- **REST API** — `/api/2.1/` for programmatic access

## Deploy

```bash
# Deploy dependency first
./uis deploy postgresql

# Deploy Unity Catalog
./uis deploy unity-catalog
```

## Verify

```bash
# Quick check
./uis verify unity-catalog

# Manual check
kubectl get pods -n unity-catalog

# Test API (uses wget since container has BusyBox, not curl)
kubectl exec -it -n unity-catalog deploy/unity-catalog -- \
  wget -qO- http://localhost:8080/api/2.1/unity-catalog/catalogs
```

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| API port | `8080` | REST API endpoint |
| Database | PostgreSQL | Metadata stored in `unity_catalog` database |
| Security | UID 100/GID 101 | Runs as `unitycatalog` user, not root |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/320-setup-unity-catalog.yml` | Deployment playbook |
| `ansible/playbooks/320-remove-unity-catalog.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy unity-catalog
```

## Troubleshooting

**Container crashes with permission denied:**
This is a known issue with the official Unity Catalog container images. The container must run as UID 100/GID 101 (unitycatalog user). Check:
```bash
kubectl describe pod -n unity-catalog -l app=unity-catalog
kubectl logs -n unity-catalog -l app=unity-catalog
```

**API returns 404:**
The API version is `/api/2.1/`, not `/api/1.0/`:
```bash
kubectl exec -it -n unity-catalog deploy/unity-catalog -- \
  wget -qO- http://localhost:8080/api/2.1/unity-catalog/catalogs
```

**BusyBox container limitations:**
The Unity Catalog container uses BusyBox. Use `wget` instead of `curl`:
```bash
# Use wget -S for HTTP status
kubectl exec -it -n unity-catalog deploy/unity-catalog -- wget -S http://localhost:8080/
```

## Learn More

- [Official Unity Catalog documentation](https://www.unitycatalog.io/)
- [Unity Catalog GitHub](https://github.com/unitycatalog/unitycatalog)
- [Spark integration](./spark.md)
