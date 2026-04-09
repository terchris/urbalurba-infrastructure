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
#   - azure-aks-config.sh exists and is sourced
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

# ─── Load config ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../azure-aks-config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config not found: $CONFIG_FILE"
    echo "Copy the template first:"
    echo "  cp platforms/aks/azure-aks-config.sh-template platforms/aks/azure-aks-config.sh"
    echo "  # Edit platforms/aks/azure-aks-config.sh with your values"
    exit 1
fi

source "$CONFIG_FILE"

print_section "OPENTOFU STATE BACKEND BOOTSTRAP"
echo "This runs ONCE. The storage account survives cluster destroy/recreate."
echo
echo "Will create:"
echo "  Resource Group:   $STATE_RESOURCE_GROUP"
echo "  Storage Account:  $STATE_STORAGE_ACCOUNT"
echo "  Container:        $STATE_CONTAINER"
echo "  Location:         $LOCATION"
echo

read -p "Continue? (y/N): " confirm
[[ "${confirm,,}" != "y" ]] && { print_warning "Aborted"; exit 0; }

# ─── Azure login ──────────────────────────────────────────────────────────────
print_status "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
    print_warning "Not logged in — starting device code login..."
    az login --tenant "$TENANT_ID" --use-device-code
fi

az account set --subscription "$SUBSCRIPTION_ID"
CURRENT_SUB=$(az account show --query name -o tsv)
print_success "Using subscription: $CURRENT_SUB"

# ─── State resource group ─────────────────────────────────────────────────────
print_status "Checking state resource group: $STATE_RESOURCE_GROUP..."
if az group show --name "$STATE_RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "Resource group already exists"
else
    print_status "Creating resource group..."
    az group create \
        --name "$STATE_RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags \
            Project="$TAG_PROJECT" \
            Environment="$TAG_ENVIRONMENT" \
            Purpose="OpenTofu state storage" \
            ITOwner="$TAG_IT_OWNER"
    print_success "Resource group created: $STATE_RESOURCE_GROUP"
fi

# ─── Storage account ──────────────────────────────────────────────────────────
print_status "Checking storage account: $STATE_STORAGE_ACCOUNT..."
if az storage account show --name "$STATE_STORAGE_ACCOUNT" --resource-group "$STATE_RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "Storage account already exists"
else
    print_status "Creating storage account (this takes ~30 seconds)..."
    az storage account create \
        --name "$STATE_STORAGE_ACCOUNT" \
        --resource-group "$STATE_RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --access-tier Hot \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --tags \
            Project="$TAG_PROJECT" \
            Environment="$TAG_ENVIRONMENT" \
            Purpose="OpenTofu state storage" \
            ITOwner="$TAG_IT_OWNER"
    print_success "Storage account created: $STATE_STORAGE_ACCOUNT"
fi

# ─── Blob container ───────────────────────────────────────────────────────────
print_status "Checking blob container: $STATE_CONTAINER..."
ACCOUNT_KEY=$(az storage account keys list \
    --resource-group "$STATE_RESOURCE_GROUP" \
    --account-name "$STATE_STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

if az storage container show \
    --name "$STATE_CONTAINER" \
    --account-name "$STATE_STORAGE_ACCOUNT" \
    --account-key "$ACCOUNT_KEY" >/dev/null 2>&1; then
    print_success "Container already exists"
else
    print_status "Creating container..."
    az storage container create \
        --name "$STATE_CONTAINER" \
        --account-name "$STATE_STORAGE_ACCOUNT" \
        --account-key "$ACCOUNT_KEY"
    print_success "Container created: $STATE_CONTAINER"
fi

# ─── Enable versioning (protects state files) ─────────────────────────────────
print_status "Enabling blob versioning for state protection..."
az storage account blob-service-properties update \
    --account-name "$STATE_STORAGE_ACCOUNT" \
    --resource-group "$STATE_RESOURCE_GROUP" \
    --enable-versioning true >/dev/null
print_success "Blob versioning enabled"

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "BOOTSTRAP COMPLETE"

echo "Your backend.tf values (already set in tofu/backend.tf via tfvars):"
echo
echo "  resource_group_name  = \"$STATE_RESOURCE_GROUP\""
echo "  storage_account_name = \"$STATE_STORAGE_ACCOUNT\""
echo "  container_name       = \"$STATE_CONTAINER\""
echo "  key                  = \"$STATE_KEY\""
echo
echo "These values come from azure-aks-config.sh — no manual edits needed."
echo
print_success "Ready to run: ./scripts/01-apply.sh"
