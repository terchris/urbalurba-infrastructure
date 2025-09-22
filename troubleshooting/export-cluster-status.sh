#!/bin/bash
# filename: export-cluster-status.sh
# description: Comprehensive Kubernetes cluster status exporter for troubleshooting and diagnostics
#
# PURPOSE:
# Extracts complete cluster configuration and state information for debugging, auditing,
# or sharing with support teams. Creates a snapshot of all Kubernetes resources and
# service configurations at a specific point in time.
#
# OUTPUT:
# Files are stored in troubleshooting/output/<cluster-name>/
# Creates individual .txt files for each resource type plus:
# - vital-cluster-config.txt: Merged file with all information
# - vital-cluster-config.tar.gz: Compressed archive for easy sharing
#
# USAGE:
# From host (if kubectl is configured locally):
#   ./troubleshooting/export-cluster-status.sh [cluster-name]
#
# From provision-host container:
#   docker exec provision-host bash -c "cd /mnt/urbalurbadisk && bash ./troubleshooting/export-cluster-status.sh [cluster-name]"
#   docker cp provision-host:/mnt/urbalurbadisk/troubleshooting/output/[cluster-name] troubleshooting/output/
#
# ARGUMENTS:
#   cluster-name: Optional. Name of the Kubernetes context to export (default: rancher-desktop)
#
# EXTRACTED RESOURCES:
# - Nodes, Namespaces, Pods, Services, Deployments, StatefulSets
# - ConfigMaps, Secrets, PVCs, PVs, StorageClasses
# - Ingress, NetworkPolicies, ServiceAccounts
# - ClusterRoles, ClusterRoleBindings, CRDs
# - ResourceQuotas, LimitRanges, HPA
# - Helm releases, kubectl version, node resource usage
# - Service-specific versions (PostgreSQL, Redis, Elasticsearch)
#
# REQUIREMENTS:
# - Bash 4.0+ (uses associative arrays)
# - kubectl configured with access to the target cluster
# - ansible-playbook available (uses utility/u03-extract-cluster-config.yml)
#
# EXAMPLE:
# ./troubleshooting/export-cluster-status.sh production-cluster
# Creates: troubleshooting/output/production-cluster/ with all cluster information

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
# Determine if we're running inside provision-host container
if [ -d "/mnt/urbalurbadisk" ]; then
    BASE_PATH="/mnt/urbalurbadisk"
else
    BASE_PATH="."
fi

PLAYBOOK_PATH_CLUSTER_STATUS="$BASE_PATH/ansible/playbooks/utility/u03-extract-cluster-config.yml"
EXTRACT_BASE_PATH="$BASE_PATH/troubleshooting/output"
MERGED_KUBECONF_FILE="$BASE_PATH/kubeconfig/kubeconf-all"
TARGET_HOST=${1:-"rancher-desktop"}

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