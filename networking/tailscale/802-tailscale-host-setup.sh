#!/bin/bash
# filename: 802-tailscale-host-setup.sh
# description: Configures Tailscale for the provision-host container
# moved from: net1-setup-tailscale.sh (September 8, 2025)
# 
# This script sets up the persistent storage for Tailscale, 
# starts the daemon, and authenticates using keys from Kubernetes secrets.
#
# Usage: ./802-tailscale-host-setup.sh

# Source the Tailscale library
# Using realpath with dirname to handle the script being run from any location
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/tailscale-lib.sh"

# Exit immediately if a command exits with a non-zero status
set -e

# Setup persistent storage for Tailscale
setup_tailscale_storage() {
    tailscale_log "Setting up persistent storage for Tailscale..."
    
    # Create the directory structure in the persistent volume
    sudo mkdir -p /mnt/provision-data/tailscale/state
    sudo mkdir -p /mnt/provision-data/tailscale/run
    sudo chmod 755 /mnt/provision-data/tailscale/state
    sudo chmod 755 /mnt/provision-data/tailscale/run
    
    # Create symlinks to standard locations
    sudo ln -sfn /mnt/provision-data/tailscale/state /var/lib/tailscale
    sudo ln -sfn /mnt/provision-data/tailscale/run /var/run/tailscale
    
    tailscale_log "Created Tailscale persistent storage in /mnt/provision-data/tailscale"
}

# Ensure tailscaled is running
ensure_tailscaled_running() {
    tailscale_log "Ensuring tailscaled is running..."
    
    # Use the library function to check if tailscaled is running
    if ! tailscale_is_running; then
        tailscale_log "Starting tailscaled daemon..."
        
        # Make sure storage is set up
        setup_tailscale_storage
        
        # Kill any existing instances that might be stuck
        sudo pkill -9 tailscaled >/dev/null 2>&1 || true
        
        # Start tailscaled without trying to write logs to a file
        sudo nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
        
        # Wait for tailscaled to initialize
        tailscale_log "Waiting for tailscaled to initialize..."
        sleep 3
        
        # Check again if tailscaled is running
        if ! tailscale_is_running; then
            tailscale_log "ERROR: Failed to start tailscaled"
            return 1
        fi
    fi
    
    tailscale_log "tailscaled is running"
    return 0
}

# Configure Tailscale
configure_tailscale() {
    tailscale_log "Configuring Tailscale..."
    
    # Get Tailscale tags if available
    local tailscale_tags="tag:provision-host"  # Default tag
    local tags_result
    
    if tags_result=$(kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_TAGS}" | base64 -d 2>/dev/null); then
        if [ -n "$tags_result" ]; then
            tailscale_tags="$tags_result"
        fi
    fi
    
    tailscale_log "Connecting to Tailscale network..."
    if ! sudo tailscale up --authkey="$TAILSCALE_SECRET" --hostname="provision-host" --advertise-tags="$tailscale_tags" --accept-routes --accept-dns; then
        tailscale_log "ERROR: Failed to connect to Tailscale network"
        return 1
    fi
    
    # Enable SSH if supported
    tailscale_log "Enabling Tailscale SSH..."
    sudo tailscale set --ssh --accept-routes --accept-dns || true
    
    return 0
}

# Main function
main() {
    tailscale_log "Setting up Tailscale for provision-host container..."
    
    # Check if Tailscale is installed using library function
    if ! tailscale_is_installed; then
        tailscale_log "ERROR: Tailscale is not installed. Please install Tailscale first."
        exit 1
    fi
    
    # Ensure Kubernetes is operational
    tailscale_log "Verifying Kubernetes is operational..."
    if ! kubectl get nodes &>/dev/null; then
        tailscale_log "ERROR: Cannot access Kubernetes. Please ensure Kubernetes is running."
        exit 1
    fi
    
    # Ensure Kubernetes secrets are available
    tailscale_log "Verifying Kubernetes secrets are available..."
    if ! kubectl get secret --namespace default urbalurba-secrets &>/dev/null; then
        tailscale_log "ERROR: Cannot access Kubernetes secrets. Please ensure secrets are applied."
        exit 1
    fi
    
    # Get Tailscale secrets from Kubernetes using library function
    if ! tailscale_get_secrets; then
        tailscale_log "ERROR: Failed to retrieve Tailscale secrets from Kubernetes"
        exit 1
    fi
    
    # Check if Tailscale credentials are properly configured
    if ! tailscale_check_credentials "$TAILSCALE_SECRET" "$TAILSCALE_CLIENTID" "$TAILSCALE_CLIENTSECRET" "$TAILSCALE_TAILNET" "$TAILSCALE_DOMAIN"; then
        tailscale_log "Skipping Tailscale setup due to template values in configuration."
        # Exit with success to allow the installation to continue
        exit 0
    fi
    
    # Ensure tailscaled is running
    if ! ensure_tailscaled_running; then
        tailscale_log "ERROR: Failed to ensure tailscaled is running"
        exit 1
    fi
    
    # Check if already authenticated using library function
    if tailscale_is_authenticated; then
        tailscale_log "Tailscale is already authenticated. Current status:"
        tailscale_print_status
        exit 0
    fi
    
    # Configure Tailscale
    if ! configure_tailscale; then
        tailscale_log "ERROR: Failed to configure Tailscale"
        exit 1
    fi
    
    # Print Tailscale status using library function
    if ! tailscale_print_status; then
        tailscale_log "ERROR: Failed to verify Tailscale status"
        exit 1
    fi
    
    tailscale_log "Tailscale setup completed successfully"
    exit 0
}

# Run the main function
main