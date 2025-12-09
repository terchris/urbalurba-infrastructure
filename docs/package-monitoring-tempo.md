# Tempo - Distributed Tracing Backend

**Key Features**: Distributed Tracing • OTLP Protocol • gRPC & HTTP Endpoints • TraceQL Queries • Cost-Effective Storage • Jaeger/Zipkin Compatible • Multi-Tenancy

**File**: `docs/package-monitoring-tempo.md`
**Purpose**: Complete guide to Tempo deployment and configuration for distributed tracing in Urbalurba infrastructure
**Target Audience**: DevOps engineers, platform administrators, SREs, developers
**Last Updated**: October 3, 2025

**Deployed Version**: Tempo v2.8.2 (Helm Chart: tempo-1.23.3)
**Official Documentation**: https://grafana.com/docs/tempo/v2.8.x/

## 📋 Overview

Tempo is a **high-performance distributed tracing backend** designed for cloud-native applications. It provides cost-effective trace storage and powerful querying capabilities through TraceQL. Unlike traditional tracing backends, Tempo only indexes a small set of metadata, dramatically reducing storage and operational costs.

As part of the unified observability stack, Tempo works alongside Prometheus (metrics) and Loki (logs), with all data visualized in Grafana. Applications instrumented with OpenTelemetry send traces to the OTLP Collector, which forwards them to Tempo for storage and querying.

**Key Capabilities**:
- **OTLP Native**: Primary ingestion via OpenTelemetry Collector (gRPC 4317, HTTP 4318)
- **TraceQL**: SQL-like query language for powerful trace filtering and analysis
- **Low Storage Cost**: Indexes only metadata, stores traces in efficient object storage format
- **Multi-Protocol**: Supports OTLP, Jaeger, and Zipkin protocols
- **Scalable Architecture**: Designed for high-volume trace ingestion
- **Grafana Integration**: Native datasource for trace visualization and exploration

**Architecture Type**: Append-only trace storage with metadata indexing

## 🏗️ Architecture

### **Deployment Components**
```
┌──────────────────────────────────────────────────────┐
│           Tempo Stack (namespace: monitoring)        │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │             Tempo Server                   │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  OTLP Receivers                      │ │    │
│  │  │  - gRPC: 4317                        │ │    │
│  │  │  - HTTP: 4318                        │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Trace Storage                       │ │    │
│  │  │  - Metadata Index                    │ │    │
│  │  │  - Trace Blocks (10Gi PVC)           │ │    │
│  │  │  - 24h Retention                     │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  │                                            │    │
│  │  ┌──────────────────────────────────────┐ │    │
│  │  │  Query APIs                          │ │    │
│  │  │  - HTTP API: 3200                    │ │    │
│  │  │  - TraceQL Engine                    │ │    │
│  │  │  - Search API                        │ │    │
│  │  └──────────────────────────────────────┘ │    │
│  └────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
         ▲                          │
         │                          ▼
┌──────────────────┐    ┌──────────────────────┐
│ OTLP Collector   │    │   Grafana Query      │
│ (Trace Export)   │    │   (TraceQL/HTTP)     │
└──────────────────┘    └──────────────────────┘
```

### **Data Flow**
```
Application (OTLP instrumented)
         │
         │ OTLP/HTTP or OTLP/gRPC
         ▼
┌──────────────────────┐
│  OTLP Collector      │
│  (Trace Receiver)    │
└──────────────────────┘
         │
         │ OTLP Export
         ▼
┌──────────────────────┐
│   Tempo Backend      │
│   (4317/4318)        │
├──────────────────────┤
│ - Receive traces     │
│ - Extract metadata   │
│ - Store trace blocks │
│ - Index for search   │
└──────────────────────┘
         │
         ├─► Persistent Storage (10Gi)
         └─► Query API (3200)
                  │
                  ▼
         ┌──────────────────┐
         │  Grafana Explore │
         │  (TraceQL Query) │
         └──────────────────┘
```

