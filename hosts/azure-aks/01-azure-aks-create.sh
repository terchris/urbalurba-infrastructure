#!/bin/bash

# File: hosts/azure-aks/01-azure-aks-create.sh
#
# Description:
# Creates Azure AKS cluster with PIM activation and proper configuration
# Based on validated steps from steps-plan.md
#
# Prerequisites:
# - Azure CLI installed (available in provision-host)
# - Azure subscription access with Contributor role
#
# Usage:
# ./01-azure-aks-create.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions for colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/azure-aks-config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

print_status "Loading configuration from azure-aks-config.sh..."
source "$CONFIG_FILE"

# Function to check PIM activation
check_pim_activation() {
    print_status "Checking for Contributor role..."
    
    local has_role=$(az role assignment list \
        --assignee $(az account show --query user.name -o tsv) \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --query "[?roleDefinitionName=='Contributor'].roleDefinitionName" \
        -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$has_role" ]]; then
        print_success "Contributor role is active"
        return 0
    else
        print_warning "Contributor role not active"
        echo
        echo "Please activate your PIM role:"
        echo "1. Open: https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac"
        echo "2. Find and activate 'Contributor' role for subscription: $SUBSCRIPTION_ID"
        echo "3. Wait 1-2 minutes for activation"
        echo
        read -p "Press Enter after activating PIM role (or Ctrl+C to cancel)..."
        
        # Re-check after user confirms
        check_pim_activation
    fi
}

# Function to wait for operation with status updates
wait_for_operation() {
    local message="$1"
    local check_command="$2"
    local max_attempts="${3:-60}"
    local delay="${4:-5}"
    
    echo -n "$message"
    local attempts=0
    
    while [[ $attempts -lt $max_attempts ]]; do
        if eval "$check_command" >/dev/null 2>&1; then
            echo " ✅"
            return 0
        fi
        echo -n "."
        sleep $delay
        ((attempts++))
    done
    
    echo " ❌"
    return 1
}

# Main cluster creation flow
main() {
    print_status "Starting Azure AKS cluster creation..."
    
    # Step 1: Azure login
    print_status "Checking Azure login status..."
    if ! az account show >/dev/null 2>&1; then
        print_warning "Not logged in to Azure. Starting login process..."
        az login --tenant "$TENANT_ID" --use-device-code
        
        # Select subscription interactively
        echo
        print_status "Select the subscription for deployment:"
        az account list --query "[].{Name:name, ID:id}" -o table
        read -p "Enter subscription number or press Enter for default: " sub_choice
        
        if [[ -n "$sub_choice" ]]; then
            # User selected a specific subscription
            az account set --subscription "$sub_choice"
        fi
    fi
    
    # Show current subscription
    CURRENT_SUB=$(az account show --query name -o tsv)
    print_success "Using subscription: $CURRENT_SUB"
    
    # Step 2: Set subscription
    print_status "Setting subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
    
    # Step 3: Check PIM activation
    check_pim_activation
    
    # Step 4: Check quota
    print_status "Checking Azure quota availability..."
    if [[ -f "$SCRIPT_DIR/check-aks-quota.sh" ]]; then
        if ! "$SCRIPT_DIR/check-aks-quota.sh"; then
            print_error "Quota check failed. Please resolve quota issues before continuing."
            exit 1
        fi
    else
        print_warning "Quota check script not found, skipping quota validation"
    fi
    
    # Step 5: Create resource group
    print_status "Checking resource group: $RESOURCE_GROUP..."
    if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        print_warning "Resource group already exists: $RESOURCE_GROUP"
        read -p "Do you want to use the existing resource group? (y/n): " use_existing
        if [[ "$use_existing" != "y" ]]; then
            print_error "Cancelled by user"
            exit 1
        fi
    else
        print_status "Creating resource group: $RESOURCE_GROUP..."
        az group create \
            --name "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --tags $TAGS
        print_success "Resource group created"
    fi
    
    # Step 6: Check if cluster already exists
    print_status "Checking for existing cluster: $CLUSTER_NAME..."
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
        print_warning "Cluster already exists: $CLUSTER_NAME"
        read -p "Do you want to delete and recreate it? (y/n): " recreate
        
        if [[ "$recreate" == "y" ]]; then
            print_status "Deleting existing cluster..."
            az aks delete \
                --resource-group "$RESOURCE_GROUP" \
                --name "$CLUSTER_NAME" \
                --yes \
                --no-wait
            
            # Wait for deletion
            wait_for_operation "Waiting for cluster deletion" \
                "! az aks show --resource-group '$RESOURCE_GROUP' --name '$CLUSTER_NAME' 2>/dev/null" \
                120 10
        else
            print_status "Using existing cluster"
            # Get credentials and continue
            print_status "Getting cluster credentials..."
            az aks get-credentials \
                --resource-group "$RESOURCE_GROUP" \
                --name "$CLUSTER_NAME" \
                --file "$KUBECONFIG_FILE" \
                --overwrite-existing
            print_success "Cluster credentials retrieved"
            exit 0
        fi
    fi
    
    # Step 7: Create AKS cluster
    print_status "Creating AKS cluster: $CLUSTER_NAME..."
    print_status "This will take 5-10 minutes..."
    
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --node-count "$NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --location "$LOCATION" \
        --network-plugin azure \
        --network-policy azure \
        --generate-ssh-keys \
        --enable-managed-identity \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 3 \
        --enable-addons monitoring \
        --tier free \
        --node-osdisk-size 30 \
        --tags $TAGS
    
    print_success "AKS cluster created successfully"
    
    # Step 8: Get cluster credentials
    print_status "Getting cluster credentials..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --file "$KUBECONFIG_FILE" \
        --overwrite-existing
    
    print_success "Cluster credentials saved to: $KUBECONFIG_FILE"
    
    # Step 9: Verify cluster access
    print_status "Verifying cluster access..."
    export KUBECONFIG="$KUBECONFIG_FILE"
    
    if kubectl get nodes >/dev/null 2>&1; then
        print_success "✅ Cluster is accessible via kubectl"
        echo
        kubectl get nodes
    else
        print_error "❌ Cannot access cluster with kubectl"
        exit 1
    fi
    
    print_success "Azure AKS cluster creation completed!"
    echo
    echo "Cluster Details:"
    echo "================"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Location: $LOCATION"
    echo "Node Count: $NODE_COUNT"
    echo "Node Size: $NODE_SIZE"
    echo "Kubeconfig: $KUBECONFIG_FILE"
    echo
}

# Run main function
main "$@"