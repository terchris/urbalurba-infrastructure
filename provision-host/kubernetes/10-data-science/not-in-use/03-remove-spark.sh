#!/bin/bash

# File: provision-host/kubernetes/10-data-science/not-in-use/03-remove-spark.sh
# Description: Remove Spark Kubernetes Operator from Kubernetes cluster
# Usage: ./03-remove-spark.sh [target-host]
# Example: ./03-remove-spark.sh rancher-desktop
#
# This script follows the Script + Ansible pattern defined in doc/rules-provisioning.md:
# - Minimal orchestration in shell script
# - Heavy lifting delegated to Ansible playbook

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/330-remove-spark.yml"

# Default target host
TARGET_HOST="${1:-rancher-desktop}"

# Display script purpose
echo "🗑️  $(basename "$0"): Removing Spark Kubernetes Operator from Kubernetes cluster..."
echo "📍 Target Host: $TARGET_HOST"
echo "📋 Playbook: $PLAYBOOK_PATH"
echo

# Verify prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl not found. Please ensure kubectl is installed and configured."
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: ansible-playbook not found. Please ensure Ansible is installed."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ Error: helm not found. Please ensure Helm is installed."
    exit 1
fi

# Check if playbook exists
if [[ ! -f "$PLAYBOOK_PATH" ]]; then
    echo "❌ Error: Ansible playbook not found at $PLAYBOOK_PATH"
    echo "💡 Please ensure the remove playbook exists before running this script."
    exit 1
fi

# Change to ansible directory for proper relative path resolution
cd "$ANSIBLE_DIR" || {
    echo "❌ Error: Could not change to ansible directory: $ANSIBLE_DIR"
    exit 1
}

# Execute Ansible playbook (delegate heavy lifting to Ansible)
run_playbook() {
    echo "🔧 $(basename "$0"): Running Ansible playbook for Spark Operator removal..."
    ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"
}

# Run the playbook and capture result
if run_playbook; then
    echo
    echo "✅ $(basename "$0"): Spark Operator removal completed successfully!"
    echo "🎯 Target: $TARGET_HOST"
    echo "📝 Note: Spark Kubernetes Operator has been removed"
    echo "📁 Note: Namespace spark-operator removed"
    echo "♻️  Ready for fresh installation: ./03-setup-spark.sh"
else
    echo
    echo "❌ $(basename "$0"): Spark Operator removal failed!"
    echo "🔍 Check the Ansible playbook output above for details"
    exit 1
fi