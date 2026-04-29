#!/bin/bash
# service-postgrest.sh - PostgREST service metadata
#
# PostgREST turns a curated PostgreSQL schema into a REST API. UIS
# deploys one PostgREST instance per consuming application; all
# instances share a namespace and the platform's PostgreSQL service.
#
# This file currently contains METADATA ONLY — SCRIPT_PLAYBOOK is
# intentionally empty so the docs page renders, but ./uis deploy
# does not yet do anything. The implementation plan
# (PLAN-002-postgrest-implementation.md, not yet written) will
# add the playbook, configure handler, and Jinja templates.
#
# See INVESTIGATE-postgrest.md for the full design.

# === Service Metadata (Required) ===
SCRIPT_ID="postgrest"
SCRIPT_NAME="PostgREST"
SCRIPT_DESCRIPTION="Auto-generated REST API from a curated PostgreSQL schema"
SCRIPT_CATEGORY="INTEGRATION"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK=""
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get deploy -n postgrest -l app.kubernetes.io/name=postgrest --no-headers 2>/dev/null | grep -qE '\\s([1-9][0-9]*)/\\1\\s'"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES="postgresql"
SCRIPT_PRIORITY="50"

# === Deployment Details (Optional) ===
SCRIPT_IMAGE="postgrest/postgrest:<version-pinned-during-PLAN-002>"
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
SCRIPT_LOGO="postgrest-logo.png"
SCRIPT_WEBSITE="https://postgrest.org"
SCRIPT_TAGS="rest-api,postgrest,api-platform,postgresql,read-only"
SCRIPT_DOCS="/docs/services/integration/postgrest"
