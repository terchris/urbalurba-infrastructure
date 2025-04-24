#!/bin/bash
# filename: net1-setup-tailscale.sh
# description: Configures Tailscale for the provision-host container
# 
# This script sets up the persistent storage for Tailscale, 
# starts the daemon, and authenticates using keys from Kubernetes secrets.
#
# Usage: ./net1-setup-tailscale.sh

set -e

# Function to log messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if required commands are available
check_requirements() {
    local missing=false
    
    if ! command -v tailscale &>/dev/null; then
        log "ERROR: tailscale command not found. Please install Tailscale first."
        missing=true
    fi
    
    if ! command -v kubectl &>/dev/null; then
        log "ERROR: kubectl command not found. Please install kubectl first."
        missing=true
    fi
    
    if [ "$missing" = "true" ]; then
        return 1
    fi
    
    return 0
}

# Setup persistent storage for Tailscale
setup_tailscale_storage() {
    log "Setting up persistent storage for Tailscale..."
    
    # Create the directory structure in the persistent volume
    sudo mkdir -p /mnt/provision-data/tailscale/state
    sudo mkdir -p /mnt/provision-data/tailscale/run
    sudo chmod 755 /mnt/provision-data/tailscale/state
    sudo chmod 755 /mnt/provision-data/tailscale/run
    
    # Create symlinks to standard locations
    sudo ln -sfn /mnt/provision-data/tailscale/state /var/lib/tailscale
    sudo ln -sfn /mnt/provision-data/tailscale/run /var/run/tailscale
    
    log "Created Tailscale persistent storage in /mnt/provision-data/tailscale"
}

# Ensure tailscaled is running
ensure_tailscaled_running() {
    log "Ensuring tailscaled is running..."
    
    if ! pgrep tailscaled >/dev/null; then
        log "Starting tailscaled daemon..."
        
        # Make sure storage is set up
        setup_tailscale_storage
        
        # Kill any existing instances that might be stuck
        sudo pkill -9 tailscaled >/dev/null 2>&1 || true
        
        # Start tailscaled without trying to write logs to a file
        sudo nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
        
        # Wait for tailscaled to start
        log "Waiting for tailscaled to initialize..."
        sleep 3
        
        if ! pgrep tailscaled >/dev/null; then
            log "ERROR: Failed to start tailscaled"
            return 1
        fi
    fi
    
    log "tailscaled is running"
    return 0
}

# Configure Tailscale
configure_tailscale() {
    log "Configuring Tailscale..."
    
    # Get Tailscale secret from Kubernetes
    log "Retrieving Tailscale auth key from Kubernetes secrets..."
    local tailscale_secret
    
    if ! tailscale_secret=$(kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_SECRET}" | base64 -d); then
        log "ERROR: Failed to retrieve Tailscale auth key from Kubernetes secrets"
        return 1
    fi
    
    if [ -z "$tailscale_secret" ]; then
        log "ERROR: Tailscale auth key is empty"
        return 1
    fi
    
    # Get tags if available
    local tailscale_tags="tag:provision-host"  # Default tag
    local tags_result
    
    if tags_result=$(kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_TAGS}" | base64 -d 2>/dev/null); then
        if [ -n "$tags_result" ]; then
            tailscale_tags="$tags_result"
        fi
    fi
    
    log "Connecting to Tailscale network..."
    if ! sudo tailscale up --authkey="$tailscale_secret" --hostname="provision-host" --advertise-tags="$tailscale_tags" --accept-routes --accept-dns; then
        log "ERROR: Failed to connect to Tailscale network"
        return 1
    fi
    
    # Enable SSH if supported
    log "Enabling Tailscale SSH..."
    sudo tailscale set --ssh --accept-routes --accept-dns || true
    
    return 0
}

# Verify Tailscale status
verify_tailscale() {
    log "Verifying Tailscale status..."
    
    # Capture status to a temporary file to avoid terminal corruption
    local tmp_status
    tmp_status=$(mktemp)
    
    if ! tailscale status > "$tmp_status" 2>/dev/null; then
        rm -f "$tmp_status"
        log "ERROR: Tailscale status check failed"
        return 1
    fi
    
    # Display the captured status
    cat "$tmp_status"
    rm -f "$tmp_status"
    
    return 0
}

# Main function
main() {
    log "Setting up Tailscale for provision-host container..."
    
    # Check requirements
    if ! check_requirements; then
        log "ERROR: Missing required dependencies"
        exit 1
    fi
    
    # Ensure Kubernetes is operational
    log "Verifying Kubernetes is operational..."
    if ! kubectl get nodes &>/dev/null; then
        log "ERROR: Cannot access Kubernetes. Please ensure Kubernetes is running."
        exit 1
    fi
    
    # Ensure Kubernetes secrets are available
    log "Verifying Kubernetes secrets are available..."
    if ! kubectl get secret --namespace default urbalurba-secrets &>/dev/null; then
        log "ERROR: Cannot access Kubernetes secrets. Please ensure secrets are applied."
        exit 1
    fi
    
    # Ensure tailscaled is running
    if ! ensure_tailscaled_running; then
        log "ERROR: Failed to ensure tailscaled is running"
        exit 1
    fi
    
    # Check if already authenticated
    if tailscale status &>/dev/null; then
        log "Tailscale is already authenticated. Current status:"
        verify_tailscale
        exit 0
    fi
    
    # Configure Tailscale
    if ! configure_tailscale; then
        log "ERROR: Failed to configure Tailscale"
        exit 1
    fi
    
    # Verify Tailscale status
    if ! verify_tailscale; then
        log "ERROR: Failed to verify Tailscale status"
        exit 1
    fi
    
    log "Tailscale setup completed successfully"
    
  
    exit 0
}

# Run the main function
main