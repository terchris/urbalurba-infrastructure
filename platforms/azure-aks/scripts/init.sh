#!/bin/bash
# init.sh — Interactive wizard for AKS cluster onboarding.
#
# Spec: website/docs/ai-developer/plans/completed/PLAN-uis-platform-init-azure-aks.md
# Entry point: ./uis platform init azure-aks
#
# Orchestrates the helpers in provision-host/uis/lib/azure-discovery.sh in a
# fail-fast order (per Q7 of INVESTIGATE-platform-aks-novice-onboarding.md): each step
# surfaces failures the moment its required input is known. The wizard ends
# by writing .uis.secrets/cloud-accounts/azure-default.env atomically.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# platforms/azure-aks/scripts/init.sh → repo root is three levels up.
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
UIS_LIB="${UIS_LIB:-$REPO_ROOT/provision-host/uis/lib}"
ENV_FILE="$REPO_ROOT/.uis.secrets/cloud-accounts/azure-default.env"

# ----- Load shared helpers -----
# shellcheck source=../../../provision-host/uis/lib/azure-discovery.sh
source "$UIS_LIB/azure-discovery.sh"

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " AKS account setup wizard"
echo " (uis platform init azure-aks)"
echo " Registers Azure providers + writes config. No cluster is created."
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Preflight (Q5 + tool check) -----
require_interactive_or_die
require_tools_or_die

# ----- Overwrite gate (Q4) -----
prompt_overwrite_if_exists "$ENV_FILE"

# ----- Azure auth + discovery (Q7 fail-fast ordering) -----
# Each step's failure surfaces the moment its required input is known.
az_login_if_needed
pick_subscription               # sets AZURE_SUBSCRIPTION_{ID,NAME}, AZURE_TENANT_ID
check_owner_or_contributor      # fail-fast (with PIM retry-3x recovery)
pick_region                     # sets AZURE_REGION (defaults to westeurope)
check_quota                     # fail-fast on insufficient quota in chosen region
register_providers              # block until all four Registered (Q6)

# ----- Persist -----
write_env_atomically "$ENV_FILE"

# ----- Summary -----
# Show the env file as a host-relative path (the user runs `./uis` from their
# repo root, so `.uis.secrets/...` is what they'd `cat` or `ls`). The bind
# mount means the in-container `/mnt/urbalurbadisk/.uis.secrets/...` is the
# *same file* — but displaying the container prefix to a novice on the host
# side is just noise.
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ AKS setup ready"
echo "═══════════════════════════════════════════════════════════"
echo "  Subscription: $AZURE_SUBSCRIPTION_NAME"
echo "                ($AZURE_SUBSCRIPTION_ID)"
echo "  Tenant:       $AZURE_TENANT_ID"
echo "  Region:       $AZURE_REGION"
echo "  Config:       ${ENV_FILE#$REPO_ROOT/}"
echo
echo "Next: ./uis platform up azure-aks"
