# Loki - Log Aggregation System

**Key Features**: Log Aggregation • LogQL Query Language • Label-Based Indexing • Structured Metadata • Low Storage Cost • OTLP Ingestion • Grafana Integration • Multi-Tenancy

**File**: `doc/package-monitoring-loki.md`
**Purpose**: Complete guide to Loki deployment and configuration for log aggregation in Urbalurba infrastructure
**Target Audience**: DevOps engineers, platform administrators, SREs, developers
**Last Updated**: October 3, 2025

**Deployed Version**: Loki v3.5.5 (Helm Chart: loki-6.41.1)
**Official Documentation**: https://grafana.com/docs/loki/v3.5.x/
**OTLP Integration Guide**: https://grafana.com/docs/loki/latest/send-data/otel/

## 📋 Overview

Loki is a **horizontally scalable, highly available log aggregation system** inspired by Prometheus. Unlike traditional log aggregators that index full-text content, Loki only indexes metadata labels, dramatically reducing storage costs and operational complexity. It's designed to work seamlessly with Grafana and Prometheus.

As part of the unified observability stack, Loki works alongside Prometheus (metrics) and Tempo (traces), with all data visualized in Grafana. Applications instrumented with OpenTelemetry send logs to the OTLP Collector, which forwards them to Loki for storage and querying.

**Key Capabilities**:
- **Label-Based Indexing**: Like Prometheus but for logs - indexes labels, not full text
- **LogQL**: Familiar PromQL-like query syntax for powerful log filtering
- **OTLP Native**: Ingests logs from OpenTelemetry Collector
- **Structured Metadata**: Supports structured data extraction from logs
- **Low Cost**: Minimal storage overhead (no full-text indexing)
- **Grafana Integration**: Native datasource with Explore and dashboard support
- **Retention Management**: Automatic log expiration via compactor

**Architecture Type**: Distributed log aggregation with label indexing

## 🏗️ Architecture

### **Deployment Components**
```
┌──────────────────────────────────────────────────────┐
│           Loki Stack (namespace: monitoring)         │
│              SingleBinary Deployment Mode            │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │            Loki SingleBinary               │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Ingester (Write Path)               │ │    │
│  │  │  - OTLP Receiver (via OTLP Collector)│ │    │
│  │  │  - Label Extraction                  │ │    │
│  │  │  - Chunk Creation                    │ │    │
│  │  │  - WAL Persistence                   │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Querier (Read Path)                 │ │    │
│  │  │  - LogQL Engine                      │ │    │
│  │  │  - Label Matching                    │ │    │
│  │  │  - Stream Filtering                  │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Compactor                           │ │    │
│  │  │  - Retention Management (24h)        │ │    │
│  │  │  - Chunk Compaction                  │ │    │
│  │  │  - Index Cleanup                     │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Storage (10Gi PVC)                  │ │    │
│  │  │  - TSDB Index (/var/loki/tsdb-index) │ │    │
│  │  │  - Log Chunks (/var/loki/chunks)     │ │    │
│  │  │  - WAL (/var/loki/wal)               │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  HTTP API: 3100   gRPC: 9095              │    │
│  └────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
         ▲                          │
         │                          ▼
┌──────────────────┐    ┌──────────────────────┐
│ OTLP Collector   │    │   Grafana Query      │
│ (Log Export)     │    │   (LogQL/HTTP)       │
└──────────────────┘    └──────────────────────┘
```

### **Data Flow**
```
Application Logs (OTLP instrumented)
         │
         │ OTLP/HTTP
         ▼
┌──────────────────────┐
│  OTLP Collector      │
│  (Log Receiver)      │
└──────────────────────┘
         │
         │ Loki Push API
         ▼
┌──────────────────────┐
│   Loki Ingester      │
│   (3100/loki/api/v1) │
├──────────────────────┤
│ 1. Extract labels    │
│ 2. Create chunks     │
│ 3. Index metadata    │
│ 4. Store to disk     │
└──────────────────────┘
         │
         ├─► TSDB Index (labels)
         ├─► Log Chunks (content)
         └─► WAL (write-ahead log)
                  │
                  ▼
         ┌──────────────────┐
         │  Query API       │
         │  (LogQL Engine)  │
         └──────────────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  Grafana Explore │
         │  (LogQL Query)   │
         └──────────────────┘
```

