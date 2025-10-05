# Grafana - Visualization & Dashboards

**Key Features**: Unified Visualization • Multi-Datasource Queries • Dashboard Sidecar • Explore Mode • Alert Management • User Authentication • Dashboard as Code • Plugin Ecosystem

**File**: `doc/package-monitoring-grafana.md`
**Purpose**: Complete guide to Grafana deployment and configuration for visualization and exploration in Urbalurba infrastructure
**Target Audience**: DevOps engineers, platform administrators, SREs, developers, data analysts
**Last Updated**: October 5, 2025

**Deployed Version**: Grafana v12.1.1 (Helm Chart: grafana-10.0.0)
**Official Documentation**: https://grafana.com/docs/grafana/v12.1/

## 📋 Overview

Grafana is the **unified visualization platform** for the Urbalurba observability stack. It provides a single pane of glass for querying, visualizing, and alerting on data from Prometheus (metrics), Loki (logs), and Tempo (traces). Grafana's Explore mode enables ad-hoc investigation, while dashboards provide persistent monitoring views.

As the **front-end of the observability stack**, Grafana enables:
- **Unified Querying**: Query metrics, logs, and traces from a single interface
- **Dashboard Management**: Auto-load dashboards from Kubernetes ConfigMaps
- **Correlation**: Link metrics → logs → traces for complete context
- **Alerting**: Define alert rules and notification channels
- **Exploration**: Ad-hoc queries with Explore mode

**Key Capabilities**:
- **Pre-Configured Datasources**: Prometheus (default), Loki, Tempo ready to use
- **Dashboard Sidecar**: Auto-loads dashboards from ConfigMaps with label `grafana_dashboard: "1"`
- **PromQL, LogQL, TraceQL**: Native query language support for all backends
- **Correlation Links**: Jump from metrics → logs → traces seamlessly
- **Web UI Access**: `http://grafana.localhost` via Traefik IngressRoute
- **Persistent Storage**: 10Gi PVC for dashboards and configuration

**Architecture Type**: Web-based visualization and exploration platform

## 🏗️ Architecture

### **Deployment Components**
```
┌──────────────────────────────────────────────────────────┐
│         Grafana Stack (namespace: monitoring)            │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │            Grafana Deployment                  │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Web UI (Port 80)                        │ │    │
│  │  │  - Login/Authentication                  │ │    │
│  │  │  - Dashboard Rendering                   │ │    │
│  │  │  - Explore Mode                          │ │    │
│  │  │  - Alert Management                      │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Pre-Configured Datasources              │ │    │
│  │  │                                          │ │    │
│  │  │  • Prometheus (default)                  │ │    │
│  │  │    url: prometheus-server:80             │ │    │
│  │  │                                          │ │    │
│  │  │  • Loki                                  │ │    │
│  │  │    url: loki-gateway:80                  │ │    │
│  │  │                                          │ │    │
│  │  │  • Tempo                                 │ │    │
│  │  │    url: tempo:3200                       │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Dashboard Sidecar (Auto-Load)           │ │    │
│  │  │                                          │ │    │
│  │  │  Watches for ConfigMaps with:            │ │    │
│  │  │  label: grafana_dashboard: "1"           │ │    │
│  │  │  namespace: monitoring                   │ │    │
│  │  │                                          │ │    │
│  │  │  Auto-reloads dashboards every 60s       │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Persistent Storage (10Gi PVC)           │ │    │
│  │  │  - Dashboard definitions                 │ │    │
│  │  │  - User preferences                      │ │    │
│  │  │  - Alert states                          │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  Access: http://grafana.localhost (Traefik Ingress)    │
└──────────────────────────────────────────────────────────┘
         │                          ▲
         │                          │
         ▼                          │
┌──────────────────────────────────────────────────────┐
│   Datasource Backends                                │
│   - Prometheus (metrics)                             │
│   - Loki (logs)                                      │
│   - Tempo (traces)                                   │
└──────────────────────────────────────────────────────┘
```

### **Data Flow**
```
User Browser
         │
         │ HTTP (http://grafana.localhost)
         ▼
┌──────────────────────┐
│  Traefik Ingress     │
│  (Host: grafana.*)   │
└──────────────────────┘
         │
         │ Routes to Grafana Service
         ▼
┌──────────────────────────────┐
│  Grafana Web UI              │
│  (Port 80)                   │
├──────────────────────────────┤
│  User Actions:               │
│  1. Dashboard view           │
│  2. Explore query            │
│  3. Alert configuration      │
└──────────────────────────────┘
         │
         ├─► Query Prometheus (PromQL)
         ├─► Query Loki (LogQL)
         └─► Query Tempo (TraceQL)
                  │
                  ▼
         ┌──────────────────┐
         │  Render Results  │
         │  - Graphs        │
         │  - Tables        │
         │  - Logs          │
         │  - Traces        │
         └──────────────────┘
```

