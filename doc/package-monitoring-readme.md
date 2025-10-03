# Monitoring & Observability - Complete Observability Stack

**File**: `doc/package-monitoring-readme.md`
**Purpose**: Overview of all monitoring and observability services in Urbalurba infrastructure
**Target Audience**: DevOps engineers, developers, system administrators, platform engineers
**Last Updated**: October 3, 2025

**Deployed Versions**:
- Prometheus v3.6.0 (chart 27.39.0)
- Tempo v2.8.2 (chart 1.23.3)
- Loki v3.5.5 (chart 6.41.1)
- OpenTelemetry Collector v0.136.0 (chart 0.136.1)
- Grafana v12.1.1 (chart 10.0.0)

## 📋 Overview

Urbalurba infrastructure provides a comprehensive observability stack built on industry-standard open-source tools. The monitoring system implements the three pillars of observability: **metrics** (Prometheus), **traces** (Tempo), and **logs** (Loki), unified through **OpenTelemetry** and visualized in **Grafana**.

This architecture enables:
- **Full-stack observability**: Monitor infrastructure, applications, and business metrics
- **Distributed tracing**: Track requests across microservices
- **Log aggregation**: Centralized logging with powerful query capabilities
- **Unified visualization**: Single pane of glass for all observability data

**Available Monitoring Services**:
- **Prometheus**: Metrics collection, storage, and alerting
- **Tempo**: Distributed tracing backend
- **Loki**: Log aggregation and querying
- **OpenTelemetry Collector**: Vendor-neutral telemetry pipeline
- **Grafana**: Visualization, dashboards, and data exploration

## 📊 Monitoring Services

### **Prometheus - Metrics & Alerting** 🥇
**Status**: ✅ Active | **Port**: 9090 | **Type**: Metrics Database

**Key Features**: Time-Series Database • PromQL Query Language • Service Discovery • Multi-Dimensional Data Model • Alerting Rules • Prometheus Operator

Prometheus serves as the **primary metrics backend** with powerful querying capabilities and native Kubernetes integration. Uses Prometheus Operator for automated service monitoring and alert management.

**Key Capabilities**:
- **Metrics Collection**: Pull-based scraping from Kubernetes services
- **Time-Series Storage**: Efficient storage with configurable retention
- **PromQL**: Powerful query language for metrics analysis
- **Service Discovery**: Automatic discovery of Kubernetes services

**Configuration**: `manifests/030-prometheus-config.yaml`
**Deployment**: `ansible/playbooks/030-setup-prometheus.yml`

📚 **[Complete Documentation →](./package-monitoring-prometheus.md)**

---

### **Tempo - Distributed Tracing** 🔍
**Status**: ✅ Active | **Port**: 3100 (query), 4317 (gRPC), 4318 (HTTP) | **Type**: Trace Backend

**Key Features**: Distributed Tracing • Jaeger/Zipkin/OTLP Support • Cost-Effective Storage • High-Volume Ingestion • TraceQL Query Language

High-performance distributed tracing backend designed for cloud-native applications. Accepts traces via OpenTelemetry, Jaeger, and Zipkin protocols with minimal storage overhead.

**Key Capabilities**:
- **OTLP Native**: Primary ingestion via OpenTelemetry Collector
- **TraceQL**: Query traces with powerful filtering
- **Low Storage Cost**: Efficient object storage backend
- **Multi-Tenancy**: Isolated trace data per tenant

**Configuration**: `manifests/031-tempo-config.yaml`
**Deployment**: `ansible/playbooks/031-setup-tempo.yml`

📚 **[Complete Documentation →](./package-monitoring-tempo.md)**

---

### **Loki - Log Aggregation** 📝
**Status**: ✅ Active | **Port**: 3100 | **Type**: Log Database

**Key Features**: Log Aggregation • LogQL Query Language • Label-Based Indexing • Cost-Effective Storage • Grafana Integration • Multi-Tenancy

Like Prometheus but for logs - Loki indexes labels not full-text, making it extremely efficient for cloud-native logging. Designed to work seamlessly with Grafana and Prometheus.

