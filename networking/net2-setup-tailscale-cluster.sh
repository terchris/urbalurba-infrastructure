#!/bin/bash
# filename: net2-setup-tailscale-cluster.sh
# description: Sets up the base Tailscale infrastructure for the entire Kubernetes cluster
# 
# This script is the first step in setting up Tailscale for your Kubernetes cluster.
# It installs the Tailscale operator and configures the base infrastructure needed
# for exposing services through Tailscale.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Tailscale API credentials in urbalurba-secrets
#
# Usage: ./net2-setup-tailscale-cluster.sh [cluster-hostname] [optional:kubeconfig-path]
# example: ./net2-setup-tailscale-cluster.sh rancher-traefik /mnt/urbalurbadisk/kubeconfig/kubeconf-all
#
# If no cluster-hostname is provided, the script will use TAILSCALE_CLUSTER_HOSTNAME
# from the urbalurba-secrets Kubernetes secret.

# Source the Tailscale library
# Using realpath with dirname to handle the script being run from any location
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/tailscale-lib.sh"

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    tailscale_log "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_TAILSCALE="$ANSIBLE_DIR/playbooks/net2-setup-tailscale-cluster.yml"
ANSIBLE_EXTRA_VARS="-e hide_sensitive_info=true" # Add option to hide sensitive info

# Command line parameters
KUBECONFIG_PATH=${2:-"/mnt/urbalurbadisk/kubeconfig/kubeconf-all"}
TAILSCALE_CLUSTER_HOSTNAME=${1:-""}

# Function to add status
add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

# Function to add error
add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

# Function to check command success
check_command_success() {
    local step=$1
    local exit_code=$2
    if [ $exit_code -ne 0 ]; then
        add_status "$step" "FAIL"
        add_error "$step" "Command failed with exit code $exit_code"
        tailscale_log "ERROR: $step failed with exit code $exit_code"
        return 1
    else
        add_status "$step" "OK"
        tailscale_log "SUCCESS: $step completed"
        return 0
    fi
}

# Function to run Ansible playbook
run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    local result=0
    
    tailscale_log "Running playbook for $step..."
    
    cd $ANSIBLE_DIR && ansible-playbook $playbook \
        -e TAILSCALE_CLUSTER_HOSTNAME=$TAILSCALE_CLUSTER_HOSTNAME \
        -e kubeconfig_path=$KUBECONFIG_PATH \
        -e tailscale_clientid=$TAILSCALE_CLIENTID \
        -e tailscale_clientsecret=$TAILSCALE_CLIENTSECRET \
        -e tailscale_tailnet=$TAILSCALE_TAILNET \
        -e tailscale_domain=$TAILSCALE_DOMAIN \
        $ANSIBLE_EXTRA_VARS $extra_args -v
    result=$?
    
    check_command_success "$step" $result
    return $result
}

# Print summary
print_summary() {
    tailscale_log "---------- Deployment Summary ----------"
    for step in "${!STATUS[@]}"; do
        tailscale_log "$step: ${STATUS[$step]}"
    done

    has_failure=false
    for status in "${STATUS[@]}"; do
        if [ "$status" = "FAIL" ]; then
            has_failure=true
            break
        fi
    done

    if [ "$has_failure" = false ]; then
        if [[ "${STATUS[Tailscale Setup]}" == "SKIPPED"* ]]; then
            tailscale_log "Tailscale setup was skipped due to template configuration values."
            tailscale_log "To set up Tailscale later, update your Kubernetes secrets with valid Tailscale keys"
            tailscale_log "and run this script again."
        else
            tailscale_log "All steps completed successfully."
            if [ -n "$TAILSCALE_DOMAIN" ]; then
                tailscale_log "Your service should be accessible at: https://$TAILSCALE_CLUSTER_HOSTNAME.$TAILSCALE_DOMAIN"
            else
                tailscale_log "Your service should be accessible at the URL shown in the playbook output"
            fi
            tailscale_log "Note: It may take up to 10 minutes for DNS to fully propagate and TLS certificates to be provisioned"
        fi
    else
        tailscale_log "Errors occurred during deployment:"
        for step in "${!ERRORS[@]}"; do
            if [ -n "${ERRORS[$step]}" ]; then
                tailscale_log "  $step: ${ERRORS[$step]}"
            fi
        done
    fi
}

# Main function
main() {
    tailscale_log "Starting Tailscale funnel deployment setup..."
    
    # Check if kubeconfig exists
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        tailscale_log "ERROR: Kubeconfig file not found at $KUBECONFIG_PATH"
        add_status "Kubeconfig Check" "FAIL"
        add_error "Kubeconfig Check" "File not found"
        print_summary
        exit 2
    fi
    
    add_status "Kubeconfig Check" "OK"
    
    # Get Tailscale secrets from Kubernetes using library function
    if ! tailscale_get_secrets "$KUBECONFIG_PATH"; then
        tailscale_log "ERROR: Failed to retrieve Tailscale secrets from Kubernetes"
        add_status "Tailscale Secrets" "FAIL"
        add_error "Tailscale Secrets" "Failed to retrieve secrets"
        print_summary
        exit 1
    fi
    
    add_status "Tailscale Secrets" "OK"
    
    # Use command line parameter for TAILSCALE_CLUSTER_HOSTNAME if provided
    if [ -z "$TAILSCALE_CLUSTER_HOSTNAME" ]; then
        TAILSCALE_CLUSTER_HOSTNAME="$TAILSCALE_CLUSTER_HOSTNAME_SECRET"
    fi
    
    # Check if Tailscale credentials are properly configured using library function
    if ! tailscale_check_credentials "$TAILSCALE_SECRET" "$TAILSCALE_CLIENTID" "$TAILSCALE_CLIENTSECRET" "$TAILSCALE_TAILNET" "$TAILSCALE_DOMAIN"; then
        tailscale_log "Skipping Tailscale cluster setup due to template configuration values."
        add_status "Tailscale Setup" "SKIPPED (using template values)"
        
        print_summary
        
        # Exit with code 0 to not cause the main installation to fail
        exit 0
    fi
    
    add_status "Tailscale Credentials" "OK"
    
    tailscale_log "Using hostname: $TAILSCALE_CLUSTER_HOSTNAME"
    tailscale_log "Using kubeconfig: $KUBECONFIG_PATH"
    tailscale_log "---------------------------------------------------"
    
    # Run the Ansible playbook to deploy Tailscale
    tailscale_log "Deploying Tailscale ingress (this may take a few minutes)..."
    
    if ! run_playbook "Deploy Tailscale ingress" "$PLAYBOOK_PATH_SETUP_TAILSCALE"; then
        # Even if the playbook fails, check if the operator is running
        tailscale_log "Checking if Tailscale operator is running despite playbook failure..."
        
        # Check for Tailscale operator in tailnet using tailscale status
        if tailscale status 2>/dev/null | grep -q "tailscale-operator"; then
            tailscale_log "Good news! Tailscale operator appears to be running in the tailnet."
            tailscale_log "The failure might be in a later step but the core functionality may still work."
            add_status "Tailscale Operator" "RUNNING (despite playbook failure)"
        else
            tailscale_log "Tailscale operator not found in tailnet."
            add_status "Tailscale Operator" "NOT RUNNING"
        fi
        
        print_summary
        exit 3
    fi
    
    print_summary
    return 0
}

# Run the main function and exit with its return code
main
exit $?