#!/bin/bash

# File: hosts/azure-aks/03-azure-aks-cleanup.sh
#
# Description:
# Removes Azure AKS cluster and optionally cleans up associated resources
# Provides options for partial or complete cleanup to manage costs
#
# Prerequisites:
# - Azure CLI logged in with appropriate permissions
# - azure-aks-config.sh with cluster configuration
#
# Usage:
# ./03-azure-aks-cleanup.sh [--full]
#   --full : Also delete the resource group and all resources in it

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

source "$CONFIG_FILE"

# Parse command line arguments
FULL_CLEANUP=false
for arg in "$@"; do
    case $arg in
        --full)
            FULL_CLEANUP=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--full]"
            echo "  --full : Also delete the resource group and all resources"
            echo ""
            echo "Without --full, only the AKS cluster is deleted."
            echo "With --full, the entire resource group is deleted."
            exit 0
            ;;
    esac
done

# Function to check if resource exists
resource_exists() {
    local resource_type="$1"
    local name="$2"
    local resource_group="${3:-$RESOURCE_GROUP}"
    
    case "$resource_type" in
        "cluster")
            az aks show --resource-group "$resource_group" --name "$name" >/dev/null 2>&1
            ;;
        "group")
            az group show --name "$name" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to wait for deletion
wait_for_deletion() {
    local message="$1"
    local check_command="$2"
    local max_wait="${3:-300}"
    
    echo -n "$message"
    local waited=0
    while eval "$check_command" >/dev/null 2>&1; do
        echo -n "."
        sleep 5
        waited=$((waited + 5))
        if [[ $waited -ge $max_wait ]]; then
            echo " (timeout)"
            return 1
        fi
    done
    echo " ✅"
    return 0
}

