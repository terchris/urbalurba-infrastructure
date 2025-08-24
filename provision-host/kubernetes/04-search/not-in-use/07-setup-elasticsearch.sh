#!/bin/bash
# filename: 07-setup-elasticsearch.sh
# description: Setup Elasticsearch on a microk8s cluster using Ansible playbook.
# usage: ./07-setup-elasticsearch.sh [target-host]
# example: ./07-setup-elasticsearch.sh multipass-microk8s
# note: Uses default Elasticsearch version 8.16.3

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
PLAYBOOK_PATH_SETUP_ELASTICSEARCH="$ANSIBLE_DIR/playbooks/060-setup-elasticsearch.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"multipass-microk8s"}

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
    
    echo "Running playbook for $step..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e target_host=$TARGET_HOST $extra_args
    check_command_success "$step"
}

# Test Ansible connection
test_connection() {
    echo "Testing connection to $TARGET_HOST..."
    cd $ANSIBLE_DIR && ansible $TARGET_HOST -m ping
    check_command_success "Test connection"
}

# Main execution
main() {
    echo "Starting Elasticsearch setup on $TARGET_HOST (using default version 8.16.1)"
    echo "---------------------------------------------------"

    test_connection || return 1
    
    run_playbook "Setup Elasticsearch" "$PLAYBOOK_PATH_SETUP_ELASTICSEARCH" || return 1

    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo "Elasticsearch 8.16.1 has been deployed."
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