---
title: Elasticsearch
sidebar_label: Elasticsearch
---

# Elasticsearch

Distributed search and analytics engine for full-text search and log analysis.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy elasticsearch` |
| **Undeploy** | `./uis undeploy elasticsearch` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `elastic/elasticsearch` (unpinned) |
| **Default namespace** | `default` |

## What It Does

Elasticsearch provides full-text search, real-time analytics, and structured document storage. It runs as a single-node standalone instance suitable for development and testing.

Key capabilities:
- **Full-text search** with relevance scoring and highlighting
- **Analytics** via aggregations (date histograms, terms, metrics)
- **RESTful API** for all operations
- **Security enabled** with username/password authentication

## Deploy

```bash
./uis deploy elasticsearch
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify elasticsearch

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=elasticsearch

# Test cluster health
kubectl exec -it elasticsearch-master-0 -- curl -u "elastic:$ES_PASSWORD" -s \
  "http://localhost:9200/_cluster/health?pretty"
```

## Configuration

Elasticsearch configuration is in `manifests/060-elasticsearch-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Architecture | `standalone` | Single master node, no data/coordinating/ingest nodes |
| Storage | `8Gi` PVC | Persistent index data |
| HTTP port | `9200` | REST API |
| Transport port | `9300` | Inter-node communication |
| Security | Enabled | Username/password auth required |
| JVM heap | `512m` | Xms and Xmx |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_ELASTICSEARCH_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Elastic user password |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/060-elasticsearch-config.yaml` | Helm values (single-node, security, JVM) |
| `ansible/playbooks/060-setup-elasticsearch.yml` | Deployment playbook with verification |
| `ansible/playbooks/060-remove-elasticsearch.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy elasticsearch
```

## Troubleshooting

**Pod won't start (OOM or JVM errors):**
```bash
kubectl describe pod -l app.kubernetes.io/name=elasticsearch
kubectl logs -l app.kubernetes.io/name=elasticsearch
```

**Authentication failed:**
```bash
kubectl get secret urbalurba-secrets -o jsonpath="{.data.ELASTICSEARCH_PASSWORD}" | base64 -d
```

**Cluster status yellow/red:**
```bash
kubectl exec -it elasticsearch-master-0 -- curl -u "elastic:$ES_PASSWORD" -s \
  "http://localhost:9200/_cat/indices?v&health=yellow,red"
```

## Learn More

- [Official Elasticsearch documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
