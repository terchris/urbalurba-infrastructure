---
title: Redis
sidebar_label: Redis
---

# Redis

In-memory data store used as a cache and message broker.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy redis` |
| **Undeploy** | `./uis undeploy redis` |
| **Depends on** | None |
| **Required by** | authentik, redisinsight |
| **Helm chart** | `bitnami/redis` (unpinned) |
| **Default namespace** | `default` |

## What It Does

Redis is an open-source, in-memory data structure store that supports strings, hashes, lists, sets, and sorted sets. In UIS, Redis serves as:

- **Session store** for Authentik (stores authentication sessions and tokens)
- **Cache** for services that need fast key-value storage
- **Message broker** for pub/sub messaging between services

Redis is deployed as a standalone single-instance using the Bitnami Helm chart with authentication enabled.

## Deploy

```bash
# Deploy Redis
./uis deploy redis
```

No dependencies. Redis is typically deployed early because Authentik depends on it.

## Verify

```bash
# Quick check
./uis verify redis

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=redis

# Test Redis authentication
kubectl exec -it redis-master-0 -- redis-cli -a "$REDIS_PASSWORD" ping
# Expected: PONG
```

## Configuration

Redis configuration is in `manifests/050-redis-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Architecture | `standalone` | Single instance, no replicas |
| Storage | `6Gi` PVC | Persistent data across restarts |
| Port | `6379` | Standard Redis port |
| Auth | Enabled | Password from secrets |
| Memory limit | `256Mi` | Pod memory limit |

### Secrets

The Redis password is managed through UIS secrets:

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_REDIS_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Redis authentication password |

The password flows from `default-secrets.env` through `first-run.sh` into the common values template, then into the Helm deployment via `--set global.redis.password`.

## Undeploy

```bash
./uis undeploy redis
```

This removes the Helm release, pods, and PVCs. Services that depend on Redis (authentik, redisinsight) should be undeployed first.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n default -l app.kubernetes.io/name=redis
kubectl logs -n default -l app.kubernetes.io/name=redis
```

**Authentication failed (NOAUTH):**
The password in the deployment doesn't match what Redis expects. Check the secret:
```bash
kubectl get secret urbalurba-secrets -o jsonpath="{.data.REDIS_PASSWORD}" | base64 -d
```

**Connection refused from other services:**
Verify the service exists and has endpoints:
```bash
kubectl get svc redis-master
kubectl get endpoints redis-master
```

**Authentik won't start after Redis redeploy:**
If Redis was redeployed with a different password, Authentik's cached connection will fail. Restart Authentik:
```bash
kubectl rollout restart deployment -n authentik authentik-server
kubectl rollout restart deployment -n authentik authentik-worker
```

## Learn More

- [Official Redis documentation](https://redis.io)
- [Bitnami Redis Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [RedisInsight management tool](../management/redisinsight.md)