### **Dashboard Auto-Loading**
```
ConfigMap Created
(label: grafana_dashboard: "1")
         │
         ▼
┌──────────────────────────────┐
│  Dashboard Sidecar Container │
│  (watches monitoring ns)     │
└──────────────────────────────┘
         │
         │ Detects new ConfigMap
         ▼
┌──────────────────────────────┐
│  Load Dashboard JSON         │
│  - Parse dashboard def       │
│  - Register with Grafana     │
│  - Assign to folder          │
└──────────────────────────────┘
         │
         ▼
Dashboard Available in UI (~30s)
```

### **File Structure**
```
manifests/
├── 034-grafana-config.yaml                 # Grafana Helm values
├── 035-grafana-dashboards.yaml             # (if exists) Installation test dashboards
├── 036-grafana-sovdev-verification.yaml    # sovdev-logger verification dashboard
└── 038-grafana-ingressroute.yaml           # Traefik IngressRoute

ansible/playbooks/
├── 034-setup-grafana.yml                   # Deployment automation
└── 034-remove-grafana.yml                  # Removal automation

provision-host/kubernetes/11-monitoring/not-in-use/
├── 05-setup-grafana.sh                     # Shell script wrapper
└── 05-remove-grafana.sh                    # Removal script

Storage:
└── PersistentVolumeClaim
    └── grafana (10Gi)                      # Configuration and dashboards
```

## 🚀 Deployment

### **Automated Deployment**

**Via Monitoring Stack** (Recommended):
```bash
# Deploy entire monitoring stack (includes Grafana)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./00-setup-all-monitoring.sh rancher-desktop
```

**Individual Deployment**:
```bash
# Deploy Grafana only (requires Prometheus, Loki, Tempo already deployed)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./05-setup-grafana.sh rancher-desktop
```

### **Manual Deployment**

**Prerequisites**:
- Kubernetes cluster running (Rancher Desktop)
- `monitoring` namespace exists
- **Datasources deployed first**: Prometheus, Loki, Tempo
- Helm installed in provision-host container
- Manifest files: `034-grafana-config.yaml`, `038-grafana-ingressroute.yaml`

**Deployment Steps**:
```bash
# 1. Enter provision-host container
docker exec -it provision-host bash

# 2. Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. Deploy Grafana
helm upgrade --install grafana grafana/grafana \
  -f /mnt/urbalurbadisk/manifests/034-grafana-config.yaml \
  --namespace monitoring \
  --create-namespace \
  --timeout 600s \
  --kube-context rancher-desktop

# 4. Deploy IngressRoute for web UI access
kubectl apply -f /mnt/urbalurbadisk/manifests/038-grafana-ingressroute.yaml

# 5. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=grafana \
  -n monitoring --timeout=300s
```

**Deployment Time**: ~2-3 minutes

## ⚙️ Configuration

### **Grafana Configuration** (`manifests/034-grafana-config.yaml`)

**Admin Credentials**:
```yaml
adminUser: admin
adminPassword: SecretPassword1
```

**Pre-Configured Datasources**:
```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      # Prometheus (default datasource)
      - name: Prometheus
        type: prometheus
        uid: prometheus
        url: http://prometheus-server.monitoring.svc.cluster.local:80
        access: proxy
        isDefault: true
        editable: true

      # Loki (logs)
      - name: Loki
        type: loki
        uid: loki
        url: http://loki-gateway.monitoring.svc.cluster.local:80
        access: proxy
        editable: true

      # Tempo (traces)
      - name: Tempo
        type: tempo
        uid: tempo
        url: http://tempo.monitoring.svc.cluster.local:3200
        access: proxy
        editable: true
```

**Official Datasource Docs**:
- Prometheus: https://grafana.com/docs/grafana/v12.1/datasources/prometheus/
- Loki: https://grafana.com/docs/grafana/v12.1/datasources/loki/
- Tempo: https://grafana.com/docs/grafana/v12.1/datasources/tempo/

**Dashboard Sidecar (Auto-Loading)**:
```yaml
sidecar:
  dashboards:
    enabled: true
    label: grafana_dashboard           # Watch for ConfigMaps with this label
    labelValue: "1"
    folder: /tmp/dashboards
    searchNamespace: monitoring         # Only watch monitoring namespace
    folderAnnotation: grafana_folder    # Optional folder organization
    provider:
      foldersFromFilesStructure: true
```

