---
title: Loki
sidebar_label: Loki
---

# Loki

Log aggregation and storage with label-based indexing.

| | |
|---|---|
| **Category** | Observability |
| **Deploy** | `./uis deploy loki` |
| **Undeploy** | `./uis undeploy loki` |
| **Depends on** | None |
| **Required by** | otel-collector, grafana |
| **Helm chart** | `grafana/loki` (unpinned) |
| **Default namespace** | `monitoring` |

## What It Does

Loki is the log aggregation backend for UIS observability. Unlike traditional log systems, Loki indexes only labels (not full text), making it lightweight and cost-effective. Logs are queried using LogQL.

UIS deploys 3 components:
- **Loki** — stores and indexes logs
- **Loki Canary** — synthetic log generator for health monitoring
- **Loki Gateway** — nginx-based entry point for log ingestion

Key capabilities:
- **LogQL** query language for filtering and aggregating logs
- **Label-based indexing** — fast queries on stream selectors
- **JSON field extraction** — parse structured logs at query time
- **24-hour retention** with automatic compaction
- **OTLP ingestion** — receives logs from the OpenTelemetry Collector

## Deploy

```bash
./uis deploy loki
```

No dependencies. Deploy before otel-collector and grafana.

## Verify

```bash
# Quick check
./uis verify loki

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Test readiness
kubectl exec -it -n monitoring loki-0 -- wget -qO- http://localhost:3100/ready
```

## Configuration

Loki configuration is in `manifests/032-loki-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Retention | `24h` | Logs kept for 24 hours |
| Port | `3100` | Loki API |
| Mode | `SingleBinary` | All components in one process |
| Compaction | Enabled | Automatic log compaction |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/032-loki-config.yaml` | Helm values (retention, storage, limits) |
| `ansible/playbooks/032-setup-loki.yml` | Deployment playbook |
| `ansible/playbooks/032-remove-loki.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy loki
```

Services that depend on Loki (otel-collector, grafana) will lose log data.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=loki
kubectl logs -n monitoring -l app.kubernetes.io/name=loki
```

**No logs appearing in Grafana:**
Check that the Loki datasource is configured and that OTLP Collector is forwarding logs:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --tail=20
```

**Gateway returning 503:**
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/component=gateway
kubectl logs -n monitoring -l app.kubernetes.io/component=gateway
```

## Learn More

- [Official Loki documentation](https://grafana.com/docs/loki/latest/)
- [LogQL query language](https://grafana.com/docs/loki/latest/query/)
- [Grafana dashboards](./grafana.md)
