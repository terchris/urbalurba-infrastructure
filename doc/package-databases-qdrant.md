# Qdrant - Vector Database for AI/ML Applications

**Key Features**: Vector Search • Semantic Similarity • Embeddings Storage • API Authentication • Persistent Storage • High Performance • Python SDK

**File**: `doc/package-databases-qdrant.md`
**Purpose**: Complete guide to Qdrant vector database deployment and configuration in Urbalurba infrastructure
**Target Audience**: AI/ML engineers, developers working with embeddings, data scientists building vector search applications
**Last Updated**: September 24, 2025

## 📋 Overview

Qdrant serves as a **high-performance vector database** in the Urbalurba infrastructure, designed for AI/ML applications that require fast similarity search over high-dimensional vectors. It provides advanced vector search capabilities with semantic similarity matching for embeddings and machine learning workloads.

**Key Features**:
- **Vector Search Engine**: Optimized for high-dimensional vector similarity search
- **Embeddings Storage**: Store and retrieve text, image, and other embeddings efficiently
- **API Authentication**: Secure access with API key-based authentication
- **Helm-Based Deployment**: Uses official Qdrant chart with production-ready configuration
- **Persistent Storage**: Data and snapshots preserved across pod restarts
- **Secret Management**: Integrates with urbalurba-secrets for secure API key management
- **Comprehensive Testing**: Includes connectivity verification and API validation

## 🏗️ Architecture

### **Deployment Components**
```
Qdrant Vector Database Stack:
├── Helm Release (qdrant/qdrant)
├── Deployment (qdrant:latest container)
├── ConfigMap (Qdrant configuration)
├── Service (ClusterIP on port 6333 HTTP, 6334 gRPC)
├── PersistentVolumeClaims (12GB data + 5GB snapshots)
├── urbalurba-secrets (API key authentication)
└── Pod (qdrant container with vector search engine)
```

### **File Structure**
```
02-databases/
├── not-in-use/
    ├── 07-setup-qdrant.sh        # Main deployment script
    └── 07-remove-qdrant.sh       # Removal script

manifests/
└── 044-qdrant-config.yaml       # Qdrant Helm configuration

ansible/playbooks/
├── 044-setup-qdrant.yml         # Main deployment logic
└── 044-remove-qdrant.yml        # Removal logic
```

## 🚀 Deployment

### **Manual Deployment**
Qdrant is available in the `02-databases/not-in-use` category and can be deployed manually:

```bash
# Deploy Qdrant with default settings
cd provision-host/kubernetes/02-databases/not-in-use/
./07-setup-qdrant.sh rancher-desktop

# Deploy to specific Kubernetes context
./07-setup-qdrant.sh multipass-microk8s
./07-setup-qdrant.sh azure-aks
```

### **Prerequisites**
Before deploying Qdrant, ensure the required secrets are configured in `urbalurba-secrets`:

- `QDRANT_API_KEY`: API key for secure access to Qdrant endpoints

The API key should be a strong random string that will be used to authenticate all requests to the Qdrant API.

## ⚙️ Configuration

### **Qdrant Configuration**
Qdrant uses the official Qdrant image with authentication and persistent storage enabled:

```yaml
# From manifests/044-qdrant-config.yaml
service:
  type: ClusterIP

apiConfig:
  enable: true

auth:
  apiKey: # Set by Ansible playbook from urbalurba-secrets

storage:
  # Persistent storage for vector data
  data:
    size: 12Gi
    storageClass: local-path
  # Separate storage for snapshots
  snapshots:
    size: 5Gi
    storageClass: local-path
```

### **Resource Configuration**
```yaml
# Resource limits and requests
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "500m"

# Replica configuration
replicaCount: 1  # Single instance for development
```

### **Security Configuration**
```yaml
# API authentication
apiConfig:
  enable: true

# Environment variables from secrets
envFrom:
  - secretRef:
      name: urbalurba-secrets

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=qdrant

# Check deployment status
kubectl get deployment qdrant

# Check service status
kubectl get svc qdrant

# View Qdrant logs
kubectl logs -l app.kubernetes.io/name=qdrant
```

### **Service Verification**
```bash
# Check service endpoints
kubectl get endpoints qdrant

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup qdrant.default.svc.cluster.local

# Check persistent volumes
kubectl get pvc -l app.kubernetes.io/name=qdrant
```

