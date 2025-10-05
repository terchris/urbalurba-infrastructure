# OpenTelemetry Collector - Telemetry Pipeline

**Key Features**: OTLP Protocol • Multi-Backend Export • HTTP & gRPC Receivers • Traefik Ingress • External Access • Logs/Traces/Metrics • Resource Processing • Debug Mode

**File**: `doc/package-monitoring-otel.md`
**Purpose**: Complete guide to OpenTelemetry Collector deployment and configuration for telemetry ingestion in Urbalurba infrastructure
**Target Audience**: DevOps engineers, platform administrators, SREs, developers
**Last Updated**: October 3, 2025

**Deployed Version**: OpenTelemetry Collector v0.136.0 (Helm Chart: opentelemetry-collector-0.136.1)
**Official Documentation**: https://opentelemetry.io/docs/collector/
**Configuration Reference**: https://opentelemetry.io/docs/collector/configuration/

## 📋 Overview

The **OpenTelemetry Collector** is a vendor-neutral telemetry gateway that receives, processes, and exports observability data. It acts as the central ingestion point for all OTLP (OpenTelemetry Protocol) telemetry from applications, routing logs to Loki, traces to Tempo, and metrics to Prometheus.

As the **hub of the observability stack**, the OTLP Collector provides:
- **Unified Ingestion**: Single endpoint for logs, traces, and metrics
- **Protocol Translation**: Converts OTLP to backend-specific formats
- **Resource Enrichment**: Adds cluster metadata to telemetry data
- **External Access**: Traefik IngressRoute for applications outside the cluster
- **Multi-Backend Export**: Routes telemetry to appropriate storage backends

**Key Capabilities**:
- **OTLP Receivers**: HTTP (4318) and gRPC (4317) endpoints
- **External Ingestion**: Accessible via `http://otel.localhost/v1/logs` and `/v1/traces`
- **Smart Routing**: Logs → Loki, Traces → Tempo, Metrics → Prometheus
- **Resource Processing**: Enriches telemetry with cluster and service metadata
- **Debug Mode**: Detailed logging for troubleshooting data flow
- **Batch Processing**: Optimizes throughput with batching and buffering

**Architecture Type**: Telemetry aggregation and routing gateway

## 🏗️ Architecture

### **Deployment Components**
```
┌──────────────────────────────────────────────────────────┐
│     OTLP Collector Stack (namespace: monitoring)         │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │       OpenTelemetry Collector Deployment       │    │
│  │                                                │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Receivers (Ingestion)                   │ │    │
│  │  │  - OTLP/gRPC: 4317                       │ │    │
│  │  │  - OTLP/HTTP: 4318                       │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  │                      │                        │    │
│  │                      ▼                        │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Processors (Enrichment)                 │ │    │
│  │  │  - Resource Processor                    │ │    │
│  │  │    • Adds cluster.name                   │ │    │
│  │  │    • Extracts service_name               │ │    │
│  │  │  - Transform Processor                   │ │    │
│  │  │    • Sets log attributes                 │ │    │
│  │  │  - Batch Processor                       │ │    │
│  │  │    • Optimizes throughput                │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  │                      │                        │    │
│  │                      ▼                        │    │
│  │  ┌──────────────────────────────────────────┐ │    │
│  │  │  Exporters (Multi-Backend Routing)       │ │    │
│  │  │                                          │ │    │
│  │  │  Traces → otlp/tempo (4317)              │ │    │
│  │  │  Logs → otlphttp/loki (/otlp)            │ │    │
│  │  │  Metrics → prometheusremotewrite (/write)│ │    │
│  │  │  Debug → stdout (sampling)               │ │    │
│  │  └──────────────────────────────────────────┘ │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  Ports: 4317 (gRPC), 4318 (HTTP), 8888 (metrics)       │
└──────────────────────────────────────────────────────────┘
         ▲                          │
         │                          ▼
┌──────────────────┐    ┌─────────────────────────────┐
│   Applications   │    │   Backend Services          │
│   (OTLP SDK)     │    │   - Loki (logs)             │
│                  │    │   - Tempo (traces)          │
│   - TypeScript   │    │   - Prometheus (metrics)    │
│   - Python       │    └─────────────────────────────┘
│   - C#/Go/etc    │
└──────────────────┘

External Access (via Traefik IngressRoute):
┌──────────────────────────────────────────┐
│  http://otel.localhost/v1/logs           │
│  http://otel.localhost/v1/traces         │
│  (Future: http://otel.urbalurba.no)      │
└──────────────────────────────────────────┘
```

