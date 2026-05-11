#!/bin/bash
# up.sh — Provision an AKS cluster end-to-end.
#
# Spec: website/docs/ai-developer/plans/completed/PLAN-uis-platform-up-azure-aks.md
# Entry point: uis platform up azure-aks
#
# Chains the three existing lifecycle scripts in order, with inter-step
# banners per the always-have-output principle (Q10). All three are
# idempotent today, so warm runs are fast no-ops with visible logging.
#
# Q11: refuses with a clear pointer if .uis.secrets/cloud-accounts/azure-default.env
# is missing — does NOT auto-run init. init and up have different mental
# models; surprise wizards are out of scope.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/cloud-accounts/azure-default.env"

# ----- Q11: refuse with a pointer if init has not been run -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No config file found at $ENV_FILE" >&2
    echo "  Run 'uis platform init azure-aks' first to set one up." >&2
    exit 1
fi

# Make AZURE_* available to the lifecycle scripts.
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " AKS cluster provisioning"
echo " (uis platform up azure-aks)"
echo " Subscription: ${AZURE_SUBSCRIPTION_ID:-unset}"
echo " Region:       ${AZURE_REGION:-unset}"
echo "═══════════════════════════════════════════════════════════"
echo
echo "⚠  This will create or update Azure resources and may incur cost (~€1/day)."
echo "   Run 'uis platform down azure-aks' to tear down when finished."
echo

# ----- 1/3 Bootstrap remote tofu state -----
echo "▶ 1/3 Bootstrap remote tofu state (Azure storage account + container)..."
"$SCRIPT_DIR/00-bootstrap-state.sh"
echo

# ----- 2/3 Apply cluster -----
echo "▶ 2/3 Apply cluster (tofu apply against platforms/azure-aks/tofu/)..."
"$SCRIPT_DIR/01-apply.sh"
echo

# ----- 3/3 Post-apply (kubeconfig + storage classes + Traefik) -----
echo "▶ 3/3 Post-apply (kubeconfig merge + storage-class aliases + Traefik)..."
"$SCRIPT_DIR/02-post-apply.sh"

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ AKS cluster is up"
echo "═══════════════════════════════════════════════════════════"
echo "  Try: kubectl get nodes"
echo "       uis deploy nginx"
echo
echo "  Tear down: uis platform down azure-aks"
