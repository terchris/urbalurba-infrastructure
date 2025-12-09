# Elasticsearch - Search and Analytics Engine

**Key Features**: Full-Text Search • Real-Time Analytics • Document Storage • RESTful API • Distributed Architecture • Aggregations • Query DSL

**File**: `docs/package-search-elasticsearch.md`
**Purpose**: Complete guide to Elasticsearch deployment and configuration in Urbalurba infrastructure
**Target Audience**: Developers, DevOps engineers, data engineers working with search, analytics, and document storage
**Last Updated**: September 23, 2025

## 📋 Overview

Elasticsearch serves as the **primary search and analytics engine** in the Urbalurba infrastructure. It provides powerful full-text search capabilities, real-time analytics, and scalable document storage for applications requiring advanced search functionality.

**Key Features**:
- **Search Engine**: Advanced full-text search with relevance scoring and highlighting
- **Analytics**: Real-time aggregations and data analysis capabilities
- **Document Store**: JSON document storage with automatic schema detection
- **RESTful API**: HTTP-based API for all operations
- **Helm-Based Deployment**: Uses Bitnami Elasticsearch chart with secure configuration
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes comprehensive connectivity and functionality verification
- **Single-Node Architecture**: Optimized deployment for development and testing environments

## 🏗️ Architecture

### **Deployment Components**
```
Elasticsearch Service Stack:
├── Helm Release (bitnami/elasticsearch)
├── StatefulSet (elasticsearch:8.16.1 container)
├── ConfigMap (Elasticsearch configuration)
├── Service (ClusterIP on port 9200 HTTP, 9300 Transport)
├── PersistentVolumeClaim (8GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (elasticsearch container with security enabled)
```

### **File Structure**
```
04-search/
├── not-in-use/
    ├── 07-setup-elasticsearch.sh       # Main deployment script
    └── 07-remove-elasticsearch.sh      # Removal script

manifests/
└── 060-elasticsearch-config.yaml      # Elasticsearch Helm configuration

ansible/playbooks/
├── 060-setup-elasticsearch.yml        # Main deployment logic
└── 060-remove-elasticsearch.yml       # Removal logic
```

## 🚀 Deployment

### **Manual Deployment**
Elasticsearch is currently in the `04-search/not-in-use` category and can be deployed manually:

```bash
# Deploy Elasticsearch with default settings (8.16.1)
cd provision-host/kubernetes/04-search/not-in-use/
./07-setup-elasticsearch.sh rancher-desktop

# Deploy to specific Kubernetes context
./07-setup-elasticsearch.sh multipass-microk8s
./07-setup-elasticsearch.sh azure-aks

# Deploy with specific version
ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/060-setup-elasticsearch.yml \
  -e target_host=rancher-desktop \
  -e elasticsearch_version=8.16.1
```

### **Prerequisites**
Before deploying Elasticsearch, ensure the required secrets are configured in `urbalurba-secrets`:

- `ELASTICSEARCH_USERNAME`: Elasticsearch admin username (default: elastic)
- `ELASTICSEARCH_PASSWORD`: Elasticsearch admin password

## ⚙️ Configuration

### **Elasticsearch Configuration**
Elasticsearch uses the Bitnami Elasticsearch 8.16.1 image with security and authentication enabled:

```yaml
# From manifests/060-elasticsearch-config.yaml
service:
  type: ClusterIP

# Single-node configuration for development
master:
  replicaCount: 1
data:
  replicaCount: 0
coordinating:
  replicaCount: 0
ingest:
  enabled: false

# Security configuration
security:
  enabled: true
  elasticPassword: # Set by playbook using --set security.elasticPassword=<password>

architecture: standalone
```

### **Helm Configuration**
```bash
# Deployment command (from Ansible playbook)
helm upgrade --install elasticsearch bitnami/elasticsearch \
  -f manifests/060-elasticsearch-config.yaml \
  --set security.elasticPassword="$ELASTICSEARCH_PASSWORD" \
  --set image.tag=8.16.1 \
  --set master.replicaCount=1 \
  --set data.replicaCount=0 \
  --set coordinating.replicaCount=0 \
  --set ingest.enabled=false
```

### **Resource Configuration**
```yaml
# Resource limits and requests
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"

# Storage configuration
persistence:
  enabled: true
  size: 8Gi
  accessMode: ReadWriteOnce
```

### **Security Configuration**
```yaml
# Authentication configuration
security:
  enabled: true

# JVM heap configuration
extraConfiguration: |
  -Xms512m
  -Xmx512m
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=elasticsearch

# Check StatefulSet status
kubectl get statefulset elasticsearch

# Check service status
kubectl get svc elasticsearch

# View Elasticsearch logs
kubectl logs -l app.kubernetes.io/name=elasticsearch
```