### **File Structure**
```
manifests/
└── 032-loki-config.yaml                    # Loki Helm values

ansible/playbooks/
├── 032-setup-loki.yml                      # Deployment automation
└── 032-remove-loki.yml                     # Removal automation

provision-host/kubernetes/11-monitoring/not-in-use/
├── 03-setup-loki.sh                        # Shell script wrapper
└── 03-remove-loki.sh                       # Removal script

Storage:
└── PersistentVolumeClaim
    └── loki (10Gi)                         # Chunks + Index + WAL
```

## 🚀 Deployment

### **Automated Deployment**

**Via Monitoring Stack** (Recommended):
```bash
# Deploy entire monitoring stack (includes Loki)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./00-setup-all-monitoring.sh rancher-desktop
```

**Individual Deployment**:
```bash
# Deploy Loki only
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./03-setup-loki.sh rancher-desktop
```

### **Manual Deployment**

**Prerequisites**:
- Kubernetes cluster running (Rancher Desktop)
- `monitoring` namespace exists
- Helm installed in provision-host container
- Manifest file: `manifests/032-loki-config.yaml`

**Deployment Steps**:
```bash
# 1. Enter provision-host container
docker exec -it provision-host bash

# 2. Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Deploy Loki
helm upgrade --install loki grafana/loki \
  -f /mnt/urbalurbadisk/manifests/032-loki-config.yaml \
  --namespace monitoring \
  --create-namespace \
  --timeout 600s \
  --kube-context rancher-desktop

# 4. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=loki \
  -n monitoring --timeout=300s
```

**Deployment Time**: ~2-3 minutes

## ⚙️ Configuration

### **Loki Configuration** (`manifests/032-loki-config.yaml`)

**Deployment Mode**:
```yaml
deploymentMode: SingleBinary          # Simplified deployment (all components in one pod)
```

**Core Settings**:
```yaml
loki:
  auth_enabled: false                 # No authentication (cluster-internal only)

  limits_config:
    allow_structured_metadata: true   # Enable structured log data
    retention_period: 24h             # Log retention period
    ingestion_rate_mb: 10             # Max ingestion rate per stream
    max_streams_per_user: 0           # Unlimited streams
    max_line_size: 256000             # Max log line size (256KB)

  schemaConfig:
    configs:
      - from: "2024-01-01"
        schema: v13                   # TSDB schema version
        store: tsdb                   # Time-series database indexing
        object_store: filesystem      # Local filesystem storage
```

**Key Configuration Sections**:

**1. Retention & Compaction**:
```yaml
loki:
  compactor:
    retention_enabled: true
    retention_delete_delay: 2h        # Grace period before deletion
    compaction_interval: 10m          # Compact chunks every 10 minutes

  limits_config:
    retention_period: 24h             # Logs older than 24h are deleted
```

**Official Retention Docs**: https://grafana.com/docs/loki/v3.5.x/operations/storage/retention/

**2. Ingester (Write Path)**:
```yaml
loki:
  ingester:
    chunk_idle_period: 5m             # Flush chunks after 5m idle
    chunk_retain_period: 30s          # Retain in memory for 30s
    wal:
      dir: /var/loki/wal              # Write-ahead log location
```

**3. Schema & Storage**:
```yaml
loki:
  schemaConfig:
    configs:
      - from: "2024-01-01"
        index:
          period: 24h                 # Daily index rotation
          prefix: index_
        schema: v13                   # TSDB schema (recommended)
        store: tsdb

  storage_config:
    filesystem:
      directory: /var/loki/chunks
    tsdb_shipper:
      active_index_directory: /var/loki/tsdb-index
      cache_location: /var/loki/tsdb-cache
```

**Official Schema Config Docs**: https://grafana.com/docs/loki/v3.5.x/configure/#schema_config

**4. OTLP Integration**:
Loki receives logs from the OTLP Collector, which translates OTLP log format to Loki's push API format.

**OTLP Collector → Loki Flow**:
```yaml
# In OTLP Collector config (manifests/033-otel-collector-config.yaml)
exporters:
  loki:
    endpoint: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push
```

