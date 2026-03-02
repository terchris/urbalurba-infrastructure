---
title: Qdrant
sidebar_label: Qdrant
---

# Qdrant

High-performance vector database for AI/ML similarity search.

| | |
|---|---|
| **Category** | Databases |
| **Deploy** | `./uis deploy qdrant` |
| **Undeploy** | `./uis undeploy qdrant` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `qdrant/qdrant` (unpinned) |
| **Default namespace** | `default` |

## What It Does

Qdrant is a vector similarity search engine for AI/ML applications. It stores high-dimensional vectors (embeddings) and performs fast nearest-neighbor searches. Use it for semantic search, recommendation systems, image similarity, and RAG (Retrieval-Augmented Generation) pipelines.

Key capabilities:
- **Vector search** with cosine, dot product, and Euclidean distance
- **Payload filtering** — attach metadata to vectors and filter during search
- **Named vectors** — store multiple vector types per point (text + image)
- **API key authentication** for secure access
- **Snapshot-based backups** for data safety

## Deploy

```bash
./uis deploy qdrant
```

No dependencies.

## Verify

```bash
# Quick check
./uis verify qdrant

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=qdrant

# Test API (via port-forward)
kubectl port-forward svc/qdrant 6333:6333 &
curl http://localhost:6333/healthz
```

## Configuration

Qdrant configuration is in `manifests/044-qdrant-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| HTTP port | `6333` | REST API |
| gRPC port | `6334` | High-performance gRPC API |
| Data storage | `12Gi` PVC | Vector data |
| Snapshot storage | `5Gi` PVC | Backup snapshots |
| Auth | API key | From secrets |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_QDRANT_API_KEY` | `.uis.secrets/secrets-config/default-secrets.env` | API key for all requests |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/044-qdrant-config.yaml` | Helm values (storage, auth, resources) |
| `ansible/playbooks/044-setup-qdrant.yml` | Deployment playbook with 15 verification tests |
| `ansible/playbooks/044-remove-qdrant.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy qdrant
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -l app.kubernetes.io/name=qdrant
kubectl logs -l app.kubernetes.io/name=qdrant
```

**API authentication fails (401):**
Check the API key in secrets:
```bash
kubectl get secret urbalurba-secrets -o jsonpath="{.data.QDRANT_API_KEY}" | base64 -d
```

**Storage full:**
```bash
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- df -h
```

## Learn More

- [Official Qdrant documentation](https://qdrant.tech/documentation/)
- [Qdrant Helm chart](https://github.com/qdrant/qdrant-helm)