### **Elasticsearch Connection Testing**
```bash
# Test cluster health
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_cluster/health?pretty"

# Check cluster nodes
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_nodes?pretty"

# Test basic functionality
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/"

# Check service endpoints
kubectl get endpoints elasticsearch
```

### **Port Forward for External Access**
```bash
# Port forward for local access
kubectl port-forward svc/elasticsearch 9200:9200

# Access via browser or curl
# URL: http://localhost:9200
# Username: elastic (from secrets)
# Password: [from secrets]

# Test with curl
curl -u "elastic:password" "http://localhost:9200/_cluster/health?pretty"
```

### **Automated Verification**
The deployment includes comprehensive testing of Elasticsearch functionality:

**Verification Process**:
1. **Two-stage pod readiness**: Waits for Running and Ready status
2. **Cluster health check**: Verifies cluster status (green/yellow)
3. **Index creation test**: Creates a test index to verify write operations
4. **Document indexing test**: Indexes a test document
5. **Search functionality test**: Performs search query to verify read operations
6. **Cleanup**: Removes test index after verification

## 🛠️ Management Operations

### **Elasticsearch Administration**
```bash
# Access Elasticsearch container
kubectl exec -it elasticsearch-0 -- bash

# Check cluster status
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_cluster/health?pretty"

# List all indices
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_cat/indices?v"

# Check node information
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_nodes/stats?pretty"

# Monitor cluster stats
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_cluster/stats?pretty"
```

### **Index Management**
```bash
# Create an index
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/my-index" \
  -H 'Content-Type: application/json' \
  -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}'

# Check index settings
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/my-index/_settings?pretty"

# Delete an index
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X DELETE \
  "http://localhost:9200/my-index"

# List index mapping
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/my-index/_mapping?pretty"
```

### **Document Operations**
```bash
# Index a document
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/my-index/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"title":"My Document","content":"This is test content","timestamp":"2025-09-23T00:00:00Z"}'

# Get a document by ID
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/my-index/_doc/DOCUMENT_ID"

# Search documents
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/my-index/_search?q=title:Document&pretty"

# Update a document
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/my-index/_doc/DOCUMENT_ID/_update" \
  -H 'Content-Type: application/json' \
  -d '{"doc":{"content":"Updated content"}}'

# Delete a document
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X DELETE \
  "http://localhost:9200/my-index/_doc/DOCUMENT_ID"
```

### **Service Removal**
```bash
# Remove Elasticsearch service (preserves data by default)
cd provision-host/kubernetes/04-search/not-in-use/
./07-remove-elasticsearch.sh rancher-desktop

# Completely remove including data
ansible-playbook ansible/playbooks/060-remove-elasticsearch.yml \
  -e target_host=rancher-desktop
```

**Removal Process**:
- Uninstalls Elasticsearch Helm release
- Waits for pods to terminate
- Removes persistent volume claims and services
- Preserves urbalurba-secrets and namespace structure
- Provides data retention options and recovery instructions

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=elasticsearch
kubectl logs -l app.kubernetes.io/name=elasticsearch

# Check Java heap issues
kubectl exec -it elasticsearch-0 -- cat /opt/bitnami/elasticsearch/config/jvm.options

# Check disk space
kubectl exec -it elasticsearch-0 -- df -h
```

**Authentication Issues**:
```bash
# Check Elasticsearch credentials in secrets
kubectl get secret urbalurba-secrets -o jsonpath="{.data.ELASTICSEARCH_USERNAME}" | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath="{.data.ELASTICSEARCH_PASSWORD}" | base64 -d

# Test authentication
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" \
  "http://localhost:9200/_security/_authenticate?pretty"

# Reset elastic password (if needed)
kubectl exec -it elasticsearch-0 -- /opt/bitnami/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc elasticsearch
kubectl get endpoints elasticsearch

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup elasticsearch.default.svc.cluster.local

# Check Elasticsearch node status
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_nodes?pretty"
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod elasticsearch-0

# Monitor Elasticsearch performance
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_nodes/stats/indices,jvm,process?pretty"

# Check heap usage
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_nodes/stats/jvm?pretty"

# Monitor slow queries
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_nodes/stats/indices/search?pretty"
```

**Index Issues**:
```bash
# Check index health
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_cat/indices?v&health=yellow,red"

# Check shard allocation
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_cat/shards?v"

# Force index recovery
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/_recovery?pretty"

# Check cluster allocation explanation
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_cluster/allocation/explain?pretty"
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check cluster health and node status daily
2. **Index Monitoring**: Monitor index sizes, shard allocation, and performance
3. **Backup Schedule**: Implement regular snapshots of indices
4. **Performance Monitoring**: Monitor query performance, heap usage, and disk space

