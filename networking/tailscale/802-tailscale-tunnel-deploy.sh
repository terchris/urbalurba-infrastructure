#!/bin/bash
# filename: 802-tailscale-tunnel-deploy.sh
# description: Unified Tailscale tunnel deployment and service ingress creation
#
# This script:
# 1. **Deploys Tailscale operator** to the cluster (if not already running)
# 2. **Creates Tailscale ingress** for a specific service or cluster entry point
# 3. **Handles both existing services and catch-all behavior** for non-existent services
#
# Prerequisites:
# - urbalurba-secrets must exist in cluster with valid Tailscale keys
# - Run 801-tailscale-tunnel-setup.sh first to validate Tailscale setup
#
# Usage: ./802-tailscale-tunnel-deploy.sh [service-name] [optional-hostname]
# Examples:
#   ./802-tailscale-tunnel-deploy.sh                    # Deploy operator only
#   ./802-tailscale-tunnel-deploy.sh whoami             # Deploy operator + whoami ingress (hostname=whoami)
#   ./802-tailscale-tunnel-deploy.sh authentik          # Deploy operator + authentik ingress (hostname=authentik)
#   ./802-tailscale-tunnel-deploy.sh grafana my-grafana # Deploy operator + grafana ingress (hostname=my-grafana)
#
# Result:
# - Tailscale operator running in cluster
# - Service accessible at https://SERVICE.dog-pence.ts.net (or catch-all for non-existent services)
# - Public internet access via Tailscale Funnel

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

set -e

# Source centralized path library for backwards-compatible path resolution
if [[ -f "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh" ]]; then
    source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"
fi

# Variables
KUBECONFIG_PATH="/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all"
OPERATOR_PLAYBOOK_PATH="/mnt/urbalurbadisk/ansible/playbooks/802-deploy-network-tailscale-tunnel.yml"
INGRESS_PLAYBOOK_PATH="/mnt/urbalurbadisk/ansible/playbooks/802-tailscale-tunnel-addhost.yml"

# Parse arguments
SERVICE_NAME="$1"
INGRESS_HOSTNAME="${2:-$SERVICE_NAME}"

# Validate Tailscale secrets exist
if ! kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default >/dev/null 2>&1; then
    echo "Error: No urbalurba-secrets found"
    echo "Run ./801-tailscale-tunnel-setup.sh first to validate Tailscale configuration"
    exit 1
fi

# Check for template values in secrets
TAILSCALE_SECRET=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_SECRET}' | base64 -d 2>/dev/null)
if [[ "$TAILSCALE_SECRET" == *"tskey-auth-ktyTufs"* || "$TAILSCALE_SECRET" == *"XXXXXXX"* ]]; then
    echo "Error: Tailscale secrets contain template values"
    echo "Update your Kubernetes secrets with valid Tailscale keys first"
    exit 1
fi

# Get Tailscale domain from secrets
TAILSCALE_DOMAIN=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_DOMAIN}' | base64 -d 2>/dev/null)
if [ -z "$TAILSCALE_DOMAIN" ]; then
    echo "Error: TAILSCALE_DOMAIN not found in urbalurba-secrets"
    exit 1
fi

# Get cluster hostname from secrets
TAILSCALE_PUBLIC_HOSTNAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_PUBLIC_HOSTNAME}' | base64 -d 2>/dev/null)
if [ -z "$TAILSCALE_PUBLIC_HOSTNAME" ]; then
    echo "Error: TAILSCALE_PUBLIC_HOSTNAME not found in urbalurba-secrets"
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
if [ ! -d "/mnt/urbalurbadisk/ansible" ] || [ ! -d "/mnt/urbalurbadisk/.uis.secrets" ]; then
    echo "This script must be run from within the provision-host container"
    echo "Required directories not found: /mnt/urbalurbadisk/ansible or /mnt/urbalurbadisk/.uis.secrets"
    STATUS+=("Environment check: Fail")
    ERROR=1
else
    STATUS+=("Environment check: OK")
fi

