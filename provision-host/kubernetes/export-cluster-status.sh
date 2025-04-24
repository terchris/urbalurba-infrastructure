#!/bin/bash
# filename: export-cluster-status.sh
# description: extract the status of the cluster and store it on the filesystem.
# the extracted files are stored on provision-host on /mnt/urbalurbadisk/kubeconfig/extract/<cluster-name>
# where <cluster-name> is the name of the cluster.
# the script is run on provision-host as ansible user.

# Example:
# ./export-cluster-status.sh my-cluster
# will store the status in /mnt/urbalurbadisk/kubeconfig/extract/my-cluster

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
PLAYBOOK_PATH_CLUSTER_STATUS="/mnt/urbalurbadisk/ansible/playbooks/utility/u03-extract-cluster-config.yml"
EXTRACT_BASE_PATH="/mnt/urbalurbadisk/kubeconfig/extract"
MERGED_KUBECONF_FILE="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
TARGET_HOST=${1:-"multipass-microk8s"}

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

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
    ansible-playbook $playbook \
        -e target_host=$TARGET_HOST \
        -e config_extract_folder=$EXTRACT_BASE_PATH \
        -e merged_kubeconf_file=$MERGED_KUBECONF_FILE \
        $extra_args
    check_command_success "$step"
}

# Main execution
main() {
    echo "Starting cluster status export for $TARGET_HOST"
    echo "---------------------------------------------------"

    # Run the Ansible playbook
    run_playbook "Extract Cluster Status" "$PLAYBOOK_PATH_CLUSTER_STATUS" "${@:2}" || return 1

    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo "---------- Export Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "Cluster status exported successfully to $EXTRACT_BASE_PATH/$TARGET_HOST"
    else
        echo "Errors occurred during export:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
    fi
}

# Run the main function and exit with its return code
main "$@"
exit $?