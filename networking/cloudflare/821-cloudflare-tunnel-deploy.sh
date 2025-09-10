#!/bin/bash
# filename: 821-cloudflare-tunnel-deploy.sh
# description: Deploy Cloudflare tunnel connector pod to Kubernetes cluster
#
# This script:
# 1. **Auto-detects domain** from existing cloudflared-credentials secret
# 2. **Extracts tunnel ID** from the stored credentials
# 3. **Deploys tunnel connector pod** that runs in the cluster
# 4. **Establishes outbound connection** to Cloudflare edge
# 5. **Tests connectivity** to verify tunnel is working
#
# Prerequisites:
# - Run 820-cloudflare-tunnel-setup.sh first to create tunnel and store credentials
# - cloudflared-credentials secret must exist in cluster with domain metadata
#
# usage: ./821-cloudflare-tunnel-deploy.sh
# example: ./821-cloudflare-tunnel-deploy.sh
#
# Result:
# - Tunnel connector pod running in cluster
# - All *.{domain} traffic routes through tunnel to Traefik ingress
# - Connectivity test confirms tunnel is operational

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Extract domain from existing Secret
TUNNEL_NAME="cloudflare-tunnel"
TARGET_HOST="current-cluster"

# Check if cloudflared-credentials secret exists and extract domain
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
if kubectl --kubeconfig="$KUBECONFIG_PATH" get secret cloudflared-credentials -n default >/dev/null 2>&1; then
    DOMAIN=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret cloudflared-credentials -n default -o jsonpath='{.metadata.labels.cloudflare\.tunnel/domain}' 2>/dev/null)
    if [ -z "$DOMAIN" ]; then
        echo "Error: cloudflared-credentials secret exists but has no domain label"
        echo "Run ./820-cloudflare-tunnel-setup.sh <domain> to recreate the tunnel"
        exit 1
    fi
else
    echo "Error: No cloudflared-credentials secret found"
    echo "Run ./820-cloudflare-tunnel-setup.sh <domain> first to create the tunnel"
    exit 1
fi


# Variables
PROVISION_HOST="provision-host"
PLAYBOOK_PATH_DEPLOY_CLOUDFLARETUNNEL="/mnt/urbalurbadisk/ansible/playbooks/821-deploy-network-cloudflare-tunnel.yml"
KUBERNETES_SECRETS_FILE="/mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml"
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

# Ensure we can access required directories and files (more flexible check)
if [ ! -d "/mnt/urbalurbadisk/ansible" ] || [ ! -d "/mnt/urbalurbadisk/topsecret" ]; then
    echo "This script must be run from within the provision-host container"
    echo "Required directories not found: /mnt/urbalurbadisk/ansible or /mnt/urbalurbadisk/topsecret"
    echo "Current directory: $PWD"
    STATUS+=("Environment check: Fail")
    ERROR=1
else
    STATUS+=("Environment check: OK")
fi

# Ensure that the kubernetes-secrets.yml file exists
if [ ! -f $KUBERNETES_SECRETS_FILE ]; then
    echo "The file $KUBERNETES_SECRETS_FILE does not exist"
    STATUS+=("kubernetes-secrets.yml check: Fail")
    ERROR=1
else
    STATUS+=("kubernetes-secrets.yml check: OK")
fi

# Add parameter values to STATUS
STATUS+=("TUNNEL_NAME= $TUNNEL_NAME (fixed)")
STATUS+=("DOMAIN= $DOMAIN") 
STATUS+=("TARGET_HOST= $TARGET_HOST")

echo "Deploying Cloudflare tunnel: $TUNNEL_NAME for domain: $DOMAIN"
echo "Target cluster: $TARGET_HOST"
echo "Using playbook: $PLAYBOOK_PATH_DEPLOY_CLOUDFLARETUNNEL"
echo ""

# Execute the Ansible playbook with direct parameters
if [ "$TARGET_HOST" = "current-cluster" ]; then
    # Use localhost since we're running everything in the provision-host container
    echo "Using current cluster context (deploying from provision-host)"
    cd /mnt/urbalurbadisk/ansible && ansible-playbook $PLAYBOOK_PATH_DEPLOY_CLOUDFLARETUNNEL -e tunnel_name="$TUNNEL_NAME" -e domain="$DOMAIN" -e target_host="localhost"
else
    # Deploy to specific target host
    echo "Deploying to target host: $TARGET_HOST"
    cd /mnt/urbalurbadisk/ansible && ansible-playbook $PLAYBOOK_PATH_DEPLOY_CLOUDFLARETUNNEL -e tunnel_name="$TUNNEL_NAME" -e domain="$DOMAIN" -e target_host="$TARGET_HOST"
fi
check_command_success "Deploying Cloudflare tunnel to cluster"




echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo "---------------- E R R O R --------------------"
    echo "Check the error messages above"
else
    echo "--------------- All OK ------------------------"
fi

exit $ERROR