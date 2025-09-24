#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/04-setup-grafana.sh
# Description: Deploy Grafana for observability dashboards
# Usage: ./04-setup-grafana.sh [target-host]
# Example: ./04-setup-grafana.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/234-setup-grafana.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "Grafana Deployment"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo "Playbook: $PLAYBOOK_PATH"
echo

# Validate ansible playbook exists
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: Ansible playbook not found at $PLAYBOOK_PATH"
    exit 1
fi

# Execute ansible playbook
echo "Deploying Grafana..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ Grafana deployment completed!"
echo
echo "Access:"
echo "  📊 Grafana UI: http://grafana.localhost (local development)"
echo "  📊 Grafana UI: https://grafana.urbalurba.no (external access)"
echo "  🔐 Default credentials in kubernetes secrets"
echo
echo "Data Sources configured:"
echo "  🔍 Tempo: http://tempo.monitoring.svc.cluster.local:3200"
echo "  📋 Loki: http://loki.monitoring.svc.cluster.local:3100"