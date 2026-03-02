---
title: MongoDB
sidebar_label: MongoDB
---

# MongoDB

Document-oriented NoSQL database with ARM64 support.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy mongodb` |
| **Undeploy** | `./uis undeploy mongodb` |
| **Depends on** | None |
| **Required by** | None |
| **Image** | `mongo:8.0.5` |
| **Default namespace** | `default` |

## What It Does

MongoDB provides a document database for applications that need flexible JSON-like storage. It is deployed as a StatefulSet (not via Helm) with authentication enabled and automatic user initialization. MongoDB is currently pre-configured with a Gravitee application user, though this coupling is planned to be removed.

## Deploy

```bash
./uis deploy mongodb
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify mongodb

# Manual check
kubectl get pods -n default -l app=mongodb

# Test connection
kubectl exec -it mongodb-0 -- mongosh --quiet --eval "db.adminCommand('ping')"
```

## Configuration

MongoDB configuration is in `manifests/040-mongodb-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Architecture | StatefulSet | Single replica, not Helm-based |
| Storage | `8Gi` PVC | Persistent data |
| Port | `27017` | Standard MongoDB port |
| Auth | Enabled | Root credentials from secrets |
| Memory | `256Mi` request, `1Gi` limit | |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_MONGODB_ROOT_USER` | `.uis.secrets/secrets-config/default-secrets.env` | Root admin username |
| `DEFAULT_MONGODB_ROOT_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Root admin password |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/040-mongodb-config.yaml` | StatefulSet, Service, ConfigMaps, PVC |
| `ansible/playbooks/040-setup-mongodb.yml` | Deployment playbook |
| `ansible/playbooks/040-remove-database-mongodb.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy mongodb
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod mongodb-0
kubectl logs mongodb-0
```

**Authentication failed:**
```bash
kubectl exec -it mongodb-0 -- mongosh --username root --password \
  --authenticationDatabase admin --eval "db.runCommand({connectionStatus:1})"
```

**PVC not bound:**
```bash
kubectl get pvc -l app=mongodb
kubectl describe pvc mongodb-data-mongodb-0
```

## Learn More

- [Official MongoDB documentation](https://www.mongodb.com/docs/)
