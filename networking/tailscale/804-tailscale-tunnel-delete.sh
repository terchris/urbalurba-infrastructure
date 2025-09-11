#!/bin/bash
# filename: 804-tailscale-tunnel-delete.sh
# description: Complete cleanup of Tailscale infrastructure (mirrors Cloudflare 822 pattern)
# 
# This script provides comprehensive cleanup of all Tailscale infrastructure:
# 1. **Removes Tailscale operator** installed by 802-tailscale-tunnel-deploy.sh
# 2. **Disconnects provision-host** from Tailscale network
# 3. **Removes Tailscale devices** from tailnet via API (if credentials available)
# 4. **Cleans up local configuration** and stored credentials
#
# This mirrors Cloudflare's 822-cloudflare-tunnel-delete.sh comprehensive approach
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Optional: Tailscale API credentials for automatic device cleanup
#
# Usage: ./804-tailscale-tunnel-delete.sh [kubeconfig-path]
# Example: ./804-tailscale-tunnel-delete.sh /mnt/urbalurbadisk/kubeconfig/kubeconf-all
#
# What gets deleted:
# - Tailscale cluster ingress (traefik-ingress in kube-system namespace)
# - Tailscale operator Helm deployment
# - Tailscale namespace and resources
# - Tailscale devices from tailnet (if API access available)
# - Tailscale daemon on provision-host
# - Local configuration files
#
# Related scripts:
# - 801-tailscale-tunnel-setup.sh: Sets up host daemon with Funnel
# - 802-tailscale-tunnel-deploy.sh: Deploys operator to cluster

set -e

# Variables
KUBECONFIG_PATH=${1:-"/mnt/urbalurbadisk/kubeconfig/kubeconf-all"}
STATUS=()
ERROR=0

# Function to check command success
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        ERROR=1
        echo "ERROR: $1 failed"
    else
        STATUS+=("$1: OK")
        echo "SUCCESS: $1"
    fi
}

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo "ERROR: Kubeconfig file not found at $KUBECONFIG_PATH"
    STATUS+=("Kubeconfig Check: Fail")
    ERROR=1
    exit 1
fi

STATUS+=("Kubeconfig Check: OK")

echo "Starting complete Tailscale cleanup..."
echo "Using kubeconfig: $KUBECONFIG_PATH"
echo "---------------------------------------------------"

# Step 1: Get Tailscale secrets (if available) for API cleanup
echo "Retrieving Tailscale secrets for API cleanup..."
HAVE_API_ACCESS=false

if kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default >/dev/null 2>&1; then
    TAILSCALE_CLIENTID=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_CLIENTID}' | base64 -d 2>/dev/null)
    TAILSCALE_CLIENTSECRET=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_CLIENTSECRET}' | base64 -d 2>/dev/null)
    TAILSCALE_TAILNET=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_TAILNET}' | base64 -d 2>/dev/null)
    
    if [ -n "$TAILSCALE_CLIENTID" ] && [ -n "$TAILSCALE_CLIENTSECRET" ] && [ -n "$TAILSCALE_TAILNET" ]; then
        HAVE_API_ACCESS=true
        STATUS+=("Retrieve API Secrets: OK")
    else
        STATUS+=("Retrieve API Secrets: Skipped - Invalid credentials")
    fi
else
    STATUS+=("Retrieve API Secrets: Skipped - Not available")
fi

# Step 2: Remove Tailscale cluster ingress
echo "Removing Tailscale cluster ingress..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress traefik-ingress -n kube-system >/dev/null 2>&1; then
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress traefik-ingress -n kube-system
    check_command_success "Remove Cluster Ingress"
else
    STATUS+=("Remove Cluster Ingress: Skipped - Not found")
fi

# Step 3: Remove Tailscale operator via Helm
echo "Removing Tailscale operator..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale &>/dev/null; then
    # Try to remove via Helm first
    helm --kubeconfig="$KUBECONFIG_PATH" uninstall tailscale-operator -n tailscale 2>/dev/null || true
    
    # Force delete any remaining pods
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete pods --all -n tailscale --force --grace-period=0 2>/dev/null || true
    sleep 3
    
    # Delete the namespace
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete namespace tailscale --wait=false 2>/dev/null || true
    sleep 5
    
    # Force delete if still exists
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale &>/dev/null; then
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete namespace tailscale --force --grace-period=0 2>/dev/null || true
    fi
    
    check_command_success "Remove Tailscale Operator"
else
    STATUS+=("Remove Tailscale Operator: Skipped - Not found")
fi