### **Data Flow**
```
Application (OTLP Instrumented)
         │
         │ HTTP POST /v1/logs OR gRPC
         ▼
┌──────────────────────┐
│  Traefik Ingress     │
│  (otel.localhost)    │
└──────────────────────┘
         │
         │ Routes to Service
         ▼
┌──────────────────────────────┐
│  OTLP Collector              │
│  (4318 HTTP, 4317 gRPC)      │
├──────────────────────────────┤
│  1. Receive OTLP data        │
│  2. Resource enrichment      │
│     - Add cluster.name       │
│     - Extract service_name   │
│  3. Transform attributes     │
│  4. Batch for efficiency     │
│  5. Route to backends:       │
│     - Logs → Loki            │
│     - Traces → Tempo         │
│     - Metrics → Prometheus   │
│  6. Debug sampling output    │
└──────────────────────────────┘
         │
         ├─► Loki (HTTP push API)
         ├─► Tempo (gRPC OTLP)
         ├─► Prometheus (remote write)
         └─► Debug logs (stdout)
```

### **File Structure**
```
manifests/
├── 033-otel-collector-config.yaml          # OTLP Collector Helm values
└── 039-otel-collector-ingress.yaml         # Traefik IngressRoute

ansible/playbooks/
├── 033-setup-otel-collector.yml            # Deployment automation
└── 033-remove-otel-collector.yml           # Removal automation

provision-host/kubernetes/11-monitoring/not-in-use/
├── 04-setup-otel-collector.sh              # Shell script wrapper
└── 04-remove-otel-collector.sh             # Removal script

No persistent storage required (stateless deployment)
```

## 🚀 Deployment

### **Automated Deployment**

**Via Monitoring Stack** (Recommended):
```bash
# Deploy entire monitoring stack (includes OTLP Collector)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./00-setup-all-monitoring.sh rancher-desktop
```

**Individual Deployment**:
```bash
# Deploy OTLP Collector only (requires Loki, Tempo, Prometheus already deployed)
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./04-setup-otel-collector.sh rancher-desktop
```

### **Manual Deployment**

**Prerequisites**:
- Kubernetes cluster running (Rancher Desktop)
- `monitoring` namespace exists
- **Backends deployed first**: Prometheus, Tempo, Loki
- Helm installed in provision-host container
- Manifest files: `033-otel-collector-config.yaml`, `039-otel-collector-ingress.yaml`

**Deployment Steps**:
```bash
# 1. Enter provision-host container
docker exec -it provision-host bash

# 2. Add OpenTelemetry Helm repository
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# 3. Deploy OTLP Collector
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  -f /mnt/urbalurbadisk/manifests/033-otel-collector-config.yaml \
  --namespace monitoring \
  --create-namespace \
  --timeout 600s \
  --kube-context rancher-desktop

# 4. Deploy IngressRoute for external access
kubectl apply -f /mnt/urbalurbadisk/manifests/039-otel-collector-ingress.yaml

# 5. Wait for pods to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=opentelemetry-collector \
  -n monitoring --timeout=300s
```

**Deployment Time**: ~1-2 minutes

## ⚙️ Configuration

### **OTLP Collector Configuration** (`manifests/033-otel-collector-config.yaml`)

**Deployment Mode**:
```yaml
mode: deployment                  # Kubernetes Deployment (stateless)
```

**Receivers (Ingestion Endpoints)**:
```yaml
config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317  # gRPC receiver (recommended)
        http:
          endpoint: 0.0.0.0:4318  # HTTP receiver (easier for testing)
```