# Check if Tailscale operator is running
OPERATOR_RUNNING=false
# Check if there are any running pods in the tailscale namespace
if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q "Running"; then
    # Check if any of those pods are actually the operator
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "(operator|tailscale)" | grep -q "Running"; then
        OPERATOR_RUNNING=true
        STATUS+=("Tailscale operator: Already running")
        echo "✅ Tailscale operator is already running"
    else
        STATUS+=("Tailscale operator: Not running (other pods found)")
        echo "⚠️  Tailscale operator not found - will deploy it"
    fi
else
    STATUS+=("Tailscale operator: Not running")
    echo "⚠️  Tailscale operator not found - will deploy it"
fi

# If no service specified, deploy operator only and exit
if [ -z "$SERVICE_NAME" ]; then
    if [ "$OPERATOR_RUNNING" = false ]; then
        echo ""
        echo "Deploying Tailscale operator: $TAILSCALE_PUBLIC_HOSTNAME"
        echo "Using playbook: $OPERATOR_PLAYBOOK_PATH"
        echo ""
        
        # Execute the operator deployment playbook (includes cluster ingress)
        echo "Deploying Tailscale operator (this may take a few minutes)..."
        cd /mnt/urbalurbadisk/ansible && ansible-playbook $OPERATOR_PLAYBOOK_PATH -e TAILSCALE_PUBLIC_HOSTNAME="$TAILSCALE_PUBLIC_HOSTNAME"
        check_command_success "Deploy Tailscale operator"
        
        # Wait for operator to be ready
        echo "Waiting for Tailscale operator to be ready..."
        for i in {1..12}; do
            if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "(operator|tailscale)" | grep -q "Running"; then
                echo "✅ Tailscale operator is ready"
                STATUS+=("Tailscale operator: Deployed and ready")
                break
            fi
            echo "Waiting... ($i/12)"
            sleep 10
        done
    else
        echo "✅ Tailscale operator is already running - no changes needed"
    fi
    
    echo ""
    echo "✅ Tailscale operator deployment completed"
    echo ""
    echo "To add individual services, run:"
    echo "  ./802-tailscale-tunnel-deploy.sh whoami"
    echo "  ./802-tailscale-tunnel-deploy.sh authentik"
    echo "  ./802-tailscale-tunnel-deploy.sh grafana"
    echo ""
    echo "Each service will be accessible at: https://[service-name].$TAILSCALE_DOMAIN"
    echo ""
    echo "Note: If a service doesn't exist, Traefik will serve the catch-all nginx page"
    echo ""
    echo "DNS Troubleshooting:"
    echo "  Check DNS resolution: nslookup [service-name].$TAILSCALE_DOMAIN"
    echo "  Check DNS details: dig [service-name].$TAILSCALE_DOMAIN"
    echo "  Note: DNS propagation can take 1-5 minutes globally"
    exit 0
fi

# For individual services, only deploy operator if not running (no cluster ingress)
if [ "$OPERATOR_RUNNING" = false ]; then
    echo ""
    echo "Deploying Tailscale operator only (no cluster ingress for individual service)"
    echo "Using playbook: $OPERATOR_PLAYBOOK_PATH"
    echo ""
    
    # Execute the operator deployment playbook (includes cluster ingress - we'll clean it up)
    echo "Deploying Tailscale operator (this may take a few minutes)..."
    cd /mnt/urbalurbadisk/ansible && ansible-playbook $OPERATOR_PLAYBOOK_PATH -e TAILSCALE_PUBLIC_HOSTNAME="$TAILSCALE_PUBLIC_HOSTNAME"
    check_command_success "Deploy Tailscale operator"
    
    # Wait for operator to be ready
    echo "Waiting for Tailscale operator to be ready..."
    for i in {1..12}; do
        if kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -n tailscale --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "(operator|tailscale)" | grep -q "Running"; then
            echo "✅ Tailscale operator is ready"
            STATUS+=("Tailscale operator: Deployed and ready")
            break
        fi
        echo "Waiting... ($i/12)"
        sleep 10
    done
    
    # Remove the cluster ingress since we only want individual services
    echo "Removing cluster ingress (keeping only individual service ingresses)..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress traefik-ingress -n kube-system --ignore-not-found=true
    check_command_success "Remove cluster ingress"
