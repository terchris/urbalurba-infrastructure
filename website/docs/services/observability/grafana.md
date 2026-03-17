---
title: Grafana
sidebar_label: Grafana
---

# Grafana

Visualization and dashboards for metrics, logs, and traces.

| | |
|---|---|
| **Category** | Observability |
| **Deploy** | `./uis deploy grafana` |
| **Undeploy** | `./uis undeploy grafana` |
| **Depends on** | prometheus, loki, tempo, otel-collector |
| **Required by** | None |
| **Helm chart** | `grafana/grafana` (unpinned) |
| **Default namespace** | `monitoring` |

## What It Does

Grafana is the visualization frontend for UIS observability. It connects to Prometheus (metrics), Loki (logs), and Tempo (traces) and provides a unified interface for exploring telemetry data.

Key capabilities:
- **Pre-configured datasources** — Prometheus, Loki, and Tempo connected automatically
- **Dashboard sidecar** — dashboards deployed as ConfigMaps are auto-loaded
- **Explore mode** — ad-hoc queries across all datasources
- **Correlation** — jump from metrics to logs to traces in a single workflow
- **Anonymous access** — enabled for development, no login required

UIS includes pre-built dashboards:
- **Test Suite Dashboard** — service health and deployment status
- **sovdev-metrics** — application-level metrics
- **sovdev-verification** — telemetry pipeline verification

## Deploy

```bash
# Deploy all observability dependencies first
./uis deploy prometheus
./uis deploy loki
./uis deploy tempo
./uis deploy otel-collector

# Deploy Grafana
./uis deploy grafana
```

Or use the observability stack:
```bash
./uis stack install observability
```

## Verify

```bash
# Quick check
./uis verify grafana

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://grafana.localhost
# Expected: 200
```

Access the dashboard at [http://grafana.localhost](http://grafana.localhost).

## Configuration

Grafana configuration is in `manifests/034-grafana-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `3000` | Web UI |
| Anonymous access | Enabled | No login required for development |
| Dashboard sidecar | Enabled | Auto-loads dashboards from ConfigMaps |
| Datasource sidecar | Enabled | Auto-configures Prometheus, Loki, Tempo |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/034-grafana-config.yaml` | Helm values (datasources, sidecar, anonymous access) |
| `manifests/034-grafana-dashboards-*.yaml` | Dashboard ConfigMaps (auto-loaded by sidecar) |
| `ansible/playbooks/034-setup-grafana.yml` | Deployment playbook |
| `ansible/playbooks/034-remove-grafana.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy grafana
```

This only removes the Grafana frontend. Backend services (Prometheus, Loki, Tempo) continue collecting data.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

**Datasource shows "No data":**
Check that the backend service is running:
```bash
kubectl get pods -n monitoring
```

**Dashboard not appearing:**
The sidecar watches for ConfigMaps with label `grafana_dashboard: "1"`. Check:
```bash
kubectl get configmap -n monitoring -l grafana_dashboard=1
```

**`http://grafana.localhost` returns nothing:**
Check that the IngressRoute exists:
```bash
kubectl get ingressroute -n monitoring | grep grafana
```

## Learn More

- [Official Grafana documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus metrics](./prometheus.md)
- [Loki logs](./loki.md)
- [Tempo traces](./tempo.md)