**Official OTLP Integration Guide**: https://grafana.com/docs/loki/latest/send-data/otel/

### **Resource Configuration**

**Storage Requirements**:
- **Loki PVC**: 10Gi persistent volume (24-hour retention)
- **Estimated Usage**: Depends on log volume (typically 1-5GB per million log lines)

**Service Endpoints**:
- **HTTP API**: `loki.monitoring.svc.cluster.local:3100`
- **gRPC**: `loki.monitoring.svc.cluster.local:9095`
- **Ready Check**: `loki.monitoring.svc.cluster.local:3100/ready`
- **Metrics**: `loki.monitoring.svc.cluster.local:3100/metrics`

### **Security Configuration**

**Network Access**:
```yaml
# Internal cluster access only (no IngressRoute)
service:
  type: ClusterIP
```

**Authentication**: Disabled (`auth_enabled: false`) - Loki is accessed only from within the cluster via Grafana and OTLP Collector.

## 🔍 Monitoring & Verification

### **Health Checks**

**Check Pod Status**:
```bash
# All Loki pods
kubectl get pods -n monitoring | grep loki

# Expected output (3 pods total):
NAME                              READY   STATUS    RESTARTS   AGE
loki-0                            2/2     Running   0          5m     # Main Loki server (SingleBinary mode) + promtail sidecar
loki-canary-xxx                   1/1     Running   0          5m     # Loki canary for synthetic log testing
loki-gateway-xxx                  1/1     Running   0          5m     # NGINX gateway for load balancing/routing
```

**Pod Descriptions**:
- **loki-0**: Main Loki server running in SingleBinary mode (all components: ingester, querier, compactor) + promtail sidecar for collecting Loki's own logs
- **loki-canary**: Synthetic log generator that continuously writes and reads test logs to verify Loki is functioning correctly
- **loki-gateway**: NGINX reverse proxy that routes requests to Loki components (provides load balancing and unified HTTP endpoint)

**Check Service Endpoints**:
```bash
# Verify service is accessible
kubectl get svc -n monitoring -l app.kubernetes.io/name=loki

# Expected services:
loki           ClusterIP   10.43.x.x    3100/TCP,9095/TCP
loki-headless  ClusterIP   None         3100/TCP
```

### **Service Verification**

**Test Ready Endpoint**:
```bash
# Check if Loki is ready to receive logs
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/ready

# Expected: ready (HTTP 200)
```

**Test Labels API**:
```bash
# List all label names
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels

# Expected: JSON array of label names
```

**Test Label Values**:
```bash
# Get values for a specific label (e.g., service_name)
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/label/service_name/values

# Expected: JSON array of service names
```

### **Query API Testing**

**Simple LogQL Query**:
```bash
# Query logs from last hour
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s -G http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="sovdev-test-company-lookup-typescript"}' \
  --data-urlencode 'start=1h'

# Expected: JSON response with log streams
```

### **Automated Verification**

The deployment playbook (`032-setup-loki.yml`) performs automated tests:
1. ✅ Ready endpoint verification
2. ✅ Metrics endpoint check
3. ✅ Labels API validation
4. ✅ Query range API test

## 🛠️ Management Operations

### **Query Logs in Grafana**

**Access Grafana**:
```bash
# Open Grafana UI
http://grafana.localhost
```

**Explore Logs**:
1. Navigate to **Explore** → Select **Loki** datasource
2. Choose builder or code mode
3. Run LogQL queries

**LogQL Query Examples**:
```logql
# All logs from a service
{service_name="sovdev-test-company-lookup-typescript"}

# Filter by log level
{service_name="my-app"} |= "error"

# JSON field extraction
{service_name="my-app"} | json | level="error"

# Regex pattern matching
{service_name=~"sovdev-test.*"}

# Count log lines per minute
rate({service_name="my-app"}[1m])

# Parse and filter structured logs
{service_name="my-app"}
  | json
  | functionName="lookup"
  | correlationId!=""
```

**Official LogQL Documentation**: https://grafana.com/docs/loki/v3.5.x/query/

### **Common LogQL Patterns**

**Error Investigation**:
```logql
# Find errors in last hour
{service_name="my-app"} |= "error"

# Count errors by service
sum by (service_name) (rate({job="otlp"} |= "error" [5m]))
```

