# Prometheus - Metrics Collection & Alerting

**Key Features**: Time-Series Database • PromQL Query Language • Service Discovery • Multi-Dimensional Data • Alertmanager • Pushgateway • Node Exporter • Kube-State-Metrics

**File**: `docs/package-monitoring-prometheus.md`
**Purpose**: Complete guide to Prometheus deployment and configuration for metrics monitoring in Urbalurba infrastructure
**Target Audience**: DevOps engineers, platform administrators, SREs, developers
**Last Updated**: October 3, 2025

**Deployed Version**: Prometheus v3.6.0 (Helm Chart: prometheus-27.39.0)
**Official Documentation**: https://prometheus.io/docs/prometheus/3.6/

## 📋 Overview

Prometheus is the **primary metrics backend** in the Urbalurba monitoring stack. It provides time-series data storage, powerful querying capabilities, and automated service discovery for Kubernetes environments. Prometheus implements a pull-based model, actively scraping metrics from instrumented applications and exporters.

As part of the unified observability stack, Prometheus works alongside Tempo (traces) and Loki (logs), with all data visualized in Grafana.

**Key Capabilities**:
- **Time-Series Database**: Efficient storage of metrics with configurable retention (15 days default)
- **PromQL**: Powerful query language for metrics analysis and alerting
- **Service Discovery**: Automatic discovery of Kubernetes services via ServiceMonitor CRDs
- **Multi-Dimensional Data**: Label-based data model for flexible querying
- **Remote Write**: Accepts metrics from OpenTelemetry Collector
- **Built-in Exporters**: Node metrics, Kubernetes state, push gateway for batch jobs

**Architecture Type**: Pull-based metrics collector with time-series database and alerting

## 🏗️ Architecture

### **Deployment Components**
```
┌─────────────────────────────────────────────────────────┐
│              Prometheus Stack (namespace: monitoring)   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────┐    ┌──────────────────┐         │
│  │ Prometheus Server│    │   Alertmanager   │         │
│  │                  │    │                  │         │
│  │ - Metrics Storage│    │ - Alert Routing  │         │
│  │ - PromQL Engine  │    │ - Deduplication  │         │
│  │ - Scraping       │◄───┤ - Notifications  │         │
│  │ - Remote Write   │    │                  │         │
│  └────────┬─────────┘    └──────────────────┘         │
│           │                                            │
│           │ Scrapes Metrics                            │
│           ▼                                            │
│  ┌──────────────────┐    ┌──────────────────┐         │
│  │  Node Exporter   │    │ Kube-State-Metrics│        │
│  │                  │    │                  │         │
│  │ - Host Metrics   │    │ - K8s Objects    │         │
│  │ - CPU/Memory     │    │ - Deployments    │         │
│  │ - Disk I/O       │    │ - Pods/Services  │         │
│  │ - Network        │    │ - ConfigMaps     │         │
│  └──────────────────┘    └──────────────────┘         │
│                                                         │
│  ┌──────────────────┐    ┌──────────────────┐         │
│  │   Pushgateway    │    │ ServiceMonitor   │         │
│  │                  │    │    Discovery     │         │
│  │ - Batch Jobs     │    │                  │         │
│  │ - Ephemeral      │    │ - Auto Scraping  │         │
│  │ - Push Metrics   │    │ - Label Config   │         │
│  └──────────────────┘    └──────────────────┘         │
└─────────────────────────────────────────────────────────┘
         │                          │
         ▼                          ▼
┌──────────────────┐    ┌──────────────────────┐
│  Grafana Query   │    │ OTLP Collector Push  │
│                  │    │  (Remote Write API)  │
└──────────────────┘    └──────────────────────┘
```

### **Data Flow**
```
Application Metrics (Prometheus format)
         │
         │ HTTP Scrape (Pull)
         ▼
  ┌──────────────┐
  │  Prometheus  │
  │    Server    │
  └──────────────┘
         │
         ├─► Time-Series Storage (15d retention)
         ├─► PromQL Evaluation
         ├─► Alerting Rules
         └─► Grafana Datasource

OTLP Collector (Metrics)
         │
         │ Remote Write (Push)
         ▼
  ┌──────────────┐
  │  Prometheus  │
  │    Server    │
  └──────────────┘
```

### **File Structure**
```
manifests/
└── 030-prometheus-config.yaml              # Prometheus Helm values

ansible/playbooks/
├── 030-setup-prometheus.yml                # Deployment automation
└── 030-remove-prometheus.yml               # Removal automation

provision-host/kubernetes/11-monitoring/not-in-use/
├── 01-setup-prometheus.sh                  # Shell script wrapper
└── 01-remove-prometheus.sh                 # Removal script

Storage:
└── PersistentVolumeClaim
    ├── prometheus-server (8Gi)             # Metrics storage
    └── prometheus-alertmanager (2Gi)       # Alert state
```

