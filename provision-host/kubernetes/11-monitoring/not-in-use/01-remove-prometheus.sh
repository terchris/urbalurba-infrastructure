#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/01-remove-prometheus.sh
# Description: Remove Prometheus from monitoring stack
# Usage: ./01-remove-prometheus.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "Prometheus Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Removing Prometheus via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/030-remove-prometheus.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ Prometheus removal completed!"