### **File Structure**
```
manifests/
└── 031-tempo-config.yaml                   # Tempo Helm values

ansible/playbooks/
├── 031-setup-tempo.yml                     # Deployment automation
└── 031-remove-tempo.yml                    # Removal automation

provision-host/kubernetes/11-monitoring/not-in-use/
├── 02-setup-tempo.sh                       # Shell script wrapper
└── 02-remove-tempo.sh                      # Removal script

Storage:
└── PersistentVolumeClaim
    └── tempo (10Gi)                        # Trace blocks storage
```

## 🚀 Deployment

### **Automated Deployment**

**Via Monitoring Stack** (Recommended):
```bash
# Deploy entire monitoring stack (includes Tempo)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./00-setup-all-monitoring.sh rancher-desktop
```

**Individual Deployment**:
```bash
# Deploy Tempo only
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./02-setup-tempo.sh rancher-desktop
```

### **Manual Deployment**

**Prerequisites**:
- Kubernetes cluster running (Rancher Desktop)
- `monitoring` namespace exists
- Helm installed in provision-host container
- Manifest file: `manifests/031-tempo-config.yaml`

**Deployment Steps**:
```bash
# 1. Enter provision-host container
docker exec -it provision-host bash

# 2. Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Deploy Tempo
helm upgrade --install tempo grafana/tempo \
  -f /mnt/urbalurbadisk/manifests/031-tempo-config.yaml \
  --namespace monitoring \
  --create-namespace \
  --timeout 600s \
  --kube-context rancher-desktop

# 4. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=tempo \
  -n monitoring --timeout=300s
```

**Deployment Time**: ~2-3 minutes

## ⚙️ Configuration

### **Tempo Configuration** (`manifests/031-tempo-config.yaml`)

**Core Settings**:
```yaml
tempo:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317    # OTLP gRPC receiver
        http:
          endpoint: 0.0.0.0:4318    # OTLP HTTP receiver

  retention: 24h                     # Trace retention period

persistence:
  enabled: true
  size: 10Gi                         # Trace block storage

service:
  type: ClusterIP                    # Internal cluster access only
```

**Key Configuration Sections**:

**1. OTLP Receivers** (Primary Ingestion):
```yaml
tempo:
  receivers:
    otlp:
      protocols:
        # Recommended for production (lower overhead)
        grpc:
          endpoint: 0.0.0.0:4317
        # Alternative for HTTP-only environments
        http:
          endpoint: 0.0.0.0:4318
```

**2. Retention Policy**:
```yaml
tempo:
  retention: 24h                     # Traces older than 24h are deleted
```

**3. Storage Backend**:
```yaml
persistence:
  enabled: true
  size: 10Gi                         # Adjust based on trace volume
```

**4. Metrics Generator** (Automatic Service Graphs):
```yaml
tempo:
  metricsGenerator:
    enabled: true
    remoteWriteUrl: "http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write"

  structuredConfig:
    metrics_generator:
      registry:
        external_labels:
          source: tempo
      storage:
        path: /var/tempo/generator/wal
        remote_write:
          - url: http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write
            send_exemplars: true
      traces_storage:
        path: /var/tempo/generator/traces
      processor:
        service_graphs:
          dimensions:
            - service.name
            - peer.service
          histogram_buckets: [0.1, 0.2, 0.5, 1, 2, 5, 10]
        span_metrics:
          dimensions:
            - service.name
            - peer.service
            - log.type
    overrides:
      defaults:
        metrics_generator:
          processors: [service-graphs, span-metrics]
```

**Key Features**:
- **Service Graphs**: Automatically generate service dependency metrics from traces
- **Span Metrics**: Create Prometheus metrics for trace calls, latency, and errors
- **Remote Write**: Send generated metrics to Prometheus for visualization
- **Dimensions**: Track service.name, peer.service, and log.type for detailed filtering

**Generated Prometheus Metrics**:
- `traces_spanmetrics_calls_total` - Total calls between services
- `traces_spanmetrics_latency_bucket` - Latency histogram distribution
- `traces_spanmetrics_size_total` - Span size tracking