### **Backup Procedures**
```bash
# Create snapshot repository (filesystem)
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/_snapshot/backup_repo" \
  -H 'Content-Type: application/json' \
  -d '{"type":"fs","settings":{"location":"/opt/bitnami/elasticsearch/snapshots"}}'

# Create a snapshot
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d_%H%M%S)" \
  -H 'Content-Type: application/json' \
  -d '{"indices":"*","ignore_unavailable":true,"include_global_state":false}'

# List snapshots
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_snapshot/backup_repo/_all?pretty"

# Copy snapshot data
kubectl cp elasticsearch-0:/opt/bitnami/elasticsearch/snapshots \
  ./elasticsearch-backup-$(date +%Y%m%d)/
```

### **Disaster Recovery**
```bash
# Restore from snapshot
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/_snapshot/backup_repo/SNAPSHOT_NAME/_restore" \
  -H 'Content-Type: application/json' \
  -d '{"indices":"*","ignore_unavailable":true,"include_global_state":false}'

# Monitor restore progress
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/_recovery?pretty"

# Restore specific indices
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/_snapshot/backup_repo/SNAPSHOT_NAME/_restore" \
  -H 'Content-Type: application/json' \
  -d '{"indices":"index1,index2","rename_pattern":"(.+)","rename_replacement":"restored_$1"}'
```

## 🚀 Use Cases

### **Full-Text Search**
```bash
# Create search index with text analysis
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/search_index" \
  -H 'Content-Type: application/json' \
  -d '{
    "settings": {
      "analysis": {
        "analyzer": {
          "my_analyzer": {
            "tokenizer": "standard",
            "filter": ["lowercase", "stop"]
          }
        }
      }
    },
    "mappings": {
      "properties": {
        "title": {"type": "text", "analyzer": "my_analyzer"},
        "content": {"type": "text", "analyzer": "my_analyzer"},
        "tags": {"type": "keyword"}
      }
    }
  }'

# Index searchable documents
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/search_index/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Getting Started with Elasticsearch","content":"Elasticsearch is a powerful search engine","tags":["search","tutorial"]}'

# Perform full-text search
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/search_index/_search" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"content":"search engine"}},"highlight":{"fields":{"content":{}}}}'
```

### **Analytics and Aggregations**
```bash
# Create analytics index
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/analytics" \
  -H 'Content-Type: application/json' \
  -d '{
    "mappings": {
      "properties": {
        "timestamp": {"type": "date"},
        "user_id": {"type": "keyword"},
        "action": {"type": "keyword"},
        "value": {"type": "double"}
      }
    }
  }'

# Index analytics data
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/analytics/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"timestamp":"2025-09-23T10:00:00Z","user_id":"user123","action":"login","value":1}'

# Perform aggregations
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/analytics/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "aggs": {
      "actions_per_hour": {
        "date_histogram": {
          "field": "timestamp",
          "calendar_interval": "hour"
        }
      },
      "top_actions": {
        "terms": {
          "field": "action",
          "size": 10
        }
      }
    }
  }'
```

### **Log Analysis**
```bash
# Create log index with timestamp field
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/logs" \
  -H 'Content-Type: application/json' \
  -d '{
    "mappings": {
      "properties": {
        "@timestamp": {"type": "date"},
        "level": {"type": "keyword"},
        "message": {"type": "text"},
        "service": {"type": "keyword"},
        "host": {"type": "keyword"}
      }
    }
  }'

# Index log entries
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/logs/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"@timestamp":"2025-09-23T10:00:00Z","level":"ERROR","message":"Database connection failed","service":"api","host":"server1"}'

# Search logs by level and time range
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/logs/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "filter": [
          {"term": {"level": "ERROR"}},
          {"range": {"@timestamp": {"gte": "2025-09-23T09:00:00Z", "lte": "2025-09-23T11:00:00Z"}}}
        ]
      }
    },
    "sort": [{"@timestamp": {"order": "desc"}}]
  }'
```

### **Geospatial Search**
```bash
# Create geospatial index
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X PUT \
  "http://localhost:9200/locations" \
  -H 'Content-Type: application/json' \
  -d '{
    "mappings": {
      "properties": {
        "name": {"type": "text"},
        "location": {"type": "geo_point"},
        "category": {"type": "keyword"}
      }
    }
  }'

# Index location data
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X POST \
  "http://localhost:9200/locations/_doc" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Coffee Shop","location":{"lat":59.9139,"lon":10.7522},"category":"restaurant"}'

# Search by distance
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s -X GET \
  "http://localhost:9200/locations/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "geo_distance": {
        "distance": "5km",
        "location": {"lat": 59.9139, "lon": 10.7522}
      }
    }
  }'
```

---

**💡 Key Insight**: Elasticsearch provides powerful search and analytics capabilities that enable real-time data exploration, full-text search, and complex aggregations. Use Elasticsearch for implementing search functionality, log analysis, monitoring dashboards, and any application requiring fast, scalable document storage and retrieval.