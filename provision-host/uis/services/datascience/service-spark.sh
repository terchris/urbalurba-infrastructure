#!/bin/bash
# service-spark.sh - Apache Spark service metadata
#
# Apache Spark is a unified analytics engine for large-scale data processing.

# === Service Metadata (Required) ===
SCRIPT_ID="spark"
SCRIPT_NAME="Apache Spark"
SCRIPT_DESCRIPTION="Unified analytics engine for big data"
SCRIPT_CATEGORY="DATASCIENCE"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="330-setup-spark.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n datascience -l app.kubernetes.io/name=spark --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="91"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Fast and general-purpose cluster computing system for big data processing"
SCRIPT_LOGO="spark-logo.webp"
SCRIPT_WEBSITE="https://spark.apache.org"
