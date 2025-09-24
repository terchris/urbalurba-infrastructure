#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/02-setup-tempo.sh
# Description: Deploy Grafana Tempo for distributed tracing storage
# Usage: ./02-setup-tempo.sh [target-host]
# Example: ./02-setup-tempo.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/232-setup-tempo.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "Grafana Tempo Deployment"
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
echo "Deploying Grafana Tempo..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ Grafana Tempo deployment completed!"
echo
echo "Access:"
echo "  🔍 Tempo endpoint: tempo.monitoring.svc.cluster.local:3200"
echo "  📊 Traces API: tempo.monitoring.svc.cluster.local:3200/api/traces"
echo
echo "Next steps:"
echo "  📋 Deploy Loki: ./03-setup-loki.sh $TARGET_HOST"
echo "  📊 Deploy Grafana: ./04-setup-grafana.sh $TARGET_HOST"