#!/bin/bash
# filename: 801-tailscale-service-expose.sh
# moved from: net2-expose-tailscale-service.sh (September 8, 2025)
# description: Exposes individual Kubernetes services through Tailscale
# 
# This script is used to expose individual Kubernetes services through Tailscale.
# It must be run AFTER 803-tailscale-cluster-setup.sh has been executed to set up
# the base Tailscale infrastructure.
#
# Prerequisites:
# - 803-tailscale-cluster-setup.sh must have been run successfully
# - Tailscale operator must be installed and running
# - Kubernetes service to expose must exist
#
# Usage: ./801-tailscale-service-expose.sh <service-name> [options]
#
# Arguments:
#   <service-name>              Name of the Kubernetes service to expose
#
# Options:
#   --hostname/-h <hostname>    Hostname to use (defaults to service name)
#   --namespace/-n <namespace>  Kubernetes namespace (defaults to "default")
#   --kubeconfig/-k <path>      Path to kubeconfig file
#   --tailnet/-t <tailnet>      Tailscale tailnet name (defaults to dog-pence)
#   --remove/-r <hostname>      Remove a previously configured hostname
#   --help                      Show this help message
#
# Examples:
#   ./801-tailscale-service-expose.sh open-webui
#   ./801-tailscale-service-expose.sh pgadmin --hostname admin
#   ./801-tailscale-service-expose.sh gravitee-apim-gateway --namespace gravitee
#   ./801-tailscale-service-expose.sh --remove openwebui
#
# Related scripts:
# - 803-tailscale-cluster-setup.sh: Must be run first to set up base infrastructure
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Required parameters missing
# 3 - Service not found
# 4 - Tailscale operator not found
# 5 - Ansible playbook execution failed

set -e

# Default values
KUBECONFIG_PATH="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK="playbooks/801-expose-tailscale-service.yml"
NAMESPACE="default"
TAILNET="dog-pence"
HOSTNAME=""
REMOVE_MODE=false
REMOVE_HOSTNAME=""

# Function to display usage information
show_help() {
    echo "Usage: $0 <service-name> [options]"
    echo ""
    echo "Arguments:"
    echo "  <service-name>              Name of the Kubernetes service to expose"
    echo ""
    echo "Options:"
    echo "  --hostname/-h <hostname>    Hostname to use (defaults to service name)"
    echo "  --namespace/-n <namespace>  Kubernetes namespace (defaults to \"default\")"

    echo "  --kubeconfig/-k <path>      Path to kubeconfig file"
    echo "  --tailnet/-t <tailnet>      Tailscale tailnet name (defaults to dog-pence)"
    echo "  --remove/-r <hostname>      Remove a previously configured hostname"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 open-webui"
    echo "  $0 pgadmin --hostname admin --port 80"
    echo "  $0 gravitee-apim-gateway --namespace gravitee"
    echo "  $0 --remove openwebui"
}

# Check if no arguments were provided
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --help)
            show_help
            exit 0
            ;;
        --remove|-r)
            REMOVE_MODE=true
            REMOVE_HOSTNAME="$2"
            shift
            shift
            ;;
        --hostname|-h)
            HOSTNAME="$2"
            shift
            shift
            ;;
        --namespace|-n)
            NAMESPACE="$2"
            shift
            shift
            ;;

        --kubeconfig|-k)
            KUBECONFIG_PATH="$2"
            shift
            shift
            ;;
        --tailnet|-t)
            TAILNET="$2"
            shift
            shift
            ;;
        *)
            # First positional argument is assumed to be the service name
            if [ -z "$SERVICE_NAME" ]; then
                SERVICE_NAME="$1"
            else
                echo "Error: Unknown argument '$1'"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create tailscale-hosts directory if it doesn't exist
mkdir -p /mnt/urbalurbadisk/tailscale-hosts

# Handle removal mode
if [ "$REMOVE_MODE" = true ]; then
    if [ -z "$REMOVE_HOSTNAME" ]; then
        log "Error: No hostname specified for removal"
        exit 1
    fi

    log "Removing Tailscale funnel host: $REMOVE_HOSTNAME"
    
    # Remove Tailscale tunnel ingress
    kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress -n kube-system "${REMOVE_HOSTNAME}-tailscale-ingress" 2>/dev/null || true
    
    # Try to find and remove the Traefik ingress in any namespace
    NAMESPACES=$(kubectl --kubeconfig="$KUBECONFIG_PATH" get ns -o name | cut -d/ -f2)
    for ns in $NAMESPACES; do
        kubectl --kubeconfig="$KUBECONFIG_PATH" delete ingress -n "$ns" "${REMOVE_HOSTNAME}-ingress" 2>/dev/null || true
    done
    
    # Remove configuration file
    rm -f "/mnt/urbalurbadisk/tailscale-hosts/${REMOVE_HOSTNAME}.conf"
    
    log "Tailscale funnel host removed: $REMOVE_HOSTNAME"
    log "Note: The Tailscale device may still appear in 'tailscale status' for a few minutes"
    exit 0
fi

# Validate required parameters
if [ -z "$SERVICE_NAME" ]; then
    log "Error: No service name provided"
    show_help
    exit 1
fi

# If hostname is not specified, use service name
if [ -z "$HOSTNAME" ]; then
    HOSTNAME="$SERVICE_NAME"
    log "No hostname specified, using service name: $HOSTNAME"
fi

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG_PATH" ]; then
    log "Error: Kubeconfig file not found at $KUBECONFIG_PATH"
    exit 1
fi

# Build Ansible extra vars
ANSIBLE_VARS="-e service_name=$SERVICE_NAME"
ANSIBLE_VARS="$ANSIBLE_VARS -e hostname=$HOSTNAME"
ANSIBLE_VARS="$ANSIBLE_VARS -e namespace=$NAMESPACE"
ANSIBLE_VARS="$ANSIBLE_VARS -e kubeconfig_path=$KUBECONFIG_PATH"
ANSIBLE_VARS="$ANSIBLE_VARS -e tailnet=$TAILNET"



# Run Ansible playbook
log "Setting up Tailscale funnel host for service: $SERVICE_NAME"
log "Using hostname: $HOSTNAME.$TAILNET.ts.net"
log "Running Ansible playbook..."

cd "$ANSIBLE_DIR" && ansible-playbook "$PLAYBOOK" $ANSIBLE_VARS -v

exit_code=$?
if [ $exit_code -ne 0 ]; then
    log "Error: Ansible playbook failed with exit code $exit_code"
    exit $exit_code
fi

log "Setup completed successfully!"
log "Your service should be accessible at: https://$HOSTNAME.$TAILNET.ts.net"
log "Note: It may take up to 10 minutes for DNS to fully propagate and TLS certificates to be provisioned"