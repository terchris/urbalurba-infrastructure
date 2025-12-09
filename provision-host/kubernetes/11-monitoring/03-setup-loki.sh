#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/03-setup-loki.sh
# Description: Deploy Grafana Loki for log aggregation
# Usage: ./03-setup-loki.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "Grafana Loki Deployment"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Deploying Grafana Loki via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/032-setup-loki.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ Grafana Loki deployment completed!"
