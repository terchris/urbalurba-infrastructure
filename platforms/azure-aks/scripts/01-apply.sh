#!/bin/bash
# File: platforms/azure-aks/scripts/01-apply.sh
#
# Description:
#   Runs OpenTofu init → plan → apply for the AKS platform.
#   Reads all values from .uis.secrets/cloud-accounts/azure-default.env — no manual tfvars editing needed.
#   Writes kubeconfig output to the standard UIS kubeconfig location.
#
# Prerequisites:
#   - Running inside provision-host container
#   - .uis.secrets/cloud-accounts/azure-default.env exists (copied from template and filled in)
#   - scripts/00-bootstrap-state.sh has been run once
#   - Azure CLI logged in with Contributor role
#
# Usage:
#   ./scripts/01-apply.sh

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
    echo "Copy the template first:"
    echo "  cp provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template $CONFIG_FILE"
    echo "  # then fill in AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, AZURE_STATE_STORAGE_ACCOUNT"
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
# B2ms is gone in many regions/subscriptions; B2s_v2 is broadly allowed and similarly priced.
AZURE_AKS_NODE_SIZE="${AZURE_AKS_NODE_SIZE:-Standard_B2s_v2}"
AZURE_AKS_NODE_COUNT="${AZURE_AKS_NODE_COUNT:-1}"
AZURE_AKS_MIN_COUNT="${AZURE_AKS_MIN_COUNT:-1}"
AZURE_AKS_MAX_COUNT="${AZURE_AKS_MAX_COUNT:-3}"
AZURE_AKS_OS_DISK_SIZE="${AZURE_AKS_OS_DISK_SIZE:-30}"
AZURE_AKS_STATE_RESOURCE_GROUP="${AZURE_AKS_STATE_RESOURCE_GROUP:-rg-urbalurba-tfstate}"
AZURE_AKS_STATE_CONTAINER="${AZURE_AKS_STATE_CONTAINER:-tfstate}"
AZURE_AKS_STATE_KEY="${AZURE_AKS_STATE_KEY:-aks/terraform.tfstate}"
AZURE_TAG_COST_CENTER="${AZURE_TAG_COST_CENTER:-helpers-no}"

# Derived. Kubeconfig dir is /mnt/urbalurbadisk/kubeconfig/ (in-container,
# NOT bind-mounted). The .uis.secrets/.../kubeconfig path returned by
# get_kubeconfig_path() is bind-mounted and breaks kubectl's flock on
# Rancher Desktop's lima VM. 04-merge-kubeconf.yml uses the same path.
KUBECONFIG_DIR="/mnt/urbalurbadisk/kubeconfig"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${AZURE_AKS_CLUSTER_NAME}-kubeconf"

print_section "AKS PLATFORM — OPENTOFU APPLY"

# ─── Azure login ──────────────────────────────────────────────────────────────
print_status "Checking Azure login..."
if ! az account show >/dev/null 2>&1; then
    az login --tenant "$AZURE_TENANT_ID" --use-device-code
fi
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
print_success "Using subscription: $(az account show --query name -o tsv)"

# Default tag emails to signed-in user if not overridden
_SIGNED_IN_EMAIL=$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || echo "")
AZURE_TAG_BUSINESS_OWNER="${AZURE_TAG_BUSINESS_OWNER:-${_SIGNED_IN_EMAIL}}"
AZURE_TAG_IT_OWNER="${AZURE_TAG_IT_OWNER:-${_SIGNED_IN_EMAIL}}"

# ─── Role check (Owner or Contributor — either can manage AKS) ────────────────
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
print_success "Cluster-admin role active"

# ─── Get storage account key for backend ──────────────────────────────────────
print_status "Fetching state storage account key..."
export ARM_ACCESS_KEY=$(az storage account keys list \
    --resource-group "$AZURE_AKS_STATE_RESOURCE_GROUP" \
    --account-name "$AZURE_STATE_STORAGE_ACCOUNT" \
    --query "[0].value" -o tsv)

if [[ -z "$ARM_ACCESS_KEY" ]]; then
    print_error "Could not fetch storage account key"
    echo "  Has 00-bootstrap-state.sh been run?"
    exit 1
fi
print_success "Storage account key loaded (not logged)"

# ─── Generate tfvars ──────────────────────────────────────────────────────────
TFVARS_FILE="$TOFU_DIR/terraform.tfvars"
print_status "Generating terraform.tfvars from config..."

cat > "$TFVARS_FILE" <<EOF
# Auto-generated by 01-apply.sh from .uis.secrets/cloud-accounts/azure-default.env — do not edit manually
tenant_id       = "$AZURE_TENANT_ID"
subscription_id = "$AZURE_SUBSCRIPTION_ID"

