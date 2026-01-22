#!/bin/bash
# service-whoami.sh - Whoami test service metadata
#
# Whoami is a simple test container that returns request information.

# === Service Metadata (Required) ===
SCRIPT_ID="whoami"
SCRIPT_NAME="Whoami"
SCRIPT_DESCRIPTION="Test service for debugging"
SCRIPT_CATEGORY="CORE"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="025-setup-whoami-testpod.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n default -l app=whoami --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="2"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Lightweight test container for debugging ingress and authentication"
SCRIPT_LOGO=""
SCRIPT_WEBSITE="https://github.com/traefik/whoami"
