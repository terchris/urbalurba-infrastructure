#!/bin/bash
# service-unity-catalog.sh - Unity Catalog service metadata
#
# Unity Catalog is an open-source data catalog for data governance.

# === Service Metadata (Required) ===
SCRIPT_ID="unity-catalog"
SCRIPT_NAME="Unity Catalog"
SCRIPT_DESCRIPTION="Open-source data catalog and governance"
SCRIPT_CATEGORY="DATASCIENCE"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="320-setup-unity-catalog.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n datascience -l app.kubernetes.io/name=unity-catalog --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="90"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Open-source data catalog for unified governance across data and AI assets"
SCRIPT_LOGO="unity-catalog-logo.webp"
SCRIPT_WEBSITE="https://www.unitycatalog.io"
SCRIPT_TAGS="data-catalog,governance,metadata,lakehouse,data-lineage"
SCRIPT_SUMMARY="Unity Catalog is an open-source data catalog that provides unified governance for data and AI assets. It enables fine-grained access control, data lineage tracking, and metadata management across your data lakehouse."
SCRIPT_DOCS="/docs/packages/datascience/unity-catalog"