## 🚀 Deployment

### **Automated Deployment**

**Via Monitoring Stack** (Recommended):
```bash
# Deploy entire monitoring stack (includes Prometheus)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./00-setup-all-monitoring.sh rancher-desktop
```

**Individual Deployment**:
```bash
# Deploy Prometheus only
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./01-setup-prometheus.sh rancher-desktop
```

### **Manual Deployment**

**Prerequisites**:
- Kubernetes cluster running (Rancher Desktop)
- `monitoring` namespace exists
- Helm installed in provision-host container
- Manifest file: `manifests/030-prometheus-config.yaml`

**Deployment Steps**:
```bash
# 1. Enter provision-host container
docker exec -it provision-host bash

# 2. Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 3. Deploy Prometheus
helm upgrade --install prometheus prometheus-community/prometheus \
  -f /mnt/urbalurbadisk/manifests/030-prometheus-config.yaml \
  --namespace monitoring \
  --create-namespace \
  --timeout 600s \
  --kube-context rancher-desktop

# 4. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=prometheus \
  -l app.kubernetes.io/component=server \
  -n monitoring --timeout=300s
```

**Deployment Time**: ~2-3 minutes

## ⚙️ Configuration

### **Prometheus Configuration** (`manifests/030-prometheus-config.yaml`)

**Core Settings**:
```yaml
server:
  retention: 15d                    # Metrics retention period
  persistentVolume:
    enabled: true
    size: 8Gi                       # Storage for time-series data
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  extraArgs:
    web.enable-remote-write-receiver: ""  # REQUIRED: Enables /api/v1/write endpoint for OTLP Collector
```

**Key Configuration Sections**:

**1. Alertmanager** (Alert Processing):
```yaml
alertmanager:
  enabled: true
  persistentVolume:
    enabled: true
    size: 2Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
```

**2. Node Exporter** (Host Metrics):
```yaml
nodeExporter:
  enabled: true
  hostNetwork: false                # Use pod network
```

**3. Pushgateway** (Batch Job Metrics):
```yaml
pushgateway:
  enabled: true
  persistentVolume:
    enabled: false                  # Ephemeral storage
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
```

**4. Kube-State-Metrics** (Kubernetes Objects):
```yaml
kubeStateMetrics:
  enabled: true                     # Pod/Deployment/Service metrics
```

**5. ServiceMonitor** (Auto-Discovery):
```yaml
serviceMonitors:
  enabled: true                     # Automatic service discovery
```

### **Resource Configuration**

**Storage Requirements**:
- **Prometheus Server**: 8Gi persistent volume (15-day retention)
- **Alertmanager**: 2Gi persistent volume (alert state)
- **Pushgateway**: No persistence (ephemeral metrics)

**Memory & CPU**:
- **Server**: 512Mi request, 1Gi limit / 200m CPU request, 500m limit
- **Alertmanager**: 128Mi request, 256Mi limit / 100m CPU request, 200m limit
- **Pushgateway**: 64Mi request, 128Mi limit / 50m CPU request, 100m limit

### **Security Configuration**

**Network Access**:
```yaml
# Internal cluster access only (no IngressRoute by default)
Service: prometheus-server.monitoring.svc.cluster.local:80
```

**Optional External Access**:
```bash
# Port forwarding for local development
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Access at: http://localhost:9090
```

## 🔍 Monitoring & Verification

### **Health Checks**

**Check Pod Status**:
```bash
# All Prometheus components
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Expected output (5 pods total):
NAME                                               READY   STATUS
prometheus-server-xxx                              2/2     Running    # Main Prometheus server + config reloader
prometheus-alertmanager-xxx                        1/1     Running    # Alert processing and routing
prometheus-kube-state-metrics-xxx                  1/1     Running    # Kubernetes object metrics
prometheus-prometheus-node-exporter-xxx            1/1     Running    # Host/node metrics (CPU, memory, disk)
prometheus-prometheus-pushgateway-xxx              1/1     Running    # Batch job metrics receiver
```

**Pod Descriptions**:
- **prometheus-server**: Main Prometheus server (scraping, storage, querying) + config-reload sidecar
- **prometheus-alertmanager**: Processes and routes alerts to notification channels
- **prometheus-kube-state-metrics**: Exposes Kubernetes object state as Prometheus metrics (pods, deployments, services)
- **prometheus-prometheus-node-exporter**: DaemonSet that collects host-level metrics from the node (CPU, memory, disk I/O, network)
- **prometheus-prometheus-pushgateway**: Allows ephemeral/batch jobs to push metrics to Prometheus

