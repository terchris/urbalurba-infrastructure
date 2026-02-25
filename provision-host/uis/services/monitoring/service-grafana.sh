#!/bin/bash
# service-grafana.sh - Grafana service metadata
#
# Grafana provides dashboards and visualization for metrics, logs, and traces.
# Part of the observability stack.

# === Service Metadata (Required) ===
SCRIPT_ID="grafana"
SCRIPT_NAME="Grafana"
SCRIPT_DESCRIPTION="Visualization and dashboards for observability"
SCRIPT_CATEGORY="MONITORING"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="034-setup-grafana.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="034-remove-grafana.yml"
SCRIPT_REQUIRES="prometheus loki tempo otel-collector"
SCRIPT_PRIORITY="20"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Observability platform for metrics, logs, and distributed tracing"
SCRIPT_LOGO="grafana-logo.webp"
SCRIPT_WEBSITE="https://grafana.com"
SCRIPT_TAGS="monitoring,dashboards,visualization,observability,metrics,logs"
SCRIPT_SUMMARY="Grafana is the open-source analytics and monitoring solution for every database. Create, explore, and share dashboards with your team and foster a data-driven culture."
SCRIPT_DOCS="/docs/packages/monitoring/grafana"
