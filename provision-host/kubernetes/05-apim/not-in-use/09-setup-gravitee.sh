#!/bin/bash
# filename: provision-host/kubernetes/01-default-apps/09-setup-gravitee.sh
# description: Setup Gravitee APIM in the default namespace using Ansible playbook.
# usage: ./09-setup-gravitee.sh [target-host]
# example: ./09-setup-gravitee.sh rancher-desktop

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
PLAYBOOK_PATH_SETUP_GRAVITEE="$ANSIBLE_DIR/playbooks/090-setup-gravitee.yml"

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
    local result=$2
    if [ ! -z "$result" ] && [ $result -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed with exit code $result"
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
    local result=$?
    check_command_success "$step" $result
    return $result
}


# Main execution
main() {
    echo "Starting Gravitee APIM setup on $TARGET_HOST in the default namespace"
    echo "---------------------------------------------------"

    run_playbook "Setup Gravitee APIM" "$PLAYBOOK_PATH_SETUP_GRAVITEE" || return 1

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
        echo ""
        echo "Gravitee APIM has been deployed to the default namespace."
        echo ""
        echo "You can check the Gravitee pods with: kubectl get pods | grep gravitee"

    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if MongoDB is running: kubectl get pods -l app=mongodb"
        echo "  - Check if Elasticsearch is running: kubectl get pods -l app.kubernetes.io/name=elasticsearch"
        echo "  - Check MongoDB logs: kubectl logs \$(kubectl get pods -l app=mongodb -o jsonpath='{.items[0].metadata.name}')"
        echo "  - Check Elasticsearch logs: kubectl logs \$(kubectl get pods -l app.kubernetes.io/name=elasticsearch -o jsonpath='{.items[0].metadata.name}')"
        echo "  - Check deployments: kubectl get deployments"
    fi
}

# Run the main function and exit with its return code
main
exit $?