**Key Capabilities**:
- **Label-Based Indexing**: Fast queries without full-text indexing
- **LogQL**: Familiar PromQL-like query syntax
- **OTLP Ingestion**: Receives logs via OpenTelemetry Collector
- **Low Cost**: Minimal storage and operational overhead

**Configuration**: `manifests/032-loki-config.yaml`
**Deployment**: `ansible/playbooks/032-setup-loki.yml`

📚 **[Complete Documentation →](./package-monitoring-loki.md)**

---

### **OpenTelemetry Collector - Telemetry Pipeline** 🔄
**Status**: ✅ Active | **Port**: 4317 (gRPC), 4318 (HTTP) | **Type**: Telemetry Gateway

**Key Features**: Vendor-Neutral Protocol • Logs/Traces/Metrics • HTTP & gRPC Endpoints • Traefik IngressRoute • External Ingestion • Multi-Backend Export

Central telemetry collection hub that receives OpenTelemetry Protocol (OTLP) data from applications and routes it to Prometheus, Tempo, and Loki backends.

**Key Capabilities**:
- **OTLP Receivers**: HTTP (4318) and gRPC (4317) endpoints
- **External Access**: Traefik IngressRoute at `http://otel.localhost/v1/logs`
- **Multi-Export**: Routes logs to Loki, traces to Tempo, metrics to Prometheus
- **Protocol Translation**: Converts OTLP to backend-specific formats

**Configuration**: `manifests/033-otel-collector-config.yaml`
**IngressRoute**: `manifests/039-otel-collector-ingressroute.yaml`
**Deployment**: `ansible/playbooks/033-setup-otel-collector.yml`

📚 **[Complete Documentation →](./package-monitoring-otel.md)**

---

### **Grafana - Visualization Platform** 📈
**Status**: ✅ Active | **Port**: 80 (UI) | **Type**: Visualization & Dashboards

**Key Features**: Unified Dashboards • Multi-Datasource Queries • Dashboard Sidecar • Alert Management • User Authentication • Dashboard as Code

Grafana provides unified visualization for all observability data with pre-configured datasources for Prometheus, Tempo, and Loki. Dashboards are managed as ConfigMaps and auto-loaded via sidecar.

**Key Capabilities**:
- **Pre-Configured Datasources**: Prometheus, Loki, Tempo ready to use
- **Dashboard Sidecar**: Auto-loads dashboards from ConfigMaps
- **Unified Queries**: Correlate metrics, logs, and traces
- **Authentik SSO**: Optional authentication via forward auth

**Configuration**: `manifests/034-grafana-config.yaml`
**Dashboards**: `manifests/035-grafana-dashboards.yaml`, `036-grafana-sovdev-verification.yaml`
**IngressRoute**: `manifests/038-grafana-ingressroute.yaml`
**Deployment**: `ansible/playbooks/034-setup-grafana.yml`

📚 **[Complete Documentation →](./package-monitoring-grafana.md)**

## 🏗️ Architecture

### **Observability Data Flow**
```
Applications (with OTLP SDK)
         │
         ├─► Logs ────────────────────┐
         ├─► Traces ──────────────────┤
         └─► Metrics ─────────────────┤
                                      ▼
                    ┌──────────────────────────────┐
                    │  OpenTelemetry Collector     │
                    │  (OTLP Receiver)             │
                    │  - HTTP: 4318                │
                    │  - gRPC: 4317                │
                    │  - Ingress: otel.localhost   │
                    └──────────────────────────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                ▼                ▼                ▼
         ┌──────────┐     ┌──────────┐    ┌──────────┐
         │   Loki   │     │  Tempo   │    │Prometheus│
         │  (Logs)  │     │ (Traces) │    │ (Metrics)│
         └──────────┘     └──────────┘    └──────────┘
                │                │                │
                └────────────────┼────────────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │    Grafana      │
                        │  (Visualization)│
                        │  grafana.localhost
                        └─────────────────┘
```

### **Namespace & Deployment**
All monitoring services are deployed in the `monitoring` namespace:

```
kubectl get pods -n monitoring

COMPONENT                           STATUS
otel-collector-xxx                  Running   # OTLP ingestion
prometheus-xxx                      Running   # Metrics backend
tempo-xxx                           Running   # Trace backend
loki-0                             Running   # Log backend
grafana-xxx                         Running   # Visualization
```

