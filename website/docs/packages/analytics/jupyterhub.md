---
title: JupyterHub
sidebar_label: JupyterHub
---

# JupyterHub

Multi-user Jupyter notebook server with PySpark integration.

| | |
|---|---|
| **Category** | Analytics |
| **Deploy** | `./uis deploy jupyterhub` |
| **Undeploy** | `./uis undeploy jupyterhub` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `jupyterhub/jupyterhub` (unpinned) |
| **Default namespace** | `jupyterhub` |

## What It Does

JupyterHub provides a web-based interactive notebook environment for data science and analytics. Each user gets their own notebook server pod with persistent storage and pre-installed data science tools.

Key capabilities:
- **PySpark integration** — pre-configured via lifecycle hooks for distributed data processing
- **Multi-user** — each user gets an isolated notebook pod (10Gi storage)
- **DummyAuthenticator** — simple password-based access for development
- **Pre-installed tools** — `jupyter/pyspark-notebook:spark-3.5.0` image with Python, Spark, pandas
- **Admin panel** — manage users and servers at `/hub/admin`

## Deploy

```bash
./uis deploy jupyterhub
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify jupyterhub

# Manual check
kubectl get pods -n jupyterhub

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://jupyterhub.localhost
# Expected: 200 or 302 (redirect to login)
```

Access the notebook interface at [http://jupyterhub.localhost](http://jupyterhub.localhost).

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Notebook image | `jupyter/pyspark-notebook:spark-3.5.0` | PySpark-enabled |
| User storage | `10Gi` per user | Persistent across sessions |
| Pod resources | 2 CPU, 2GB memory | Per notebook pod |
| Auth | DummyAuthenticator | Password from secrets |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_JUPYTERHUB_AUTH_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Login password |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/350-setup-jupyterhub.yml` | Deployment playbook |
| `ansible/playbooks/350-remove-jupyterhub.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy jupyterhub
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n jupyterhub -l app=jupyterhub
kubectl logs -n jupyterhub -l component=hub
```

**Notebook server not spawning:**
Check the hub logs for spawn errors:
```bash
kubectl logs -n jupyterhub -l component=hub --tail=30
```

**PySpark not available in notebooks:**
Verify the lifecycle hook configured Spark correctly:
```bash
kubectl logs -n jupyterhub -l component=singleuser-server --tail=20
```

## Learn More

- [Official JupyterHub documentation](https://jupyterhub.readthedocs.io/)
- [Spark operator](./spark.md)
