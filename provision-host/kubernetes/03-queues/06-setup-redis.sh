#!/bin/bash
# filename: 06-setup-redis.sh
# description: Setup redisQL on a microk8s cluster using Ansible playbook.
# usage: ./06-setup-redis.sh [target-host]
# example: ./06-setup-redis.sh multipass-microk8s

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
PLAYBOOK_PATH_SETUP_REDIS="$ANSIBLE_DIR/playbooks/050-setup-redis.yml"

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
    echo "Starting Redis setup on $TARGET_HOST"
    echo "---------------------------------------------------"

    test_connection || return 1
    
    run_playbook "Setup Redis" "$PLAYBOOK_PATH_SETUP_REDIS" || return 1

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