resource_group  = "$AZURE_AKS_RESOURCE_GROUP"
cluster_name    = "$AZURE_AKS_CLUSTER_NAME"
location        = "$AZURE_AKS_LOCATION"

node_count      = $AZURE_AKS_NODE_COUNT
node_size       = "$AZURE_AKS_NODE_SIZE"
min_count       = $AZURE_AKS_MIN_COUNT
max_count       = $AZURE_AKS_MAX_COUNT
os_disk_size_gb = $AZURE_AKS_OS_DISK_SIZE

tag_cost_center    = "$AZURE_TAG_COST_CENTER"
tag_project        = "urbalurba-infrastructure"
tag_environment    = "Sandbox"
tag_business_owner = "$AZURE_TAG_BUSINESS_OWNER"
tag_it_owner       = "$AZURE_TAG_IT_OWNER"
EOF

print_success "terraform.tfvars generated"

# ─── tofu init ────────────────────────────────────────────────────────────────
print_section "Step 1: tofu init"
cd "$TOFU_DIR"

# -upgrade lets tofu refresh providers when the constraint in main.tf changes.
# Without it, an existing .terraform.lock.hcl pinned to the old major rejects
# the new constraint (we hit this when bumping azurerm 3.x → 4.x).
tofu init \
    -backend-config="resource_group_name=$AZURE_AKS_STATE_RESOURCE_GROUP" \
    -backend-config="storage_account_name=$AZURE_STATE_STORAGE_ACCOUNT" \
    -backend-config="container_name=$AZURE_AKS_STATE_CONTAINER" \
    -backend-config="key=$AZURE_AKS_STATE_KEY" \
    -reconfigure \
    -upgrade

print_success "tofu init complete"

# ─── tofu plan ────────────────────────────────────────────────────────────────
print_section "Step 2: tofu plan"
tofu plan -out=tfplan
print_success "Plan saved to tfplan"

echo
if [[ "${UIS_NONINTERACTIVE:-0}" == "1" ]]; then
    print_status "UIS_NONINTERACTIVE=1 — skipping apply prompt"
    confirm="y"
elif [[ -t 0 ]]; then
    read -p "Review the plan above. Apply? (y/N): " confirm
else
    # No TTY — read from piped stdin (e.g. `printf 'y\n' | docker exec -i …`).
    # `|| confirm=""` is load-bearing: with `set -euo pipefail`, a bare
    # `read -r` on closed stdin (no `-i` and no env var) exits 1 *before*
    # the friendly "Aborted" line below ever runs. This bites the chained
    # `uis platform up azure-aks` flow when bootstrap consumes the first
    # piped `y` and apply then sees EOF — exact F14 from talk47. Same
    # shape as the F13 fix in 00-bootstrap-state.sh.
    read -r confirm || confirm=""
fi
[[ "${confirm,,}" != "y" ]] && { print_warning "Aborted — no changes made"; exit 0; }

# ─── tofu apply ───────────────────────────────────────────────────────────────
print_section "Step 3: tofu apply"
print_status "This will take 5-10 minutes..."
tofu apply tfplan

print_success "tofu apply complete"

# ─── Write kubeconfig ─────────────────────────────────────────────────────────
# Writes to /mnt/urbalurbadisk/kubeconfig/ (in-container, non-bind-mount),
# which is also where 04-merge-kubeconf.yml looks for *-kubeconf files.
# 02-post-apply.sh runs the merge playbook next, producing kubeconf-all in
# the same directory.
print_section "Step 4: Save kubeconfig"
mkdir -p "$KUBECONFIG_DIR"

tofu output -raw kube_config_raw > "$KUBECONFIG_FILE"
chmod 600 "$KUBECONFIG_FILE"
print_success "Kubeconfig written to: $KUBECONFIG_FILE"

# ─── Quick validation ─────────────────────────────────────────────────────────
print_section "Step 5: Validate"
export KUBECONFIG="$KUBECONFIG_FILE"

if kubectl get nodes >/dev/null 2>&1; then
    print_success "Cluster is accessible"
    echo
    kubectl get nodes
else
    print_error "Cannot reach cluster — check kubeconfig"
    exit 1
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "APPLY COMPLETE"
echo "Cluster:      $AZURE_AKS_CLUSTER_NAME"
echo "Location:     $AZURE_AKS_LOCATION"
echo "Kubeconfig:   $KUBECONFIG_FILE"
echo
echo "Next step:"
echo "  ./platforms/azure-aks/scripts/02-post-apply.sh"
