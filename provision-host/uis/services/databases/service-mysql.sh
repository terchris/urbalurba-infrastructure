#!/bin/bash
# service-mysql.sh - MySQL service metadata
#
# MySQL is an open-source relational database management system.

# === Service Metadata (Required) ===
SCRIPT_ID="mysql"
SCRIPT_NAME="MySQL"
SCRIPT_DESCRIPTION="Open-source relational database"
SCRIPT_CATEGORY="DATABASES"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="040-database-mysql.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n databases -l app.kubernetes.io/name=mysql --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="040-remove-database-mysql.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="31"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Popular open-source relational database for web applications"
SCRIPT_LOGO="mysql-logo.webp"
SCRIPT_WEBSITE="https://www.mysql.com"