**Official Receiver Docs**: https://opentelemetry.io/docs/collector/configuration/#receivers

**Processors (Data Enrichment)**:
```yaml
config:
  processors:
    # Batch processing for efficiency
    batch:
      timeout: 10s
      send_batch_size: 1024

    # Add cluster metadata and extract resource attributes
    resource:
      attributes:
        - key: cluster.name
          value: urbalurba-local
          action: upsert
        - key: service_name
          from_attribute: service.name
          action: insert
        - key: session_id
          from_attribute: session.id
          action: insert

    # Transform log attributes to make them available in Loki
    transform:
      log_statements:
        - context: log
          statements:
            - set(attributes["service_name"], resource.attributes["service_name"])
            - set(attributes["session_id"], resource.attributes["session.id"]) where resource.attributes["session.id"] != nil
```

**Official Processor Docs**: https://opentelemetry.io/docs/collector/configuration/#processors

**Exporters (Backend Routing)**:
```yaml
config:
  exporters:
    # Traces to Tempo
    otlp/tempo:
      endpoint: tempo.monitoring.svc.cluster.local:4317
      tls:
        insecure: true

    # Logs to Loki (OTLP HTTP endpoint)
    otlphttp/loki:
      endpoint: http://loki-gateway.monitoring.svc.cluster.local:80/otlp
      tls:
        insecure: true

    # Metrics to Prometheus
    prometheusremotewrite:
      endpoint: http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write
      tls:
        insecure: true

    # Debug exporter (sampling for troubleshooting)
    debug:
      verbosity: detailed
      sampling_initial: 5
      sampling_thereafter: 200
```

**Official Exporter Docs**: https://opentelemetry.io/docs/collector/configuration/#exporters

**Pipelines (Data Routing)**:
```yaml
config:
  service:
    pipelines:
      # Traces pipeline
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [otlp/tempo, debug]

      # Logs pipeline
      logs:
        receivers: [otlp]
        processors: [resource, transform, batch]
        exporters: [otlphttp/loki, debug]

      # Metrics pipeline
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheusremotewrite, debug]
```

### **External Access Configuration** (`manifests/039-otel-collector-ingress.yaml`)

**Traefik IngressRoute**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  entryPoints:
    - web
  routes:
    - match: HostRegexp(`otel\..+`)        # Matches otel.localhost, otel.urbalurba.no, etc.
      kind: Rule
      services:
        - name: otel-collector-opentelemetry-collector
          port: 4318                        # HTTP endpoint only (not gRPC)
```

**Access URLs**:
- **Localhost**: `http://otel.localhost/v1/logs`, `http://otel.localhost/v1/traces`
- **Future External**: `http://otel.urbalurba.no/v1/logs` (requires DNS configuration)

### **Resource Configuration**

**No Persistent Storage**: OTLP Collector is stateless (no PVC required)

**Service Endpoints**:
- **OTLP gRPC**: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317`
- **OTLP HTTP**: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318`
- **Metrics**: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:8888`
- **Health Check**: `otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:13133`

**Resource Limits**:
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### **Security Configuration**

**Network Access**:
- **Internal**: ClusterIP service for internal cluster access
- **External**: Traefik IngressRoute at `otel.localhost` (HTTP only, port 80)

**TLS**: Disabled (`insecure: true`) for internal backends - all communication within cluster is unencrypted

## 🔍 Monitoring & Verification

### **Health Checks**

**Check Pod Status**:
```bash
# OTLP Collector pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Expected output:
NAME                                                READY   STATUS
otel-collector-opentelemetry-collector-xxx          1/1     Running
```

**Check Service Endpoints**:
```bash
# Verify service is accessible
kubectl get svc -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Expected service:
otel-collector-opentelemetry-collector   ClusterIP   10.43.x.x   4317/TCP,4318/TCP,8888/TCP
```

### **Service Verification**

**Test Health Endpoint**:
```bash
# Check if collector is healthy
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:13133/