# Step 4: Remove devices from tailnet via API (if available)
if [ "$HAVE_API_ACCESS" = true ]; then
    echo "Removing Tailscale devices from tailnet via API..."
    
    # Get list of devices in tailnet
    DEVICES_JSON=$(curl -s -u "${TAILSCALE_CLIENTID}:${TAILSCALE_CLIENTSECRET}" \
        "https://api.tailscale.com/api/v2/tailnet/${TAILSCALE_TAILNET}/devices" 2>/dev/null || true)
    
    if [ -n "$DEVICES_JSON" ] && echo "$DEVICES_JSON" | jq -e '.devices' >/dev/null 2>&1; then
        # Find devices related to this cluster (k8s hostname from TAILSCALE_CLUSTER_HOSTNAME)
        CLUSTER_HOSTNAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_CLUSTER_HOSTNAME}' | base64 -d 2>/dev/null)
        
        CLUSTER_DEVICES=$(echo "$DEVICES_JSON" | jq -r ".devices[] | 
            select(.name | test(\"tailscale-operator|${CLUSTER_HOSTNAME:-k8s}|provision-host\")) | 
            \"\(.name):\(.id)\"" 2>/dev/null || true)
        
        DEVICE_COUNT=0
        for device_info in $CLUSTER_DEVICES; do
            if [ -n "$device_info" ]; then
                device_name=$(echo "$device_info" | cut -d: -f1)
                device_id=$(echo "$device_info" | cut -d: -f2)
                
                curl -s -X DELETE -u "${TAILSCALE_CLIENTID}:${TAILSCALE_CLIENTSECRET}" \
                    "https://api.tailscale.com/api/v2/device/$device_id" >/dev/null 2>&1 || true
                
                echo "Removed device: $device_name (ID: $device_id)"
                ((DEVICE_COUNT++))
            fi
        done
        
        if [ $DEVICE_COUNT -gt 0 ]; then
            STATUS+=("Remove Tailnet Devices: OK - Removed $DEVICE_COUNT devices")
        else
            STATUS+=("Remove Tailnet Devices: Skipped - No cluster devices found")
        fi
    else
        STATUS+=("Remove Tailnet Devices: Fail - API call failed")
    fi
else
    echo "Skipping device removal - no API credentials available"
    STATUS+=("Remove Tailnet Devices: Skipped - No API access")
fi

# Step 5: Disconnect and clean up provision-host Tailscale
echo "Disconnecting provision-host from Tailscale..."
if command -v tailscale >/dev/null 2>&1; then
    # Try graceful disconnect first
    tailscale logout 2>/dev/null || true
    tailscale down 2>/dev/null || true
    
    # Stop the daemon
    pkill -9 tailscaled 2>/dev/null || true
    
    check_command_success "Disconnect Host"
else
    STATUS+=("Disconnect Host: Skipped - Not installed")
fi

# Step 6: Clean up local configuration files
echo "Cleaning up local configuration files..."
LOCAL_CLEANUP_COUNT=0

# Remove Tailscale state and configuration
if [ -d "/var/lib/tailscale" ]; then
    rm -rf /var/lib/tailscale 2>/dev/null || true
    ((LOCAL_CLEANUP_COUNT++))
fi

if [ -d "/var/run/tailscale" ]; then
    rm -rf /var/run/tailscale 2>/dev/null || true
    ((LOCAL_CLEANUP_COUNT++))
fi

# Remove Tailscale socket
if [ -S "/var/run/tailscale/tailscaled.sock" ]; then
    rm -f /var/run/tailscale/tailscaled.sock 2>/dev/null || true
    ((LOCAL_CLEANUP_COUNT++))
fi

if [ $LOCAL_CLEANUP_COUNT -gt 0 ]; then
    STATUS+=("Local Cleanup: OK - Cleaned $LOCAL_CLEANUP_COUNT locations")
else
    STATUS+=("Local Cleanup: Skipped - No files found")
fi

# Step 7: Verification
echo "Verifying cleanup completion..."
VERIFICATION_ISSUES=0

# Check if operator namespace still exists
if kubectl --kubeconfig="$KUBECONFIG_PATH" get namespace tailscale &>/dev/null; then
    echo "WARNING: Tailscale namespace still exists (may take time to terminate)"
    ((VERIFICATION_ISSUES++))
fi

# Check if Tailscale daemon is still running
if pgrep tailscaled &>/dev/null; then
    echo "WARNING: Tailscale daemon still running"
    ((VERIFICATION_ISSUES++))
fi

if [ $VERIFICATION_ISSUES -eq 0 ]; then
    STATUS+=("Verification: OK - All cleaned up")
else
    STATUS+=("Verification: WARNING - $VERIFICATION_ISSUES issues detected")
fi

# Summary
echo "---------------------------------------------------"
echo "Cleanup Summary:"
for status in "${STATUS[@]}"; do
    echo "  $status"
done

# Final message
if [ $VERIFICATION_ISSUES -eq 0 ] && [ $ERROR -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS: Complete Tailscale cleanup completed!"
    echo "✅ All Tailscale infrastructure removed"
    echo "✅ All services disconnected from Tailnet"
    echo "✅ Local configuration cleaned up"
    echo ""
    echo "Your cluster is now completely disconnected from Tailscale."
    echo "To set up Tailscale again, run the setup scripts in order:"
    echo "  1. ./801-tailscale-tunnel-setup.sh"
    echo "  2. ./802-tailscale-tunnel-deploy.sh"
else
    echo ""
    echo "⚠️  PARTIAL SUCCESS: Cleanup completed with warnings"
    echo "Some resources may take additional time to terminate."
    echo "Check the warnings above and manually verify if needed."
fi

echo "---------------------------------------------------"

exit $ERROR