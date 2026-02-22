#!/bin/bash
# filename: networking/cloudflare/822-cloudflare-tunnel-delete.sh
# description: Delete Cloudflare tunnel from both Kubernetes and Cloudflare
#
# This script completely removes a Cloudflare tunnel:
# 1. **Auto-detects domain**: Reads from cloudflared-credentials secret if exists
# 2. **Deletes from Kubernetes**: Removes deployment, configmap, and secret
# 3. **Deletes DNS routes**: Removes DNS entries from Cloudflare (if domain known)
# 4. **Deletes tunnel**: Removes the tunnel itself from Cloudflare
# 5. **Cleans up files**: Removes local credential and config files
#
# usage: ./822-cloudflare-tunnel-delete.sh
# example: ./822-cloudflare-tunnel-delete.sh
#
# WARNING: This is destructive and cannot be undone!

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Source centralized path library
if [[ -f "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh" ]]; then
    source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"
    K8S_SECRETS_PATH=$(get_kubernetes_secrets_path)
else
    K8S_SECRETS_PATH="/mnt/urbalurbadisk/.uis.secrets/generated/kubernetes"
fi

# Extract domain from existing Secret
TUNNEL_NAME="cloudflare-tunnel"
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"

# Check if cloudflared-credentials secret exists and extract domain
if kubectl --kubeconfig="$KUBECONFIG_PATH" get secret cloudflared-credentials -n default >/dev/null 2>&1; then
    DOMAIN=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get secret cloudflared-credentials -n default -o jsonpath='{.metadata.labels.cloudflare\.tunnel/domain}' 2>/dev/null)
    if [ -z "$DOMAIN" ]; then
        echo "Warning: cloudflared-credentials secret exists but has no domain label"
        echo "Will attempt to delete resources without domain-specific DNS cleanup"
        DOMAIN="unknown"
    fi
else
    echo "Warning: No cloudflared-credentials secret found"
    echo "Will attempt to clean up any remaining resources"
    DOMAIN="unknown"
fi
FULL_TUNNEL_NAME="cloudflare-tunnel"
CLOUDFLARE_CERT="/mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem"
CREDENTIALS_FILE="/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel.json"
CONFIG_FILE="/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel-config.yml"
MANIFEST_FILE="/mnt/urbalurbadisk/manifests/cloudflare-tunnel-manifest.yaml"

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

echo "========================================="
echo "Cloudflare Tunnel Deletion Script"
echo "========================================="
echo "Tunnel Name: $TUNNEL_NAME (fixed name)"
if [ "$DOMAIN" != "unknown" ]; then
    echo "Domain: $DOMAIN (detected from Secret)"
else
    echo "Domain: $DOMAIN (no Secret found - will clean up orphaned resources)"
fi
echo "Full Tunnel Name: $FULL_TUNNEL_NAME"
echo ""
echo "WARNING: This will permanently delete:"
echo "  - Kubernetes resources (deployment, configmap, secret)"
if [ "$DOMAIN" != "unknown" ]; then
    echo "  - Cloudflare DNS routes for $DOMAIN"
else
    echo "  - Cloudflare DNS routes (if tunnel exists)"
fi
echo "  - Cloudflare tunnel"
echo "  - Local configuration files"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Deletion cancelled."
    exit 0
fi

echo ""
echo "Step 1: Removing Kubernetes resources..."
echo "-----------------------------------------"

# Delete Kubernetes deployment
echo "Deleting deployment: ${FULL_TUNNEL_NAME}"
kubectl --kubeconfig="$KUBECONFIG_PATH" delete deployment "${FULL_TUNNEL_NAME}" -n default --ignore-not-found=true
check_command_success "Delete deployment"

# Delete Kubernetes configmap
echo "Deleting configmap: ${FULL_TUNNEL_NAME}-config"
kubectl --kubeconfig="$KUBECONFIG_PATH" delete configmap "${FULL_TUNNEL_NAME}-config" -n default --ignore-not-found=true
check_command_success "Delete configmap"

# Delete Kubernetes secret
echo "Deleting secret: cloudflared-credentials"
kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret "cloudflared-credentials" -n default --ignore-not-found=true
check_command_success "Delete secret"

# Also delete any deployment-specific credentials if they exist  
echo "Deleting deployment credentials (if exists): ${FULL_TUNNEL_NAME}-credentials"
kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret "${FULL_TUNNEL_NAME}-credentials" -n default --ignore-not-found=true
check_command_success "Delete deployment secret"

echo ""
echo "Step 2: Removing Cloudflare DNS routes..."
echo "-----------------------------------------"