### **File Structure**
```
manifests/
├── 030-prometheus-config.yaml              # Prometheus Helm values
├── 031-tempo-config.yaml                   # Tempo Helm values
├── 032-loki-config.yaml                    # Loki Helm values
├── 033-otel-collector-config.yaml          # OTLP Collector Helm values
├── 034-grafana-config.yaml                 # Grafana Helm values
├── 035-grafana-dashboards.yaml             # Installation test dashboards
├── 036-grafana-sovdev-verification.yaml    # sovdev-logger verification
├── 038-grafana-ingressroute.yaml           # Grafana UI ingress
└── 039-otel-collector-ingressroute.yaml    # OTLP Collector ingress

ansible/playbooks/
├── 030-setup-prometheus.yml                # Prometheus deployment
├── 030-remove-prometheus.yml               # Prometheus removal
├── 031-setup-tempo.yml                     # Tempo deployment
├── 031-remove-tempo.yml                    # Tempo removal
├── 032-setup-loki.yml                      # Loki deployment
├── 032-remove-loki.yml                     # Loki removal
├── 033-setup-otel-collector.yml            # OTLP Collector deployment
├── 033-remove-otel-collector.yml           # OTLP Collector removal
├── 034-setup-grafana.yml                   # Grafana deployment
└── 034-remove-grafana.yml                  # Grafana removal

provision-host/kubernetes/11-monitoring/not-in-use/
├── 00-setup-all-monitoring.sh              # Deploy all monitoring services
├── 00-remove-all-monitoring.sh             # Remove all monitoring services
├── 01-setup-prometheus.sh                  # Prometheus deployment script
├── 01-remove-prometheus.sh                 # Prometheus removal script
├── 02-setup-tempo.sh                       # Tempo deployment script
├── 02-remove-tempo.sh                      # Tempo removal script
├── 03-setup-loki.sh                        # Loki deployment script
├── 03-remove-loki.sh                       # Loki removal script
├── 04-setup-otel-collector.sh              # OTLP Collector deployment script
├── 04-remove-otel-collector.sh             # OTLP Collector removal script
├── 05-setup-grafana.sh                     # Grafana deployment script
└── 05-remove-grafana.sh                    # Grafana removal script
```

### **Storage & Persistence**
All monitoring services use Kubernetes PersistentVolumeClaims:
- **Prometheus**: Configurable retention (default 15d)
- **Tempo**: Object storage for traces
- **Loki**: Chunk storage for logs
- **Grafana**: Dashboard and configuration persistence

## 🚀 Quick Start

### **Deploy Complete Monitoring Stack**

**Option 1: Automated Deployment (Recommended)**
```bash
# All monitoring services deploy automatically during cluster build
./install-rancher.sh
```

**Option 2: Manual Deployment (for testing/development)**
```bash
# Enter provision-host container
docker exec -it provision-host bash

# Navigate to monitoring scripts
cd /mnt/urbalurbadisk/provision-host/kubernetes/11-monitoring/not-in-use

# Deploy all monitoring services
./00-setup-all-monitoring.sh rancher-desktop
```

**Option 3: Deploy Individual Services**
```bash
# Deploy in order (dependencies matter!)
./01-setup-prometheus.sh rancher-desktop
./02-setup-tempo.sh rancher-desktop
./03-setup-loki.sh rancher-desktop
./04-setup-otel-collector.sh rancher-desktop
./05-setup-grafana.sh rancher-desktop
```

### **Access Monitoring Services**

**Grafana UI**:
```bash
# Open in browser
http://grafana.localhost

# Default credentials (if auth not configured)
# Username: admin
# Password: (from urbalurba-secrets ConfigMap)
```

**OTLP Collector Ingestion**:
```bash
# Logs endpoint
http://otel.localhost/v1/logs

# Traces endpoint
http://otel.localhost/v1/traces

# Required header for localhost routing
Host: otel.localhost
```

**Prometheus UI** (internal only):
```bash
# Port forward to access
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open in browser
http://localhost:9090
```

