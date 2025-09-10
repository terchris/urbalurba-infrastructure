#!/bin/bash
# filename: net1-delete-tailscale-host.sh

# TODO: Det this to work properly - now it dos not work.


# description: Removes a specific host from your Tailscale network using the Tailscale API
# 
# Usage: ./net1-delete-tailscale-host.sh <hostname>
# Example: ./net1-delete-tailscale-host.sh provision-host
#
# This script requires jq to parse the Tailscale status output
# It uses the Tailscale API key stored in Kubernetes secrets to authenticate.

set -e

# Function to log messages with timestamps
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if required commands are available
check_requirements() {
    local missing=false
    
    if ! command -v curl &>/dev/null; then
        log "ERROR: curl command not found. Please install curl first."
        missing=true
    fi
    
    if ! command -v jq &>/dev/null; then
        log "ERROR: jq command not found. Please install jq first."
        missing=true
    fi
    
    if ! command -v tailscale &>/dev/null; then
        log "ERROR: tailscale command not found. Please install tailscale first."
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

# Retrieve the API key from Kubernetes secrets
get_tailscale_api_key() {
    log "Retrieving Tailscale API key from Kubernetes secrets..."
    local api_key
    
    if ! api_key=$(kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_ACL_KEY}" | base64 -d); then
        log "ERROR: Failed to retrieve Tailscale API key from Kubernetes secrets"
        return 1
    fi
    
    if [ -z "$api_key" ]; then
        log "ERROR: Tailscale API key is empty"
        return 1
    fi
    
    echo "$api_key"
    return 0
}

# List all devices in Tailscale network
list_all_devices() {
    log "Listing all devices in your Tailscale network..."
    
    # Get the devices directly from tailscale status
    local devices_json
    if ! devices_json=$(tailscale status --json); then
        log "ERROR: Failed to get Tailscale status"
        return 1
    fi
    
    # Process self (current device)
    local self_json
    self_json=$(echo "$devices_json" | jq -r '.Self')
    if [ -n "$self_json" ] && [ "$self_json" != "null" ]; then
        local self_id=$(echo "$self_json" | jq -r '.ID')
        local self_name=$(echo "$self_json" | jq -r '.HostName')
        echo "$self_id $self_name self"
    fi
    
    # Process peers (other devices)
    local peers_json
    peers_json=$(echo "$devices_json" | jq -r '.Peer')
    if [ -n "$peers_json" ] && [ "$peers_json" != "null" ]; then
        echo "$devices_json" | jq -r '.Peer | to_entries[] | .value.ID + " " + .value.HostName + " peer"'
    fi
    
    return 0
}

# Delete a specific device by ID
delete_device() {
    local api_key=$1
    local device_id=$2
    local device_name=$3
    
    log "Deleting device $device_name (ID: $device_id) from Tailscale network..."
    
    # Get the tailnet name
    local tailnet=""
    # Suppress log messages during this call
    tailnet=$(kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_TAILNET}" | base64 -d 2>/dev/null) || \
    tailnet=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\..*//g')
    
    log "Using tailnet: $tailnet"
    
    # Make API request to delete the device
    log "Sending DELETE request to https://api.tailscale.com/api/v2/tailnet/${tailnet}/devices/${device_id}"
    
    # Use a temporary file for curl to avoid issues with complex API keys
    local auth_header="Authorization: Bearer ${api_key}"
    curl -s -X DELETE \
        -H "$auth_header" \
        "https://api.tailscale.com/api/v2/tailnet/${tailnet}/devices/${device_id}"
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to delete device $device_name"
        return 1
    fi
    
    log "Successfully deleted device $device_name (ID: $device_id) from Tailscale"
    return 0
}

# Main function
main() {
    # Check if hostname parameter is provided
    if [ $# -lt 1 ]; then
        log "Usage: $0 <hostname_pattern>"
        log "Example: $0 provision-host (to delete a specific host)"
        exit 1
    fi
    
    local host_pattern=$1
    log "Starting Tailscale host deletion for: $host_pattern"
    
    # Check requirements
    if ! check_requirements; then
        log "ERROR: Missing required dependencies"
        exit 1
    fi
    
    # Get Tailscale API key from Kubernetes secrets
    local api_key
    if ! api_key=$(get_tailscale_api_key); then
        log "ERROR: Failed to get Tailscale API key"
        exit 1
    fi
    
    # List all devices
    local devices
    if ! devices=$(list_all_devices); then
        log "ERROR: Failed to list Tailscale devices"
        exit 1
    fi
    
    # Find matching devices
    local matching_devices=()
    local matching_ids=()
    local matching_types=()
    
    while read -r device_line; do
        if [[ -z "$device_line" ]]; then
            continue
        fi
        
        local device_id=$(echo "$device_line" | cut -d' ' -f1)
        local device_name=$(echo "$device_line" | cut -d' ' -f2)
        local device_type=$(echo "$device_line" | cut -d' ' -f3)
        
        # Check if device name matches the pattern
        if [[ "$device_name" == *"$host_pattern"* ]]; then
            matching_devices+=("$device_name")
            matching_ids+=("$device_id")
            matching_types+=("$device_type")
        fi
    done <<< "$devices"
    
    # Check if any devices matched
    if [ ${#matching_devices[@]} -eq 0 ]; then
        log "No matching devices found to delete"
        log "Available devices:"
        echo "$devices" | while read -r line; do
            if [[ -n "$line" ]]; then
                local name=$(echo "$line" | cut -d' ' -f2)
                local type=$(echo "$line" | cut -d' ' -f3)
                log "  - $name ($type)"
            fi
        done
        exit 0
    fi
    
    # Display matching devices
    log "Found ${#matching_devices[@]} matching devices:"
    for i in "${!matching_devices[@]}"; do
        log "  $((i+1)). ${matching_devices[$i]} (${matching_types[$i]})"
    done
    
    # If there's exactly one device, delete it automatically
    if [ ${#matching_devices[@]} -eq 1 ]; then
        log "Automatically deleting the single matching device: ${matching_devices[0]}"
        
        if ! delete_device "$api_key" "${matching_ids[0]}" "${matching_devices[0]}"; then
            log "ERROR: Failed to delete device ${matching_devices[0]}"
            exit 1
        fi
    else
        # If there are multiple devices, ask which one to delete
        log "Multiple devices found matching the pattern."
        echo "Please enter the number of the device to delete (1-${#matching_devices[@]}),"
        echo "or 'a' to delete all matching devices, or 'q' to quit:"
        read -p "> " selection
        
        if [[ "$selection" == "q" ]]; then
            log "Operation cancelled"
            exit 0
        elif [[ "$selection" == "a" ]]; then
            log "Deleting all matching devices..."
            for i in "${!matching_devices[@]}"; do
                if ! delete_device "$api_key" "${matching_ids[$i]}" "${matching_devices[$i]}"; then
                    log "ERROR: Failed to delete device ${matching_devices[$i]}"
                    # Continue with the next device
                fi
            done
        elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#matching_devices[@]}" ]; then
            local idx=$((selection-1))
            log "Deleting device: ${matching_devices[$idx]}"
            
            if ! delete_device "$api_key" "${matching_ids[$idx]}" "${matching_devices[$idx]}"; then
                log "ERROR: Failed to delete device ${matching_devices[$idx]}"
                exit 1
            fi
        else
            log "Invalid selection"
            exit 1
        fi
    fi
    
    log "Deletion process completed."
    exit 0
}

# Run the main function
main "$@"