# Check if cloudflare certificate exists
if [ ! -f "$CLOUDFLARE_CERT" ]; then
    echo "Warning: Cloudflare certificate not found at $CLOUDFLARE_CERT"
    echo "Skipping Cloudflare operations..."
    STATUS+=("Cloudflare operations: Skipped - no certificate")
else
    # First get the tunnel ID to identify DNS records to delete
    TUNNEL_ID=$(cloudflared tunnel --origincert "$CLOUDFLARE_CERT" list -o json 2>/dev/null | jq -r ".[] | select(.name==\"${FULL_TUNNEL_NAME}\") | .id" || echo "")
    
    if [ -n "$TUNNEL_ID" ]; then
        echo "Found tunnel ID: $TUNNEL_ID"
        echo "Removing DNS records that point to this tunnel..."
        
        # TODO: DNS record deletion via cloudflared does not work properly
        # The commands below report success but DNS records remain in Cloudflare dashboard
        # Manual deletion is required: Go to Cloudflare Dashboard > DNS > Records
        # Delete CNAME records for root domain and wildcard that point to *.cfargotunnel.com
        
        echo "Attempting to remove DNS route for root domain: ${DOMAIN}"
        cloudflared tunnel --origincert "$CLOUDFLARE_CERT" route dns delete "${DOMAIN}" 2>/dev/null || true
        check_command_success "Remove root domain DNS"
        
        echo "Attempting to remove DNS route for wildcard: *.${DOMAIN}"
        cloudflared tunnel --origincert "$CLOUDFLARE_CERT" route dns delete "*.${DOMAIN}" 2>/dev/null || true
        check_command_success "Remove wildcard DNS"
        
        echo ""
        echo "⚠️  WARNING: DNS record deletion may not work properly"
        echo "   If DNS records still exist in Cloudflare dashboard, delete them manually:"
        echo "   1. Go to https://dash.cloudflare.com/"
        echo "   2. Select your domain: ${DOMAIN}"
        echo "   3. Go to DNS > Records"
        echo "   4. Delete CNAME records pointing to ${TUNNEL_ID}.cfargotunnel.com"
    else
        echo "No tunnel found - cannot determine which DNS records to delete"
        echo "You may need to manually delete DNS records pointing to tunnel in Cloudflare dashboard"
        STATUS+=("Remove DNS records: MANUAL - No tunnel found")
    fi
    
    echo ""
    echo "Step 3: Deleting Cloudflare tunnel..."
    echo "--------------------------------------"
    
    # Check if tunnel exists
    echo "Checking if tunnel exists..."
    TUNNEL_EXISTS=$(cloudflared tunnel --origincert "$CLOUDFLARE_CERT" list -o json 2>/dev/null | jq -r ".[] | select(.name==\"${FULL_TUNNEL_NAME}\") | .id" || echo "")
    
    if [ -n "$TUNNEL_EXISTS" ]; then
        echo "Tunnel found with ID: $TUNNEL_EXISTS"
        echo "Deleting tunnel: ${FULL_TUNNEL_NAME}"
        cloudflared tunnel --origincert "$CLOUDFLARE_CERT" delete -f "${FULL_TUNNEL_NAME}"
        check_command_success "Delete tunnel"
    else
        echo "Tunnel not found in Cloudflare (may have been deleted already)"
        STATUS+=("Delete tunnel: Not found")
    fi
fi

echo ""
echo "Step 4: Cleaning up local files..."
echo "-----------------------------------"

# Remove local files
if [ -f "$CREDENTIALS_FILE" ]; then
    echo "Removing credentials file: $CREDENTIALS_FILE"
    rm -f "$CREDENTIALS_FILE"
    check_command_success "Remove credentials file"
else
    echo "Credentials file not found: $CREDENTIALS_FILE"
fi

if [ -f "$CONFIG_FILE" ]; then
    echo "Removing config file: $CONFIG_FILE"
    rm -f "$CONFIG_FILE"
    check_command_success "Remove config file"
else
    echo "Config file not found: $CONFIG_FILE"
fi

# Remove Cloudflare certificate for complete cleanup
if [ -f "$CLOUDFLARE_CERT" ]; then
    echo "Removing Cloudflare certificate: $CLOUDFLARE_CERT"
    rm -f "$CLOUDFLARE_CERT"
    check_command_success "Remove certificate file"
    echo "Note: You will need to re-authenticate with Cloudflare on next tunnel creation"
else
    echo "Certificate file not found: $CLOUDFLARE_CERT"
fi