### **Qdrant API Testing**
```bash
# Port forward for external access
kubectl port-forward svc/qdrant 6333:6333

# Test API connectivity (replace YOUR_API_KEY)
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections

# Check cluster info
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/cluster

# Test health endpoint
curl http://localhost:6333/health
```

### **Automated Verification**
The deployment includes comprehensive testing of Qdrant functionality with **15 automated verification tests**:

**Complete Verification Process**:
1. **API Authentication**: Validates API key from urbalurba-secrets
2. **Collection Management**: Tests collection creation and deletion
3. **Vector Operations**: Verifies vector insertion and retrieval
4. **Similarity Search**: Tests vector search functionality with exact matches
5. **Data Persistence**: Confirms vectors persist correctly in storage
6. **API Endpoints**: Tests all core Qdrant API endpoints
7. **Cleanup Verification**: Ensures proper data cleanup and collection removal

**Verification Tests Include**:
- ✅ **API connectivity and authentication** (HTTP 200 responses)
- ✅ **Collection creation and management** (create, list, delete operations)
- ✅ **Vector data insertion and persistence** (points API with payload)
- ✅ **Point retrieval by ID** (validates data integrity)
- ✅ **Vector similarity search functionality** (semantic search with scoring)
- ✅ **Data cleanup and collection deletion** (proper resource management)

The verification runs automatically when using `./07-setup-qdrant.sh` and provides comprehensive testing of all core Qdrant vector database capabilities.

## 🛠️ Management Operations

### **Qdrant Administration**
```bash
# Access Qdrant container
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- bash

# Check Qdrant process
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- ps aux | grep qdrant

# View configuration
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- cat /qdrant/config/production.yaml
```

### **Collection Management**
```bash
# List all collections
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections

# Create a collection
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }' \
  http://localhost:6333/collections/my_collection

# Get collection info
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections/my_collection

# Delete a collection
curl -X DELETE -H "api-key: YOUR_API_KEY" http://localhost:6333/collections/my_collection
```

### **Vector Operations**
```bash
# Insert vectors into collection
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, 0.3, /* ... 384 dimensions */],
        "payload": {"text": "sample document", "category": "example"}
      }
    ]
  }' \
  http://localhost:6333/collections/my_collection/points

# Search similar vectors
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vector": [0.1, 0.2, 0.3, /* query vector */],
    "limit": 5,
    "with_payload": true
  }' \
  http://localhost:6333/collections/my_collection/points/search

# Get specific point
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections/my_collection/points/1
```

### **Service Removal**
```bash
# Remove Qdrant service (preserves data by default)
cd provision-host/kubernetes/02-databases/not-in-use/
./07-remove-qdrant.sh rancher-desktop

# Complete removal including data
kubectl delete pvc qdrant-data qdrant-snapshots
```

**Removal Process**:
- Uninstalls Qdrant Helm release
- Waits for pods to terminate
- Preserves PVCs by default for data safety
- Maintains urbalurba-secrets
- Provides complete cleanup options if needed

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=qdrant
kubectl logs -l app.kubernetes.io/name=qdrant

# Check persistent volume claims
kubectl describe pvc qdrant-data qdrant-snapshots
```

**Authentication Issues**:
```bash
# Check API key in secrets
kubectl get secret urbalurba-secrets -o jsonpath="{.data.QDRANT_API_KEY}" | base64 -d

# Test authentication
curl -v -H "api-key: $(kubectl get secret urbalurba-secrets -o jsonpath='{.data.QDRANT_API_KEY}' | base64 -d)" \
  http://localhost:6333/collections

# Check environment variables in pod
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- env | grep -i qdrant
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc qdrant
kubectl get endpoints qdrant

# Check port connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- \
  curl -v http://qdrant:6333/health

# Test gRPC port (6334)
kubectl run test-pod --image=busybox --rm -it -- \
  nc -zv qdrant 6334
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod -l app.kubernetes.io/name=qdrant

# Monitor disk usage
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- df -h

# Check memory usage
kubectl exec -it $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name) -- free -h

# View Qdrant metrics
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/metrics
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **Storage Monitoring**: Monitor disk usage for vector data and snapshots
3. **Performance Monitoring**: Track query response times and throughput
4. **Collection Monitoring**: Review collection sizes and vector counts