### **Verify Stack Health**
```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Verify Grafana datasources
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://localhost:3000/api/datasources

# Test OTLP endpoint
curl -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test"}}]},"scopeLogs":[{"logRecords":[{"body":{"stringValue":"test log"}}]}]}]}'
```

## 🔍 Integration Patterns

### **Application Instrumentation**

**OpenTelemetry SDK (Recommended)**:
```typescript
// TypeScript example using @sovdev/logger
import { initializeSovdevLogger } from '@sovdev/logger';

// Initialize with OTLP endpoint
initializeSovdevLogger('my-service-name');

// Environment variables
SYSTEM_ID=my-service-name
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://127.0.0.1/v1/logs
OTEL_EXPORTER_OTLP_HEADERS={"Host":"otel.localhost"}
```

**Query Logs in Grafana**:
```logql
# LogQL query
{service_name="my-service-name"}

# Filter by level
{service_name="my-service-name"} |= "error"

# Regex pattern
{service_name=~"sovdev-test.*"}
```

### **Dashboard Management**

**Auto-Loading Pattern**:
```yaml
# Create ConfigMap with label
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"  # Triggers sidecar auto-load
data:
  dashboard.json: |
    { ... dashboard JSON ... }
```

**Apply and Verify**:
```bash
kubectl apply -f manifests/036-my-dashboard.yaml

# Wait ~30 seconds for sidecar to reload
kubectl rollout restart deployment/grafana -n monitoring
```

## 🔧 Troubleshooting

### **Common Issues**

**No data in Grafana**:
```bash
# 1. Verify datasource configuration
kubectl exec -n monitoring deployment/grafana -- \
  curl -s http://localhost:3000/api/datasources

# 2. Check Loki for labels
kubectl exec -n monitoring loki-0 -c loki -- \
  wget -q -O - 'http://localhost:3100/loki/api/v1/labels'

# 3. Test OTLP collector connectivity
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
```

**Dashboard not loading**:
```bash
# 1. Verify ConfigMap exists with correct label
kubectl get configmap -n monitoring -l grafana_dashboard=1

# 2. Check Grafana sidecar logs
kubectl logs -n monitoring deployment/grafana -c grafana-sc-dashboard

# 3. Restart Grafana to force reload
kubectl rollout restart deployment/grafana -n monitoring
```

**OTLP ingestion failing**:
```bash
# 1. Verify IngressRoute exists
kubectl get ingressroute -n monitoring otel-collector

# 2. Check Host header routing
curl -v -X POST http://127.0.0.1/v1/logs \
  -H "Host: otel.localhost" \
  -H "Content-Type: application/json" \
  -d '{...}'

# 3. Check OTLP collector logs
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=50
```

## 🔗 Related Documentation

**Core Documentation**:
- **[Prometheus Metrics Backend](./package-monitoring-prometheus.md)** - Metrics collection and alerting
- **[Tempo Tracing Backend](./package-monitoring-tempo.md)** - Distributed tracing
- **[Loki Log Aggregation](./package-monitoring-loki.md)** - Log storage and querying
- **[OpenTelemetry Collector](./package-monitoring-otel.md)** - OTLP ingestion pipeline
- **[Grafana Visualization](./package-monitoring-grafana.md)** - Dashboards and exploration

**Integration Guides**:
- **[Traefik IngressRoute Patterns](./rules-ingress-traefik.md)** - Routing configuration for Grafana and OTLP
- **[Secrets Management](./rules-secrets-management.md)** - Managing Grafana admin credentials
- **[Naming Conventions](./rules-naming-conventions.md)** - Manifest and playbook numbering (030-039)
- **[Development Workflow](./rules-development-workflow.md)** - Working with monitoring configuration

**Provisioning**:
- **[Automated Deployment Rules](./rules-automated-kubernetes-deployment.md)** - Orchestration patterns
- **[Provisioning Scripts](./rules-provisioning.md)** - Shell script standards

---

**💡 Key Insight**: The monitoring stack is designed as a unified observability platform where all three pillars (metrics, logs, traces) are collected via OpenTelemetry, stored in purpose-built backends (Prometheus, Loki, Tempo), and visualized together in Grafana. This architecture provides complete visibility into application behavior while maintaining operational simplicity through standardized protocols and automation.
