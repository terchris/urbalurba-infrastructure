---
title: Prometheus
sidebar_label: Prometheus
---

# Prometheus

Metrics collection, storage, and alerting for the observability stack.

| | |
|---|---|
| **Category** | Observability |
| **Deploy** | `./uis deploy prometheus` |
| **Undeploy** | `./uis undeploy prometheus` |
| **Depends on** | None |
| **Required by** | otel-collector, grafana |
| **Helm chart** | `prometheus-community/prometheus` (unpinned) |
| **Default namespace** | `monitoring` |

## What It Does

Prometheus is the metrics backend for UIS observability. It scrapes metrics from Kubernetes nodes, pods, and services, stores them as time-series data, and provides PromQL for querying.

UIS deploys 5 components:
- **Prometheus Server** — scrapes and stores metrics, 15-day retention
- **Alertmanager** — handles alerts and notifications
- **Node Exporter** — collects host-level metrics (CPU, memory, disk)
- **Kube-State-Metrics** — exposes Kubernetes object states (pods, deployments)
- **Pushgateway** — accepts metrics from short-lived jobs

Prometheus also acts as a remote-write receiver, accepting metrics from the OpenTelemetry Collector.

## Deploy

```bash
./uis deploy prometheus
```

No dependencies. Deploy before otel-collector and grafana.

## Verify

```bash
# Quick check
./uis verify prometheus

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Test PromQL query
kubectl exec -it -n monitoring deploy/prometheus-server -- \
  wget -qO- "http://localhost:9090/api/v1/query?query=up" | head -c 200
```

## Configuration

Prometheus configuration is in `manifests/030-prometheus-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Retention | `15d` | Time-series data kept for 15 days |
| Port | `9090` | Prometheus server |
| Remote write | Enabled | Accepts metrics from OTLP Collector |
| ServiceMonitor | Enabled | Auto-discovers services with annotations |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/030-prometheus-config.yaml` | Helm values (retention, remote write, components) |
| `ansible/playbooks/030-setup-prometheus.yml` | Deployment playbook |
| `ansible/playbooks/030-remove-prometheus.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy prometheus
```

Services that depend on Prometheus (otel-collector, grafana) will lose metrics data.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

**Targets not being scraped:**
```bash
# Check targets via port-forward
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 &
# Visit http://localhost:9090/targets
```

**High memory usage:**
Prometheus memory scales with number of active time series. Check cardinality:
```bash
kubectl top pod -n monitoring -l app.kubernetes.io/name=prometheus
```

## Learn More

- [Official Prometheus documentation](https://prometheus.io/docs/)
- [PromQL query examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana dashboards](./grafana.md)
