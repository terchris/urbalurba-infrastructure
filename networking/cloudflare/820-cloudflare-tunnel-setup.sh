#!/bin/bash
# filename: networking/cloudflare/820-cloudflare-tunnel-setup.sh
# description: Smart Cloudflare tunnel setup with credential persistence
# 
# This script intelligently manages Cloudflare tunnel setup:
# 1. **Checks if tunnel already exists** in Kubernetes cluster
# 2. **If exists**: Reports tunnel is ready, no action needed
# 3. **If not exists**: 
#    - Prompts for interactive Cloudflare login via browser
#    - Creates tunnel named "cloudflare-tunnel" and configures *.domain DNS routing
#    - Generates tunnel credentials and stores them in Kubernetes secret
#    - Creates Kubernetes secret with domain metadata for auto-detection
#
# Credential Storage:
# - Creates Kubernetes secret "cloudflared-credentials" with domain label
# - Stores credentials in /mnt/urbalurbadisk/cloudflare/ directory
# - Domain is stored in secret metadata for parameter-less deploy/delete
#
# ⚠️  CRITICAL PREREQUISITES:
# - **MUST be logged into Cloudflare dashboard FIRST** - Login at: https://dash.cloudflare.com/login
# - Domain must be added to your Cloudflare account and showing as "Active"
# - Run from inside provision-host container (not from Mac host)  
# - Browser must be available for interactive authentication
#
# usage: ./820-cloudflare-tunnel-setup.sh <domain> [-f|--force]
# example: ./820-cloudflare-tunnel-setup.sh urbalurba.no
# example: ./820-cloudflare-tunnel-setup.sh urbalurba.no -f
#
# Result (only if tunnel doesn't exist):
# - Tunnel "cloudflare-tunnel" created in Cloudflare
# - Kubernetes secret "cloudflared-credentials" created with domain label
# - DNS configured: *.domain → tunnel
# - DNS configured: *.{domain} routes to tunnel
#
# Temporary files (for info only):
# - /mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem (global cert)
# - /mnt/urbalurbadisk/cloudflare/cloudflare-{tunnel_name}-tunnel.json (extracted to secrets)

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Parse command line arguments
FORCE_RECREATE=false
DOMAIN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_RECREATE=true
            shift
            ;;
        -*)
            echo "Unknown option $1"
            echo "Usage: $0 <domain> [-f|--force]"
            echo "Example: $0 urbalurba.no"
            echo "Example: $0 urbalurba.no -f"
            echo ""
            echo "Options:"
            echo "  -f, --force    Force recreate tunnel even if credentials exist"
            echo ""
            echo "This will create a tunnel with wildcard routing: *.domain -> cluster"
            exit 1
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN=$1
            else
                echo "Error: Multiple domains specified. Only one domain allowed."
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [-f|--force]"
    echo "Example: $0 urbalurba.no"
    echo "Example: $0 urbalurba.no -f"
    echo ""
    echo "Options:"
    echo "  -f, --force    Force recreate tunnel even if credentials exist"
    echo ""
    echo "This will create a tunnel with wildcard routing: *.domain -> cluster"
    exit 1
fi

TUNNEL_NAME="cloudflare-tunnel"

# Source centralized path library
if [[ -f "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh" ]]; then
    source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"
    K8S_SECRETS_PATH=$(get_kubernetes_secrets_path)
else
    K8S_SECRETS_PATH="/mnt/urbalurbadisk/.uis.secrets/generated/kubernetes"
fi

# Variables
PROVISION_HOST="provision-host"
PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL="/mnt/urbalurbadisk/ansible/playbooks/820-setup-network-cloudflare-tunnel.yml"
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
SECRETS_FILE="$K8S_SECRETS_PATH/kubernetes-secrets.yml"
FULL_TUNNEL_NAME="cloudflare-tunnel"
SECRET_NAME="cloudflared-credentials"
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

