#!/bin/bash
# service-postgresql.sh - PostgreSQL service metadata
#
# PostgreSQL is a powerful open-source relational database.

# === Service Metadata (Required) ===
SCRIPT_ID="postgresql"
SCRIPT_NAME="PostgreSQL"
SCRIPT_DESCRIPTION="Open-source relational database"
SCRIPT_CATEGORY="DATABASES"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="040-database-postgresql.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n databases -l app=postgresql --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="040-remove-database-postgresql.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="30"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="World's most advanced open-source relational database"
SCRIPT_LOGO="postgresql-logo.webp"
SCRIPT_WEBSITE="https://www.postgresql.org"
SCRIPT_TAGS="database,sql,relational,postgres,rdbms"
SCRIPT_SUMMARY="PostgreSQL is a powerful, open-source object-relational database system with over 35 years of active development. It has earned a strong reputation for reliability, feature robustness, and performance."
SCRIPT_DOCS="/docs/packages/databases/postgresql"
