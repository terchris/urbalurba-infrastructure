#!/bin/bash
# filename: 05-cloud-setup-postgres.sh
# description: Setup PostgreSQL on a cluster using Ansible playbook. Verifies storage folder and deploys PostgreSQL.
# usage: ./05-cloud-setup-postgres.sh [target-host]
# example: ./05-cloud-setup-postgres.sh multipass-microk8s
# or in case of rancher desktop use: ./05-cloud-setup-postgres.sh rancher-desktop
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

# Test Ansible connection
test_connection() {
    echo "Testing connection to $TARGET_HOST..."
    cd "$ANSIBLE_DIR" || return 1
    local output
    output=$(ansible "$TARGET_HOST" -m ping 2>&1)
    echo "$output"
    if echo "$output" | grep -q "UNREACHABLE"; then
        add_status "Test connection" "Fail"
        add_error "Test connection" "Ansible unreachable: $output"
        return 1
    fi
    if echo "$output" | grep -q "FAILED"; then
        add_status "Test connection" "Fail"
        add_error "Test connection" "Ansible failed: $output"
        return 1
    fi
    check_command_success "Test connection"
    return $?
}

# Verify Kubernetes context
verify_context() {
    echo "Verifying Kubernetes context..."
    CONTEXTS=$(kubectl --kubeconfig=$MERGED_KUBECONF_FILE config get-contexts -o name)
    if echo "$CONTEXTS" | grep -q "$TARGET_HOST"; then
        kubectl --kubeconfig=$MERGED_KUBECONF_FILE config use-context $TARGET_HOST
        check_command_success "Setting context to cluster: $TARGET_HOST"
    else
        add_status "Verify context" "Fail"
        add_error "Verify context" "Context $TARGET_HOST not found"
        return 1
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