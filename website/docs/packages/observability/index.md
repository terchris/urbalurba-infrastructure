---
title: Observability
sidebar_label: Observability
---

# Observability

The observability package provides metrics, logs, and traces for all services running in UIS. All components are designed to work together as an integrated stack.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [Prometheus](./prometheus.md) | Metrics collection and storage | `./uis deploy prometheus` |
| [Loki](./loki.md) | Log aggregation with label-based indexing | `./uis deploy loki` |
| [Tempo](./tempo.md) | Distributed tracing backend | `./uis deploy tempo` |
| [OTLP Collector](./otel.md) | Telemetry pipeline routing to all backends | `./uis deploy otel-collector` |
| [Grafana](./grafana.md) | Visualization dashboards for all data | `./uis deploy grafana` |

## Quick Start

Deploy the full observability stack in order:

```bash
./uis stack install observability
```

Or deploy individually:

```bash
./uis deploy prometheus
./uis deploy loki
./uis deploy tempo
./uis deploy otel-collector
./uis deploy grafana
```

## How It Works

```
Applications → OTLP Collector → Prometheus (metrics)
                               → Loki (logs)
                               → Tempo (traces)
                                      ↓
                                   Grafana (visualization)
```

1. Applications send telemetry via OTLP protocol to the collector
2. The collector routes data to the appropriate backend
3. Grafana queries all three backends for unified visualization
4. Pre-built dashboards show service health and telemetry pipeline status

All services deploy to the `monitoring` namespace.
