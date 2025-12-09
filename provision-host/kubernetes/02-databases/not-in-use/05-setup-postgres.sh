#!/bin/bash
# filename: 05-setup-postgres.sh
# description: Setup PostgreSQL on a cluster using Ansible playbook. Verifies storage folder and deploys PostgreSQL.
# usage: ./05-setup-postgres.sh [target-host]
# example: ./05-setup-postgres.sh multipass-microk8s
# or in case of rancher desktop use: ./05-setup-postgres.sh rancher-desktop
# If no target host is provided, the script will default to rancher-desktop.

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
PLAYBOOK_PATH_SETUP_POSTGRES="$ANSIBLE_DIR/playbooks/040-database-postgresql.yml"
PLAYBOOK_PATH_VERIFY_POSTGRES="$ANSIBLE_DIR/playbooks/utility/u02-verify-postgres.yml"
MERGED_KUBECONF_FILE="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

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
    if [ $? -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed"
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
    
    echo "$(basename "$0"): Running playbook for $step: $(basename "$playbook")..."
    cd "$ANSIBLE_DIR" && ansible-playbook "$playbook" -e "target_host=$TARGET_HOST" $extra_args
    local result=$?
    if [ $result -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Playbook failed with exit code $result"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Test Kubernetes connection
test_connection() {
    echo "Testing connection to Kubernetes context $TARGET_HOST..."
    
    # Check if context exists
    if ! kubectl config get-contexts "$TARGET_HOST" &>/dev/null; then
        add_status "Test connection" "Fail"
        add_error "Test connection" "Context $TARGET_HOST not found in kubeconfig"
        echo "Available contexts:"
        kubectl config get-contexts
        return 1
    fi
    
    # Switch to context and check nodes
    kubectl config use-context "$TARGET_HOST" >/dev/null 2>&1
    if kubectl get nodes &>/dev/null; then
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        add_status "Test connection" "OK"
        echo "Successfully connected to $TARGET_HOST (${node_count} nodes)"
        kubectl get nodes
        return 0
    else
        add_status "Test connection" "Fail"
        add_error "Test connection" "Cannot reach Kubernetes API for context $TARGET_HOST"
        return 1
    fi
}

# Verify Kubernetes context
verify_context() {
    echo "Verifying Kubernetes context..."
    # Use the current kubeconfig (already set by test_connection)
    if kubectl config current-context | grep -q "$TARGET_HOST"; then
        add_status "Verify context" "OK"
        echo "Current context is $TARGET_HOST"
        return 0
    else
        # Try to switch to the context
        if kubectl config use-context "$TARGET_HOST" >/dev/null 2>&1; then
            add_status "Verify context" "OK"
            echo "Switched to context $TARGET_HOST"
            return 0
        else
            add_status "Verify context" "Fail"
            add_error "Verify context" "Could not switch to context $TARGET_HOST"
            return 1
        fi
    fi
}

# Main execution
main() {
    echo "- Script: $(basename "$0") ----- Starting PostgreSQL setup on $TARGET_HOST -----"
    echo "---------------------------------------------------"

    test_connection || { print_summary; return 1; }
    
    verify_context || { print_summary; return 1; }
    
    run_playbook "Setup PostgreSQL" "$PLAYBOOK_PATH_SETUP_POSTGRES" || { print_summary; return 1; }
    
    run_playbook "Verify PostgreSQL" "$PLAYBOOK_PATH_VERIFY_POSTGRES" || { print_summary; return 1; }

    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo "- Script: $(basename "$0") ----- Installation Summary ----- Target Host: $TARGET_HOST"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
    fi
}

# Run the main function and exit with its return code
main
exit $?