#!/bin/bash
# service-otel-collector.sh - OpenTelemetry Collector service metadata
#
# OpenTelemetry Collector receives, processes, and exports telemetry data.
# Part of the observability stack.

# === Service Metadata (Required) ===
SCRIPT_ID="otel-collector"
SCRIPT_NAME="OpenTelemetry Collector"
SCRIPT_DESCRIPTION="Telemetry data collection and processing"
SCRIPT_CATEGORY="MONITORING"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="033-setup-otel-collector.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n monitoring -l app.kubernetes.io/name=opentelemetry-collector --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="033-remove-otel-collector.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="13"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Vendor-agnostic telemetry collection and processing"
SCRIPT_LOGO="opentelemetry-logo.webp"
SCRIPT_WEBSITE="https://opentelemetry.io"