**Persistent Storage**:
```yaml
persistence:
  enabled: true
  size: 10Gi
```

### **External Access Configuration** (`manifests/038-grafana-ingressroute.yaml`)

**Traefik IngressRoute**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  entryPoints:
    - web
  routes:
    - match: HostRegexp(`grafana\..+`)   # Matches grafana.localhost, grafana.urbalurba.no, etc.
      kind: Rule
      services:
        - name: grafana
          port: 80
```

**Access URLs**:
- **Localhost**: `http://grafana.localhost`
- **Future External**: `http://grafana.urbalurba.no` (requires DNS configuration)

### **Resource Configuration**

**Storage Requirements**:
- **Grafana PVC**: 10Gi persistent volume

**Service Endpoints**:
- **Web UI**: `grafana.monitoring.svc.cluster.local:80`
- **External UI**: `http://grafana.localhost` (via Traefik)

### **Security Configuration**

**Authentication**:
- **Default Credentials**: `admin` / `SecretPassword1`
- **Configuration Source**: Defined in `manifests/034-grafana-config.yaml` (lines 31-32)
  ```yaml
  adminUser: admin
  adminPassword: SecretPassword1
  ```
- **Not Hardcoded**: The password is set via Helm values file, not hardcoded in the Grafana chart
- **Customization**: Change password by editing `034-grafana-config.yaml` and running `helm upgrade`
- **Production Recommendation**: Change default password for production deployments
- **Future Enhancement**: Authentik SSO integration (optional)

**Network Access**:
- **Internal**: ClusterIP service for internal cluster access
- **External**: Traefik IngressRoute at `grafana.localhost` (HTTP, port 80)

## 🔍 Monitoring & Verification

### **Health Checks**

**Check Pod Status**:
```bash
# Grafana pods (main + sidecar containers)
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Expected output:
NAME                       READY   STATUS    RESTARTS   AGE
grafana-xxx                2/2     Running   0          5m
```

**Check Service Endpoints**:
```bash
# Verify service is accessible
kubectl get svc -n monitoring -l app.kubernetes.io/name=grafana

# Expected service:
grafana   ClusterIP   10.43.x.x   80/TCP
```

### **Service Verification**

**Test Web UI Access**:
```bash
# Via Traefik IngressRoute
curl -H "Host: grafana.localhost" http://127.0.0.1/

# Expected: HTML response with Grafana login page
```

**Test Datasource Connectivity** (from within pod):
```bash
# Test Prometheus datasource
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/status/config

# Test Loki datasource
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://loki-gateway.monitoring.svc.cluster.local:80/ready

# Test Tempo datasource
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://tempo.monitoring.svc.cluster.local:3200/ready
```

### **Verify Datasources in UI**

1. Open `http://grafana.localhost`
2. Login: `admin` / `SecretPassword1`
3. Navigate to **Configuration** → **Data sources**
4. Verify all three datasources are listed:
   - ✅ Prometheus (default)
   - ✅ Loki
   - ✅ Tempo

### **Automated Verification**

The deployment playbook (`034-setup-grafana.yml`) performs automated tests:
1. ✅ Web UI accessibility
2. ✅ Datasource configuration verification
3. ✅ Dashboard sidecar functionality
4. ✅ Test data generation and visualization (Installation Test Suite)

### **Installation Test Suite Dashboards**

Grafana automatically deploys 3 validation dashboards organized in the "Installation Test Suite" folder. These dashboards verify end-to-end functionality of the monitoring stack by displaying test telemetry generated during setup.

**Purpose**: Validate that logs, traces, and metrics flow correctly from OTLP Collector → Loki/Tempo/Prometheus → Grafana

**Dashboards Deployed** (`manifests/035-grafana-test-dashboards.yaml`):

#### **1. Test Data - Logs**
**UID**: `test-data-logs`
**Query**: `{service_name="telemetrygen-logs"}`
**Expected Data**: 100+ log entries from `telemetrygen` tool

**What This Validates**:
- ✅ OTLP Collector receives logs via HTTP
- ✅ Logs are exported from OTLP Collector to Loki
- ✅ Loki indexes logs by `service_name` label
- ✅ Grafana can query Loki datasource via LogQL
- ✅ Log panel displays structured log entries

**How Test Data is Generated** (during Grafana setup):
```bash
# Ansible playbook runs this command (step 23):
kubectl run telemetrygen-dashboard-logs \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  --rm -i --restart=Never -n monitoring -- \
  logs --otlp-endpoint=otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318 \
  --otlp-insecure --otlp-http --duration=10s --logs=100 \
  --service telemetrygen-logs \
  --body "Test log entry for Installation Test Suite dashboard"
```

