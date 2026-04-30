#!/bin/bash
# service-gravitee.sh - Gravitee API Management service metadata
#
# Gravitee APIM is an open-source API management platform: API gateway,
# admin Console, and Developer Portal. UIS deploys APIM 4.11 with
# PostgreSQL as the management/config store via the JDBC repository
# plugin (no MongoDB). Elasticsearch and Redis are intentionally not
# deployed; analytics dashboards and rate-limit policies are disabled.
#
# See PLAN-gravitee-postgresql-deployment.md and INVESTIGATE-gravitee-fix.md.

# === Service Metadata (Required) ===
SCRIPT_ID="gravitee"
SCRIPT_NAME="Gravitee"
SCRIPT_DESCRIPTION="API management and gateway platform"
SCRIPT_CATEGORY="INTEGRATION"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="090-setup-gravitee.yml"
SCRIPT_MANIFEST="091-gravitee-ingress.yaml"
SCRIPT_CHECK_COMMAND="kubectl get pods -n gravitee -l app.kubernetes.io/instance=gravitee-apim --no-headers 2>/dev/null | grep -qE '\\s(Running|Completed)\\s'"
SCRIPT_REMOVE_PLAYBOOK="090-remove-gravitee.yml"
SCRIPT_REQUIRES="postgresql"
SCRIPT_PRIORITY="50"

# === Deployment Details (Optional) ===
# Pinned at the latest stable 4.11.x as of 2026-04-30. The graviteeio/apim
# chart follows APIM versioning. Bump deliberately and re-run Phase 4
# validation; chart breakages are usually visible in Liquibase migration
# logs on first start of the Management API pod.
# SCRIPT_IMAGE is informational only — the chart pulls per-component images
# (graviteeio/apim-management-api, apim-gateway, apim-management-ui, apim-portal-ui).
SCRIPT_IMAGE="graviteeio/apim:4.11.3"
SCRIPT_HELM_CHART="graviteeio/apim"
SCRIPT_NAMESPACE="gravitee"

# === Extended Metadata (Optional) ===
SCRIPT_KIND="Component"
SCRIPT_TYPE="service"
SCRIPT_OWNER="platform-team"
SCRIPT_PROVIDES_APIS="gravitee-api"
SCRIPT_CONSUMES_APIS="postgresql"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="A platform service that runs Gravitee API Management with PostgreSQL as the metadata store and no Elasticsearch/Redis dependencies."
SCRIPT_LOGO="gravitee-logo.svg"
SCRIPT_WEBSITE="https://www.gravitee.io"
SCRIPT_TAGS="api-gateway,api-management,gravitee,postgresql"
SCRIPT_SUMMARY="Gravitee APIM is an open-source API gateway and management platform with admin Console, Developer Portal, and runtime API gateway. UIS deploys APIM 4.11 with PostgreSQL as the management store via the JDBC repository plugin (no MongoDB). Elasticsearch and Redis are not deployed; analytics dashboards and rate-limit policies are disabled. Suitable for laptop-scale development clusters."
SCRIPT_DOCS="/docs/services/integration/gravitee"