fi

# Skip service validation - Traefik handles routing
STATUS+=("Service validation: Skipped - Traefik handles routing")
echo "✅ Skipping service validation - Traefik will handle routing to $SERVICE_NAME"

# Add parameter values to STATUS
STATUS+=("SERVICE_NAME: $SERVICE_NAME")
STATUS+=("HOSTNAME: $INGRESS_HOSTNAME")
STATUS+=("DOMAIN: $TAILSCALE_DOMAIN")

echo ""
echo "Creating Tailscale ingress for: $SERVICE_NAME"
echo "Hostname: $INGRESS_HOSTNAME"
echo "Domain: $TAILSCALE_DOMAIN"
echo "Will be accessible at: https://$INGRESS_HOSTNAME.$TAILSCALE_DOMAIN"
echo "Traefik will handle routing to the appropriate service"
echo ""

# Execute the ingress creation playbook
echo "Creating Tailscale ingress..."
cd /mnt/urbalurbadisk/ansible && ansible-playbook $INGRESS_PLAYBOOK_PATH \
    -e service_name="$SERVICE_NAME" \
    -e ingress_hostname="$INGRESS_HOSTNAME" \
    -e tailscale_domain="$TAILSCALE_DOMAIN" \
    -e SKIP_OPERATOR_CHECK="true"
check_command_success "Create Tailscale ingress"

# Check actual hostname from ingress status
ACTUAL_HOSTNAME=""
INGRESS_NAME="${INGRESS_HOSTNAME}-tailscale"
echo ""
echo "Checking actual hostname from ingress status..."
for i in {1..6}; do
    ACTUAL_HOSTNAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get ingress "$INGRESS_NAME" -n default \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ACTUAL_HOSTNAME" ]; then
        break
    fi
    echo "Waiting for ingress hostname... ($i/6)"
    sleep 5
done

EXPECTED_URL="https://$INGRESS_HOSTNAME.$TAILSCALE_DOMAIN"
if [ -n "$ACTUAL_HOSTNAME" ]; then
    ACTUAL_URL="https://$ACTUAL_HOSTNAME"
    if [ "$ACTUAL_HOSTNAME" != "$INGRESS_HOSTNAME.$TAILSCALE_DOMAIN" ]; then
        STATUS+=("Hostname Check: WARNING - Mismatch detected")
        echo ""
        echo "⚠️  HOSTNAME MISMATCH DETECTED"
        echo "  Expected: $EXPECTED_URL"
        echo "  Actual:   $ACTUAL_URL"
        echo ""
        echo "  This usually means a stale Tailscale device exists with the same name."
        echo "  To fix: run deletehost to remove the old device, then re-add."
    else
        STATUS+=("Hostname Check: OK")
    fi
else
    ACTUAL_URL="$EXPECTED_URL"
    STATUS+=("Hostname Check: Skipped - Could not read ingress status")
fi

echo ""
echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo ""
    echo "❌ DEPLOYMENT FAILED"
    echo "Check the error messages above"
else
    echo ""
    echo "✅ TAILSCALE DEPLOYMENT COMPLETED SUCCESSFULLY"
    echo "Service '$SERVICE_NAME' is now accessible at:"
    echo "  $ACTUAL_URL"
    echo ""
    echo "✅ Traefik will handle routing to the appropriate service"
    echo ""
    echo "DNS Troubleshooting:"
    echo "  Check DNS resolution: nslookup ${ACTUAL_HOSTNAME:-$INGRESS_HOSTNAME.$TAILSCALE_DOMAIN}"
    echo "  Check DNS details: dig ${ACTUAL_HOSTNAME:-$INGRESS_HOSTNAME.$TAILSCALE_DOMAIN}"
    echo "  Test connectivity: curl $ACTUAL_URL"
    echo ""
    echo "Note: DNS propagation can take 1-5 minutes globally"
fi

echo "-----------------------------------------------------------"

exit $ERROR