**How to Use**:
1. Open `http://grafana.localhost`
2. Login: `admin` / `SecretPassword1`
3. Navigate to **Dashboards** → **Installation Test Suite** → **Test Data - Logs**
4. Verify panel shows 100+ log entries
5. Expand log entries to see structured fields (timestamp, service_name, body)

**Troubleshooting**:
- **No logs displayed**: Check OTLP Collector logs for ingestion errors
- **"No data" message**: Query Loki directly: `kubectl exec -n monitoring loki-0 -c loki -- wget -q -O - 'http://localhost:3100/loki/api/v1/label/service_name/values'`
- **Old data only**: Generate fresh test data (see command above)

---

#### **2. Test Data - Traces**
**UID**: `test-data-traces`
**Query**: `{resource.service.name="telemetrygen-traces"}`
**Expected Data**: 20+ trace entries from `telemetrygen` tool

**What This Validates**:
- ✅ OTLP Collector receives traces via gRPC
- ✅ Traces are exported from OTLP Collector to Tempo
- ✅ Tempo stores trace data with resource attributes
- ✅ Grafana can query Tempo datasource via TraceQL
- ✅ Trace count stat panel shows total traces
- ✅ Trace table displays trace IDs for inspection

**How Test Data is Generated** (during Grafana setup):
```bash
# Ansible playbook runs this command (step 24):
kubectl run telemetrygen-dashboard-traces \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  --rm -i --restart=Never -n monitoring -- \
  traces --otlp-endpoint=otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317 \
  --otlp-insecure --duration=5s --traces=20 \
  --service telemetrygen-traces
```

**How to Use**:
1. Navigate to **Dashboards** → **Installation Test Suite** → **Test Data - Traces**
2. Verify **Trace Count** stat panel shows 20+ traces (green background = success)
3. View **All Test Traces** table with trace IDs
4. Click on a trace ID to open trace waterfall view (spans visualization)
5. Inspect trace spans, duration, and resource attributes

**Troubleshooting**:
- **Trace count shows 0**: Check Tempo ingestion: `kubectl logs -n monitoring tempo-0 | grep telemetrygen`
- **Table empty**: Query Tempo API directly: `kubectl exec -n monitoring tempo-0 -- wget -q -O - 'http://localhost:3200/api/search?tags=service.name%3Dtelemetrygen-traces'`
- **Old traces only**: Generate fresh test data (see command above)

---

#### **3. Test Data - Metrics**
**UID**: `test-data-metrics`
**Query**: `up` (Prometheus 'up' metric for all scraped targets)
**Expected Data**: Timeseries graph showing health of all monitored services

**What This Validates**:
- ✅ Prometheus scrapes metrics from all targets
- ✅ Prometheus stores time-series data
- ✅ Grafana can query Prometheus datasource via PromQL
- ✅ Timeseries panel displays multiple metrics with legend
- ✅ Monitoring stack services are healthy (value = 1)

**How Test Data is Available**:
- **No generation needed**: Prometheus automatically scrapes `up` metric from all targets (Prometheus server, alertmanager, node-exporter, kube-state-metrics, pushgateway, OTLP Collector, Loki, Tempo, Grafana)
- Metric value: `1` = service is up and responding to scrapes, `0` = service is down

**How to Use**:
1. Navigate to **Dashboards** → **Installation Test Suite** → **Test Data - Metrics**
2. View timeseries graph showing multiple services
3. Check legend on right: All services should show `1` (up) in "Last" column
4. Hover over graph lines to see individual service metrics
5. Verify services like `prometheus-server`, `loki`, `tempo` are present

**Troubleshooting**:
- **No metrics displayed**: Check Prometheus targets: `kubectl port-forward -n monitoring svc/prometheus-server 9090:80` → Open `http://localhost:9090/targets`
- **Services showing 0**: Check pod health: `kubectl get pods -n monitoring`
- **Missing services in legend**: Verify Prometheus ServiceMonitor configuration

---

**Access Installation Test Suite**:
```bash
# Open Grafana
open http://grafana.localhost

# Navigate to folder
Dashboards → Browse → Installation Test Suite folder
```

**Dashboard Files**:
- **ConfigMap Manifest**: `manifests/035-grafana-test-dashboards.yaml`
- **3 ConfigMaps**: `grafana-dashboard-test-logs`, `grafana-dashboard-test-traces`, `grafana-dashboard-test-metrics`
- **Folder Label**: `grafana_folder: "Installation Test Suite"`

**Dashboard Auto-Loading**:
- Dashboards are automatically loaded via Grafana sidecar (~30-60 seconds after deployment)
- No manual import required
- Changes to ConfigMaps automatically reload in Grafana

