# Observability Stack Implementation Plan

## Overview
This plan describes the step-by-step implementation of a local observability stack for Rancher Desktop Kubernetes, following the requirements in observability-stack.md and conventions from the urbalurba-infrastructure repository.

---

## 1. Components & Responsibilities
- **OpenTelemetry Collector**: Receives OTLP traces/logs/metrics from devcontainers, routes to backends.
- **Grafana**: Dashboards for metrics, logs, traces. Preconfigured datasources.
- **Loki**: Log aggregation backend.
- **Tempo**: Distributed tracing backend.
- **Prometheus**: Metrics collection, storage, alerting.

---

## 2. Directory & File Structure
- **Scripts**: `provision-host/kubernetes/11-monitoring/`
  - `030-setup-observability.sh` (installs stack via Helm/Ansible)
- **Ansible Playbooks**: `ansible/playbooks/`
  - `030-setup-observability.yml`
- **Manifests**: `manifests/`
  - `030-grafana-config.yaml`, `030-grafana-ingress.yaml`, etc.
- **Config/Secrets**: Use `topsecret/kubernetes/kubernetes-secrets-template.yml` for admin users/passwords.

---

## 3. Installation Approach
- Use **Helm charts** for all components (Grafana, Loki, Tempo, Prometheus, OpenTelemetry Collector) unless a requirement cannot be met (will request clarification if so).
- Use **LTS/stable versions** for all charts.
- Use **default storage class** for all PVCs.
- All resources in the `monitoring` namespace.

---

## 4. Kubernetes Resources
- **Namespace**: `monitoring` (created if not exists)
- **HelmReleases/Helm install** for each component
- **ConfigMaps** for custom config (e.g., OpenTelemetry Collector pipeline, Grafana datasources)
- **PersistentVolumeClaims** for data (Grafana, Loki, Tempo, Prometheus)
- **Ingress** for each UI (Traefik, `*.localhost`)
- **Secrets**: Use admin user/password from `kubernetes-secrets-template.yml` for Grafana and other UIs

---

## 5. Networking & Access
- **Ingress**: Traefik, HTTP only, routes:
  - `grafana.localhost` → Grafana
  - `loki.localhost` → Loki
  - `tempo.localhost` → Tempo
  - `prometheus.localhost` → Prometheus
- **OTLP Endpoint**: OpenTelemetry Collector listens on `4318` (HTTP), accessible from devcontainers (e.g., `host.docker.internal:4318`)

---

## 6. Configuration
- **Grafana**: Preconfigure datasources (Prometheus, Loki, Tempo), default dashboards, admin user/password from secrets
- **OpenTelemetry Collector**: Pipeline for traces/logs/metrics → correct backends
- **Loki/Tempo/Prometheus**: Minimal config for local dev, persistent storage

---

## 7. Documentation
- **Deployment guide**: How to install and verify the stack
- **Usage guide**: How to access UIs, send traces/logs from devcontainers
- **Troubleshooting**: Common networking issues, how to check pod logs, etc.

---

## 8. Status Tracking
- Progress and issues tracked in `observability-stack-status.md`

---

## 9. Open Questions / Assumptions
- All components can be installed via Helm; if not, will request clarification.
- Default storage class is available and sufficient for all PVCs.
- Using admin user/password from secrets for all UIs is acceptable for local dev.
- No additional authentication/OAuth required for UIs.
- If any of these assumptions are incorrect, please clarify before implementation.

---

## 10. Next Steps
1. Create/verify `monitoring` namespace
2. Write install script and Ansible playbook
3. Write/adjust manifests and configs
4. Prepare documentation
5. Test deployment and update status file 