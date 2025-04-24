#!/bin/bash
# filename: net1-check-tailscale.sh
# description: Checks Tailscale connectivity for the provision-host container
# 
# This script verifies that Tailscale is properly configured and connected,
# displaying current status and attempting recovery if needed.
#
# Usage: ./net1-check-tailscale.sh

# Global variable to track if jq is installed
JQ_INSTALLED="false"

# Function to log messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if jq is installed once at the beginning
check_jq_installed() {
    if command -v jq &>/dev/null; then
        JQ_INSTALLED="true"
    else
        JQ_INSTALLED="false"
        log "jq is not installed. Some detailed information will be limited."
        log "To install jq: sudo apt-get update && sudo apt-get install -y jq"
    fi
}

# Check if Tailscale is installed
check_tailscale_installed() {
    if ! command -v tailscale &>/dev/null; then
        log "ERROR: Tailscale is not installed"
        log "Please install Tailscale first using provision-host-03-net.sh"
        return 1
    fi
    return 0
}

# Check tailscaled daemon status
check_tailscaled_running() {
    if ! pgrep tailscaled &>/dev/null; then
        log "ERROR: Tailscale daemon (tailscaled) is not running"
        return 1
    fi
    log "Tailscale daemon is running"
    return 0
}

# Attempt to start the tailscaled daemon
start_tailscaled() {
    log "Attempting to start tailscaled daemon..."
    
    # Kill any existing processes that might be stuck
    sudo pkill -9 tailscaled &>/dev/null || true
    
    # Start daemon without logs
    sudo nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
    
    # Wait for daemon to start
    sleep 3
    
    if ! pgrep tailscaled &>/dev/null; then
        log "ERROR: Failed to start tailscaled daemon"
        return 1
    fi
    
    log "Successfully started tailscaled daemon"
    return 0
}

# Check Tailscale's authentication status
check_authentication() {
    log "Checking Tailscale authentication status..."
    
    if ! tailscale status &>/dev/null; then
        log "ERROR: Tailscale is not authenticated"
        return 1
    fi
    
    log "Tailscale is authenticated"
    return 0
}

# Get detailed Tailscale status as JSON
get_tailscale_status() {
    if [ "$JQ_INSTALLED" != "true" ]; then
        log "WARNING: jq is not installed, skipping detailed status checks"
        return 1
    fi
    
    log "Getting detailed Tailscale status..."
    local status_json
    
    # Use POSIX-compliant command substitution and redirect stderr
    if ! status_json=$(tailscale status --json 2>/dev/null); then
        log "ERROR: Failed to get Tailscale status"
        return 1
    fi
    
    # Use echo to avoid terminal corruption
    local ips
    if ! ips=$(echo "$status_json" | jq -r '.Self.TailscaleIPs | join(", ")' 2>/dev/null); then
        log "ERROR: Failed to parse Tailscale IPs"
        return 1
    fi
    
    log "Tailscale IP(s): $ips"
    
    # Get hostname
    local hostname
    if ! hostname=$(echo "$status_json" | jq -r '.Self.HostName' 2>/dev/null); then
        log "ERROR: Failed to parse Tailscale hostname"
        return 1
    fi
    
    log "Tailscale hostname: $hostname"
    
    # Check if we're connected to a DERP relay
    local derp_region
    if ! derp_region=$(echo "$status_json" | jq -r '.Self.RelayRegion' 2>/dev/null); then
        derp_region="unknown"
    fi
    
    if [[ "$derp_region" != "null" && "$derp_region" != "" && "$derp_region" != "unknown" ]]; then
        log "Connected to DERP relay region: $derp_region"
    else
        log "Not connected to any DERP relay, this may indicate connectivity issues"
    fi
    
    return 0
}

# Suggest recovery steps
suggest_recovery() {
    log "Suggesting recovery steps:"
    log "1. Run 'sudo tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &' to start the daemon"
    log "2. Run '/mnt/urbalurbadisk/networking/net1-setup-tailscale.sh' to authenticate"
    log "3. Run 'sudo journalctl -u tailscaled' to check system logs if available"
}

# Display other nodes on the network
list_network_nodes() {
    if [ "$JQ_INSTALLED" != "true" ]; then
        log "Cannot list network nodes without jq"
        return 1
    fi
    
    log "Peers on your Tailscale network:"
    
    local status_json
    if ! status_json=$(tailscale status --json 2>/dev/null); then
        log "ERROR: Failed to get Tailscale status"
        return 1
    fi
    
    # Check if there are any peers
    local peer_count
    if ! peer_count=$(echo "$status_json" | jq '.Peer | length' 2>/dev/null); then
        log "ERROR: Failed to parse peer count"
        return 1
    fi
    
    if [[ "$peer_count" -eq 0 ]]; then
        log "No peers found on your Tailscale network"
        return 0
    fi
    
    # Create a temporary file for the peer list to avoid terminal corruption
    local tmp_file
    tmp_file=$(mktemp)
    
    # List peers with their status to a temporary file
    echo "$status_json" | jq -r '.Peer | to_entries[] | 
        "\(.value.HostName)\t\(.value.TailscaleIPs[0])\t\(if .value.Online then "online" else "offline" end)"' > "$tmp_file"
    
    # Read the file line by line in a controlled manner
    while IFS=$'\t' read -r hostname ip status; do
        log "- $hostname: $ip ($status)"
    done < "$tmp_file"
    
    # Clean up
    rm -f "$tmp_file"
    
    return 0
}

# Main function
main() {
    log "Starting Tailscale connectivity check for provision-host..."
    
    # Check if jq is installed once at the beginning
    check_jq_installed
    
    # Step 1: Check if Tailscale is installed
    if ! check_tailscale_installed; then
        log "ERROR: Tailscale installation check failed"
        exit 1
    fi
    
    # Step 2: Check if tailscaled daemon is running
    if ! check_tailscaled_running; then
        log "Attempting to recover tailscaled daemon..."
        if ! start_tailscaled; then
            log "ERROR: Failed to start tailscaled daemon"
            suggest_recovery
            exit 1
        fi
    fi
    
    # Step 3: Check if Tailscale is authenticated
    if ! check_authentication; then
        log "ERROR: Tailscale is not authenticated"
        log "Run '/mnt/urbalurbadisk/networking/net1-setup-tailscale.sh' to authenticate"
        exit 1
    fi
    
    # Step 4: Get detailed status
    get_tailscale_status || true  # Continue even if this fails
    
    # Step 5: Display basic status (to a temporary file to avoid terminal issues)
    local tmp_status
    tmp_status=$(mktemp)
    tailscale status > "$tmp_status" 2>/dev/null
    log "Current Tailscale status:"
    cat "$tmp_status"
    rm -f "$tmp_status"
    
    # Step 6: List other nodes on the network
    list_network_nodes || true  # Continue even if this fails
    
    log "Tailscale connectivity check completed successfully"
    
    
    exit 0
}

# Run the main function
main