# Function to confirm deletion
confirm_deletion() {
    local resource="$1"
    local default_answer="${2:-n}"
    
    echo
    print_warning "⚠️  WARNING: You are about to delete $resource"
    echo "This action cannot be undone!"
    echo
    
    if [[ "$default_answer" == "y" ]]; then
        read -p "Are you sure you want to proceed? (Y/n): " answer
        answer="${answer:-y}"
    else
        read -p "Are you sure you want to proceed? (y/N): " answer
        answer="${answer:-n}"
    fi
    
    if [[ "${answer,,}" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to remove kubeconfig context
remove_kubeconfig_context() {
    print_status "Removing azure-aks context from kubeconfig..."
    
    # Check if context exists
    if kubectl config get-contexts azure-aks >/dev/null 2>&1; then
        kubectl config delete-context azure-aks >/dev/null 2>&1 || true
        print_success "Removed azure-aks context"
    else
        print_status "azure-aks context not found in kubeconfig"
    fi
    
    # Remove from individual kubeconfig file if it exists
    if [[ -f "$KUBECONFIG_FILE" ]]; then
        print_status "Removing kubeconfig file: $KUBECONFIG_FILE"
        rm -f "$KUBECONFIG_FILE"
        print_success "Kubeconfig file removed"
    fi
}

# Main cleanup flow
main() {
    echo
    print_warning "========================================="
    print_warning "    AZURE AKS CLUSTER CLEANUP TOOL     "
    print_warning "========================================="
    echo
    
    # Check Azure login
    print_status "Checking Azure login status..."
    if ! az account show >/dev/null 2>&1; then
        print_error "Not logged in to Azure"
        echo "Please run: az login --tenant $TENANT_ID"
        exit 1
    fi
    
    # Set subscription
    print_status "Setting subscription to $SUBSCRIPTION_ID..."
    az account set --subscription "$SUBSCRIPTION_ID"
    
    CURRENT_SUB=$(az account show --query name -o tsv)
    print_success "Using subscription: $CURRENT_SUB"
    
    # Display what will be deleted
    echo
    echo "Cleanup Configuration:"
    echo "====================="
    echo "Subscription: $CURRENT_SUB"
    echo "Resource Group: $RESOURCE_GROUP"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Cleanup Mode: $(if $FULL_CLEANUP; then echo "FULL (Resource Group + All Resources)"; else echo "CLUSTER ONLY"; fi)"
    echo
    
    if $FULL_CLEANUP; then
        # Full cleanup - delete entire resource group
        
        # Check if resource group exists
        if ! resource_exists "group" "$RESOURCE_GROUP"; then
            print_warning "Resource group does not exist: $RESOURCE_GROUP"
            remove_kubeconfig_context
            print_success "Nothing to delete"
            exit 0
        fi
        
        # List resources in the group
        print_status "Listing resources in resource group $RESOURCE_GROUP..."
        echo
        az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name,Type:type}" -o table
        echo
        
        # Confirm deletion
        if ! confirm_deletion "the entire resource group '$RESOURCE_GROUP' and ALL resources in it"; then
            print_warning "Cleanup cancelled by user"
            exit 0
        fi
        
        # Delete resource group
        print_status "Deleting resource group: $RESOURCE_GROUP..."
        print_status "This will delete all resources in the group..."
        
        az group delete \
            --name "$RESOURCE_GROUP" \
            --yes \
            --no-wait
        
        # Wait for deletion
        wait_for_deletion "Waiting for resource group deletion" \
            "az group show --name '$RESOURCE_GROUP'" \
            600
        
        print_success "Resource group deleted: $RESOURCE_GROUP"
        
    else
        # Cluster-only cleanup
        
        # Check if cluster exists
        if ! resource_exists "cluster" "$CLUSTER_NAME" "$RESOURCE_GROUP"; then
            print_warning "Cluster does not exist: $CLUSTER_NAME"
            remove_kubeconfig_context
            print_success "Nothing to delete"
            exit 0
        fi
        
        # Get cluster details
        print_status "Getting cluster details..."
        NODE_COUNT=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
            --query "agentPoolProfiles[0].count" -o tsv 2>/dev/null || echo "unknown")
        NODE_SIZE=$(az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
            --query "agentPoolProfiles[0].vmSize" -o tsv 2>/dev/null || echo "unknown")
        
        echo
        echo "Cluster Details:"
        echo "==============="
        echo "Name: $CLUSTER_NAME"
        echo "Nodes: $NODE_COUNT x $NODE_SIZE"
        echo
        
        # Confirm deletion
        if ! confirm_deletion "AKS cluster '$CLUSTER_NAME'"; then
            print_warning "Cleanup cancelled by user"
            exit 0
        fi
        
        # Delete cluster
        print_status "Deleting AKS cluster: $CLUSTER_NAME..."
        
        az aks delete \
            --resource-group "$RESOURCE_GROUP" \
            --name "$CLUSTER_NAME" \
            --yes \
            --no-wait
        
        # Wait for deletion
        wait_for_deletion "Waiting for cluster deletion" \
            "az aks show --resource-group '$RESOURCE_GROUP' --name '$CLUSTER_NAME'" \
            300
        
        print_success "AKS cluster deleted: $CLUSTER_NAME"
        
        # Check if resource group is empty
        RESOURCE_COUNT=$(az resource list --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        
        if [[ "$RESOURCE_COUNT" -eq 0 ]]; then
            echo
            print_status "Resource group '$RESOURCE_GROUP' is now empty"
            read -p "Do you want to delete the empty resource group? (y/n): " delete_empty
            
            if [[ "${delete_empty,,}" == "y" ]]; then
                print_status "Deleting empty resource group..."
                az group delete --name "$RESOURCE_GROUP" --yes --no-wait
                wait_for_deletion "Waiting for resource group deletion" \
                    "az group show --name '$RESOURCE_GROUP'" \
                    120
                print_success "Empty resource group deleted"
            fi
        elif [[ "$RESOURCE_COUNT" -gt 0 ]]; then
            print_warning "Resource group still contains $RESOURCE_COUNT resources"
            echo "To delete everything, run: $0 --full"
        fi
    fi
    
    # Clean up kubeconfig
    remove_kubeconfig_context
    
    # Final summary
    echo
    print_success "========================================="
    print_success "         CLEANUP COMPLETED              "
    print_success "========================================="
    echo
    
    if $FULL_CLEANUP; then
        echo "✅ Deleted resource group: $RESOURCE_GROUP"
        echo "✅ Deleted all resources in the group"
    else
        echo "✅ Deleted AKS cluster: $CLUSTER_NAME"
    fi
    echo "✅ Removed kubeconfig context: azure-aks"
    echo
    
    # Cost savings estimate
    MONTHLY_COST=160  # Approximate monthly cost in USD
    DAILY_COST=$((MONTHLY_COST / 30))
    echo "💰 Estimated savings: ~\$${DAILY_COST}/day or ~\$${MONTHLY_COST}/month"
    echo
    
    print_success "Cleanup completed successfully!"
}

# Run main function
main "$@"