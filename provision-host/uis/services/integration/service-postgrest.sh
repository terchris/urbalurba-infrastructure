#!/bin/bash
# service-postgrest.sh - PostgREST service metadata
#
# PostgREST turns a curated PostgreSQL schema into a REST API. UIS
# deploys one PostgREST instance per consuming application; all
# instances share a namespace and the platform's PostgreSQL service.
#
# Multi-instance lifecycle (PLAN-002):
#   ./uis configure postgrest --app <name> [--database <db>] \
#       [--schema api_v1] [--url-prefix api-<name>]
#   ./uis deploy postgrest --app <name>
#
# See INVESTIGATE-postgrest.md and PLAN-002-postgrest-deployment.md.

# === Service Metadata (Required) ===
SCRIPT_ID="postgrest"
SCRIPT_NAME="PostgREST"
SCRIPT_DESCRIPTION="Auto-generated REST API from a curated PostgreSQL schema"
SCRIPT_CATEGORY="INTEGRATION"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="088-setup-postgrest.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get deploy -n postgrest -l app.kubernetes.io/name=postgrest --no-headers 2>/dev/null | grep -qE '\\s([1-9][0-9]*)/\\1\\s'"
SCRIPT_REMOVE_PLAYBOOK="088-remove-postgrest.yml"
SCRIPT_REQUIRES="postgresql"
SCRIPT_MULTI_INSTANCE="true"
SCRIPT_PRIORITY="50"

# === Deployment Details (Optional) ===
SCRIPT_IMAGE="postgrest/postgrest:v12.2.3"  # pinned 2026-04-29 per INVESTIGATE-version-pinning.md
SCRIPT_NAMESPACE="postgrest"

# === Extended Metadata (Optional) ===
SCRIPT_KIND="Component"
SCRIPT_TYPE="service"
SCRIPT_OWNER="platform-team"
# Multi-instance — see INVESTIGATE-postgrest.md Decisions #3, #16, #19
# Backstage shape per Decision #9 (deferred until Backstage deploys)
SCRIPT_CONSUMES_APIS="postgresql"
SCRIPT_PROVIDES_APIS=""  # TODO(backstage): emit per-instance <app>-rest entries when Backstage deploys

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="A platform service that turns a curated api_v1 PostgreSQL schema into a public REST API."
SCRIPT_SUMMARY="PostgREST is a single Haskell binary that introspects a PostgreSQL schema and exposes its tables and views as REST endpoints, with foreign keys becoming embedded-resource relations and OpenAPI 3.0 metadata served at GET /. UIS deploys one PostgREST instance per consuming application, all sharing a single namespace and the shared PostgreSQL service. Each instance is configured separately via ./uis configure postgrest --app <name>."
SCRIPT_LOGO="postgrest-logo.svg"
SCRIPT_WEBSITE="https://postgrest.org"
SCRIPT_TAGS="rest-api,postgrest,api-platform,postgresql,read-only"
SCRIPT_DOCS="/docs/services/integration/postgrest"
