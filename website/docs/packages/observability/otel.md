---
title: OpenTelemetry Collector
sidebar_label: OTLP Collector
---

# OpenTelemetry Collector

Telemetry data collection, processing, and multi-backend routing.

| | |
|---|---|
| **Category** | Observability |
| **Deploy** | `./uis deploy otel-collector` |
| **Undeploy** | `./uis undeploy otel-collector` |
| **Depends on** | prometheus, loki, tempo |
| **Required by** | grafana |
| **Helm chart** | `open-telemetry/opentelemetry-collector` (unpinned) |
| **Default namespace** | `monitoring` |

## What It Does

The OpenTelemetry Collector is the central telemetry pipeline for UIS. It receives logs, traces, and metrics from applications via OTLP protocol and routes them to the appropriate backends:

- **Traces** → Tempo (via OTLP gRPC)
- **Logs** → Loki (via Loki exporter)
- **Metrics** → Prometheus (via remote write)

Key capabilities:
- **OTLP receivers** — HTTP (port 4318) and gRPC (port 4317)
- **Resource processing** — enriches telemetry with Kubernetes metadata
- **Transform processing** — maps attributes between formats
- **Debug exporter** — sampled output for troubleshooting pipelines
- **External access** — Traefik IngressRoute for applications outside the cluster

## Deploy

```bash
# Deploy backends first
./uis deploy prometheus
./uis deploy loki
./uis deploy tempo

# Deploy the collector
./uis deploy otel-collector
```

## Verify

```bash
# Quick check
./uis verify otel-collector

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector

# Test OTLP HTTP endpoint
kubectl exec -it -n monitoring deploy/otel-collector -- \
  wget -qO- http://localhost:13133/
```

## Configuration

OTLP Collector configuration is in `manifests/033-otel-collector-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| OTLP gRPC | `4317` | For instrumented applications |
| OTLP HTTP | `4318` | For HTTP-based telemetry |
| Health check | `13133` | Collector health endpoint |
| External access | `otel.localhost` | Via Traefik IngressRoute |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/033-otel-collector-config.yaml` | Helm values (receivers, processors, exporters, pipelines) |
| `ansible/playbooks/033-setup-otel-collector.yml` | Deployment playbook |
| `ansible/playbooks/033-remove-otel-collector.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy otel-collector
```

Applications sending telemetry to the collector will get connection errors. Grafana will still display historical data from Prometheus, Loki, and Tempo.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
```

**Telemetry not reaching backends:**
Check the pipeline is healthy:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=30 | grep -i error
```

**External applications can't send telemetry:**
Verify the IngressRoute exists:
```bash
kubectl get ingressroute -n monitoring | grep otel
```

## Learn More

- [Official OpenTelemetry Collector documentation](https://opentelemetry.io/docs/collector/)
- [OTLP protocol specification](https://opentelemetry.io/docs/specs/otlp/)
- [Grafana dashboards](./grafana.md)
