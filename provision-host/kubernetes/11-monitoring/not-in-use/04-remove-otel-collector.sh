#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/04-remove-otel-collector.sh
# Description: Remove OpenTelemetry Collector from monitoring stack
# Usage: ./04-remove-otel-collector.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "OpenTelemetry Collector Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Removing OpenTelemetry Collector via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/033-remove-otel-collector.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ OpenTelemetry Collector removal completed!"
