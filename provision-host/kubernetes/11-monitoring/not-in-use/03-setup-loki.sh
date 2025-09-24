#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/03-setup-loki.sh
# Description: Deploy Grafana Loki for log aggregation
# Usage: ./03-setup-loki.sh [target-host]
# Example: ./03-setup-loki.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/233-setup-loki.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "Grafana Loki Deployment"
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
echo "Deploying Grafana Loki..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ Grafana Loki deployment completed!"
echo
echo "Access:"
echo "  📋 Loki endpoint: loki.monitoring.svc.cluster.local:3100"
echo "  📊 Push API: loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
echo "  🔍 Query API: loki.monitoring.svc.cluster.local:3100/loki/api/v1/query"
echo
echo "Next steps:"
echo "  📊 Deploy Grafana: ./04-setup-grafana.sh $TARGET_HOST"