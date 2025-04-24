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
#
# After running this script, you can use net2-expose-tailscale-service.sh to expose
# individual services through Tailscale.
#
# Related scripts:
# - net2-expose-tailscale-service.sh: Used to expose individual services after this base setup
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Kubeconfig file not found
# 3 - Tailscale operator installation failed
# 4 - Tailscale ingress configuration failed

set -e

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Function to log messages with timestamps
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
}

# Function to get secret from Kubernetes
get_secret() {
    local secret_name=$1
    kubectl get secret --namespace default urbalurba-secrets -o jsonpath="{.data.$secret_name}" --kubeconfig "$KUBECONFIG_PATH" | base64 -d
}

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_TAILSCALE="$ANSIBLE_DIR/playbooks/net2-setup-tailscale-cluster.yml"
ANSIBLE_EXTRA_VARS="-e hide_sensitive_info=true" # Add option to hide sensitive info

# Get Tailscale secrets from Kubernetes
log "Reading Tailscale secrets from Kubernetes..."
TAILSCALE_CLIENTID=$(get_secret "TAILSCALE_CLIENTID")
TAILSCALE_CLIENTSECRET=$(get_secret "TAILSCALE_CLIENTSECRET")
TAILSCALE_TAILNET=$(get_secret "TAILSCALE_TAILNET")
TAILSCALE_DOMAIN=$(get_secret "TAILSCALE_DOMAIN")
TAILSCALE_CLUSTER_HOSTNAME_SECRET=$(get_secret "TAILSCALE_CLUSTER_HOSTNAME")

# Command line parameters
TAILSCALE_CLUSTER_HOSTNAME=${1:-"$TAILSCALE_CLUSTER_HOSTNAME_SECRET"}
KUBECONFIG_PATH=${2:-"/mnt/urbalurbadisk/kubeconfig/kubeconf-all"}

# Verify secrets were retrieved
if [ -z "$TAILSCALE_CLIENTID" ] || [ -z "$TAILSCALE_CLIENTSECRET" ] || [ -z "$TAILSCALE_TAILNET" ] || [ -z "$TAILSCALE_DOMAIN" ]; then
    log "ERROR: Failed to retrieve required Tailscale secrets from Kubernetes"
    log "Please ensure the following secrets exist in the urbalurba-secrets secret:"
    log "  - TAILSCALE_CLIENTID"
    log "  - TAILSCALE_CLIENTSECRET"
    log "  - TAILSCALE_TAILNET"
    log "  - TAILSCALE_DOMAIN"
    exit 1
fi

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
        log "ERROR: $step failed with exit code $exit_code"
        return 1
    else
        add_status "$step" "OK"
        log "SUCCESS: $step completed"
        return 0
    fi
}

# Function to run Ansible playbook
run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    local result=0
    
    log "Running playbook for $step..."
    
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

# Main function
main() {
    log "Starting Tailscale funnel deployment with hostname $TAILSCALE_CLUSTER_HOSTNAME"
    log "Using kubeconfig: $KUBECONFIG_PATH"
    log "---------------------------------------------------"
    
    # Check if kubeconfig exists
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        log "ERROR: Kubeconfig file not found at $KUBECONFIG_PATH"
        add_status "Kubeconfig Check" "FAIL"
        add_error "Kubeconfig Check" "File not found"
        print_summary
        return 1
    fi
    
    add_status "Kubeconfig Check" "OK"
    
    # Run the Ansible playbook to deploy Tailscale
    log "Deploying Tailscale ingress (this may take a few minutes)..."
    if ! run_playbook "Deploy Tailscale ingress" "$PLAYBOOK_PATH_SETUP_TAILSCALE"; then
        # Even if the playbook fails, check if the operator is running
        log "Checking if Tailscale operator is running despite playbook failure..."
        
        # Check for Tailscale operator in tailnet
        if tailscale status | grep -q "tailscale-operator"; then
            log "Good news! Tailscale operator appears to be running in the tailnet."
            log "The failure might be in a later step but the core functionality may still work."
            add_status "Tailscale Operator" "RUNNING (despite playbook failure)"
        else
            log "Tailscale operator not found in tailnet."
            add_status "Tailscale Operator" "NOT RUNNING"
        fi
        
        print_summary
        return 1
    fi
    
    print_summary
}

# Print summary
print_summary() {
    log "---------- Deployment Summary ----------"
    for step in "${!STATUS[@]}"; do
        log "$step: ${STATUS[$step]}"
    done

    has_failure=false
    for status in "${STATUS[@]}"; do
        if [ "$status" = "FAIL" ]; then
            has_failure=true
            break
        fi
    done

    if [ "$has_failure" = false ]; then
        log "All steps completed successfully."
        if [ -n "$TAILNET" ]; then
            log "Your service should be accessible at: https://$TAILSCALE_CLUSTER_HOSTNAME.$TAILNET.ts.net"
        else
            log "Your service should be accessible at the URL shown in the playbook output"
        fi
        log "Note: It may take up to 10 minutes for DNS to fully propagate and TLS certificates to be provisioned"
    else
        log "Errors occurred during deployment:"
        for step in "${!ERRORS[@]}"; do
            if [ -n "${ERRORS[$step]}" ]; then
                log "  $step: ${ERRORS[$step]}"
            fi
        done
    fi
}

# Run the main function and exit with its return code
main
exit $?