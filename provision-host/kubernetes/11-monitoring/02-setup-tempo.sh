#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/02-setup-tempo.sh
# Description: Deploy Grafana Tempo for distributed tracing storage
# Usage: ./02-setup-tempo.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo "Grafana Tempo Deployment"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Deploying Grafana Tempo via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/031-setup-tempo.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ Grafana Tempo deployment completed!"