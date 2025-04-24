#!/bin/bash
# filename: net2-delete-tailscale-cluster.sh
# description: Removes Tailscale operator and related resources from Kubernetes and Tailscale tailnet
# 
# This script is used to clean up the Tailscale infrastructure that was set up by
# net2-setup-tailscale-cluster.sh. It removes the Tailscale operator, related
# Kubernetes resources, and provides instructions for cleaning up Tailscale devices.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Tailscale API credentials (optional, for automatic device cleanup):
#   - TAILSCALE_CLIENTID
#   - TAILSCALE_CLIENTSECRET
#   - TAILSCALE_TAILNET
#   - TAILSCALE_DOMAIN
#
# Usage: ./net2-delete-tailscale-cluster.sh [optional:kubeconfig-path]
# example: ./net2-delete-tailscale-cluster.sh /mnt/urbalurbadisk/kubeconfig/kubeconf-all
#
# Related scripts:
# - net2-setup-tailscale-cluster.sh: Sets up the Tailscale infrastructure
# - net2-expose-tailscale-service.sh: Used to expose individual services
#
# Exit codes:
# 0 - Success
# 1 - Kubeconfig file not found
# 2 - Failed to remove Helm release
# 3 - Failed to remove Kubernetes resources
# 4 - Failed to remove Tailscale namespace

set -e

# Variables
KUBECONFIG_PATH=${1:-"/mnt/urbalurbadisk/kubeconfig/kubeconf-all"}
LOG_FILE="/tmp/tailscale-cleanup-$(date +%Y%m%d-%H%M%S).log"

# Function to get secret from Kubernetes
get_secret() {
    local secret_name=$1
    kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.$secret_name}" --kubeconfig "$KUBECONFIG_PATH" | base64 -d
}

# Function to log messages
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    log "ERROR: Kubeconfig file not found at $KUBECONFIG_PATH"
    exit 1
fi

log "Starting Tailscale cleanup with kubeconfig: $KUBECONFIG_PATH"
log "---------------------------------------------------"

# Get Tailscale secrets from Kubernetes
log "Reading Tailscale secrets from Kubernetes..."
TAILSCALE_CLIENTID=$(get_secret "TAILSCALE_CLIENTID")
TAILSCALE_CLIENTSECRET=$(get_secret "TAILSCALE_CLIENTSECRET")
TAILSCALE_TAILNET=$(get_secret "TAILSCALE_TAILNET")

# Step 1: Check for Tailscale resources
log "Checking for Tailscale resources..."
INGRESS_EXISTS=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress -n kube-system -o name | grep -c "traefik-ingress" || true)
OPERATOR_EXISTS=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale -o name 2>/dev/null || true)
TAILSCALE_DEVICES=$(tailscale status | grep -E 'tailscale-operator|ts-' | awk '{print $1}')

# Step 2: Remove Helm release
log "Removing Tailscale Helm release..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale &>/dev/null; then
    helm --kubeconfig="$KUBECONFIG_PATH" uninstall tailscale-operator -n tailscale 2>/dev/null || log "No Helm release found or already removed"
    log "Helm release removed (or was not present)"
else
    log "Tailscale namespace not found, skipping Helm uninstall"
fi

# Step 3: Remove Ingress resources
log "Removing Tailscale Ingress resources..."
if [ "$INGRESS_EXISTS" -gt 0 ]; then
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress traefik-ingress -n kube-system 2>/dev/null || log "Failed to delete ingress or already removed"
    log "Ingress resources removed"
else
    log "No Tailscale Ingress resources found"
fi

# Step 4: Force delete any remaining pods in the tailscale namespace
log "Force deleting any remaining pods in tailscale namespace..."
if [ -n "$OPERATOR_EXISTS" ]; then
    # Delete all pods with force
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete pods --all -n tailscale --force --grace-period=0 2>/dev/null || log "No pods to delete or already removed"
    
    # Wait a moment for pod deletion
    sleep 5
    
    # Delete the namespace
    log "Removing Tailscale namespace..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete namespace tailscale --wait=false 2>/dev/null || log "Failed to delete namespace or already removed"
    
    # Force delete the namespace if it still exists after 10 seconds
    sleep 10
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale &>/dev/null; then
        log "Namespace still exists, attempting force deletion..."
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete namespace tailscale --force --grace-period=0 2>/dev/null || log "Force delete failed"
    fi
    log "Tailscale namespace removal initiated"
else
    log "Tailscale namespace not found"
fi

# Step 5: Check for and remove Tailscale devices from tailnet
if [ -n "$TAILSCALE_DEVICES" ]; then
    log "Found Tailscale devices in tailnet:"
    echo "$TAILSCALE_DEVICES" | tee -a "$LOG_FILE"
    
    # If we have API credentials, try to remove devices automatically
    if [ -n "$TAILSCALE_CLIENTID" ] && [ -n "$TAILSCALE_CLIENTSECRET" ] && [ -n "$TAILSCALE_TAILNET" ]; then
        log "Attempting to remove devices using Tailscale API..."
        for device in $TAILSCALE_DEVICES; do
            # Get device ID from name
            device_id=$(curl -s -u "${TAILSCALE_CLIENTID}:${TAILSCALE_CLIENTSECRET}" \
                "https://api.tailscale.com/api/v2/tailnet/${TAILSCALE_TAILNET}/devices" | \
                jq -r ".devices[] | select(.name==\"$device\") | .id")
            
            if [ -n "$device_id" ]; then
                log "Removing device $device (ID: $device_id)..."
                curl -s -X DELETE -u "${TAILSCALE_CLIENTID}:${TAILSCALE_CLIENTSECRET}" \
                    "https://api.tailscale.com/api/v2/device/$device_id" || \
                    log "Failed to remove device $device via API"
            fi
        done
    else
        log "These devices need to be manually removed from the Tailscale admin console."
        log "Visit: https://login.tailscale.com/admin/machines"
        log ""
        log "Instructions for manual removal:"
        log "1. Go to the Tailscale admin console (URL above)"
        log "2. Find the 'tailscale-operator' device and any devices starting with 'ts-'"
        log "3. Click on each device and select 'Delete' from the options"
    fi
else
    log "No Tailscale devices found in tailnet"
fi

# Step 6: Verify cleanup
log "Verifying cleanup..."
kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale 2>/dev/null || log "Tailscale namespace confirmed deleted"
kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress -n kube-system 2>/dev/null | grep -q traefik-ingress || log "Tailscale Ingress confirmed deleted"

log "---------------------------------------------------"
log "Cleanup completed successfully!"
log "Don't forget to manually remove the Tailscale devices from your tailnet if needed."
log "Log file saved to: $LOG_FILE"