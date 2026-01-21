#!/bin/bash
# filename: 03-remove-tailscale-internal.sh
# description: Remove internal Tailscale ingress from the cluster
#
# This script removes:
# - Tailscale internal ingress resource
# - Optionally: Tailscale operator (if --remove-operator flag is used)
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
#
# Usage: ./03-remove-tailscale-internal.sh [--remove-operator]
# Examples:
#   ./03-remove-tailscale-internal.sh                  # Remove ingress only
#   ./03-remove-tailscale-internal.sh --remove-operator  # Also remove operator
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute playbook

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Parse arguments
REMOVE_OPERATOR="false"
for arg in "$@"; do
    case $arg in
        --remove-operator)
            REMOVE_OPERATOR="true"
            shift
            ;;
    esac
done

echo "=========================================="
echo "Tailscale Internal Ingress Removal"
echo "=========================================="
echo ""
echo "This will remove the Tailscale internal ingress from this cluster."
if [ "$REMOVE_OPERATOR" = "true" ]; then
    echo "The Tailscale operator will also be removed."
fi
echo ""
echo "WARNING: Developers will NOT be able to access cluster services"
echo "via SovereignSky containers after this operation!"
echo ""

# Call Ansible playbook for removal
echo "Removing Tailscale internal ingress via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/806-remove-tailscale-internal-ingress.yml" \
    -e "remove_operator=$REMOVE_OPERATOR"

echo ""
echo "=========================================="
echo "Tailscale internal ingress removal completed!"
echo "=========================================="
echo ""
echo "The cluster is no longer accessible via internal Tailnet."
echo "To restore access, run: ./03-setup-tailscale-internal.sh"
