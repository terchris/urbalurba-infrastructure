#!/bin/bash
# filename: networking/tailscale-lib.sh
# description: Common functions for Tailscale operations in the Urbalurba infrastructure
#
# This library provides shared functionality for Tailscale-related operations
# across different scripts in the networking directory. It includes functions
# for validating Tailscale credentials, checking installation status, and
# other common operations.
#
# Usage:
#   1. Source this file in your script:
#      source "$(dirname "$0")/tailscale-lib.sh"
#   or with absolute path:
#      source "/mnt/urbalurbadisk/networking/tailscale-lib.sh"
#
#   2. Use the functions as needed:
#      if ! tailscale_check_credentials "$TAILSCALE_SECRET" "$TAILSCALE_CLIENTID" "$TAILSCALE_CLIENTSECRET"; then
#          echo "Using template Tailscale credentials. Skipping setup."
#      fi
#
# Functions:
#   - tailscale_log: Log messages with timestamps
#   - tailscale_check_credentials: Check if Tailscale credentials are template values
#   - tailscale_is_installed: Check if Tailscale is installed
#   - tailscale_is_running: Check if Tailscale daemon is running
#   - tailscale_is_authenticated: Check if Tailscale is authenticated
#   - tailscale_get_secrets: Retrieve Tailscale secrets from Kubernetes

# Stop execution on error
# Note: The calling script should decide whether to set -e based on its needs
# set -e

# ==================== LOGGING FUNCTIONS ====================

# Function to log messages with timestamps
# Usage: tailscale_log "Your message here"
tailscale_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ==================== VALIDATION FUNCTIONS ====================

# Function to check if Tailscale credentials are template values
# Returns 0 if credentials are valid (not templates)
# Returns 1 if credentials are template values
#
# Usage: tailscale_check_credentials "$TAILSCALE_SECRET" "$TAILSCALE_CLIENTID" "$TAILSCALE_CLIENTSECRET" "$TAILSCALE_TAILNET" "$TAILSCALE_DOMAIN"
tailscale_check_credentials() {
    local tailscale_secret="$1"
    local tailscale_clientid="$2"
    local tailscale_clientsecret="$3"
    local tailscale_tailnet="$4"
    local tailscale_domain="$5"
    
    # Flag to track if any credentials are template values
    local using_templates=false
    local issues=()
    
    # Check auth key (used for device registration)
    if [[ -z "$tailscale_secret" || 
          "$tailscale_secret" == "tskey-auth-ktyTufs...and---so-on" || 
          "$tailscale_secret" == *"XXXXXXX"* ]]; then
        using_templates=true
        issues+=("TAILSCALE_SECRET appears to be a template value")
    fi
    
    # Check client ID (used for API access)
    if [[ -z "$tailscale_clientid" || 
          "$tailscale_clientid" == "ksNFYZ...." || 
          "$tailscale_clientid" == *"XXXXXXX"* ]]; then
        using_templates=true
        issues+=("TAILSCALE_CLIENTID appears to be a template value")
    fi
    
    # Check client secret (used for API access)
    if [[ -z "$tailscale_clientsecret" || 
          "$tailscale_clientsecret" == "tskey-client-ksNF..." || 
          "$tailscale_clientsecret" == *"XXXXXXX"* ]]; then
        using_templates=true
        issues+=("TAILSCALE_CLIENTSECRET appears to be a template value")
    fi
    
    # Check tailnet name
    if [[ -z "$tailscale_tailnet" || 
          "$tailscale_tailnet" == "githubid.github" || 
          "$tailscale_tailnet" == *"XXXXXXX"* ]]; then
        using_templates=true
        issues+=("TAILSCALE_TAILNET appears to be a template value")
    fi
    
    # Check domain name
    if [[ -z "$tailscale_domain" || 
          "$tailscale_domain" == "some-name.ts.net" || 
          "$tailscale_domain" == *"XXXXXXX"* ]]; then
        using_templates=true
        issues+=("TAILSCALE_DOMAIN appears to be a template value")
    fi
    
    # If using templates, log the issues
    if [ "$using_templates" = true ]; then
        tailscale_log "NOTICE: Using template/placeholder Tailscale values:"
        for issue in "${issues[@]}"; do
            tailscale_log "  - $issue"
        done
        tailscale_log "To use Tailscale, update your Kubernetes secrets with valid Tailscale keys."
        return 1
    fi
    
    return 0
}

# ==================== STATUS FUNCTIONS ====================

