#!/bin/bash
# File: platforms/azure-aks/scripts/03-destroy.sh
#
# Description:
#   Destroys the AKS cluster and all associated resources via OpenTofu.
#   The state storage account (rg-urbalurba-tfstate) is intentionally preserved —
#   it holds state history and is shared across platforms.
#
# Prerequisites:
#   - Running inside provision-host container
#   - .uis.secrets/cloud-accounts/azure-default.env exists
#   - Azure CLI logged in with Contributor role
#
# Usage:
#   ./scripts/03-destroy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_section() { echo; echo -e "${YELLOW}========================================${NC}"; echo -e "${YELLOW}$1${NC}"; echo -e "${YELLOW}========================================${NC}"; echo; }

# ─── Environment check ────────────────────────────────────────────────────────
if [[ ! -f /.dockerenv ]] || [[ ! -d /mnt/urbalurbadisk ]]; then
    print_error "This script must run inside the provision-host container"
    exit 1
fi

# ─── Load config from .uis.secrets/cloud-accounts/azure-default.env ───────────
source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/.."
TOFU_DIR="$PLATFORM_DIR/tofu"
CONFIG_FILE="$(get_cloud_credentials_path azure)"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Azure cloud-account config not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Validate required values
: "${AZURE_TENANT_ID:?Required in $CONFIG_FILE}"
: "${AZURE_SUBSCRIPTION_ID:?Required in $CONFIG_FILE}"

# Defensive default for AZURE_STATE_STORAGE_ACCOUNT — derived from the sub ID
# the same way `uis platform init azure-aks`'s write_env_atomically does
# (provision-host/uis/lib/azure-discovery.sh). Keeps pre-PR-#156 env files (3
# vars: TENANT/SUBSCRIPTION/REGION) working without a manual edit.
if [[ -z "${AZURE_STATE_STORAGE_ACCOUNT:-}" ]]; then
    _stripped_sub="${AZURE_SUBSCRIPTION_ID//-/}"
    AZURE_STATE_STORAGE_ACCOUNT="sa${_stripped_sub:0:16}tf"
    unset _stripped_sub
fi

# Inline defaults for optional cluster-shape values. AZURE_AKS_LOCATION falls
# back through AZURE_REGION (the wizard's region pick) before the hard-coded
# westeurope default.
AZURE_AKS_LOCATION="${AZURE_AKS_LOCATION:-${AZURE_REGION:-westeurope}}"
AZURE_AKS_RESOURCE_GROUP="${AZURE_AKS_RESOURCE_GROUP:-rg-urbalurba-aks-weu}"
AZURE_AKS_CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:-azure-aks}"
AZURE_AKS_NODE_SIZE="${AZURE_AKS_NODE_SIZE:-Standard_B2s_v2}"
AZURE_AKS_NODE_COUNT="${AZURE_AKS_NODE_COUNT:-1}"
AZURE_AKS_STATE_RESOURCE_GROUP="${AZURE_AKS_STATE_RESOURCE_GROUP:-rg-urbalurba-tfstate}"
AZURE_AKS_STATE_CONTAINER="${AZURE_AKS_STATE_CONTAINER:-tfstate}"
AZURE_AKS_STATE_KEY="${AZURE_AKS_STATE_KEY:-aks/terraform.tfstate}"

# Derived. Same in-container kubeconfig location as 01-apply.sh, 02-post-apply.sh,
# and 04-merge-kubeconf.yml. Avoids the bind-mount flock issue (see 01-apply.sh).
KUBECONFIG_DIR="/mnt/urbalurbadisk/kubeconfig"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${AZURE_AKS_CLUSTER_NAME}-kubeconf"

print_section "AKS PLATFORM — DESTROY"

echo "This will permanently delete:"
echo "  Cluster:        $AZURE_AKS_CLUSTER_NAME"
echo "  Resource Group: $AZURE_AKS_RESOURCE_GROUP"
echo "  Location:       $AZURE_AKS_LOCATION"
echo
echo "This will NOT delete:"
echo "  State backend:  $AZURE_AKS_STATE_RESOURCE_GROUP / $AZURE_STATE_STORAGE_ACCOUNT"
echo "  (State history is preserved for future re-creates)"
echo

if [[ "${UIS_NONINTERACTIVE:-0}" == "1" ]]; then
    # Non-interactive destroy is dangerous — require an explicit env var that
    # carries the cluster name, so an accidental UIS_NONINTERACTIVE=1 in the
    # environment can't trigger a teardown.
    if [[ "${UIS_DESTROY_CONFIRM:-}" != "$AZURE_AKS_CLUSTER_NAME" ]]; then
        print_error "Non-interactive destroy requires UIS_DESTROY_CONFIRM=\"$AZURE_AKS_CLUSTER_NAME\""
        exit 1
    fi
    typed="$AZURE_AKS_CLUSTER_NAME"
elif [[ -t 0 ]]; then
    read -p "Type the cluster name to confirm deletion ($AZURE_AKS_CLUSTER_NAME): " typed