**Example Prometheus Queries**:
```promql
# Service dependency graph
traces_spanmetrics_calls_total{service_name="my-service"}

# Average latency between services
rate(traces_spanmetrics_latency_sum[1m]) / rate(traces_spanmetrics_latency_count[1m])

# Error rate by service
rate(traces_spanmetrics_calls_total{status_code="STATUS_CODE_ERROR"}[1m])
```

### **Resource Configuration**

**Storage Requirements**:
- **Tempo PVC**: 10Gi persistent volume (24-hour retention)
- **Estimated Usage**: ~400-500MB per million spans (varies by trace size)

**Service Endpoints**:
- **OTLP gRPC**: `tempo.monitoring.svc.cluster.local:4317`
- **OTLP HTTP**: `tempo.monitoring.svc.cluster.local:4318`
- **HTTP API**: `tempo.monitoring.svc.cluster.local:3200`
- **Ready Check**: `tempo.monitoring.svc.cluster.local:3200/ready`

### **Security Configuration**

**Network Access**:
```yaml
service:
  type: ClusterIP                    # Internal cluster access only
```

**No External Access**: Tempo is internal-only. Traces are sent via OTLP Collector, and queries are performed through Grafana.

## 🔍 Monitoring & Verification

### **Health Checks**

**Check Pod Status**:
```bash
# Tempo pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Expected output:
NAME        READY   STATUS    RESTARTS   AGE
tempo-0     1/1     Running   0          5m
```

**Check Service Endpoints**:
```bash
# Verify services are accessible
kubectl get svc -n monitoring -l app.kubernetes.io/name=tempo

# Expected services:
tempo        ClusterIP   10.43.x.x    3200/TCP,4317/TCP,4318/TCP
```

### **Service Verification**

**Test HTTP API**:
```bash
# Test API echo endpoint
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://tempo.monitoring.svc.cluster.local:3200/api/echo

# Expected: HTTP 200 response
```

**Test Ready Endpoint**:
```bash
# Check if Tempo is ready to receive traces
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://tempo.monitoring.svc.cluster.local:3200/ready

# Expected: HTTP 200 response
```

**Test OTLP Endpoints**:
```bash
# Test gRPC port accessibility
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v telnet://tempo.monitoring.svc.cluster.local:4317

# Test HTTP port accessibility
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s -o /dev/null -w "%{http_code}" \
  http://tempo.monitoring.svc.cluster.local:4318/
```

### **Search API Testing**

**Query Traces**:
```bash
# Test search API (returns trace metadata)
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s "http://tempo.monitoring.svc.cluster.local:3200/api/search"

# Expected: JSON response with traces/metrics
```

### **Automated Verification**

The deployment playbook (`031-setup-tempo.yml`) performs automated tests:
1. ✅ HTTP API endpoint connectivity
2. ✅ Ready endpoint verification
3. ✅ Metrics endpoint check
4. ✅ Search API validation
5. ✅ OTLP gRPC port accessibility
6. ✅ OTLP HTTP port accessibility

## 🛠️ Management Operations

### **Query Traces in Grafana**

**Access Grafana**:
```bash
# Open Grafana UI
http://grafana.localhost
```

**Explore Traces**:
1. Navigate to **Explore** → Select **Tempo** datasource
2. Choose query type:
   - **Search**: Find traces by service/operation
   - **TraceQL**: Use SQL-like queries
   - **Trace ID**: Lookup specific trace

**TraceQL Examples**:
```traceql
# Find traces with errors
{ status = error }

# Find slow traces (>1s duration)
{ duration > 1s }

# Find traces by service name
{ resource.service.name = "sovdev-test-company-lookup-typescript" }

# Complex query: slow traces with errors from specific service
{ resource.service.name =~ "sovdev.*" && status = error && duration > 1s }
```

**Official TraceQL Documentation**: https://grafana.com/docs/tempo/v2.8.x/traceql/

