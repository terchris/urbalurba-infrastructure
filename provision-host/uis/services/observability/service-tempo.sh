#!/bin/bash
# service-tempo.sh - Tempo service metadata
#
# Tempo is a distributed tracing backend.
# Part of the observability stack.

# === Service Metadata (Required) ===
SCRIPT_ID="tempo"
SCRIPT_NAME="Tempo"
SCRIPT_DESCRIPTION="Distributed tracing backend"
SCRIPT_CATEGORY="OBSERVABILITY"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="031-setup-tempo.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="031-remove-tempo.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="12"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Open source distributed tracing backend"
SCRIPT_LOGO="tempo-logo.webp"
SCRIPT_WEBSITE="https://grafana.com/oss/tempo/"
SCRIPT_TAGS="tracing,distributed-tracing,observability,monitoring,spans"
SCRIPT_SUMMARY="Tempo is an open source, easy-to-use, high-scale distributed tracing backend. It requires only object storage to operate and integrates seamlessly with Grafana, Prometheus, and Loki."
SCRIPT_DOCS="/docs/packages/observability/tempo"
