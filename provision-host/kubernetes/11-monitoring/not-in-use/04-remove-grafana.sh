#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/04-remove-grafana.sh
# Description: Remove Grafana from monitoring stack
# Usage: ./04-remove-grafana.sh [target-host]
# Example: ./04-remove-grafana.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/234-remove-grafana.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "Grafana Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo "Playbook: $PLAYBOOK_PATH"
echo

# Confirm removal
echo "⚠️  This will remove Grafana:"
echo "   - Grafana deployment and service"
echo "   - Dashboards and configurations"
echo "   - Persistent volumes and data"
echo "   - IngressRoutes"
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
echo "Removing Grafana..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ Grafana removal completed!"
echo
echo "Notes:"
echo "  📁 Dashboard data has been removed"
echo "  ♻️ To reinstall: ./04-setup-grafana.sh $TARGET_HOST"