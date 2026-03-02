---
title: Tempo
sidebar_label: Tempo
---

# Tempo

Distributed tracing backend for request flow visualization.

| | |
|---|---|
| **Category** | Observability |
| **Deploy** | `./uis deploy tempo` |
| **Undeploy** | `./uis undeploy tempo` |
| **Depends on** | None |
| **Required by** | otel-collector, grafana |
| **Helm chart** | `grafana/tempo` (unpinned) |
| **Default namespace** | `monitoring` |

## What It Does

Tempo is the distributed tracing backend for UIS observability. It stores trace data received via OTLP and makes it queryable through Grafana using TraceQL.

Key capabilities:
- **OTLP receivers** — gRPC (port 4317) and HTTP (port 4318) ingestion
- **TraceQL** query language for searching traces by attributes
- **Metrics generator** — automatic service graph and span metrics
- **24-hour retention** for development environments
- **Jaeger/Zipkin compatible** — accepts traces from multiple protocols
- **Trace-to-logs correlation** in Grafana

## Deploy

```bash
./uis deploy tempo
```

No dependencies. Deploy before otel-collector and grafana.

## Verify

```bash
# Quick check
./uis verify tempo

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Test readiness
kubectl exec -it -n monitoring deploy/tempo -- wget -qO- http://localhost:3200/ready
```

## Configuration

Tempo configuration is in `manifests/031-tempo-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Retention | `24h` | Traces kept for 24 hours |
| gRPC port | `4317` | OTLP gRPC receiver |
| HTTP port | `4318` | OTLP HTTP receiver |
| Query port | `3200` | TraceQL API |
| Metrics generator | Enabled | Automatic service graphs |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/031-tempo-config.yaml` | Helm values (receivers, retention, metrics generator) |
| `ansible/playbooks/031-setup-tempo.yml` | Deployment playbook |
| `ansible/playbooks/031-remove-tempo.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy tempo
```

Services that depend on Tempo (otel-collector, grafana) will lose trace data.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=tempo
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo
```

**No traces appearing in Grafana:**
Check that the OTLP Collector is forwarding traces:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=20 | grep -i trace
```

**TraceQL queries returning empty:**
Verify Tempo is receiving data:
```bash
kubectl exec -it -n monitoring deploy/tempo -- wget -qO- http://localhost:3200/metrics | grep tempo_ingester
```

## Learn More

- [Official Tempo documentation](https://grafana.com/docs/tempo/latest/)
- [TraceQL query language](https://grafana.com/docs/tempo/latest/traceql/)
- [Grafana dashboards](./grafana.md)