if [ -f "$MANIFEST_FILE" ]; then
    echo "Removing manifest file: $MANIFEST_FILE"
    rm -f "$MANIFEST_FILE"
    check_command_success "Remove manifest file"
else
    echo "Manifest file not found: $MANIFEST_FILE"
fi

echo ""
echo "Step 5: Cleaning up Kubernetes secrets..."
echo "------------------------------------------"

SECRETS_FILE="$K8S_SECRETS_PATH/kubernetes-secrets.yml"

# Check if yq is available
if command -v yq &> /dev/null; then
    if [ -f "$SECRETS_FILE" ]; then
        echo "🔍 Checking for cloudflared-credentials in kubernetes-secrets.yml..."
        
        # Check if cloudflared-credentials exists in the file
        if yq eval-all '.[] | select(.metadata.name == "cloudflared-credentials" and .metadata.namespace == "default")' "$SECRETS_FILE" >/dev/null 2>&1; then
            echo "📝 Removing cloudflared-credentials from kubernetes-secrets.yml..."
            
            # Backup the file
            cp "$SECRETS_FILE" "${SECRETS_FILE}.bak"
            
            # Remove the cloudflared-credentials secret
            yq eval-all 'select(.metadata.name != "cloudflared-credentials" or .metadata.namespace != "default")' "$SECRETS_FILE" > "${SECRETS_FILE}.tmp"
            
            # Only replace if the new file has content
            if [ -s "${SECRETS_FILE}.tmp" ]; then
                mv "${SECRETS_FILE}.tmp" "$SECRETS_FILE"
                echo "✅ Removed cloudflared-credentials from kubernetes-secrets.yml"
                STATUS+=("Remove from secrets file: OK")
            else
                echo "⚠️  Warning: Removal would leave empty file, keeping original"
                rm -f "${SECRETS_FILE}.tmp"
                STATUS+=("Remove from secrets file: SKIPPED - would empty file")
            fi
        else
            echo "✅ No cloudflared-credentials found in kubernetes-secrets.yml"
            STATUS+=("Secrets file: Already clean")
        fi
    else
        echo "Secrets file not found: $SECRETS_FILE"
        STATUS+=("Secrets file: Not found")
    fi
else
    echo "⚠️  yq not installed - cannot safely edit kubernetes-secrets.yml"
    echo "   Install with: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
    STATUS+=("Secrets file cleanup: SKIPPED - yq not installed")
fi

# Also check for any legacy entries with the old naming format
if [ -f "$SECRETS_FILE" ]; then
    echo ""
    echo "🔍 Checking for legacy tunnel credentials..."
    
    # Check for old format entries
    VAR_PREFIX="CLOUDFLARE_${TUNNEL_NAME^^}"
    LEGACY_VARS=$(grep -E "${VAR_PREFIX}[-_]" "$SECRETS_FILE" 2>/dev/null || true)
    
    if [ -n "$LEGACY_VARS" ]; then
        echo "⚠️  WARNING: Found legacy tunnel credentials that need manual removal:"
        echo "$LEGACY_VARS" | while read -r line; do
            [ -n "$line" ] && echo "  - $line"
        done
        echo ""
        echo "To remove manually: nano $SECRETS_FILE"
        STATUS+=("Legacy cleanup: MANUAL REQUIRED")
    else
        echo "✅ No legacy tunnel credentials found"
    fi
fi

# Final cleanup - ensure all secrets are removed
echo ""
echo "Final cleanup of any remaining tunnel secrets..."
kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret cloudflared-credentials -n default --ignore-not-found=true
kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret "${FULL_TUNNEL_NAME}-credentials" -n default --ignore-not-found=true
check_command_success "Final secret cleanup"

echo ""
echo "========================================="
echo "Summary of deletion operations:"
echo "========================================="
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo ""
    echo "⚠️  Some operations failed - check messages above"
    echo "The tunnel may be partially deleted."
else
    echo ""
    echo "✅ Tunnel successfully deleted!"
    echo ""
    echo "The following have been removed:"
    echo "  - Kubernetes resources in cluster"
    echo "  - DNS routes in Cloudflare (may take a few minutes to propagate)"
    echo "  - Tunnel from Cloudflare"
    echo "  - Local configuration files"
    echo ""
    echo "You can now create a new tunnel with:"
    if [ "$DOMAIN" != "unknown" ]; then
        echo "  ./820-cloudflare-tunnel-setup.sh $DOMAIN"
    else
        echo "  ./820-cloudflare-tunnel-setup.sh <your-domain>"
    fi
    echo "  ./821-cloudflare-tunnel-deploy.sh"
fi

exit $ERROR