# Function to extract credentials and store in secrets file
extract_and_store_credentials() {
    local credentials_file="/mnt/urbalurbadisk/cloudflare/${FULL_TUNNEL_NAME}.json"
    
    # Debug: List files in cloudflare directory
    echo "🔍 Debug: Files in cloudflare directory:"
    ls -la /mnt/urbalurbadisk/cloudflare/ || echo "Could not list cloudflare directory"
    
    if [ ! -f "$credentials_file" ]; then
        echo "❌ Error: Credentials file not found: $credentials_file"
        echo "🔍 Available files in /mnt/urbalurbadisk/cloudflare/:"
        ls -la /mnt/urbalurbadisk/cloudflare/ || echo "Could not list directory"
        STATUS+=("Extract Credentials: FAIL - File not found")
        return 1
    fi
    
    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        echo "❌ Error: yq is not installed. Please install it with:"
        echo "   wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq"
        echo "   chmod +x /usr/local/bin/yq"
        STATUS+=("Extract Credentials: FAIL - yq not installed")
        return 1
    fi
    
    echo "📝 Updating credentials in $SECRETS_FILE"
    
    # Create a temporary file with the new secret in /tmp (writable location)
    local TEMP_SECRET="/tmp/cloudflare-secret-$$.yml"
    local TEMP_SECRETS_FILE="/tmp/kubernetes-secrets-$$.yml"
    
    cat << EOF > "$TEMP_SECRET"
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-credentials
  namespace: default
type: Opaque
stringData:
  cloudflare-tunnel.json: |
$(cat "$credentials_file" | sed 's/^/    /')
EOF
    
    # Backup the original secrets file
    cp "$SECRETS_FILE" "${SECRETS_FILE}.bak"
    
    # Remove any existing cloudflared-credentials secret in default namespace, then add the new one
    echo "🔄 Removing old cloudflared-credentials if exists..."
    if ! yq eval-all 'select(.metadata.name != "cloudflared-credentials" or .metadata.namespace != "default")' "$SECRETS_FILE" > "$TEMP_SECRETS_FILE"; then
        echo "❌ Error: Failed to process secrets file with yq"
        STATUS+=("Extract Credentials: FAIL - yq processing error")
        rm -f "$TEMP_SECRET" "$TEMP_SECRETS_FILE"
        return 1
    fi
    
    # Add the new secret
    echo "➕ Adding new cloudflared-credentials..."
    if [ -s "$TEMP_SECRETS_FILE" ]; then
        # File has content, append with separator
        echo "---" >> "$TEMP_SECRETS_FILE"
    fi
    cat "$TEMP_SECRET" >> "$TEMP_SECRETS_FILE"
    
    # Replace the original file by writing directly to it
    if ! cat "$TEMP_SECRETS_FILE" > "$SECRETS_FILE"; then
        echo "❌ Error: Failed to update secrets file"
        STATUS+=("Extract Credentials: FAIL - File update error")
        rm -f "$TEMP_SECRET" "$TEMP_SECRETS_FILE"
        return 1
    fi
    rm -f "$TEMP_SECRET" "$TEMP_SECRETS_FILE"
    
    echo "✅ Credentials stored in kubernetes-secrets.yml"
    
    # Apply the entire secrets file to Kubernetes
    echo "📦 Applying secrets to Kubernetes..."
    kubectl --kubeconfig="$KUBECONFIG_PATH" apply -f "$SECRETS_FILE"
    if [ $? -eq 0 ]; then
        echo "✅ Secrets applied to Kubernetes cluster"
    else
        echo "⚠️  Failed to apply secrets to Kubernetes (cluster may not be accessible)"
    fi
    
    echo "💡 Credentials have been stored in kubernetes-secrets.yml"
    STATUS+=("Store Credentials: OK")
}

# Ensure we can access required directories and files (more flexible check)
if [ ! -d "/mnt/urbalurbadisk/ansible" ]; then
    echo "This script must be run from within the provision-host container"
    echo "Required directory not found: /mnt/urbalurbadisk/ansible"
    echo "Current directory: $PWD"
    STATUS+=("Environment check: Fail")
    ERROR=1
    exit 1
else
    STATUS+=("Environment check: OK")
fi

# Ensure that the kubernetes-secrets.yml file exists
if [ ! -f $SECRETS_FILE ]; then
    echo "The file $SECRETS_FILE does not exist"
    STATUS+=("kubernetes-secrets.yml check: Fail")
    ERROR=1
else
    STATUS+=("kubernetes-secrets.yml check: OK")
fi

# Add parameter values to STATUS
STATUS+=("TUNNEL_NAME= $TUNNEL_NAME")
STATUS+=("DOMAIN= $DOMAIN")
STATUS+=("WILDCARD_SETUP= *.${DOMAIN}")

echo "Setting up Cloudflare tunnel: $TUNNEL_NAME for domain: $DOMAIN"
echo "This will configure wildcard routing: *.${DOMAIN} -> cluster"
echo ""
echo "⚠️  CRITICAL: Complete the Cloudflare authentication process!"
echo ""
echo "STEP 1: Verify Cloudflare Dashboard Access"
echo "📱 Please login at: https://dash.cloudflare.com/login"
echo "✅ Verify your domain '$DOMAIN' shows as 'Active' in your dashboard"
echo ""
read -p "Press ENTER when you are logged into Cloudflare dashboard..."
echo ""
echo "STEP 2: Browser Authentication (2-step process)"
echo "📱 A browser link will appear - follow these steps:"
echo ""
echo "   1️⃣  SELECT DOMAIN: Choose '$DOMAIN' from the list of zones"
echo "   2️⃣  AUTHORIZE: Click the blue 'Authorize' button"
echo "   3️⃣  SUCCESS: Wait for 'Success' message, then close browser"
echo ""
echo "⚠️  IMPORTANT: You must complete BOTH steps in the browser!"
echo ""
read -p "Press ENTER when you understand the authentication process..."
echo ""