**Check Service Endpoints**:
```bash
# Verify services are accessible
kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus

# Expected services:
prometheus-server                    ClusterIP   10.43.x.x    80/TCP
prometheus-alertmanager              ClusterIP   10.43.x.x    9093/TCP
prometheus-prometheus-pushgateway    ClusterIP   10.43.x.x    9091/TCP
prometheus-prometheus-node-exporter  ClusterIP   10.43.x.x    9100/TCP
```

### **Service Verification**

**Test Prometheus API**:
```bash
# Runtime info endpoint
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/status/runtimeinfo

# Expected: JSON response with runtime information
```

**Test Metrics Endpoint**:
```bash
# Prometheus self-monitoring metrics
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://prometheus-server.monitoring.svc.cluster.local:80/metrics | head -20
```

### **Data Ingestion Testing**

**Push Test Metric**:
```bash
# Push metric to Pushgateway
kubectl run prometheus-data-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  /bin/sh -c 'echo "test_metric 42" | curl -X POST --data-binary @- \
  http://prometheus-prometheus-pushgateway.monitoring.svc.cluster.local:9091/metrics/job/test/instance/test'
```

**Query Test Metric**:
```bash
# Wait 15 seconds for scrape interval
sleep 15

# Query Prometheus for the test metric
kubectl run prometheus-query --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s --data-urlencode 'query=test_metric' \
  "http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query"

# Expected: JSON response with "status":"success" and test_metric value
```

### **Automated Verification**

The deployment playbook (`030-setup-prometheus.yml`) performs automated tests:
1. ✅ Server API connectivity test
2. ✅ Metrics endpoint test
3. ✅ Pushgateway ingestion test
4. ✅ Query test metric verification

## 🛠️ Management Operations

### **Prometheus UI Access** (Development)

**Port Forwarding**:
```bash
# Forward Prometheus UI to localhost
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open browser
http://localhost:9090
```

**UI Features**:
- **Graph**: PromQL query and visualization
- **Alerts**: Active alerts and rules
- **Status**: Targets, service discovery, configuration
- **Metrics Explorer**: Browse available metrics

### **Common PromQL Queries**

**Node Metrics**:
```promql
# CPU usage by node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage
100 - (node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)
```

**Kubernetes Metrics**:
```promql
# Pod count by namespace
count by (namespace) (kube_pod_info)

# Deployment replicas
kube_deployment_status_replicas{deployment="prometheus-server"}

# Container restarts
kube_pod_container_status_restarts_total
```

**Prometheus Self-Monitoring**:
```promql
# Scrape duration
prometheus_target_interval_length_seconds

# Active time series
prometheus_tsdb_head_series

# Storage size
prometheus_tsdb_storage_blocks_bytes
```

### **Service Removal**

**Automated Removal**:
```bash
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./01-remove-prometheus.sh rancher-desktop
```

**Manual Removal**:
```bash
# Remove Helm chart
helm uninstall prometheus -n monitoring --kube-context rancher-desktop

# Remove PVCs (optional - preserves data if omitted)
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=prometheus
```

## 🔧 Troubleshooting

### **Common Issues**

**Pods Not Starting**:
```bash
# Check pod events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus

# Common causes:
# - Insufficient resources (check node capacity)
# - PVC binding issues (check PV availability)
# - Image pull errors (check network connectivity)
```

**High Memory Usage**:
```bash
# Check Prometheus memory usage
kubectl top pod -n monitoring -l app.kubernetes.io/name=prometheus

# Solutions:
# 1. Reduce retention period in manifests/030-prometheus-config.yaml
# 2. Increase memory limits
# 3. Check for cardinality explosion (too many unique label combinations)
```

**Metrics Not Appearing**:
```bash
# Check scrape targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Visit http://localhost:9090/targets

# Check ServiceMonitor configuration
kubectl get servicemonitor -n monitoring

# Verify application metrics endpoint
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n <app-namespace> -- \
  curl -s http://<service>:<port>/metrics
```

**Remote Write Failures** (from OTLP Collector):
```bash
# Check Prometheus server logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -l app.kubernetes.io/component=server

# Check OTLP Collector logs for remote write errors
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i prometheus

# Verify remote write endpoint is accessible
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write
```

**IMPORTANT**: If Prometheus returns 404 or error "remote write receiver needs to be enabled", check that the remote-write-receiver flag is enabled:
```bash
# Check Prometheus startup flags
kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server \
  -o jsonpath='{.items[0].spec.containers[?(@.name=="prometheus-server")].args}' | jq -r '.[]' | grep "remote-write"

# Should see: --web.enable-remote-write-receiver
# If missing, add to manifests/030-prometheus-config.yaml:
#   server:
#     extraArgs:
#       web.enable-remote-write-receiver: ""
```