# Expected: {} (empty JSON = healthy)
```

**Test OTLP HTTP Endpoint** (Internal):
```bash
# Send test log via OTLP HTTP
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -X POST http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"scopeLogs":[{"logRecords":[{"body":{"stringValue":"test log"}}]}]}]}'

# Expected: No error (200 or 204 response)
```

**Test External Access** (via Traefik):
```bash
# From Mac host (outside cluster)
curl -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"external-test"}}]},"scopeLogs":[{"logRecords":[{"body":{"stringValue":"external test log"}}]}]}]}'

# Expected: No error
```

### **Check Data Flow to Backends**

**Verify Logs Reaching Loki**:
```bash
# Check collector logs for Loki exports
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i loki

# Query Loki for test logs
kubectl exec -n monitoring loki-0 -c loki -- \
  wget -q -O - 'http://localhost:3100/loki/api/v1/label/service_name/values'

# Should include "test" or "external-test"
```

**Verify Traces Reaching Tempo**:
```bash
# Check collector logs for Tempo exports
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i tempo
```

**Check Collector Metrics**:
```bash
# Get collector self-monitoring metrics
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -s http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:8888/metrics
```

### **Automated Verification**

The deployment playbook (`033-setup-otel-collector.yml`) performs automated tests:
1. ✅ OTLP HTTP endpoint connectivity
2. ✅ OTLP gRPC endpoint connectivity
3. ✅ Health check endpoint validation
4. ✅ Test log ingestion and export

## 🛠️ Management Operations

### **View Collector Logs**

**Real-Time Logs** (Debug Mode):
```bash
# Tail collector logs (includes debug sampling output)
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --follow

# Filter for specific pipeline
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i "logs pipeline"
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i "traces pipeline"
```

**Debug Output Examples**:
```
# Sampled log output (every 200th log after initial 5)
2025-10-03T10:15:32.123Z  debug  ResourceLog #0
  service.name: sovdev-test-company-lookup-typescript
  cluster.name: urbalurba-local
  LogRecord #0
    body: Company Lookup Service started
    service_name: sovdev-test-company-lookup-typescript
```

### **Application Integration**

**For application instrumentation and OTLP integration**, see:
- **[sovdev-logger Integration Guide](./package-monitoring-sovdev-logger.md)** - Multi-language logging library with OTLP support (TypeScript, Python, C#, PHP, Go, Rust)

**Quick Example** (TypeScript with sovdev-logger):
```bash
# Environment configuration
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

For complete integration examples in all supported languages, see the sovdev-logger documentation above.

### **Authentication Configuration**

**Default Configuration**: The sovdev-infrastructure (urbalurba-infrastructure) monitoring stack does **not use authentication** for OTLP clients by default. All endpoints are accessible without credentials.

**Production Authentication Setup**:
For production deployments requiring client authentication, refer to:
- **OpenTelemetry Collector Authentication**: https://opentelemetry.io/docs/collector/configuration/#extensions
  - Extensions: `basicauth`, `bearertokenauth`, `oidc`
  - Add to `extensions:` section in `033-otel-collector-config.yaml`
  - Enable in `service.extensions:` list
- **Traefik Authentication Middleware**: [rules-ingress-traefik.md](./rules-ingress-traefik.md)
  - Forward auth for SSO integration
  - BasicAuth for simple username/password protection

### **Troubleshooting Data Flow**

**No Data Reaching Backends**:
```bash
# 1. Check collector logs for export errors
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i error

# 2. Verify backend endpoints are reachable
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v http://loki-gateway.monitoring.svc.cluster.local:80/ready

# 3. Check collector configuration
kubectl get configmap -n monitoring -o yaml | grep -A 20 "exporters:"
```

### **Service Removal**

**Automated Removal**:
```bash
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use
./04-remove-otel-collector.sh rancher-desktop
```

**Manual Removal**:
```bash
# Remove Helm chart
helm uninstall otel-collector -n monitoring --kube-context rancher-desktop

# Remove IngressRoute
kubectl delete ingressroute -n monitoring otel-collector
```