**Performance Analysis**:
```logql
# Slow requests (duration > 1s)
{service_name="my-app"}
  | json
  | duration > 1000

# Request rate by endpoint
sum by (endpoint) (rate({service_name="api"}[1m]))
```

**Correlation with Traces**:
```logql
# Find logs for specific trace
{service_name="my-app"}
  | json
  | trace_id="abc123"
```

### **Metrics Monitoring**

**Loki Self-Monitoring**:
```bash
# Get Loki internal metrics
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/metrics | grep loki
```

**Key Metrics** (via Prometheus):
```promql
# Ingested log lines per second
rate(loki_distributor_lines_received_total[5m])

# Ingested bytes per second
rate(loki_distributor_bytes_received_total[5m])

# Query latency (P95)
histogram_quantile(0.95, rate(loki_request_duration_seconds_bucket[5m]))

# Active streams
loki_ingester_streams

# Storage size (chunks)
loki_ingester_chunk_stored_bytes_total
```

### **Service Removal**

**Automated Removal**:
```bash
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./03-remove-loki.sh rancher-desktop
```

**Manual Removal**:
```bash
# Remove Helm chart
helm uninstall loki -n monitoring --kube-context rancher-desktop

# Remove PVC (optional - preserves data if omitted)
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=loki
```

## 🔧 Troubleshooting

### **Common Issues**

**Pods Not Starting**:
```bash
# Check pod events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki

# Common causes:
# - PVC binding issues (check PV availability)
# - Insufficient resources (check node capacity)
# - Configuration errors (check loki logs)
```

**No Logs Appearing**:
```bash
# 1. Check OTLP Collector is sending logs to Loki
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep loki

# 2. Check Loki ingestion logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki -c loki | grep -i "ingester\|distributor"

# 3. Verify OTLP Collector Loki exporter configuration
kubectl get configmap -n monitoring otel-collector-opentelemetry-collector -o yaml | grep -A 10 "loki"

# Expected: Loki endpoint at loki.monitoring.svc.cluster.local:3100
```

**Query Failures**:
```bash
# Check Loki query logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki -c loki | grep -i "query\|error"

# Test query API directly
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels
```

**High Memory Usage**:
```bash
# Check memory usage
kubectl top pod -n monitoring -l app.kubernetes.io/name=loki

# Solutions:
# 1. Reduce ingestion_rate_mb in manifests/032-loki-config.yaml
# 2. Lower max_streams_per_user
# 3. Decrease chunk_idle_period (flush more frequently)
# 4. Reduce retention_period (24h → 12h)
```

**Storage Full**:
```bash
# Check PVC usage
kubectl get pvc -n monitoring -l app.kubernetes.io/name=loki

# Check storage metrics
kubectl exec -n monitoring loki-0 -c loki -- df -h /var/loki

# Solutions:
# 1. Reduce retention period in manifests/032-loki-config.yaml
# 2. Increase PVC size
# 3. Enable compaction (already enabled by default)
```

**Label Cardinality Issues**:
```bash
# Check active streams (high = potential cardinality explosion)
kubectl logs -n monitoring -l app.kubernetes.io/name=loki -c loki | grep "streams"

# Inspect label combinations
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/labels

# Solutions:
# 1. Reduce number of indexed labels in OTLP Collector config
# 2. Use structured metadata instead of labels for high-cardinality data
# 3. Set max_streams_per_user limit
```

**Official Troubleshooting Guide**: https://grafana.com/docs/loki/v3.5.x/operations/troubleshooting/

## 📋 Maintenance

### **Regular Tasks**

**Monitor Storage Usage**:
```bash
# Check PVC status
kubectl get pvc -n monitoring -l app.kubernetes.io/name=loki

# Check storage metrics via Prometheus
kubectl port-forward -n monitoring svc/loki 3100:3100
curl -s http://localhost:3100/metrics | grep loki_ingester_chunk_stored_bytes
```

**Update Loki**:
```bash
# Update Helm chart to latest version
helm repo update
helm upgrade loki grafana/loki \
  -f /mnt/urbalurbadisk/manifests/032-loki-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop
```

