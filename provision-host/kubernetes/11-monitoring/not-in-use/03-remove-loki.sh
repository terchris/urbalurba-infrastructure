#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/03-remove-loki.sh
# Description: Remove Grafana Loki from monitoring stack
# Usage: ./03-remove-loki.sh [target-host]
# Example: ./03-remove-loki.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/233-remove-loki.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "Grafana Loki Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo "Playbook: $PLAYBOOK_PATH"
echo

# Confirm removal
echo "⚠️  This will remove Grafana Loki:"
echo "   - Loki deployment and service"
echo "   - Promtail log collectors"
echo "   - Persistent volumes and log data"
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
echo "Removing Grafana Loki..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ Grafana Loki removal completed!"
echo
echo "Notes:"
echo "  📁 Log data has been removed"
echo "  ♻️ To reinstall: ./03-setup-loki.sh $TARGET_HOST"