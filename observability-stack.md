# Observability Stack Setup for Local Cluster

This document contains the complete prompt for setting up the observability stack in the local Rancher Desktop cluster using the urbalurba-infrastructure repository.

## 🎯 Cursor Agent Prompt

You are helping me set up a complete observability stack for local development and testing in a Rancher Desktop Kubernetes cluster. This setup will receive OpenTelemetry traces and logs from applications running in devcontainers and provide visualization through web interfaces.

Your first task is to analyze requirements and the existing infrastructure and based on this make a plan that I need to approve before you start implementing the observability stack. 
The plan should be stored in the file `observability-stack-plan.md` in the root of the `urbalurba-infrastructure` repository.
Keep track of the progress and status in a separate file named observability-stack-status.md.


## Context and Requirements

### Repository Structure
- **Main repo**: `urbalurba-log` (contains logging libraries for 6 programming languages)
- **Infrastructure repo**: `urbalurba-infrastructure` (this repo)
- **Networking**: Traefik ingress controller provides external access via `*.localhost` URLs

### Current Setup
- Rancher Desktop Kubernetes cluster running locally
- Traefik ingress controller configured
- Services accessible via URLs like `http://service-name.localhost`
- Logging library (TypeScript) configured to send OTLP traces to configurable endpoints

### Networking Requirements
**Two Access Patterns Needed:**

1. **Developer Browser Access** (via Traefik):
   - `http://grafana.localhost` – Dashboards for metrics, logs, and traces
   - `http://tempo.localhost` – Distributed tracing backend  
   - `http://loki.localhost` – Log query interface
   - `http://prometheus.localhost` – Prometheus web UI

2. **DevContainer Application Access**:
   - OTLP Collector endpoint for receiving traces, logs, and metrics
   - Must be reachable from devcontainer applications
   - Likely hostname: `host.docker.internal:4318` or similar Rancher Desktop equivalent

### Technology Stack Required

**Core Observability Components:**
- **OpenTelemetry Collector** – Receives OTLP traces, logs, and metrics and routes them to backends
- **Grafana** – Main dashboard interface  
- **Loki** – Log aggregation backend
- **Tempo** – Distributed tracing backend
- **Prometheus** – Metrics collection, storage, and alerting


### Configuration Requirements

### OpenTelemetry Collector
- OTLP HTTP listener on port 4318
- Accepts traces, logs, and metrics
- Routes:
  - Traces → Tempo
  - Logs → Loki
  - Metrics → Prometheus

### Grafana
- Preconfigured data sources:
   - Prometheus (metrics)
   - Tempo (traces)
   - Loki (logs)
- Default dashboards for:
   - Node/pod performance
   - Application metrics
   - Trace and log correlation
- Web UI available at: http://grafana.localhost

### Tempo
- Receives distributed traces from OpenTelemetry Collector
- Enables trace visualization and correlation across services
- Web UI (frontend by Grafana Tempo plugin) available at: http://tempo.localhost

### Loki
- Ingests structured logs from OpenTelemetry Collector
- Allows full-text log search and filtering
- Correlates logs with traces and metrics using labels like traceID
- Web UI (via Grafana Explore tab) available at: http://loki.localhost


### Storage
- PersistentVolumeClaims for:
  - Grafana dashboards and config
  - Loki logs
  - Tempo traces
  - Prometheus metrics


### Expected Application Behavior

**Development Workflow:**
1. Developer runs application in devcontainer with environment config:
   ```bash
   # .env.test
   OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://[RANCHER_HOSTNAME]:4318/v1/traces
   OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://[RANCHER_HOSTNAME]:4318/v1/logs
   ```

2. Application sends structured logs and traces to OTLP Collector

3. Developer views traces and logs in Grafana at `http://grafana.localhost`

4. Traces include correlation IDs that link related logs and spans across services

### Deployment Requirements

**Kubernetes Manifests:**
- Deployment, Service, and Ingress resources for each component
- ConfigMaps for OpenTelemetry Collector and Grafana configurations
- PersistentVolumeClaims for data storage
- Use helm charts where appropriate

**Traefik Integration:**
- Ingress resources configured for Traefik
- Proper routing rules for `*.localhost` access
- HTTP-only for local development (no TLS complexity)

### Success Criteria

**Functional Requirements:**
1. All services deploy successfully to Kubernetes cluster
2. Web interfaces accessible via browser at `*.localhost` URLs
3. OTLP Collector accepts traces and logs from devcontainer applications
4. Grafana shows correlated traces and logs with proper data source integration
5. Trace IDs from application logs are searchable and linkable in Grafana

**Operational Requirements:**
1. Services restart properly after cluster restart
2. Data persists across service restarts
3. Resource usage appropriate for local development
4. Clear documentation for developers on how to access and use the stack

## Please Create

1. **Kubernetes manifests** for the complete observability stack
2. **Configuration files** for OpenTelemetry Collector and Grafana
3. **Deployment documentation** explaining the setup process
4. **Usage guide** for developers on accessing and using the tools
5. **Networking verification** instructions to confirm devcontainer connectivity

## Additional Considerations

- Keep resource requests/limits reasonable for local development
- Include health checks and readiness probes
- Consider using official container images with specific versions for stability
- Provide troubleshooting guidance for common networking issues between devcontainer and cluster

The goal is a production-like observability experience that developers can run locally to test and debug their applications with full trace and log correlation.

## Follow existing conventions in the `urbalurba-infrastructure` repository for consistency.

- read provision-host/kubernetes/02-database folders to see how scripts that initiate install is created
- read the correcponding playbooks that the scripts call in ansible/playbooks 
- read the manifets used by the playbooks in manifests 

## Filenames and locations to use

- The folder for the observability stack is `provision-host/kubernetes/11-monitoring`
- The numbering in ansible can start with 030- in the filename
- The numbering in manifests can start with 030- in the filename

## Namespace an variables

- Use the namespace `monitoring` for all observability components
- Read the topsecret/kubernetes/kubernetes-secrets-template.yml to see how namespace and variables are defined for other systems and use the same conventions in the plan.

