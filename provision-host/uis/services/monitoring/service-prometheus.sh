#!/bin/bash
# service-prometheus.sh - Prometheus service metadata
#
# Prometheus is a time-series database for metrics collection and storage.
# Part of the observability stack.

# === Service Metadata (Required) ===
SCRIPT_ID="prometheus"
SCRIPT_NAME="Prometheus"
SCRIPT_DESCRIPTION="Metrics collection and storage for observability"
SCRIPT_CATEGORY="MONITORING"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="030-setup-prometheus.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="030-remove-prometheus.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="10"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Time-series database for metrics collection, storage, and alerting"
SCRIPT_LOGO="prometheus-logo.webp"
SCRIPT_WEBSITE="https://prometheus.io"
SCRIPT_TAGS="monitoring,metrics,alerting,time-series,observability"
SCRIPT_SUMMARY="Prometheus is a systems monitoring and alerting toolkit that collects metrics from configured targets, stores them locally, and provides a powerful query language (PromQL) for analysis and alerting."
SCRIPT_DOCS="/docs/packages/monitoring/prometheus"
