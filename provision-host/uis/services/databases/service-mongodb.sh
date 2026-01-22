#!/bin/bash
# service-mongodb.sh - MongoDB service metadata
#
# MongoDB is a document-oriented NoSQL database.

# === Service Metadata (Required) ===
SCRIPT_ID="mongodb"
SCRIPT_NAME="MongoDB"
SCRIPT_DESCRIPTION="Document-oriented NoSQL database"
SCRIPT_CATEGORY="DATABASES"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="040-setup-mongodb.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n databases -l app=mongodb --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="040-remove-database-mongodb.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="31"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="General purpose document database"
SCRIPT_LOGO="mongodb-logo.webp"
SCRIPT_WEBSITE="https://www.mongodb.com"