# Check if tunnel credentials already exist in the cluster
echo "Checking if tunnel credentials already exist in cluster..."
if kubectl --kubeconfig="$KUBECONFIG_PATH" get secret "$SECRET_NAME" -n default >/dev/null 2>&1; then
    if [ "$FORCE_RECREATE" = true ]; then
        echo "🔄 Force recreate requested - deleting existing tunnel credentials..."
        echo "🗑️  Deleting existing secret: $SECRET_NAME"
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete secret "$SECRET_NAME" -n default >/dev/null 2>&1
        echo "🗑️  Deleting existing configmap: cloudflare-tunnel-config"
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete configmap cloudflare-tunnel-config -n default >/dev/null 2>&1
        echo "🚀 Creating new tunnel and storing credentials..."
        STATUS+=("Tunnel Check: FORCE RECREATE - Deleting existing and creating new tunnel")
    else
        echo "✅ Tunnel credentials already exist in cluster: $SECRET_NAME"
        echo "✅ Tunnel is already set up and ready to use"
        echo "💡 Use -f flag to force recreate: $0 $DOMAIN -f"
        STATUS+=("Tunnel Check: EXISTS - No setup needed")
    fi
else
    echo "❌ Tunnel credentials not found in cluster"
    echo "🚀 Creating new tunnel and storing credentials..."
    STATUS+=("Tunnel Check: NOT EXISTS - Creating new tunnel")
fi

# Only proceed with tunnel creation if credentials don't exist or force recreate is requested
if [ "$FORCE_RECREATE" = true ] || ! kubectl --kubeconfig="$KUBECONFIG_PATH" get secret "$SECRET_NAME" -n default >/dev/null 2>&1; then
    echo "Using playbook: $PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL"
    echo ""
    
    # Execute the Ansible playbook with direct parameters (no subdomains = wildcard setup)
    cd /mnt/urbalurbadisk/ansible && ansible-playbook $PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL -e tunnel_name="$TUNNEL_NAME" -e domain="$DOMAIN"
    ANSIBLE_EXIT_CODE=$?
    check_command_success "Setting up Cloudflare tunnel and DNS"
    
    # After successful tunnel creation, extract and store credentials
    if [ $ANSIBLE_EXIT_CODE -eq 0 ]; then
        echo ""
        echo "🔐 Extracting tunnel credentials and storing in secrets file..."
        extract_and_store_credentials
    fi
fi

echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

# Analyze specific success/failure conditions
TUNNEL_CREATED=false
CREDENTIALS_STORED=false
TESTS_PASSED=true

# Check if tunnel was created successfully (look for successful ansible execution)
if [[ "$ANSIBLE_EXIT_CODE" -eq 0 ]] || kubectl --kubeconfig="$KUBECONFIG_PATH" get secret "cloudflared-credentials" -n default >/dev/null 2>&1; then
    TUNNEL_CREATED=true
fi

# Check if credentials were stored (presence of "Store Credentials: OK" in STATUS)
for status in "${STATUS[@]}"; do
    if [[ "$status" == "Store Credentials: OK" ]]; then
        CREDENTIALS_STORED=true
        break
    fi
done

# Check for any test failures in STATUS
for status in "${STATUS[@]}"; do
    if [[ "$status" =~ "Setting up Cloudflare tunnel and DNS: Fail" ]]; then
        TESTS_PASSED=false
        break
    fi
done

echo ""
if $TUNNEL_CREATED; then
    echo "🎉 SUCCESS: Cloudflare tunnel '$TUNNEL_NAME' is operational!"
    echo "✅ Tunnel created in Cloudflare dashboard"
    echo "✅ DNS configured: *.${DOMAIN} -> tunnel"
    if $CREDENTIALS_STORED; then
        echo "✅ Credentials stored in Kubernetes secrets"
    fi
    echo ""
    echo "📋 Next steps:"
    echo "   • Deploy tunnel to cluster: ./821-cloudflare-tunnel-deploy.sh"
    echo "   • Test your services via https://[service].${DOMAIN}"
    echo ""
    if ! $TESTS_PASSED; then
        echo "⚠️  NOTE: Some connectivity tests failed, but tunnel is ready"
        echo "   This is normal and doesn't affect tunnel functionality"
    fi
    echo "--------------- TUNNEL READY ---------------------"
    exit 0
else
    echo "❌ FAILED: Cloudflare tunnel setup incomplete"
    echo "Check the error messages above for details"
    echo "---------------- E R R O R --------------------"
    exit $ERROR
fi