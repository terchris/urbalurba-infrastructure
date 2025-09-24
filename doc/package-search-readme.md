# Search Services - Overview and Management

**Key Components**: Elasticsearch • Full-Text Search • Analytics Engine • Document Storage • Real-Time Search

**File**: `doc/package-search-readme.md`
**Purpose**: Overview of search services available in Urbalurba infrastructure
**Target Audience**: Developers, architects, and operations teams implementing search functionality
**Last Updated**: September 23, 2025

## 📋 Overview

The **Search Services** package provides powerful search and analytics capabilities for applications requiring advanced text search, real-time analytics, and document storage. These services enable full-text search, data exploration, log analysis, and complex aggregations across your applications.

**Available Services**:
- **Elasticsearch**: Primary search and analytics engine with RESTful API
- **Future Services**: Potential integration with OpenSearch, Solr, or specialized search solutions

## 🏗️ Architecture

### **Service Categories**

```
Search Services Stack:
├── 04-search/
│   ├── not-in-use/
│   │   ├── 07-setup-elasticsearch.sh    # Elasticsearch deployment
│   │   └── 07-remove-elasticsearch.sh   # Elasticsearch removal
│   └── (Future search services)
├── manifests/
│   └── 060-elasticsearch-config.yaml    # Elasticsearch configuration
└── ansible/playbooks/
    ├── 060-setup-elasticsearch.yml      # Elasticsearch deployment logic
    └── 060-remove-elasticsearch.yml     # Elasticsearch removal logic
```

### **Service Integration**
```
Application Layer
├── Search API (Full-text search)
├── Analytics Dashboard (Real-time metrics)
├── Log Aggregation (Centralized logging)
└── Data Exploration (Interactive queries)
    ↓
Search Layer
├── Elasticsearch (8.16.1)
│   ├── Full-text search engine
│   ├── Real-time analytics
│   ├── Document storage
│   └── RESTful API
└── (Future: OpenSearch, Solr)
    ↓
Storage Layer
├── Persistent Volumes (Document storage)
├── Index Storage (Optimized for search)
└── Backup Storage (Snapshots)
```

## 🚀 Available Services

### **Elasticsearch - Search & Analytics Engine** 🔍
**Status**: Available (not-in-use) | **Port**: 9200 | **Type**: Search Engine

**Key Capabilities**: Full-Text Search • Real-Time Analytics • Document Storage • RESTful API • Query DSL • Aggregations • Log Analysis

Elasticsearch provides **comprehensive search and analytics** capabilities for applications requiring advanced text search, real-time data exploration, and document storage. Essential for implementing search functionality, log aggregation, and analytics dashboards.

**Key Features**:
- **Search Engine**: Advanced full-text search with relevance scoring
- **Analytics Platform**: Real-time aggregations and data analysis
- **Document Store**: JSON document storage with automatic indexing
- **RESTful API**: HTTP-based API for all operations
- **Security**: Centralized authentication via urbalurba-secrets

📚 **[Complete Documentation →](./package-search-elasticsearch.md)**

## 🔄 Service Selection Guide

### **When to Use Elasticsearch**

**✅ Choose Elasticsearch for**:
- **Full-text search requirements**: Product catalogs, content management, documentation search
- **Real-time analytics**: Dashboards, metrics, business intelligence
- **Log aggregation**: Centralized logging from multiple services
- **Complex data exploration**: Interactive queries, faceted search
- **High-volume data**: Large datasets requiring fast search and aggregation
- **RESTful integration**: Applications preferring HTTP API access

**❌ Consider alternatives when**:
- **Simple key-value lookup**: Use Redis or database indices instead
- **Very small datasets**: Database LIKE queries may be sufficient
- **Real-time requirements**: Sub-millisecond latency needs (use Redis)
- **Memory constraints**: Elasticsearch requires significant RAM for optimal performance

### **Search Service Decision Matrix**

| Use Case | Volume | Complexity | Real-Time | Recommended Service |
|----------|--------|------------|-----------|-------------------|
| Product Search | High | High | Moderate | **Elasticsearch** |
| Content Search | Medium | High | Low | **Elasticsearch** |
| Log Analysis | High | Medium | Low | **Elasticsearch** |
| Analytics Dashboard | High | High | High | **Elasticsearch** |
| Simple Search | Low | Low | High | **Database + Redis** |
| Autocomplete | Medium | Low | High | **Elasticsearch + Redis** |
| Document Storage | High | Medium | Low | **Elasticsearch** |
| Geospatial Search | Medium | High | Moderate | **Elasticsearch** |

## 🛠️ Common Operations

### **Service Management**
```bash
# Check search services
kubectl get pods -l app.kubernetes.io/name=elasticsearch

# Monitor service logs
kubectl logs -l app.kubernetes.io/name=elasticsearch -f

# Check service status
kubectl get svc elasticsearch
```

### **Quick Health Check**
```bash
# Elasticsearch health
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" -s \
  "http://localhost:9200/_cluster/health"

# Resource usage
kubectl top pod elasticsearch-0
```

### **Deploy/Remove Services**
```bash
# Deploy Elasticsearch
cd provision-host/kubernetes/04-search/not-in-use/
./07-setup-elasticsearch.sh rancher-desktop

# Remove Elasticsearch
./07-remove-elasticsearch.sh rancher-desktop
```

## 🔧 Troubleshooting

### **Common Issues**
- **Pod Won't Start**: Check pod events, logs, and Java heap settings
- **Search Performance**: Monitor cluster stats, heap usage, and query performance
- **Authentication Failed**: Verify urbalurba-secrets configuration
- **Index Issues**: Check index health, shard allocation, and cluster status

### **Quick Diagnostics**
```bash
# Check pod status
kubectl describe pod elasticsearch-0
kubectl logs elasticsearch-0

# Verify credentials
kubectl get secret urbalurba-secrets -o jsonpath="{.data.ELASTICSEARCH_PASSWORD}" | base64 -d

# Test connectivity
kubectl exec -it elasticsearch-0 -- curl -u "elastic:password" \
  "http://localhost:9200/_cluster/health"
```

## 📋 Service Documentation

### **Detailed Service Guides**
- **[Elasticsearch](package-search-elasticsearch.md)**: Complete deployment, configuration, and management guide
- **Future Services**: Documentation will be added as new search services are integrated

### **Related Documentation**
- **[Infrastructure Rules](rules-provisioning.md)**: Deployment standards and patterns
- **[Secrets Management](secrets-management-readme.md)**: Authentication and credential management
- **[Troubleshooting](troubleshooting-readme.md)**: General troubleshooting procedures

## 🚀 Integration Examples

### **Common Integration Patterns**
- **Full-Text Search**: Product catalogs, documentation search, content discovery
- **Log Aggregation**: Centralized logging from multiple services
- **Analytics Dashboards**: Real-time metrics and business intelligence
- **Monitoring**: Application performance and system health tracking

*See detailed implementation examples in [Elasticsearch Documentation](./package-search-elasticsearch.md)*

---

**💡 Key Insight**: Search services are essential for modern applications requiring advanced data discovery, real-time analytics, and full-text search capabilities. Choose Elasticsearch for comprehensive search and analytics needs, and consider complementary services like Redis for high-speed caching and simple lookups to create a complete search architecture.