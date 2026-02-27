---
title: MySQL
sidebar_label: MySQL
---

# MySQL

Open-source relational database for applications requiring MySQL compatibility.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy mysql` |
| **Undeploy** | `./uis undeploy mysql` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `bitnami/mysql` (unpinned) |
| **Default namespace** | `default` |

## What It Does

MySQL provides an alternative relational database option alongside PostgreSQL. It is available for applications that specifically require MySQL compatibility. No other UIS services depend on MySQL — it is purely for user workloads.

## Deploy

```bash
./uis deploy mysql
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify mysql

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=mysql

# Test connection
kubectl exec -it mysql-0 -- mysqladmin ping -uroot -p
```

## Configuration

MySQL configuration is in `manifests/043-database-mysql-config.yaml`.

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `3306` | Standard MySQL port |
| Auth | Enabled | Password from secrets |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_MYSQL_ROOT_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Root user password |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/043-database-mysql-config.yaml` | Helm values and service config |
| `ansible/playbooks/040-database-mysql.yml` | Deployment playbook |
| `ansible/playbooks/040-remove-database-mysql.yml` | Removal playbook |
| `ansible/playbooks/utility/u08-verify-mysql.yml` | CRUD verification |

## Undeploy

```bash
./uis undeploy mysql
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app.kubernetes.io/name=mysql
kubectl logs -l app.kubernetes.io/name=mysql
```

**Authentication failed:**
Check the secret value:
```bash
kubectl get secret urbalurba-secrets -o jsonpath="{.data.MYSQL_ROOT_PASSWORD}" | base64 -d
```

**Connection refused:**
```bash
kubectl get svc mysql
kubectl get endpoints mysql
```

## Learn More

- [Official MySQL documentation](https://dev.mysql.com/doc/)
- [Bitnami MySQL Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/mysql)
