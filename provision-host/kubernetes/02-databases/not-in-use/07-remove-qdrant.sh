#!/bin/bash

# File: provision-host/kubernetes/02-databases/not-in-use/07-remove-qdrant.sh
# Description: Remove Qdrant vector database from Kubernetes cluster
# Usage: ./07-remove-qdrant.sh [target-host]
# Example: ./07-remove-qdrant.sh rancher-desktop
#
# This script follows the Script + Ansible pattern defined in docs/rules-provisioning.md:
# - Minimal orchestration in shell script
# - Heavy lifting delegated to Ansible playbook

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/044-remove-qdrant.yml"

# Default target host
TARGET_HOST="${1:-rancher-desktop}"
STATUS=()
ERROR=0

echo "Starting Qdrant Vector Database removal from $TARGET_HOST"
echo "---------------------------------------------------"

# Step 1: Verify prerequisites
verify_prerequisites() {
    echo "🔍 Verifying prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        echo "❌ Error: kubectl not found. Please ensure kubectl is installed and configured."
        ERROR=1
        STATUS+=("❌ Prerequisites: kubectl missing")
        return 1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        echo "❌ Error: ansible-playbook not found. Please ensure Ansible is installed."
        ERROR=1
        STATUS+=("❌ Prerequisites: Ansible missing")
        return 1
    fi

    if ! command -v helm &> /dev/null; then
        echo "❌ Error: helm not found. Please ensure Helm is installed."
        ERROR=1
        STATUS+=("❌ Prerequisites: Helm missing")
        return 1
    fi

    if [[ ! -f "$PLAYBOOK_PATH" ]]; then
        echo "❌ Error: Ansible playbook not found at $PLAYBOOK_PATH"
        echo "💡 Please ensure the Qdrant removal playbook exists before running this script."
        ERROR=1
        STATUS+=("❌ Prerequisites: Playbook missing")
        return 1
    fi

    STATUS+=("✅ Prerequisites: All tools available")
    return 0
}

# Step 2: Remove via Ansible playbook
remove_qdrant() {
    echo "🧹 Running Ansible playbook for Qdrant removal..."

    # Change to ansible directory for proper relative path resolution
    cd "$ANSIBLE_DIR" || {
        echo "❌ Error: Could not change to ansible directory: $ANSIBLE_DIR"
        ERROR=1
        STATUS+=("❌ Removal: Directory access failed")
        return 1
    }

    if ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"; then
        STATUS+=("✅ Removal: Qdrant removed successfully")
        return 0
    else
        echo "❌ Error: Ansible playbook execution failed"
        ERROR=1
        STATUS+=("❌ Removal: Ansible playbook failed")
        return 1
    fi
}

# Print removal summary
print_summary() {
    echo "---------- Removal Summary ----------"
    for step in "${STATUS[@]}"; do
        echo "$step"
    done

    if [ $ERROR -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "🗑️  Qdrant Vector Database removed successfully!"
        echo "📊 Target: $TARGET_HOST"
        echo ""
        echo "🔄 Removal Summary:"
        echo "   • Helm release: ✅ Uninstalled"
        echo "   • Pod termination: ✅ All pods terminated"
        echo "   • Service: ✅ Removed"
        echo ""
        echo "💾 Data Preservation:"
        echo "   • PVCs preserved by default (qdrant-data, qdrant-snapshots)"
        echo "   • urbalurba-secrets preserved"
        echo ""
        echo "♻️  Re-deployment:"
        echo "   • Ready for fresh deployment using ./07-setup-qdrant.sh"
        echo "   • Existing data will be preserved if PVCs remain"
        echo ""
        echo "🧹 Complete Cleanup (if needed):"
        echo "   • Remove data: kubectl delete pvc qdrant-data qdrant-snapshots"
        echo "   • Warning: This will permanently delete all vector data!"
    else
        echo "Some steps failed. Please check the logs above."
        echo ""
        echo "🔍 Troubleshooting:"
        echo "   • Check cluster connectivity: kubectl get nodes"
        echo "   • Check remaining resources: kubectl get all -l app.kubernetes.io/name=qdrant"
        echo "   • Manual cleanup: helm uninstall qdrant"
    fi
}

# Main execution function
main() {
    verify_prerequisites || return $ERROR
    remove_qdrant || return $ERROR
    print_summary
}

# Execute main function and exit with error code
main "$@"
exit $ERROR