#!/bin/bash
# service-elasticsearch.sh - Elasticsearch service metadata
#
# Elasticsearch is a distributed search and analytics engine.

# === Service Metadata (Required) ===
SCRIPT_ID="elasticsearch"
SCRIPT_NAME="Elasticsearch"
SCRIPT_DESCRIPTION="Distributed search and analytics engine"
SCRIPT_CATEGORY="SEARCH"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="060-setup-elasticsearch.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n search -l app=elasticsearch --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="70"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="RESTful search and analytics engine for all types of data"
SCRIPT_LOGO="elasticsearch-logo.webp"
SCRIPT_WEBSITE="https://www.elastic.co/elasticsearch"