## 🔧 Troubleshooting

### **Common Issues**

**Pods Not Starting**:
```bash
# Check pod events
kubectl describe pod -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Common causes:
# - Backend endpoints unreachable (check Loki/Tempo/Prometheus are deployed)
# - Configuration errors (check collector logs)
# - Image pull errors (check network)
```

**External Access Not Working**:
```bash
# 1. Check IngressRoute exists
kubectl get ingressroute -n monitoring otel-collector

# 2. Test with Host header
curl -v -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{}'

# 3. Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

**Data Not Reaching Loki**:
```bash
# Check collector → Loki export errors
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector | grep -i "loki\|error"

# Verify Loki OTLP endpoint is accessible
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never \
  -n monitoring -- \
  curl -v http://loki-gateway.monitoring.svc.cluster.local:80/otlp
```

**High Memory Usage**:
```bash
# Check memory usage
kubectl top pod -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Solutions:
# 1. Reduce batch size in config
# 2. Increase memory limits
# 3. Disable debug exporter in production
```

## 📋 Maintenance

### **Update OTLP Collector**:
```bash
# Update Helm chart to latest version
helm repo update
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -f /mnt/urbalurbadisk/manifests/033-otel-collector-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop
```

### **Configuration Changes**:
```bash
# 1. Edit configuration
vim /Users/terje.christensen/learn/redcross-public/urbalurba-infrastructure/manifests/033-otel-collector-config.yaml

# 2. Apply changes
helm upgrade otel-collector open-telemetry/opentelemetry-collector \
  -f /mnt/urbalurbadisk/manifests/033-otel-collector-config.yaml \
  -n monitoring \
  --kube-context rancher-desktop

# 3. Restart pods to pick up changes
kubectl rollout restart deployment -n monitoring otel-collector-opentelemetry-collector
```

## 🚀 Use Cases

### **1. sovdev-logger Integration**
See TypeScript integration example in Management Operations section above.

### **2. Multi-Language Support**
The OTLP Collector accepts telemetry from any language with OpenTelemetry SDK support:
- TypeScript/JavaScript, Python, Go, Java, .NET, PHP, Ruby, Rust

### **3. External Application Ingestion**
Applications running outside the cluster (on developer laptops, external servers) can send telemetry via the Traefik IngressRoute.

### **4. Debugging Data Flow**
Use debug exporter with sampling to verify data is flowing through pipelines without overwhelming logs.

---

**💡 Key Insight**: The OpenTelemetry Collector acts as the universal telemetry hub, providing a vendor-neutral ingestion point that decouples applications from backend storage systems. By centralizing telemetry collection and routing, it enables easy backend migration (swap Loki for another log system) without changing application instrumentation. The Traefik IngressRoute extends this capability to external applications, making the observability stack accessible beyond cluster boundaries.

## 🔗 Related Documentation

**Monitoring Stack**:
- **[Monitoring Overview](./package-monitoring-readme.md)** - Complete observability stack
- **[Prometheus Metrics](./package-monitoring-prometheus.md)** - Metrics backend
- **[Tempo Tracing](./package-monitoring-tempo.md)** - Trace backend
- **[Loki Logs](./package-monitoring-loki.md)** - Log backend
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Query and visualization

**Configuration & Rules**:
- **[Traefik IngressRoute](./rules-ingress-traefik.md)** - External access patterns
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest numbering (033, 039)
- **[Development Workflow](./rules-development-workflow.md)** - Configuration management

**External Resources**:
- **OTLP Specification**: https://opentelemetry.io/docs/specs/otlp/
- **Collector Configuration**: https://opentelemetry.io/docs/collector/configuration/
- **Receivers**: https://opentelemetry.io/docs/collector/configuration/#receivers
- **Processors**: https://opentelemetry.io/docs/collector/configuration/#processors
- **Exporters**: https://opentelemetry.io/docs/collector/configuration/#exporters
