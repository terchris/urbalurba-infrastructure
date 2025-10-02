#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/03-remove-loki.sh
# Description: Remove Grafana Loki from monitoring stack
# Usage: ./03-remove-loki.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "Grafana Loki Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Removing Grafana Loki via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/032-remove-loki.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ Grafana Loki removal completed!"