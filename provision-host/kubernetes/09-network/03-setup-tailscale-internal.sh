#!/bin/bash
# filename: 03-setup-tailscale-internal.sh
# description: Deploy internal-only Tailscale ingress for Central K8s access
#
# This script deploys a Tailscale ingress that is accessible ONLY from the Tailnet.
# NOT exposed to the public internet (no Funnel).
#
# Used by developers via SovereignSky containers to access:
# - grafana.sovereignsky.no
# - otel.sovereignsky.no
# - litellm.sovereignsky.no
# - etc.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Tailscale API credentials in urbalurba-secrets
# - TAILSCALE_INTERNAL_HOSTNAME set in secrets (or passed as argument)
#
# Usage: ./03-setup-tailscale-internal.sh [hostname]
# Examples:
#   ./03-setup-tailscale-internal.sh              # Uses hostname from secrets
#   ./03-setup-tailscale-internal.sh k8s-imac     # Explicit hostname
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

# Get hostname from argument
TAILSCALE_INTERNAL_HOSTNAME="${1:-}"

echo "=========================================="
echo "Tailscale Internal Ingress Deployment"
echo "=========================================="
echo ""
echo "This will deploy Tailscale ingress for INTERNAL Tailnet access only."
echo "NO public internet exposure (Funnel disabled)."
echo ""
echo "Developer Access (via SovereignSky container):"
echo "  - grafana.sovereignsky.no"
echo "  - otel.sovereignsky.no"
echo "  - litellm.sovereignsky.no"
echo ""

# Call Ansible playbook
echo "Deploying Tailscale internal ingress via Ansible..."
if [ -n "$TAILSCALE_INTERNAL_HOSTNAME" ]; then
    echo "Using hostname: $TAILSCALE_INTERNAL_HOSTNAME"
    ansible-playbook "$PROJECT_ROOT/ansible/playbooks/805-deploy-tailscale-internal-ingress.yml" \
        -e "TAILSCALE_INTERNAL_HOSTNAME=$TAILSCALE_INTERNAL_HOSTNAME"
else
    echo "Using hostname from secrets (TAILSCALE_INTERNAL_HOSTNAME)"
    ansible-playbook "$PROJECT_ROOT/ansible/playbooks/805-deploy-tailscale-internal-ingress.yml"
fi

echo ""
echo "=========================================="
echo "Tailscale internal ingress deployment completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Find the Tailscale IP in admin console: https://login.tailscale.com/admin/machines"
echo "2. Configure SovereignSky DNS: *.sovereignsky.no -> [Tailscale IP]"
echo "3. Test from devcontainer: curl http://grafana.sovereignsky.no"
