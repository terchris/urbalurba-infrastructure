---
title: RedisInsight
sidebar_label: RedisInsight
---

# RedisInsight

Web-based Redis database management and visualization tool.

| | |
|---|---|
| **Category** | Management |
| **Deploy** | `./uis deploy redisinsight` |
| **Undeploy** | `./uis undeploy redisinsight` |
| **Depends on** | redis |
| **Required by** | None |
| **Helm chart** | `redis/redisinsight` (unpinned) |
| **Default namespace** | `default` |

## What It Does

RedisInsight provides a visual interface for managing Redis databases. It requires manual connection setup on first use — you'll need to add the Redis connection details to browse data, run commands, and analyze memory usage.

Key capabilities:
- **Browser** — explore keys, values, and data types visually
- **Workbench** — run Redis commands with autocomplete
- **Memory analysis** — visualize memory usage patterns
- **5Gi persistent storage** — preserves connections and settings

## Deploy

```bash
# Deploy dependency first
./uis deploy redis

# Deploy RedisInsight
./uis deploy redisinsight
```

## Verify

```bash
# Quick check
./uis verify redisinsight

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=redisinsight

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://redisinsight.localhost
# Expected: 200
```

Access the interface at [http://redisinsight.localhost](http://redisinsight.localhost).

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `5540` | Web UI |
| Storage | `5Gi` PVC | Persistent settings |
| Security | UID 1001 | Non-root container |
| Connection | Manual setup | Not pre-configured |

### First-Time Setup

After deployment, add the Redis connection:
1. Open [http://redisinsight.localhost](http://redisinsight.localhost)
2. Accept the terms
3. Click "Add Redis Database"
4. Enter: Host=`redis-master`, Port=`6379`, Password from secrets

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/651-adm-redisinsight.yml` | Deployment playbook |
| `ansible/playbooks/651-adm-remove-redisinsight.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy redisinsight
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app.kubernetes.io/name=redisinsight
kubectl logs -l app.kubernetes.io/name=redisinsight
```

**Cannot connect to Redis:**
Verify Redis is running and get the password:
```bash
kubectl get pods -l app.kubernetes.io/name=redis
kubectl get secret urbalurba-secrets -o jsonpath="{.data.REDIS_PASSWORD}" | base64 -d
```

## Learn More

- [Official RedisInsight documentation](https://redis.io/docs/connect/insight/)
- [Redis service](../databases/redis.md)
