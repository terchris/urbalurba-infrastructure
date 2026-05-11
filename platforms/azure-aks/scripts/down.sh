#!/bin/bash
# down.sh — Tear down the AKS cluster (delegates to 03-destroy.sh).
#
# Spec: website/docs/ai-developer/plans/active/PLAN-uis-platform-down-azure-aks.md
# Entry point: uis platform down azure-aks
#
# Thin pass-through. The interactive typed-name confirmation prompt and the
# UIS_DESTROY_CONFIRM=<cluster-name> non-interactive escape hatch live in
# 03-destroy.sh (added in PR #149); the wrapper inherits both for free.
#
# Q12: leaves .uis.secrets/cloud-accounts/azure-default.env in place after
# destroy. The user typically rotates the same sub + region across up/down
# cycles; re-running the wizard each time would force them to re-pick the
# same values. The closing summary tells the user how to manually delete
# the file if they want a full reset.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/cloud-accounts/azure-default.env"

# ----- Refuse with a pointer if there's no config -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No config file found at $ENV_FILE" >&2
    echo "  No AKS cluster appears to be configured. Nothing to tear down." >&2
    echo "  (If you have a cluster from a manual run, fall back to" >&2
    echo "  './platforms/azure-aks/scripts/03-destroy.sh' directly.)" >&2
    exit 1
fi

# Make AZURE_* available to the lifecycle script.
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " AKS cluster tear-down"
echo " (uis platform down azure-aks)"
echo " Subscription: ${AZURE_SUBSCRIPTION_ID:-unset}"
echo " Region:       ${AZURE_REGION:-unset}"
echo "═══════════════════════════════════════════════════════════"
echo
echo "This will destroy the AKS cluster and stop ~€1/day cluster cost."
echo "(The state RG used by tofu is preserved — that's deliberate.)"
echo

# ----- Delegate to 03-destroy.sh -----
# It owns the typed-name confirmation prompt + UIS_DESTROY_CONFIRM env-var
# escape hatch for non-interactive flows. Not exec'd because we want to
# print the config-preservation pointer below on success.
"$SCRIPT_DIR/03-destroy.sh"

# ----- Summary (Q12 — config preservation) -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ AKS cluster destroyed"
echo "═══════════════════════════════════════════════════════════"
echo "  Cluster cost stopped. The config file is preserved:"
echo "    $ENV_FILE"
echo
echo "  To recreate the cluster with the same subscription + region:"
echo "    uis platform up azure-aks"
echo
echo "  To fully reset (e.g. before switching tenants), delete the file:"
echo "    rm $ENV_FILE"
