#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/03-remove-otel-collector.sh
# Description: Remove OpenTelemetry Collector from monitoring stack
# Usage: ./03-remove-otel-collector.sh [target-host]
# Example: ./03-remove-otel-collector.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/231-remove-otel-collector.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "OpenTelemetry Collector Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo "Playbook: $PLAYBOOK_PATH"
echo

# Confirm removal
echo "⚠️  This will remove the OpenTelemetry Collector:"
echo "   - OpenTelemetry Collector deployment and service"
echo "   - Configuration ConfigMap"
echo "   - ServiceAccount and RBAC"
echo
read -p "Continue with removal? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Removal cancelled."
    exit 0
fi

# Validate ansible playbook exists
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: Ansible playbook not found at $PLAYBOOK_PATH"
    exit 1
fi

# Execute ansible playbook
echo "Removing OpenTelemetry Collector..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ OpenTelemetry Collector removal completed!"
echo
echo "Notes:"
echo "  📁 Configuration data has been removed"
echo "  ♻️ To reinstall: ./03-setup-otel-collector.sh $TARGET_HOST"