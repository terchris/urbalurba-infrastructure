#!/bin/bash
# filename: 803-tailscale-tunnel-addhost.sh
# description: Add a new Tailscale ingress for a specific service
#
# This script creates a Tailscale ingress that exposes a service at:
# https://SERVICE.dog-pence.ts.net (accessible from public internet)
#
# Prerequisites:
# - Tailscale operator deployed via 802-tailscale-tunnel-deploy.sh
# - Target service must exist in the cluster
#
# Usage: ./803-tailscale-tunnel-addhost.sh <service-name> [namespace] [port]
# Example: ./803-tailscale-tunnel-addhost.sh whoami
# Example: ./803-tailscale-tunnel-addhost.sh whoami default 80
# Example: ./803-tailscale-tunnel-addhost.sh openwebui default 8080
#
# Result:
# - Creates Tailscale ingress for the service
# - Service accessible at https://SERVICE.dog-pence.ts.net
# - Public internet access via Tailscale Funnel

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

set -e

# Variables
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
PLAYBOOK_PATH="/mnt/urbalurbadisk/ansible/playbooks/803-tailscale-tunnel-addhost.yml"

# Parse arguments
SERVICE_NAME="$1"
NAMESPACE="${2:-default}"
SERVICE_PORT="${3:-80}"

# Validate arguments
if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name> [namespace] [port]"
    echo ""
    echo "Examples:"
    echo "  $0 whoami"
    echo "  $0 whoami default 80"
    echo "  $0 openwebui default 8080"
    echo ""
    echo "Note: Most services work with default namespace and port 80"
    echo "The Tailscale ingress handles HTTP/HTTPS automatically"
    exit 1
fi

# Check if service exists
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get service "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Service '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
    echo ""
    echo "Available services in namespace '$NAMESPACE':"
    kubectl --kubeconfig="$KUBECONFIG_PATH" get services -n "$NAMESPACE" --no-headers | awk '{print "  " $1}'
    exit 1
fi

# Get Tailscale domain from secrets
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default >/dev/null 2>&1; then
    echo "Error: urbalurba-secrets not found"
    echo "Tailscale secrets must be configured first"
    exit 1
fi

TAILSCALE_DOMAIN=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_DOMAIN}' | base64 -d 2>/dev/null)
if [ -z "$TAILSCALE_DOMAIN" ]; then
    echo "Error: TAILSCALE_DOMAIN not found in urbalurba-secrets"
    exit 1
fi

# Check if Tailscale operator is running
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale -l app=operator >/dev/null 2>&1; then
    echo "Error: Tailscale operator not found"
    echo "Run ./802-tailscale-tunnel-deploy.sh first to deploy the operator"
    exit 1
fi

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

# Add parameter values to STATUS
STATUS+=("SERVICE_NAME: $SERVICE_NAME")
STATUS+=("NAMESPACE: $NAMESPACE")
STATUS+=("SERVICE_PORT: $SERVICE_PORT")

echo "Adding Tailscale ingress for service: $SERVICE_NAME"
echo "Namespace: $NAMESPACE"
echo "Port: $SERVICE_PORT"
echo "Domain: $TAILSCALE_DOMAIN"
echo "Will be accessible at: https://$SERVICE_NAME.$TAILSCALE_DOMAIN"
echo ""

# Execute the Ansible playbook
echo "Creating Tailscale ingress..."
cd /mnt/urbalurbadisk/ansible && ansible-playbook $PLAYBOOK_PATH \
    -e SERVICE_NAME="$SERVICE_NAME" \
    -e NAMESPACE="$NAMESPACE" \
    -e SERVICE_PORT="$SERVICE_PORT" \
    -e TAILSCALE_DOMAIN="$TAILSCALE_DOMAIN"
check_command_success "Create Tailscale ingress"

echo ""
echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo ""
    echo "❌ INGRESS CREATION FAILED"
    echo "Check the error messages above"
else
    echo ""
    echo "✅ TAILSCALE INGRESS CREATED SUCCESSFULLY"
    echo "Service '$SERVICE_NAME' is now accessible at:"
    echo "  https://$SERVICE_NAME.$TAILSCALE_DOMAIN"
    echo ""
    echo "Note: It may take 1-2 minutes for the DNS to become available"
    echo "Test with: curl https://$SERVICE_NAME.$TAILSCALE_DOMAIN"
fi

echo "-----------------------------------------------------------"

exit $ERROR