**Cleanup Old Logs** (automatic):
```yaml
# Retention handled automatically via compactor
loki:
  compactor:
    retention_enabled: true
  limits_config:
    retention_period: 24h  # Logs older than 24h are deleted
```

### **Backup Procedures**

**Snapshot Log Data**:
```bash
# Export PVC data
kubectl exec -n monitoring loki-0 -c loki -- \
  tar czf /tmp/loki-backup.tar.gz /var/loki

# Copy to local machine
kubectl cp monitoring/loki-0:/tmp/loki-backup.tar.gz \
  ./loki-backup.tar.gz -c loki
```

**Note**: Loki is designed for ephemeral log storage with short retention (24h). Long-term log archival is not a primary use case.

### **Disaster Recovery**

**Restore from Backup**:
```bash
# 1. Remove existing deployment
./03-remove-loki.sh rancher-desktop

# 2. Restore PVC data (requires direct PV access)
# 3. Redeploy Loki
./03-setup-loki.sh rancher-desktop
```

**Data Loss Scenarios**:
- **PVC deleted**: Logs are lost (acceptable - 24h retention means limited impact)
- **Corruption**: Loki auto-repairs WAL on startup
- **Retention expired**: Expected behavior, increase retention if needed

## 🚀 Use Cases

### **1. Application Logging with OTLP**

**sovdev-logger Integration**:
```typescript
// TypeScript application using @sovdev/logger
import { initializeSovdevLogger } from '@sovdev/logger';

// Initialize logger (sends to OTLP Collector)
initializeSovdevLogger('my-service-name');

// Environment configuration
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

**Query in Grafana**:
```logql
{service_name="my-service-name"}
```

### **2. Error Tracking**

**Find Errors**:
```logql
# All errors
{service_name="my-app"} |= "error"

# Parse JSON and filter by level
{service_name="my-app"} | json | level="error"

# Count errors per minute
sum(rate({service_name="my-app"} |= "error" [1m]))
```

**Alert on Errors** (via Grafana):
```logql
# Alert if error rate > 10/min
sum(rate({job="otlp"} |= "error" [1m])) > 10
```

### **3. Log Correlation with Traces**

**Find logs for a trace**:
```logql
# Using trace_id from Tempo
{service_name="my-app"}
  | json
  | trace_id="abc123def456"
```

**Grafana Workflow**:
1. Find slow trace in Tempo
2. Copy `trace_id` from trace details
3. Switch to Loki datasource
4. Query logs with `trace_id` filter
5. View correlated logs and trace spans together

### **4. Performance Analysis**

**Find Slow Requests**:
```logql
# Parse duration from JSON logs
{service_name="api"}
  | json
  | duration > 1000  # >1 second

# Histogram of request durations
histogram_quantile(0.95,
  sum(rate({service_name="api"} | json | unwrap duration [5m]))
  by (le)
)
```

---

**💡 Key Insight**: Loki's "index labels, not content" design makes it extremely cost-effective for cloud-native log aggregation. By indexing only metadata and using LogQL for content filtering at query time, Loki provides powerful log analysis capabilities without the operational burden and storage costs of traditional full-text indexing solutions. When integrated with OTLP Collector for ingestion and Grafana for visualization, Loki completes the observability triangle alongside Prometheus (metrics) and Tempo (traces).

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[Prometheus Metrics](./package-monitoring-prometheus.md)** - Metrics collection
- **[Tempo Tracing](./package-monitoring-tempo.md)** - Distributed tracing
- **[OTLP Collector](./package-monitoring-otel.md)** - Telemetry pipeline (log ingestion)
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Dashboards and log exploration

**Configuration & Rules**:
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest numbering (032)
- **[Development Workflow](./rules-development-workflow.md)** - Configuration management
- **[Automated Deployment](./rules-automated-kubernetes-deployment.md)** - Orchestration

**External Resources**:
- **LogQL Language**: https://grafana.com/docs/loki/v3.5.x/query/
- **OTLP Integration**: https://grafana.com/docs/loki/latest/send-data/otel/
- **Retention Configuration**: https://grafana.com/docs/loki/v3.5.x/operations/storage/retention/
- **Schema Config**: https://grafana.com/docs/loki/v3.5.x/configure/#schema_config