### **HTTP API Queries**

**Search for Traces**:
```bash
# Search by service name
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s "http://tempo.monitoring.svc.cluster.local:3200/api/search?q=service.name%3D%22my-service%22"
```

**Retrieve Trace by ID**:
```bash
# Get specific trace (replace TRACE_ID)
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s "http://tempo.monitoring.svc.cluster.local:3200/api/traces/TRACE_ID"
```

### **Metrics Monitoring**

**Tempo Self-Monitoring**:
```bash
# Get Tempo internal metrics
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://tempo.monitoring.svc.cluster.local:3200/metrics | grep tempo
```

**Key Metrics** (via Prometheus):
```promql
# Ingested spans per second
rate(tempo_ingester_spans_ingested_total[5m])

# Trace queries per second
rate(tempo_query_frontend_queries_total[5m])

# Storage bytes used
tempo_ingester_bytes_total
```

### **Service Removal**

**Automated Removal**:
```bash
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./02-remove-tempo.sh rancher-desktop
```

**Manual Removal**:
```bash
# Remove Helm chart
helm uninstall tempo -n monitoring --kube-context rancher-desktop

# Remove PVC (optional - preserves data if omitted)
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=tempo
```

## 🔧 Troubleshooting

### **Common Issues**

**Pods Not Starting**:
```bash
# Check pod events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=tempo

# Common causes:
# - PVC binding issues (check PV availability)
# - Insufficient resources (check node capacity)
# - Image pull errors (check network)
```

**No Traces Appearing**:
```bash
# 1. Check OTLP Collector is sending traces to Tempo
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep tempo

# 2. Check Tempo ingestion logs
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo | grep -i "trace\|span"

# 3. Verify OTLP Collector configuration
kubectl get configmap -n monitoring otel-collector-opentelemetry-collector -o yaml | grep -A 10 "tempo"

# Expected: Tempo endpoint at tempo.monitoring.svc.cluster.local:4317
```

**Trace Query Failures**:
```bash
# Check Tempo query logs
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo | grep -i error

# Test search API directly
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v "http://tempo.monitoring.svc.cluster.local:3200/api/search"
```

**Storage Full**:
```bash
# Check PVC usage
kubectl get pvc -n monitoring

# Check trace block size via metrics
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl -s http://localhost:3200/metrics | grep tempo_ingester_bytes

# Solutions:
# 1. Reduce retention period in manifests/031-tempo-config.yaml
# 2. Increase PVC size
# 3. Reduce trace sampling rate at application level
```

**OTLP Ingestion Errors**:
```bash
# Check if Tempo is accepting OTLP traces
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo | grep -i "otlp\|grpc\|http"

# Test OTLP HTTP endpoint
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -X POST -v http://tempo.monitoring.svc.cluster.local:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected: 400 or 405 (endpoint is reachable, empty payload rejected)
```

## 📋 Maintenance

### **Regular Tasks**

**Monitor Storage Usage**:
```bash
# Check PVC status
kubectl get pvc -n monitoring -l app.kubernetes.io/name=tempo

# Check storage metrics
kubectl port-forward -n monitoring svc/tempo 3200:3200
curl -s http://localhost:3200/metrics | grep tempo_ingester_blocks_total
```

**Update Tempo**:
```bash
# Update Helm chart to latest version
helm repo update
helm upgrade tempo grafana/tempo \
  -f /mnt/urbalurbadisk/manifests/031-tempo-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop
```

**Cleanup Old Traces** (automatic):
```yaml
# Retention handled automatically via tempo.retention setting
tempo:
  retention: 24h  # Traces older than 24 hours are purged
```

### **Backup Procedures**

**Snapshot Trace Blocks**:
```bash
# Export PVC data
kubectl exec -n monitoring tempo-0 -- \
  tar czf /tmp/tempo-backup.tar.gz /var/tempo

# Copy to local machine
kubectl cp monitoring/tempo-0:/tmp/tempo-backup.tar.gz \
  ./tempo-backup.tar.gz
```