**Regenerate Test Data** (if dashboards show no data):
```bash
# Generate logs
kubectl run telemetrygen-logs-manual \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  --rm -i --restart=Never -n monitoring -- \
  logs --otlp-endpoint=otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318 \
  --otlp-insecure --otlp-http --duration=10s --logs=100 \
  --service telemetrygen-logs \
  --body "Manual test log entry"

# Generate traces
kubectl run telemetrygen-traces-manual \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  --rm -i --restart=Never -n monitoring -- \
  traces --otlp-endpoint=otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317 \
  --otlp-insecure --duration=5s --traces=20 \
  --service telemetrygen-traces
```

### **sovdev-logger Dashboards**

Grafana includes two pre-built dashboards for monitoring applications using **sovdev-logger**, which provides zero-effort observability through automatic logs, metrics, and traces generation.

**Dashboards Deployed**:
- **Fast Metrics Dashboard** (`manifests/037-grafana-sovdev-metrics.yaml`)
- **Verification Dashboard** (`manifests/036-grafana-sovdev-verification.yaml`)

---

#### **Fast Metrics Dashboard**
**UID**: `sovdev-metrics`
**Purpose**: Real-time application monitoring using Prometheus metrics (sub-second query performance)

**Data Source**: Prometheus
**Queries**: Uses automatic metrics generated by sovdev-logger:
- `sovdev_operations_total` - Total operations counter
- `sovdev_errors_total` - Error counter (ERROR/FATAL levels)
- `sovdev_operation_duration_milliseconds` - Duration histogram
- `sovdev_operations_active` - Active operations gauge

**What This Dashboard Shows**:
- ✅ **Operations Rate**: Requests per second by service and log type
- ✅ **Error Rate**: Errors per second by service and log type
- ✅ **Operation Duration**: P50, P95, P99 latency percentiles
- ✅ **Active Operations**: Currently in-progress operations
- ✅ **Service Dependency Graph**: Automatically generated from traces (via Tempo metrics generator)

**Dashboard Variables**:
- `service_name` - Filter by specific service
- `log_type` - Filter by log type (API, DATABASE, BATCH, etc.)
- `peer_service` - Filter by downstream service

**Benefits**:
- **Sub-second queries**: Prometheus metrics enable fast dashboard load times
- **Real-time monitoring**: Track live application behavior
- **No code changes**: Metrics automatically generated from sovdevLog() calls
- **Full dimensional filtering**: service_name, peer_service, log_level, log_type

**How to Use**:
1. Open `http://grafana.localhost`
2. Navigate to **Dashboards** → **sovdev-logger** → **Fast Metrics Dashboard**
3. Select service from `service_name` dropdown
4. View operation rates, errors, latencies, and service graphs
5. Click on panels to drill down into specific time ranges

**Requirements**:
- sovdev-logger in application
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` configured
- Tempo metrics generator enabled (for service graphs)

---

#### **Verification Dashboard**
**UID**: `sovdev-verification`
**Purpose**: Debug and verify complete observability correlation (logs + metrics + traces)

**Data Sources**: Loki (logs), Tempo (traces), Prometheus (metrics)
**Purpose**: Verify traceId correlation and debug specific application executions

**What This Dashboard Shows**:
- ✅ **Log Entries**: Structured logs from Loki with all attributes
- ✅ **Trace Correlation**: Click traceId in logs to jump to trace waterfall
- ✅ **Session Filtering**: Filter by session.id to isolate specific runs
- ✅ **Full Context**: Input/response JSON, function names, log levels
- ✅ **Error Details**: Exception stack traces and error messages

**Dashboard Variables**:
- `service_name` - Filter by specific service
- `session_id` - Filter by specific execution (unique per run)
- `log_level` - Filter by log level (ERROR, WARN, INFO, DEBUG)

**Benefits**:
- **Full correlation**: Link logs → traces → metrics via traceId
- **Session isolation**: Debug specific runs without time-based filtering
- **Complete context**: See input/response data alongside logs and traces
- **Error investigation**: Jump from error log to full trace waterfall

**How to Use**:
1. Navigate to **Dashboards** → **sovdev-logger** → **Verification Dashboard**
2. **Option A - Debug specific session**:
   - Copy session ID from application startup: `🔑 Session ID: abc123-def456-ghi789`
   - Enter in `session_id` variable
   - View all logs/metrics/traces from that execution
3. **Option B - Investigate errors**:
   - Set `log_level` to "ERROR"
   - View error logs with stack traces
   - Click traceId to see full request trace
4. **Option C - Analyze specific service**:
   - Select `service_name`
   - View chronological log stream
   - Expand log entries to see full JSON context

**Requirements**:
- sovdev-logger in application
- `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` configured
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` configured
- OTEL Collector session_id processing enabled