**Alertmanager Not Firing Alerts**:
```bash
# Check Alertmanager logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -l app.kubernetes.io/component=alertmanager

# Check alert rules in Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Visit http://localhost:9090/alerts

# Verify Alertmanager configuration
kubectl get configmap -n monitoring prometheus-alertmanager -o yaml
```

## 📋 Maintenance

### **Regular Tasks**

**Monitor Storage Usage**:
```bash
# Check PVC usage
kubectl get pvc -n monitoring

# Check Prometheus TSDB size via PromQL
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Query: prometheus_tsdb_storage_blocks_bytes
```

**Update Prometheus**:
```bash
# Update Helm chart to latest version
helm repo update
helm upgrade prometheus prometheus-community/prometheus \
  -f /mnt/urbalurbadisk/manifests/030-prometheus-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop
```

**Cleanup Old Metrics** (automatic):
```yaml
# Retention handled automatically via server.retention setting
server:
  retention: 15d  # Metrics older than 15 days are purged
```

### **Backup Procedures**

**Snapshot Time-Series Data**:
```bash
# Create snapshot via API
kubectl run curl-snap --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -X POST http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/admin/tsdb/snapshot

# Snapshot stored in: /prometheus/snapshots/
```

**Backup PVC**:
```bash
# Export PVC data (requires read/write access)
kubectl exec -n monitoring deployment/prometheus-server -- \
  tar czf /tmp/prometheus-backup.tar.gz /prometheus

# Copy to local machine
kubectl cp monitoring/prometheus-server-xxx:/tmp/prometheus-backup.tar.gz \
  ./prometheus-backup.tar.gz
```

### **Disaster Recovery**

**Restore from Backup**:
```bash
# 1. Remove existing deployment
./01-remove-prometheus.sh rancher-desktop

# 2. Restore PVC data (manual process, requires direct PV access)
# 3. Redeploy Prometheus
./01-setup-prometheus.sh rancher-desktop
```

**Data Loss Scenarios**:
- **PVC deleted**: Metrics are lost, redeploy and start fresh collection
- **Corruption**: Prometheus auto-repairs TSDB on startup (check logs)
- **Retention expired**: Expected behavior, increase retention if needed

## 🚀 Use Cases

### **1. Application Metrics Monitoring**

**Instrument Application**:
```go
// Go example with Prometheus client
import "github.com/prometheus/client_golang/prometheus/promhttp"

http.Handle("/metrics", promhttp.Handler())
```

**Expose via ServiceMonitor**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    app: my-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

**Query in Grafana**:
```promql
rate(http_requests_total{job="my-app"}[5m])
```

### **2. Alert on High Resource Usage**

**Create Alert Rule**:
```yaml
# Add to Prometheus configuration
groups:
  - name: resource_alerts
    rules:
      - alert: HighMemoryUsage
        expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
```

### **3. Integrate with OTLP Collector**

**Receive Metrics from OTLP**:
```yaml
# OTLP Collector configuration (manifests/033-otel-collector-config.yaml)
exporters:
  prometheusremotewrite:
    endpoint: http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write
```

**Verify Metrics Ingestion**:
```bash
# Query OTLP-sourced metrics
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Query: {job="otel-collector"}
```

### **4. Dashboard Creation in Grafana**

**Add Prometheus Datasource** (pre-configured):
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus-server.monitoring.svc.cluster.local:80
    access: proxy
```

**Create Dashboard Panel**:
```json
{
  "targets": [{
    "expr": "rate(prometheus_http_requests_total[5m])",
    "legendFormat": "{{handler}}"
  }]
}
```

---

**💡 Key Insight**: Prometheus serves as the metrics foundation for the entire Urbalurba observability stack. Its pull-based architecture, combined with ServiceMonitor auto-discovery and PromQL's powerful query capabilities, provides comprehensive visibility into infrastructure and application health. When integrated with OTLP Collector, Loki, and Tempo, it forms a complete observability solution visualized in Grafana.

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[Tempo Tracing](./package-monitoring-tempo.md)** - Distributed tracing backend
- **[Loki Logs](./package-monitoring-loki.md)** - Log aggregation
- **[OTLP Collector](./package-monitoring-otel.md)** - Telemetry pipeline
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Dashboards

**Configuration & Rules**:
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest numbering (030)
- **[Development Workflow](./rules-development-workflow.md)** - Configuration management
- **[Automated Deployment](./rules-automated-kubernetes-deployment.md)** - Orchestration
