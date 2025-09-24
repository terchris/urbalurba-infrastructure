#!/bin/bash

# File: provision-host/kubernetes/02-databases/not-in-use/07-setup-qdrant.sh
# Description: Deploy Qdrant vector database to Kubernetes cluster
# Usage: ./07-setup-qdrant.sh [target-host]
# Example: ./07-setup-qdrant.sh rancher-desktop
#
# This script follows the Script + Ansible pattern defined in doc/rules-provisioning.md:
# - Minimal orchestration in shell script
# - Heavy lifting delegated to Ansible playbook

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/044-setup-qdrant.yml"

# Default target host
TARGET_HOST="${1:-rancher-desktop}"

echo "Starting Qdrant Vector Database setup on $TARGET_HOST"
echo "---------------------------------------------------"

# Step 1: Verify prerequisites
echo "🔍 Verifying prerequisites..."

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

if [[ ! -f "$PLAYBOOK_PATH" ]]; then
    echo "❌ Error: Ansible playbook not found at $PLAYBOOK_PATH"
    echo "💡 Please ensure the Qdrant setup playbook exists before running this script."
    exit 1
fi

echo "✅ Prerequisites: All tools available"

# Step 2: Deploy and verify via Ansible playbook (heavy lifting)
echo "🔧 Running Ansible playbook for Qdrant deployment and verification..."

# Change to ansible directory for proper relative path resolution
cd "$ANSIBLE_DIR" || {
    echo "❌ Error: Could not change to ansible directory: $ANSIBLE_DIR"
    exit 1
}

if ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST" -e "include_verification=true"; then
    echo ""
    echo "🎯 Qdrant Vector Database deployed and verified successfully!"
    echo "📊 Target: $TARGET_HOST"
    echo ""
    echo "📋 Next Steps:"
    echo "   • Check pods: kubectl get pods -n default | grep qdrant"
    echo "   • Check service: kubectl get svc qdrant -n default"
    echo "   • Port forward: kubectl port-forward svc/qdrant 6333:6333 -n default"
    echo "   • Test API: curl -H \"api-key: YOUR_KEY\" http://localhost:6333/collections"
    echo ""
    echo "🔐 Authentication:"
    echo "   • API Key: Configured from urbalurba-secrets/QDRANT_API_KEY"
    echo "   • API Endpoint: http://qdrant:6333 (cluster internal)"
    echo "   • gRPC Endpoint: http://qdrant:6334 (cluster internal)"
    echo ""
    echo "📦 Storage:"
    echo "   • Data PVC: qdrant-data (12Gi)"
    echo "   • Snapshots PVC: qdrant-snapshots (5Gi)"
    echo ""
    echo "✅ Verification Complete: Vector database read/write operations tested successfully"
else
    echo "❌ Error: Ansible playbook execution failed"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   • Check cluster connectivity: kubectl get nodes"
    echo "   • Check remaining resources: kubectl get all -l app.kubernetes.io/name=qdrant"
    echo "   • View playbook logs above for detailed error information"
    exit 1
fi