---

**Access sovdev-logger Dashboards**:
```bash
# Open Grafana
open http://grafana.localhost

# Navigate to dashboards
Dashboards → Browse → sovdev-logger folder
```

**Dashboard Files**:
- **Fast Metrics Dashboard**: `manifests/037-grafana-sovdev-metrics.yaml`
- **Verification Dashboard**: `manifests/036-grafana-sovdev-verification.yaml`

**Auto-Loading**: Both dashboards are automatically loaded via Grafana sidecar (~30-60 seconds after deployment)

**Official sovdev-logger Documentation**: See `doc/package-monitoring-sovdev-logger.md` for library usage and features.

## 🛠️ Management Operations

### **Access Grafana UI**

**Open in Browser**:
```bash
# Direct access (Mac host)
open http://grafana.localhost

# Or manually navigate to:
http://grafana.localhost
```

**Login Credentials**:
- **Username**: `admin`
- **Password**: `SecretPassword1`

### **Dashboard Management**

Dashboards are managed as Kubernetes ConfigMaps with automatic loading via the Grafana sidecar container. This GitOps-style approach enables version-controlled dashboard definitions.

#### **Add New Dashboard**

**Method 1: Design in Grafana UI, Export, Convert to ConfigMap**

1. **Design dashboard in Grafana UI**:
   ```bash
   open http://grafana.localhost
   # Login: admin/SecretPassword1
   # Create dashboard → Add panels → Configure queries → Save
   ```

2. **Export dashboard JSON**:
   - Open dashboard → **Settings** (gear icon) → **JSON Model**
   - Copy entire JSON content

3. **Create ConfigMap manifest** (`manifests/0XX-grafana-my-dashboard.yaml`):
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: grafana-dashboard-my-service
     namespace: monitoring
     labels:
       grafana_dashboard: "1"           # Required for auto-loading
   data:
     my-service.json: |
       {
         "title": "My Service Metrics",
         "uid": "my-service-metrics",
         "panels": [
           {
             "type": "graph",
             "title": "Request Rate",
             "targets": [
               {
                 "expr": "rate(http_requests_total{service=\"my-service\"}[5m])",
                 "refId": "A"
               }
             ]
           }
         ]
       }
   ```

4. **Apply ConfigMap**:
   ```bash
   kubectl apply -f manifests/0XX-grafana-my-dashboard.yaml
   ```

5. **Verify dashboard auto-loads** (~30-60 seconds):
   - Check sidecar logs: `kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard`
   - Grafana UI → **Dashboards** → Search for "My Service Metrics"

**Method 2: Write JSON Directly** (for simple dashboards):
```bash
# Create ConfigMap with inline JSON
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-simple
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  simple.json: |
    {
      "title": "Simple Dashboard",
      "uid": "simple-dashboard",
      "panels": []
    }
EOF
```

#### **Update Existing Dashboard**

1. **Edit ConfigMap manifest** (`manifests/0XX-grafana-my-dashboard.yaml`):
   ```bash
   vim manifests/0XX-grafana-my-dashboard.yaml
   # Modify JSON in data.my-service.json
   ```

2. **Apply updated ConfigMap**:
   ```bash
   kubectl apply -f manifests/0XX-grafana-my-dashboard.yaml
   ```

3. **Wait for automatic reload** (~30-60 seconds) or force reload:
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   ```

4. **Verify changes** in Grafana UI (may need to refresh browser)

**Alternative**: Update via kubectl edit:
```bash
kubectl edit configmap -n monitoring grafana-dashboard-my-service
# Edit JSON directly in editor
# Save → Auto-reloads in ~60s
```

#### **Delete Dashboard**

**Option 1: Remove ConfigMap** (recommended for GitOps):
```bash
# Delete manifest file
kubectl delete -f manifests/0XX-grafana-my-dashboard.yaml

# Or delete directly by name
kubectl delete configmap -n monitoring grafana-dashboard-my-service
```
Dashboard automatically disappears from Grafana UI within ~60 seconds.

**Option 2: Delete via Grafana UI** (not persistent):
- Grafana UI → **Dashboards** → Find dashboard → **Settings** → **Delete**
- ⚠️ Dashboard will reappear if ConfigMap still exists (sidecar will reload it)

#### **Dashboard Organization**

**Folder Assignment** (via annotation):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-app
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
  annotations:
    grafana_folder: "Application Monitoring"  # Assigns to folder in UI
data:
  app.json: |
    { ... }
