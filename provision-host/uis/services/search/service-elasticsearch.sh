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
SCRIPT_CHECK_COMMAND="kubectl get pods -n default -l app=elasticsearch-master --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="060-remove-elasticsearch.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="70"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="RESTful search and analytics engine for all types of data"
SCRIPT_LOGO="elasticsearch-logo.webp"
SCRIPT_WEBSITE="https://www.elastic.co/elasticsearch"
SCRIPT_TAGS="search,full-text,analytics,indexing,distributed"
SCRIPT_SUMMARY="Elasticsearch is a distributed, RESTful search and analytics engine capable of addressing a growing number of use cases. It centrally stores your data for lightning fast search and fine-tuned relevancy."
SCRIPT_DOCS="/docs/packages/search/elasticsearch"
