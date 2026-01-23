#!/bin/bash
# service-loki.sh - Loki service metadata
#
# Loki is a log aggregation system designed to work with Grafana.
# Part of the observability stack.

# === Service Metadata (Required) ===
SCRIPT_ID="loki"
SCRIPT_NAME="Loki"
SCRIPT_DESCRIPTION="Log aggregation and storage"
SCRIPT_CATEGORY="MONITORING"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="032-setup-loki.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n monitoring -l app.kubernetes.io/name=loki --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="032-remove-loki.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="11"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Horizontally-scalable log aggregation system"
SCRIPT_LOGO="loki-logo.webp"
SCRIPT_WEBSITE="https://grafana.com/oss/loki/"
SCRIPT_TAGS="logging,logs,aggregation,observability,monitoring"
SCRIPT_SUMMARY="Loki is a horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus. It indexes labels, not log content, making it cost-effective and easy to operate."
SCRIPT_DOCS="/docs/packages/monitoring/loki"
