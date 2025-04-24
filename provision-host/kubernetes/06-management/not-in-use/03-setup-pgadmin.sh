#!/bin/bash
# filename: 03-setup-pgadmin.sh
# description: Setup pgadmin for admin of the PostgreSQL using Ansible playbook.
# usage: ./03-setup-pgadmin.sh <target_host>
# example: ./03-setup-pgadmin.sh multipass-microk8s
#         ./03-setup-pgadmin.sh rancher-desktop
#
# Notes:
# - For microk8s: Uses SSH-based deployment
# - For Rancher Desktop: Uses local deployment
# - Both use the same playbook with different connection methods

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
PLAYBOOK_PATH_SETUP_PGADMIN="$ANSIBLE_DIR/playbooks/641-adm-pgadmin.yml"

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
    cd $ANSIBLE_DIR && ansible-playbook $playbook $extra_args
    check_command_success "$step"
}

# Main execution
main() {
    echo "Starting pgAdmin setup on $TARGET_HOST"
    echo "---------------------------------------------------"

    # Verify Kubernetes context...
    kubectl config use-context $TARGET_HOST
    
    # Apply the pgAdmin ConfigMap first
    echo "Applying pgAdmin ConfigMap..."
    kubectl apply -f /mnt/urbalurbadisk/manifests/640-pgadmin-configmap.yaml
    
    # Check if we're running on Rancher Desktop
    if [ "$TARGET_HOST" = "rancher-desktop" ]; then
        echo "Running on Rancher Desktop - using local deployment"
        run_playbook "Setup pgAdmin" "$PLAYBOOK_PATH_SETUP_PGADMIN" "-i localhost, -c local -e target_host=\"$TARGET_HOST\""
    else
        # Original microk8s deployment method
        run_playbook "Setup pgAdmin" "$PLAYBOOK_PATH_SETUP_PGADMIN" "-e target_host=\"$TARGET_HOST\""
    fi
    
    print_summary
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