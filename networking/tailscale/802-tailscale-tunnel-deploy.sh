#!/bin/bash
# filename: 802-tailscale-tunnel-deploy.sh
# description: Deploy Tailscale tunnel connector to Kubernetes cluster
#
# This script:
# 1. **Auto-detects Tailscale configuration** from existing urbalurba-secrets
# 2. **Validates Tailscale credentials** are properly configured
# 3. **Deploys Tailscale operator** to the cluster
# 4. **Establishes cluster connectivity** to Tailscale network
# 5. **Tests connectivity** to verify tunnel is working
#
# Prerequisites:
# - Run 801-tailscale-tunnel-setup.sh first to validate Tailscale setup
# - urbalurba-secrets must exist in cluster with valid Tailscale keys
#
# Usage: ./802-tailscale-tunnel-deploy.sh [optional: cluster-hostname]
# Example: ./802-tailscale-tunnel-deploy.sh          # Uses TAILSCALE_CLUSTER_HOSTNAME from secrets
# Example: ./802-tailscale-tunnel-deploy.sh mycustomhostname       # Override with custom hostname
#
# Result:
# - Tailscale operator running in cluster
# - Cluster services accessible via Tailscale network
# - Connectivity test confirms tunnel is operational

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

set -e

# Variables
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
PLAYBOOK_PATH="/mnt/urbalurbadisk/ansible/playbooks/802-deploy-network-tailscale-tunnel.yml"

# Extract cluster hostname from command line or secrets
TAILSCALE_CLUSTER_HOSTNAME=${1:-""}
if [ -z "$TAILSCALE_CLUSTER_HOSTNAME" ]; then
    if kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default >/dev/null 2>&1; then
        TAILSCALE_CLUSTER_HOSTNAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret urbalurba-secrets -n default -o jsonpath='{.data.TAILSCALE_CLUSTER_HOSTNAME}' | base64 -d 2>/dev/null)
        if [ -z "$TAILSCALE_CLUSTER_HOSTNAME" ]; then
            echo "Error: urbalurba-secrets exists but has no TAILSCALE_CLUSTER_HOSTNAME"
            echo "Please either:"
            echo "  1. Update urbalurba-secrets with TAILSCALE_CLUSTER_HOSTNAME: k8s"
            echo "  2. Or run with: ./802-tailscale-tunnel-deploy.sh k8s"
            exit 1
        fi
    else
        echo "Error: No urbalurba-secrets found and no hostname provided"
        echo "Usage: ./802-tailscale-tunnel-deploy.sh <cluster-hostname>"
        exit 1
    fi
fi

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


STATUS=()
ERROR=0

# Function to check the success of the last command
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        ERROR=1
    else
        STATUS+=("$1: OK")
    fi
}

# Ensure we can access required directories and files
if [ ! -d "/mnt/urbalurbadisk/ansible" ] || [ ! -d "/mnt/urbalurbadisk/topsecret" ]; then
    echo "This script must be run from within the provision-host container"
    echo "Required directories not found: /mnt/urbalurbadisk/ansible or /mnt/urbalurbadisk/topsecret"
    echo "Current directory: $PWD"
    STATUS+=("Environment check: Fail")
    ERROR=1
else
    STATUS+=("Environment check: OK")
fi


# Add parameter values to STATUS
STATUS+=("CLUSTER_HOSTNAME= $TAILSCALE_CLUSTER_HOSTNAME")

echo "Deploying Tailscale operator to cluster: $TAILSCALE_CLUSTER_HOSTNAME"
echo "Using playbook: $PLAYBOOK_PATH"
echo ""

# Execute the Ansible playbook
echo "Deploying Tailscale operator (this may take a few minutes)..."
cd /mnt/urbalurbadisk/ansible && ansible-playbook $PLAYBOOK_PATH -e TAILSCALE_CLUSTER_HOSTNAME="$TAILSCALE_CLUSTER_HOSTNAME"
check_command_success "Deploying Tailscale tunnel to cluster"

echo ""
echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo ""
    echo "❌ DEPLOYMENT FAILED"
    echo "Check the error messages above"
    echo "The Tailscale operator may have deployed but connectivity testing failed"
else
    echo ""
    echo "✅ DEPLOYMENT COMPLETED SUCCESSFULLY"
    echo "Tailscale tunnel is deployed and connectivity verified"
fi

echo "-----------------------------------------------------------"

exit $ERROR