```

**Naming Convention**:
- ConfigMap name: `grafana-dashboard-<purpose>`
- Dashboard JSON key: `<descriptive-name>.json`
- Manifest file: `manifests/0XX-grafana-<purpose>.yaml` (use numbering 035-039)

#### **Examples**

**Existing Dashboards**:
- `manifests/035-grafana-test-dashboards.yaml` - **Installation Test Suite** (3 dashboards):
  - Test Data - Logs: Validates OTLP → Loki → Grafana flow
  - Test Data - Traces: Validates OTLP → Tempo → Grafana flow
  - Test Data - Metrics: Validates Prometheus → Grafana flow
  - See "Installation Test Suite Dashboards" section above for details
- `manifests/036-grafana-sovdev-verification.yaml` - **sovdev-logger Verification Dashboard**:
  - Debug logs/traces/metrics correlation
  - Session filtering for specific executions
  - TraceId links to full trace waterfall
  - See "sovdev-logger Dashboards" section above for details
- `manifests/037-grafana-sovdev-metrics.yaml` - **sovdev-logger Fast Metrics Dashboard**:
  - Real-time Prometheus metrics from sovdev-logger
  - Operation rates, error rates, latencies
  - Service dependency graphs
  - See "sovdev-logger Dashboards" section above for details

**Official Dashboard Docs**: https://grafana.com/docs/grafana/v12.1/dashboards/

#### **Troubleshooting Dashboard Management**

**Dashboard not appearing**:
```bash
# 1. Verify ConfigMap exists with correct label
kubectl get configmap -n monitoring -l grafana_dashboard=1

# 2. Check sidecar logs for errors
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard --tail=50

# 3. Force reload
kubectl rollout restart deployment/grafana -n monitoring
```

**Dashboard shows old version**:
```bash
# Refresh sidecar (faster than full restart)
kubectl delete pod -n monitoring -l app.kubernetes.io/name=grafana

# Or clear browser cache and refresh
```

### **Explore Mode Usage**

**Query Logs in Loki**:
1. Navigate to **Explore** → Select **Loki** datasource
2. Enter LogQL query:
   ```logql
   {service_name="sovdev-test-company-lookup-typescript"}
   ```
3. Run query to view log stream

**Query Metrics in Prometheus**:
1. Navigate to **Explore** → Select **Prometheus** datasource
2. Enter PromQL query:
   ```promql
   rate(prometheus_http_requests_total[5m])
   ```
3. Run query to view metrics graph

**Query Traces in Tempo**:
1. Navigate to **Explore** → Select **Tempo** datasource
2. Enter TraceQL query:
   ```traceql
   {resource.service.name="my-app"}
   ```
3. View trace waterfall/flamegraph

**Official Explore Docs**: https://grafana.com/docs/grafana/v12.1/explore/

### **Correlation Workflow**

**Metrics → Logs → Traces**:
1. Find metric spike in Prometheus dashboard
2. Note timestamp and service name
3. Switch to Loki, query logs for that time range
4. Find `trace_id` in log entry
5. Switch to Tempo, query by `trace_id`
6. View complete request flow with logs and trace spans

### **Service Removal**

**Automated Removal**:
```bash
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./05-remove-grafana.sh rancher-desktop
```

**Manual Removal**:
```bash
# Remove Helm chart
helm uninstall grafana -n monitoring --kube-context rancher-desktop

# Remove IngressRoute
kubectl delete ingressroute -n monitoring grafana

# Remove PVC (optional - preserves data if omitted)
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=grafana
```

## 🔧 Troubleshooting

### **Common Issues**

**Cannot Access Web UI**:
```bash
# 1. Check IngressRoute exists
kubectl get ingressroute -n monitoring grafana

# 2. Test with Host header
curl -v -H "Host: grafana.localhost" http://127.0.0.1/

# 3. Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik | grep grafana

# 4. Verify Grafana pod is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

**Datasource Connection Errors**:
```bash
# Test datasource connectivity from Grafana pod
kubectl exec -n monitoring deployment/grafana -- \
  curl -v http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/status/config

# Check if backend services are running
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo
```

**Dashboard Not Auto-Loading**:
```bash
# 1. Verify ConfigMap has correct label
kubectl get configmap -n monitoring -l grafana_dashboard=1

# 2. Check sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard

# 3. Verify ConfigMap is in correct namespace
kubectl get configmap -n monitoring my-dashboard

# 4. Force reload by restarting Grafana
kubectl rollout restart deployment/grafana -n monitoring
```

**Login Issues**:
```bash
# Reset admin password (if forgotten)
kubectl exec -n monitoring deployment/grafana -- \
  grafana-cli admin reset-admin-password NewPassword123

# Check Grafana logs for authentication errors
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana
```

