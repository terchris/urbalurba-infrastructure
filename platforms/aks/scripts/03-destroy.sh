#!/bin/bash
# File: platforms/aks/scripts/03-destroy.sh
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
: "${AZURE_STATE_STORAGE_ACCOUNT:?Required in $CONFIG_FILE}"

# Inline defaults for optional cluster-shape values
AZURE_AKS_LOCATION="${AZURE_AKS_LOCATION:-westeurope}"
AZURE_AKS_RESOURCE_GROUP="${AZURE_AKS_RESOURCE_GROUP:-rg-urbalurba-aks-weu}"
AZURE_AKS_CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:-azure-aks}"
AZURE_AKS_NODE_COUNT="${AZURE_AKS_NODE_COUNT:-1}"
AZURE_AKS_STATE_RESOURCE_GROUP="${AZURE_AKS_STATE_RESOURCE_GROUP:-rg-urbalurba-tfstate}"
AZURE_AKS_STATE_CONTAINER="${AZURE_AKS_STATE_CONTAINER:-tfstate}"
AZURE_AKS_STATE_KEY="${AZURE_AKS_STATE_KEY:-aks/terraform.tfstate}"

# Derived
KUBECONFIG_FILE="/mnt/urbalurbadisk/kubeconfig/${AZURE_AKS_CLUSTER_NAME}-kubeconf"

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

read -p "Type the cluster name to confirm deletion ($AZURE_AKS_CLUSTER_NAME): " typed
if [[ "$typed" != "$AZURE_AKS_CLUSTER_NAME" ]]; then
    print_warning "Name did not match — aborted"
    exit 0
fi

# ─── Azure login ──────────────────────────────────────────────────────────────
print_status "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
    az login --tenant "$AZURE_TENANT_ID" --use-device-code
fi
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# PIM check
print_status "Checking Contributor role..."
if ! az role assignment list \
    --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
    --query "[?roleDefinitionName=='Contributor' && principalType=='User']" \
    -o tsv 2>/dev/null | grep -q .; then
    print_warning "Contributor role not active"
    echo "  Activate at: https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac"
    read -p "  Press Enter after activating..."
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
    -reconfigure

print_status "This will take 5-10 minutes..."
tofu destroy -auto-approve

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

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "DESTROY COMPLETE"

echo "✅ Deleted cluster:        $AZURE_AKS_CLUSTER_NAME"
echo "✅ Deleted resource group: $AZURE_AKS_RESOURCE_GROUP"
echo "✅ Removed kubectl context"
echo
echo "💾 State preserved in:     $AZURE_STATE_STORAGE_ACCOUNT"
echo
echo "💰 Estimated savings: ~\$5/day (Standard_B2ms x $AZURE_AKS_NODE_COUNT)"
echo
echo "To recreate the cluster:"
echo "  ./platforms/aks/scripts/01-apply.sh"