**Note**: Tempo is designed as ephemeral storage with short retention. Long-term trace archival is not a primary use case.

### **Disaster Recovery**

**Restore from Backup**:
```bash
# 1. Remove existing deployment
./02-remove-tempo.sh rancher-desktop

# 2. Restore PVC data (requires direct PV access)
# 3. Redeploy Tempo
./02-setup-tempo.sh rancher-desktop
```

**Data Loss Scenarios**:
- **PVC deleted**: Traces are lost (not critical - 24h retention means limited impact)
- **Corruption**: Tempo auto-repairs blocks on startup
- **Retention expired**: Expected behavior, adjust retention if needed

## 🚀 Use Cases

### **1. Application Tracing with OpenTelemetry**

**Instrument Application** (example with Go):
```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
)

// Configure OTLP exporter to send to OTLP Collector
exporter, _ := otlptracehttp.New(ctx,
    otlptracehttp.WithEndpoint("otel.localhost"),
    otlptracehttp.WithURLPath("/v1/traces"),
    otlptracehttp.WithHeaders(map[string]string{
        "Host": "otel.localhost",
    }),
)
```

**Environment Configuration**:
```bash
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://127.0.0.1/v1/traces
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

**Query in Grafana**:
```traceql
{ resource.service.name = "my-app" }
```

### **2. Correlate Logs and Traces**

**sovdev-logger Integration**:
```typescript
// TypeScript application with sovdev-logger
import { initializeSovdevLogger } from '@sovdev/logger';

// Logs include trace_id and span_id for correlation
logger.info("Processing request", {
    trace_id: context.traceId,
    span_id: context.spanId
});
```

**Grafana Workflow**:
1. Find trace in Tempo with TraceQL
2. Note `trace_id` from trace details
3. Switch to Loki datasource
4. Query logs: `{service_name="my-app"} | json | trace_id="TRACE_ID"`
5. View correlated logs and traces together

### **3. Performance Analysis**

**Find Slow Requests**:
```traceql
# Traces slower than 2 seconds
{ duration > 2s }

# Group by service
{ duration > 2s } | group by resource.service.name
```

**Analyze Bottlenecks**:
1. Query slow traces in Grafana Explore
2. View trace waterfall/flamegraph
3. Identify slow spans (database queries, API calls, etc.)
4. Optimize identified bottlenecks

### **4. Error Investigation**

**Find Failed Requests**:
```traceql
# Traces with errors
{ status = error }

# Errors from specific service in last hour
{ resource.service.name = "api-service" && status = error }
```

**Debug Workflow**:
1. Find error traces with TraceQL
2. Examine trace details and span attributes
3. Correlate with logs (trace_id)
4. Identify root cause from span data

---

**💡 Key Insight**: Tempo's design philosophy is "store everything, index nothing (except metadata)". This approach dramatically reduces costs while enabling powerful trace analysis through TraceQL. When integrated with OTLP Collector for ingestion and Grafana for visualization, Tempo provides complete distributed tracing capabilities for microservices architectures without the operational complexity of traditional tracing backends.

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[Prometheus Metrics](./package-monitoring-prometheus.md)** - Metrics collection
- **[Loki Logs](./package-monitoring-loki.md)** - Log aggregation
- **[OTLP Collector](./package-monitoring-otel.md)** - Telemetry pipeline (trace ingestion)
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Dashboards and trace exploration

**Configuration & Rules**:
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest numbering (031)
- **[Development Workflow](./rules-development-workflow.md)** - Configuration management
- **[Automated Deployment](./rules-automated-kubernetes-deployment.md)** - Orchestration

**External Resources**:
- **TraceQL Language**: https://grafana.com/docs/tempo/v2.8.x/traceql/
- **OTLP Specification**: https://opentelemetry.io/docs/specs/otlp/
- **Tempo Configuration**: https://grafana.com/docs/tempo/v2.8.x/configuration/
