#!/bin/bash
# filename: 803-tailscale-tunnel-deletehost.sh
# description: Remove a Tailscale ingress for a specific service
#
# This script removes a Tailscale ingress and cleans up the associated pod
#
# Usage: ./803-tailscale-tunnel-deletehost.sh <hostname>
# Example: ./803-tailscale-tunnel-deletehost.sh whoami
# Example: ./803-tailscale-tunnel-deletehost.sh authentik
#
# Result:
# - Deletes Tailscale ingress for the service
# - Removes associated Tailscale pod
# - Cleans up Tailscale device from network

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

set -e

# Variables
KUBECONFIG_PATH="/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all"

# Parse arguments
HOSTNAME="$1"

# Validate arguments
if [ -z "$HOSTNAME" ]; then
    echo "Usage: $0 <hostname>"
    echo ""
    echo "Examples:"
    echo "  $0 whoami"
    echo "  $0 authentik"
    echo ""
    echo "Available Tailscale ingresses:"
    kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress -A 2>/dev/null | grep tailscale | awk '{print "  " $2 " (ns: " $1 ")"}' | sed 's/-tailscale / /'
    exit 1
fi

# Derive ingress name
INGRESS_NAME="${HOSTNAME}-tailscale"

# Check if ingress exists (check default namespace first, then all namespaces)
INGRESS_NAMESPACE=""
if kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n default >/dev/null 2>&1; then
    INGRESS_NAMESPACE="default"
elif kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n kube-system >/dev/null 2>&1; then
    INGRESS_NAMESPACE="kube-system"
fi

if [ -z "$INGRESS_NAMESPACE" ]; then
    echo "Error: Ingress '$INGRESS_NAME' not found"
    echo ""
    echo "Available Tailscale ingresses:"
    kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress -A 2>/dev/null | grep tailscale | awk '{print "  " $2 " (ns: " $1 ")"}'
    exit 1
fi

echo "Found ingress '$INGRESS_NAME' in namespace '$INGRESS_NAMESPACE'"

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

# Check environment
if [ ! -d "/mnt/urbalurbadisk/ansible" ]; then
    echo "This script must be run from within the provision-host container"
    echo "Required directories not found: /mnt/urbalurbadisk/ansible"
    STATUS+=("Environment check: Fail")
    ERROR=1
else
    STATUS+=("Environment check: OK")
fi

echo "Removing Tailscale ingress: $INGRESS_NAME"
echo ""

# Get the ingress details before deletion
echo "Getting ingress details..."
INGRESS_HOST=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n "$INGRESS_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$INGRESS_HOST" ]; then
    echo "Current hostname: $INGRESS_HOST"
fi

# Find associated pod
echo "Finding associated Tailscale pod..."
POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale -o name | grep "ts-${INGRESS_NAME}" | head -1)
if [ -n "$POD_NAME" ]; then
    echo "Found pod: $POD_NAME"
else
    echo "No associated pod found (may already be deleted)"
fi

# Delete the ingress
echo "Deleting ingress '$INGRESS_NAME' from namespace '$INGRESS_NAMESPACE'..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress "$INGRESS_NAME" -n "$INGRESS_NAMESPACE"
check_command_success "Delete ingress"

# Wait for pod cleanup (Tailscale operator should handle this automatically)
if [ -n "$POD_NAME" ]; then
    echo "Waiting for pod cleanup..."
    RETRIES=30
    while [ $RETRIES -gt 0 ]; do
        if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get "$POD_NAME" -n tailscale >/dev/null 2>&1; then
            echo "Pod cleaned up successfully"
            STATUS+=("Pod cleanup: OK")
            break
        fi
        echo "Waiting for pod to be removed... ($RETRIES retries left)"
        sleep 2
        RETRIES=$((RETRIES - 1))
    done
    
    if [ $RETRIES -eq 0 ]; then
        echo "Warning: Pod cleanup is taking longer than expected"
        STATUS+=("Pod cleanup: Timeout")
    fi
fi

# Clean up Tailscale device from tailnet via Ansible playbook
echo ""
echo "Cleaning up Tailscale device from tailnet..."
CLEANUP_PLAYBOOK="/mnt/urbalurbadisk/ansible/playbooks/803-tailscale-device-cleanup.yml"

if [ -f "$CLEANUP_PLAYBOOK" ]; then
    cd /mnt/urbalurbadisk && ansible-playbook "$CLEANUP_PLAYBOOK" \
        -e "cleanup_hostname=$HOSTNAME" 2>&1 || true
    STATUS+=("API Device Cleanup: OK")
else
    echo "Warning: Device cleanup playbook not found at $CLEANUP_PLAYBOOK"
    STATUS+=("API Device Cleanup: Skipped - Playbook not found")
fi

# Verify deletion
echo ""
echo "Verifying deletion..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n "$INGRESS_NAMESPACE" >/dev/null 2>&1; then
    echo "Warning: Ingress still exists"
    STATUS+=("Verification: Fail")
    ERROR=1
else
    echo "Ingress successfully deleted"
    STATUS+=("Verification: OK")
fi

echo ""
echo "------ Summary of deletion statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo ""
    echo "❌ DELETION COMPLETED WITH WARNINGS"
    echo "Some operations may have failed - check messages above"
else
    echo ""
    echo "✅ TAILSCALE INGRESS DELETED SUCCESSFULLY"
    if [ -n "$INGRESS_HOST" ]; then
        echo "Removed access to: https://$INGRESS_HOST"
    else
        echo "Removed ingress: $INGRESS_NAME"
    fi
    echo ""
    echo "Note: DNS entries may take a few minutes to be removed from Tailscale"
fi

echo "-----------------------------------------------------------"

# Show remaining ingresses
echo ""
echo "Remaining Tailscale ingresses:"
kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress -A 2>/dev/null | grep tailscale || echo "  None"

exit $ERROR