# Function to check if Tailscale is installed
# Returns 0 if Tailscale is installed
# Returns 1 if Tailscale is not installed
#
# Usage: if tailscale_is_installed; then echo "Tailscale is installed"; fi
tailscale_is_installed() {
    if command -v tailscale &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if Tailscale daemon is running
# Returns 0 if tailscaled is running
# Returns 1 if tailscaled is not running
#
# Usage: if tailscale_is_running; then echo "Tailscale daemon is running"; fi
tailscale_is_running() {
    if pgrep tailscaled &>/dev/null; then
        return 0
    elif systemctl is-active --quiet tailscaled 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if Tailscale is authenticated
# Returns 0 if Tailscale is authenticated
# Returns 1 if Tailscale is not authenticated
#
# Usage: if tailscale_is_authenticated; then echo "Tailscale is authenticated"; fi
tailscale_is_authenticated() {
    if tailscale status &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# ==================== KUBERNETES FUNCTIONS ====================

# Function to get Tailscale secrets from Kubernetes
# Sets the following variables if successful:
# - TAILSCALE_SECRET
# - TAILSCALE_CLIENTID
# - TAILSCALE_CLIENTSECRET
# - TAILSCALE_TAILNET
# - TAILSCALE_DOMAIN
# - TAILSCALE_CLUSTER_HOSTNAME
#
# Returns 0 if secrets were retrieved
# Returns 1 if secrets could not be retrieved
#
# Usage: 
#   if tailscale_get_secrets [kubeconfig-path]; then
#       echo "Retrieved secrets: $TAILSCALE_DOMAIN"
#   fi
tailscale_get_secrets() {
    local kubeconfig_path="${1:-}"
    local kubeconfig_arg=""
    
    # If kubeconfig path is provided, add it to the kubectl command
    if [ -n "$kubeconfig_path" ]; then
        kubeconfig_arg="--kubeconfig=$kubeconfig_path"
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &>/dev/null; then
        tailscale_log "ERROR: kubectl command not found. Please install kubectl first."
        return 1
    fi
    
    # Check if Kubernetes is accessible
    if ! kubectl get nodes $kubeconfig_arg &>/dev/null; then
        tailscale_log "ERROR: Cannot access Kubernetes. Please ensure Kubernetes is running."
        return 1
    fi
    
    # Check if urbalurba-secrets exists
    if ! kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets &>/dev/null; then
        tailscale_log "ERROR: Cannot find urbalurba-secrets in the default namespace."
        return 1
    fi
    
    # Retrieve secrets
    tailscale_log "Retrieving Tailscale secrets from Kubernetes..."
    
    # Using global variables to store results
    TAILSCALE_SECRET=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_SECRET}" | base64 -d)
    TAILSCALE_CLIENTID=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_CLIENTID}" | base64 -d)
    TAILSCALE_CLIENTSECRET=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_CLIENTSECRET}" | base64 -d)
    TAILSCALE_TAILNET=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_TAILNET}" | base64 -d)
    TAILSCALE_DOMAIN=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_DOMAIN}" | base64 -d)
    TAILSCALE_CLUSTER_HOSTNAME=$(kubectl get secret $kubeconfig_arg --namespace default urbalurba-secrets -o jsonpath="{.data.TAILSCALE_CLUSTER_HOSTNAME}" | base64 -d)
    
    # Check if any of the required values are empty
    if [ -z "$TAILSCALE_SECRET" ] || [ -z "$TAILSCALE_CLIENTID" ] || 
       [ -z "$TAILSCALE_CLIENTSECRET" ] || [ -z "$TAILSCALE_TAILNET" ] ||
       [ -z "$TAILSCALE_DOMAIN" ]; then
        tailscale_log "ERROR: One or more required Tailscale secrets are missing."
        return 1
    fi
    
    return 0
}

# ==================== UTILITY FUNCTIONS ====================

# Function to print Tailscale status in a clean format
# Usage: tailscale_print_status
tailscale_print_status() {
    tailscale_log "Tailscale Status:"
    
    if ! tailscale_is_installed; then
        tailscale_log "  - Tailscale is not installed"
        return 1
    fi
    
    if ! tailscale_is_running; then
        tailscale_log "  - Tailscale daemon is not running"
        return 1
    fi
    
    if ! tailscale_is_authenticated; then
        tailscale_log "  - Tailscale is not authenticated"
        return 1
    fi
    
    # Create a temporary file to store status output
    local tmp_status
    tmp_status=$(mktemp)
    
    # Get Tailscale status
    tailscale status > "$tmp_status" 2>/dev/null
    
    # Display tailnet name
    local tailnet
    tailnet=$(grep "tailnet:" "$tmp_status" | awk '{print $2}')
    tailscale_log "  - Tailnet: $tailnet"
    
    # Display local IP
    local ip
    ip=$(tailscale ip -4 2>/dev/null)
    tailscale_log "  - IP: $ip"
    
    # Display hostname
    local hostname
    hostname=$(hostname)
    tailscale_log "  - Hostname: $hostname"
    
    # Clean up
    rm -f "$tmp_status"
    
    return 0
}

# ==================== ENTRY POINT FUNCTION ====================

# Function to check environment for Tailscale setup
# This is a convenience function that combines several checks
# Returns 0 if environment is ready for Tailscale setup
# Returns 1 if environment is not ready
#
# Usage: 
#   if tailscale_check_environment [kubeconfig-path]; then
#     echo "Environment is ready for Tailscale setup"
#   else
#     echo "Environment is not ready for Tailscale setup"
#   fi
tailscale_check_environment() {
    local kubeconfig_path="${1:-}"
    
    # Check if Tailscale is installed
    if ! tailscale_is_installed; then
        tailscale_log "ERROR: Tailscale is not installed. Please install Tailscale first."
        return 1
    fi
    
    # Get Tailscale secrets
    if ! tailscale_get_secrets "$kubeconfig_path"; then
        tailscale_log "ERROR: Failed to retrieve Tailscale secrets."
        return 1
    fi
    
    # Check if Tailscale credentials are valid
    if ! tailscale_check_credentials "$TAILSCALE_SECRET" "$TAILSCALE_CLIENTID" "$TAILSCALE_CLIENTSECRET" "$TAILSCALE_TAILNET" "$TAILSCALE_DOMAIN"; then
        tailscale_log "ERROR: Tailscale credentials are not valid."
        return 1
    fi
    
    tailscale_log "Environment is ready for Tailscale setup."
    return 0
}

# ==================== EXPORT FUNCTIONS ====================

# Export functions so they can be used in other scripts
export -f tailscale_log
export -f tailscale_check_credentials
export -f tailscale_is_installed
export -f tailscale_is_running
export -f tailscale_is_authenticated
export -f tailscale_get_secrets
export -f tailscale_print_status
export -f tailscale_check_environment

# Notify if this script is being executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tailscale_log "This is a library script and should be sourced, not executed directly."
    tailscale_log "Usage: source \"$(realpath "${BASH_SOURCE[0]}")\""
    exit 1
fi