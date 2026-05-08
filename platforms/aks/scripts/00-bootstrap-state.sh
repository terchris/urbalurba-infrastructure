#!/bin/bash
# File: platforms/aks/scripts/00-bootstrap-state.sh
#
# Description:
#   One-time setup of Azure Storage Account for OpenTofu remote state.
#   Run this ONCE before any other platform scripts.
#   The storage account persists across cluster create/destroy cycles.
#
# Prerequisites:
#   - Running inside provision-host container
#   - .uis.secrets/cloud-accounts/azure-default.env exists and has AZURE_TENANT_ID,
#     AZURE_SUBSCRIPTION_ID, AZURE_STATE_STORAGE_ACCOUNT filled in
#   - Azure CLI logged in with Contributor role
#
# Usage:
#   ./scripts/00-bootstrap-state.sh

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
print_section() { echo; echo -e "${GREEN}========================================${NC}"; echo -e "${GREEN}$1${NC}"; echo -e "${GREEN}========================================${NC}"; echo; }

# ─── Environment check ────────────────────────────────────────────────────────
if [[ ! -f /.dockerenv ]] || [[ ! -d /mnt/urbalurbadisk ]]; then
    print_error "This script must run inside the provision-host container"
    echo "  docker exec -it provision-host bash"
    echo "  cd /mnt/urbalurbadisk && ./platforms/aks/scripts/00-bootstrap-state.sh"
    exit 1
fi

# ─── Load config from .uis.secrets/cloud-accounts/azure-default.env ───────────
source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"

CONFIG_FILE="$(get_cloud_credentials_path azure)"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Azure cloud-account config not found: $CONFIG_FILE"
    echo "Copy the template first:"
    echo "  cp provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template $CONFIG_FILE"
    echo "  # then fill in AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_STATE_STORAGE_ACCOUNT"
    exit 1
fi

source "$CONFIG_FILE"

# Validate required values
: "${AZURE_TENANT_ID:?Required in $CONFIG_FILE}"
: "${AZURE_SUBSCRIPTION_ID:?Required in $CONFIG_FILE}"
: "${AZURE_STATE_STORAGE_ACCOUNT:?Required in $CONFIG_FILE}"

# Inline defaults for optional values
AZURE_AKS_LOCATION="${AZURE_AKS_LOCATION:-westeurope}"
AZURE_AKS_STATE_RESOURCE_GROUP="${AZURE_AKS_STATE_RESOURCE_GROUP:-rg-urbalurba-tfstate}"
AZURE_AKS_STATE_CONTAINER="${AZURE_AKS_STATE_CONTAINER:-tfstate}"
AZURE_AKS_STATE_KEY="${AZURE_AKS_STATE_KEY:-aks/terraform.tfstate}"
AZURE_TAG_COST_CENTER="${AZURE_TAG_COST_CENTER:-helpers-no}"
AZURE_TAG_IT_OWNER="${AZURE_TAG_IT_OWNER:-}"

print_section "OPENTOFU STATE BACKEND BOOTSTRAP"
echo "This runs ONCE. The storage account survives cluster destroy/recreate."
echo
echo "Will create:"
echo "  Resource Group:   $AZURE_AKS_STATE_RESOURCE_GROUP"
echo "  Storage Account:  $AZURE_STATE_STORAGE_ACCOUNT"
echo "  Container:        $AZURE_AKS_STATE_CONTAINER"
echo "  Location:         $AZURE_AKS_LOCATION"
echo

read -p "Continue? (y/N): " confirm
[[ "${confirm,,}" != "y" ]] && { print_warning "Aborted"; exit 0; }

# ─── Azure login ──────────────────────────────────────────────────────────────
print_status "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
    print_warning "Not logged in — starting device code login..."
    az login --tenant "$AZURE_TENANT_ID" --use-device-code
fi

az account set --subscription "$AZURE_SUBSCRIPTION_ID"
CURRENT_SUB=$(az account show --query name -o tsv)
print_success "Using subscription: $CURRENT_SUB"

# Default IT owner tag to signed-in user if not set
if [[ -z "$AZURE_TAG_IT_OWNER" ]]; then
    AZURE_TAG_IT_OWNER=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")
fi

# ─── State resource group ─────────────────────────────────────────────────────
print_status "Checking state resource group: $AZURE_AKS_STATE_RESOURCE_GROUP..."
if az group show --name "$AZURE_AKS_STATE_RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "Resource group already exists"
else
    print_status "Creating resource group..."
    az group create \
        --name "$AZURE_AKS_STATE_RESOURCE_GROUP" \
        --location "$AZURE_AKS_LOCATION" \
        --tags \
            Project="urbalurba-infrastructure" \
            Environment="Sandbox" \
            Purpose="OpenTofu state storage" \
            CostCenter="$AZURE_TAG_COST_CENTER" \
            ITOwner="$AZURE_TAG_IT_OWNER"
    print_success "Resource group created: $AZURE_AKS_STATE_RESOURCE_GROUP"
fi

# ─── Storage account ──────────────────────────────────────────────────────────
print_status "Checking storage account: $AZURE_STATE_STORAGE_ACCOUNT..."
if az storage account show --name "$AZURE_STATE_STORAGE_ACCOUNT" --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "Storage account already exists"
else
    print_status "Creating storage account (this takes ~30 seconds)..."
    az storage account create \
        --name "$AZURE_STATE_STORAGE_ACCOUNT" \
        --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
        --location "$AZURE_AKS_LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --access-tier Hot \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --tags \
            Project="urbalurba-infrastructure" \
            Environment="Sandbox" \
            Purpose="OpenTofu state storage" \
            CostCenter="$AZURE_TAG_COST_CENTER" \
            ITOwner="$AZURE_TAG_IT_OWNER"
    print_success "Storage account created: $AZURE_STATE_STORAGE_ACCOUNT"
fi

# ─── Blob container ───────────────────────────────────────────────────────────
print_status "Checking blob container: $AZURE_AKS_STATE_CONTAINER..."
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
    --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

if az storage container show \
    --name "$AZURE_AKS_STATE_CONTAINER" \
    --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" >/dev/null 2>&1; then
    print_success "Container already exists"
else
    print_status "Creating container..."
    az storage container create \
        --name "$AZURE_AKS_STATE_CONTAINER" \
        --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
        --account-key "$ACCOUNT_KEY"
    print_success "Container created: $AZURE_AKS_STATE_CONTAINER"
fi

# ─── Enable versioning (protects state files) ─────────────────────────────────
print_status "Enabling blob versioning for state protection..."
az storage account blob-service-properties update \
    --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
    --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
    --enable-versioning true >/dev/null
print_success "Blob versioning enabled"

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "BOOTSTRAP COMPLETE"

echo "Your backend.tf values (already set in tofu/backend.tf via tfvars):"
echo
echo "  resource_group_name  = \"$AZURE_AKS_STATE_RESOURCE_GROUP\""
echo "  storage_account_name = \"$AZURE_STATE_STORAGE_ACCOUNT\""
echo "  container_name       = \"$AZURE_AKS_STATE_CONTAINER\""
echo "  key                  = \"$AZURE_AKS_STATE_KEY\""
echo
echo "These values come from $CONFIG_FILE — no manual edits needed."
echo
print_success "Ready to run: ./scripts/01-apply.sh"