else
    # No TTY — read from piped stdin
    read -r typed
fi
if [[ "$typed" != "$AZURE_AKS_CLUSTER_NAME" ]]; then
    print_warning "Name did not match — aborted"
    # Exit non-zero so callers (especially `uis platform down`) know the
    # destroy did NOT happen and can show the correct "aborted" banner instead
    # of a false "✓ destroyed" success message (F9 from talk45).
    exit 1
fi

# ─── Azure login ──────────────────────────────────────────────────────────────
print_status "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
    az login --tenant "$AZURE_TENANT_ID" --use-device-code
fi
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Role check (Owner or Contributor — either can manage AKS)
print_status "Checking cluster-admin role (Owner or Contributor)..."
if ! az role assignment list \
    --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
    --include-inherited --include-groups \
    --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='Contributor']" \
    -o tsv 2>/dev/null | grep -q .; then
    print_warning "Neither Owner nor Contributor role active"
    echo "  Activate at: https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac"
    if [[ -t 0 ]] && [[ "${UIS_NONINTERACTIVE:-0}" != "1" ]]; then
        read -p "  Press Enter after activating..."
    fi
fi

# ─── Get storage key ──────────────────────────────────────────────────────────
export ARM_ACCESS_KEY=$(az storage account keys list \
    --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
    --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

# ─── tofu init + destroy ──────────────────────────────────────────────────────
print_section "Running tofu destroy"
cd "$TOFU_DIR"

tofu init \
    -backend-config="resource_group_name=$AZURE_AKS_STATE_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$AZURE_STATE_STORAGE_ACCOUNT" \
    -backend-config="container_name=$AZURE_AKS_STATE_CONTAINER" \
    -backend-config="key=$AZURE_AKS_STATE_KEY" \
    -reconfigure \
    -upgrade

print_status "This will take 5-10 minutes..."
# Don't let `set -e` skip our own diagnostic on a destroy failure — the
# azurerm provider may report partial success even with a non-zero exit.
if ! tofu destroy -auto-approve; then
    print_error "tofu destroy failed."
    print_error "  Common causes:"
    print_error "    - Orphan resources in the cluster RG (e.g. AKS auto-creates ContainerInsights solution)."
    print_error "      The provider features.resource_group.prevent_deletion_if_contains_resources=false flag"
    print_error "      in main.tf should handle this; if you still see RG-not-empty errors, force-delete with:"
    print_error "        az group delete --name $AZURE_AKS_RESOURCE_GROUP --yes"
    print_error "    - State drift; re-run with the same backend config."
    exit 1
fi

# ─── Clean up kubeconfig ──────────────────────────────────────────────────────
print_section "Cleaning up kubeconfig"

if kubectl config get-contexts "$AZURE_AKS_CLUSTER_NAME" >/dev/null 2>&1; then
    kubectl config delete-context "$AZURE_AKS_CLUSTER_NAME" >/dev/null 2>&1 || true
    print_success "Removed kubectl context: $AZURE_AKS_CLUSTER_NAME"
fi

if [[ -f "$KUBECONFIG_FILE" ]]; then
    rm -f "$KUBECONFIG_FILE"
    print_success "Removed kubeconfig file: $KUBECONFIG_FILE"
fi

# ─── Reset cluster-config to rancher-desktop ──────────────────────────────────
# Symmetric to 02-post-apply.sh's auto-flip: after the AKS cluster is gone,
# restore the local default so the next `./uis deploy <service>` doesn't
# target a context that no longer exists.
print_section "Reset UIS target to rancher-desktop"

CLUSTER_CONFIG="/mnt/urbalurbadisk/.uis.extend/cluster-config.sh"
if [[ -f "$CLUSTER_CONFIG" ]]; then
    sed -i.bak \
        -e "s|^CLUSTER_TYPE=.*|CLUSTER_TYPE=\"rancher-desktop\"|" \
        -e "s|^TARGET_HOST=.*|TARGET_HOST=\"rancher-desktop\"|" \
        "$CLUSTER_CONFIG"
    rm -f "${CLUSTER_CONFIG}.bak"
    print_success "cluster-config.sh reset to: CLUSTER_TYPE=rancher-desktop, TARGET_HOST=rancher-desktop"
else
    print_warning "cluster-config.sh not found — skipping reset"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "DESTROY COMPLETE"

echo "✅ Deleted cluster:        $AZURE_AKS_CLUSTER_NAME"
echo "✅ Deleted resource group: $AZURE_AKS_RESOURCE_GROUP"
echo "✅ Removed kubectl context"
echo
echo "💾 State preserved in:     $AZURE_STATE_STORAGE_ACCOUNT"
echo
echo "💰 Estimated savings: ~€1/day (${AZURE_AKS_NODE_SIZE} x $AZURE_AKS_NODE_COUNT)"
echo
echo "To recreate the cluster:"
echo "  ./uis platform up azure-aks"
