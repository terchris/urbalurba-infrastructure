---
title: OpenTelemetry Collector
sidebar_label: OpenTelemetry Collector
---

# OpenTelemetry Collector

Telemetry data collection and processing

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

The OpenTelemetry Collector offers a vendor-agnostic implementation to receive, process, and export telemetry data. It removes the need to run multiple agents/collectors.

## Deploy

```bash
# Prerequisites — deploy dependencies first
./uis deploy prometheus
./uis deploy loki
./uis deploy tempo

# Deploy OpenTelemetry Collector
./uis deploy otel-collector
```

## Verify

```bash
# Quick check
./uis verify otel-collector

# Manual check
kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector
```

## Configuration

<!-- MANUAL: Service-specific configuration details -->
_No configuration documentation yet. Edit this section to add details about OpenTelemetry Collector settings, secrets, and customization options._

## Undeploy

```bash
./uis undeploy otel-collector
```

## Troubleshooting

<!-- MANUAL: Common issues and solutions -->
_No troubleshooting documentation yet. Edit this section to add common issues and their solutions._

## Learn More

- [Official OpenTelemetry Collector documentation](https://opentelemetry.io)