### **Backup Procedures**
```bash
# Create collection snapshot
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{"collection_name": "my_collection"}' \
  http://localhost:6333/collections/my_collection/snapshots

# List snapshots
curl -H "api-key: YOUR_API_KEY" http://localhost:6333/collections/my_collection/snapshots

# Download snapshot
curl -H "api-key: YOUR_API_KEY" \
  http://localhost:6333/collections/my_collection/snapshots/snapshot_name \
  -o collection_backup.snapshot

# Copy data from PVC
kubectl cp $(kubectl get pod -l app.kubernetes.io/name=qdrant -o name):/qdrant/storage \
  ./qdrant-backup-$(date +%Y%m%d)/
```

### **Disaster Recovery**
```bash
# Restore from snapshot
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data-binary @collection_backup.snapshot \
  http://localhost:6333/collections/my_collection/snapshots/restore

# Restore from PVC backup (requires pod restart)
# 1. Restore PVC data to persistent volume
# 2. Delete pod to force restart with restored data
kubectl delete pod -l app.kubernetes.io/name=qdrant
```

## 🚀 Use Cases

### **Semantic Search**
```bash
# Create text embeddings collection
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vectors": {
      "size": 384,
      "distance": "Cosine"
    }
  }' \
  http://localhost:6333/collections/documents

# Insert document embeddings
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "points": [
      {
        "id": 1,
        "vector": [/* sentence embedding from model */],
        "payload": {
          "text": "Machine learning enables computers to learn without explicit programming",
          "source": "article_1",
          "timestamp": "2025-09-24"
        }
      }
    ]
  }' \
  http://localhost:6333/collections/documents/points

# Search similar documents
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vector": [/* query embedding */],
    "limit": 5,
    "with_payload": true,
    "score_threshold": 0.8
  }' \
  http://localhost:6333/collections/documents/points/search
```

### **Recommendation System**
```bash
# Create user preferences collection
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vectors": {
      "size": 256,
      "distance": "Dot"
    }
  }' \
  http://localhost:6333/collections/user_preferences

# Store user behavior vectors
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "points": [
      {
        "id": 12345,
        "vector": [/* user preference embedding */],
        "payload": {
          "user_id": 12345,
          "categories": ["tech", "ai", "programming"],
          "last_active": "2025-09-24"
        }
      }
    ]
  }' \
  http://localhost:6333/collections/user_preferences/points

# Find similar users
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vector": [/* target user vector */],
    "limit": 10,
    "with_payload": true
  }' \
  http://localhost:6333/collections/user_preferences/points/search
```

### **Image Similarity Search**
```bash
# Create image embeddings collection
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vectors": {
      "size": 2048,
      "distance": "Cosine"
    }
  }' \
  http://localhost:6333/collections/images

# Store image feature vectors
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "points": [
      {
        "id": "img_001",
        "vector": [/* CNN feature extraction */],
        "payload": {
          "filename": "photo1.jpg",
          "tags": ["nature", "landscape", "mountains"],
          "upload_date": "2025-09-24"
        }
      }
    ]
  }' \
  http://localhost:6333/collections/images/points

# Find visually similar images
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vector": [/* query image features */],
    "limit": 8,
    "with_payload": true
  }' \
  http://localhost:6333/collections/images/points/search
```

### **Multi-Vector Collections**
```bash
# Create collection with named vectors
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vectors": {
      "text": {"size": 384, "distance": "Cosine"},
      "image": {"size": 2048, "distance": "Cosine"}
    }
  }' \
  http://localhost:6333/collections/multimodal

# Insert multi-modal data
curl -X PUT -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "points": [
      {
        "id": 1,
        "vector": {
          "text": [/* text embedding */],
          "image": [/* image embedding */]
        },
        "payload": {
          "title": "Product description",
          "category": "electronics"
        }
      }
    ]
  }' \
  http://localhost:6333/collections/multimodal/points

# Search by text similarity
curl -X POST -H "api-key: YOUR_API_KEY" -H "Content-Type: application/json" \
  --data '{
    "vector": {
      "name": "text",
      "vector": [/* query text embedding */]
    },
    "limit": 5
  }' \
  http://localhost:6333/collections/multimodal/points/search
```

---

**💡 Key Insight**: Qdrant provides essential vector database capabilities that enable advanced AI/ML applications with semantic search, recommendation systems, and similarity matching. Use Qdrant for storing embeddings, building recommendation engines, implementing semantic search, and creating AI applications that require fast similarity queries over high-dimensional data.