## 📋 Maintenance

### **Update Grafana**:
```bash
# Update Helm chart to latest version
helm repo update
helm upgrade grafana grafana/grafana \
  -f /mnt/urbalurbadisk/manifests/034-grafana-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop
```

### **Backup Dashboards**:
```bash
# Export all dashboards via API
kubectl port-forward -n monitoring svc/grafana 3000:80

# Use Grafana API to export (from Mac host)
curl -u admin:SecretPassword1 \
  http://localhost:3000/api/search?type=dash-db | \
  jq -r '.[].uid' | \
  xargs -I {} curl -u admin:SecretPassword1 \
    http://localhost:3000/api/dashboards/uid/{} \
    > dashboard-{}.json
```

### **Backup PVC Data**:
```bash
# Export Grafana configuration
kubectl exec -n monitoring deployment/grafana -- \
  tar czf /tmp/grafana-backup.tar.gz /var/lib/grafana

# Copy to local machine
kubectl cp monitoring/grafana-xxx:/tmp/grafana-backup.tar.gz \
  ./grafana-backup.tar.gz -c grafana
```

## 🚀 Use Cases

### **1. Create Custom Dashboard**

**Using Grafana UI**:
1. Navigate to **Dashboards** → **New** → **New Dashboard**
2. Add panel with Prometheus query:
   ```promql
   rate(prometheus_http_requests_total[5m])
   ```
3. Save dashboard
4. Export JSON: **Dashboard settings** → **JSON Model** → Copy JSON
5. Create ConfigMap with exported JSON
6. Apply ConfigMap for auto-loading

### **2. Log Analysis Workflow**

**Find Errors in Logs**:
1. **Explore** → **Loki**
2. Query:
   ```logql
   {service_name="my-app"} |= "error"
   ```
3. Filter time range to last 15 minutes
4. Expand log entries to view full context
5. Copy `trace_id` for correlation

### **3. Performance Monitoring**

**Dashboard for Service Health**:
- **Panel 1**: Request rate (PromQL)
  ```promql
  rate(http_requests_total{service="my-app"}[5m])
  ```
- **Panel 2**: Error rate (PromQL)
  ```promql
  rate(http_requests_total{service="my-app",status=~"5.."}[5m])
  ```
- **Panel 3**: Recent logs (LogQL)
  ```logql
  {service_name="my-app"}
  ```
- **Panel 4**: Slow traces (TraceQL)
  ```traceql
  {resource.service.name="my-app" && duration > 1s}
  ```

### **4. Alert Configuration**

**Create Alert Rule** (in dashboard panel):
1. Edit panel → **Alert** tab
2. Define condition:
   ```
   WHEN avg() OF query(A, 5m, now) IS ABOVE 100
   ```
3. Set notification channel
4. Test alert
5. Save dashboard

**Official Alerting Docs**: https://grafana.com/docs/grafana/v12.1/alerting/

---

**💡 Key Insight**: Grafana serves as the unified interface for the entire observability stack, transforming raw telemetry data into actionable insights. Its dashboard sidecar pattern enables GitOps-style dashboard management via ConfigMaps, while Explore mode provides ad-hoc investigation capabilities. By correlating metrics, logs, and traces from Prometheus, Loki, and Tempo in a single interface, Grafana delivers complete observability visibility without context switching between tools.

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[Prometheus Metrics](./package-monitoring-prometheus.md)** - Metrics datasource
- **[Loki Logs](./package-monitoring-loki.md)** - Logs datasource
- **[Tempo Tracing](./package-monitoring-tempo.md)** - Traces datasource
- **[OTLP Collector](./package-monitoring-otel.md)** - Telemetry ingestion

**Configuration & Rules**:
- **[Traefik IngressRoute](./rules-ingress-traefik.md)** - External access patterns
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest numbering (034, 038)
- **[Development Workflow](./rules-development-workflow.md)** - Configuration management
- **[Secrets Management](./rules-secrets-management.md)** - Managing admin credentials

**External Resources**:
- **Grafana Dashboards**: https://grafana.com/docs/grafana/v12.1/dashboards/
- **Grafana Explore**: https://grafana.com/docs/grafana/v12.1/explore/
- **Prometheus Datasource**: https://grafana.com/docs/grafana/v12.1/datasources/prometheus/
- **Loki Datasource**: https://grafana.com/docs/grafana/v12.1/datasources/loki/
- **Tempo Datasource**: https://grafana.com/docs/grafana/v12.1/datasources/tempo/
- **Alerting**: https://grafana.com/docs/grafana/v12.1/alerting/
