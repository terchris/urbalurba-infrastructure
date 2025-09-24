#!/bin/bash
# filename: 020-setup-nginx.sh
# description: Setup Nginx on a Kubernetes cluster using Ansible playbook.
# usage: ./020-setup-nginx.sh [kube-context]
# example: ./020-setup-nginx.sh rancher-desktop

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_NGINX="$ANSIBLE_DIR/playbooks/020-setup-nginx.yml"

# Get current context if none provided
if [ -z "$1" ]; then
    KUBE_CONTEXT=$(kubectl config current-context)
    echo "No context specified, using current context: $KUBE_CONTEXT"
else
    KUBE_CONTEXT=$1
    # Verify the context exists
    if ! kubectl config get-contexts $KUBE_CONTEXT &>/dev/null; then
        echo "Error: Context '$KUBE_CONTEXT' does not exist in kubeconfig"
        exit 1
    fi
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
        add_status "$step" "Fail"
        add_error "$step" "Command failed with exit code $exit_code"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Function to run Ansible playbook
run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    
    echo "Running playbook for $step..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$KUBE_CONTEXT $extra_args
    local exit_code=$?
    check_command_success "$step" $exit_code
    return $exit_code
}

# Test Kubernetes connection
test_connection() {
    echo "Testing connection to Kubernetes context: $KUBE_CONTEXT..."
    kubectl --context $KUBE_CONTEXT get nodes
    local exit_code=$?
    check_command_success "Test Kubernetes connection" $exit_code
    return $exit_code
}

# Main execution
main() {
    echo "Starting Nginx setup on Kubernetes context: $KUBE_CONTEXT"
    echo "---------------------------------------------------"

    test_connection || return 1
    
    run_playbook "Setup Nginx" "$PLAYBOOK_PATH_SETUP_NGINX" "-v" || return 1

    print_summary
    
    # Return 0 if no errors, 1 otherwise
    if [ ${#ERRORS[@]} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo "Nginx is now deployed in context: $KUBE_CONTEXT"
        echo "You can access it through the configured ingress path"
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo "The deployment of Nginx was not successful. Please check the errors above."
    fi
}

# Run the main function and exit with its return code
main
exit $?