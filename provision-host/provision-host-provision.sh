#!/bin/bash
# filename: provision-host-provision.sh
# description: Orchestrates the execution of all provisioning scripts for the host
#
# Usage: ./provision-host-provision.sh [cloud-provider]
#   cloud-provider: az/azure (default), aws, gcp/google, oci/oracle, tf/terraform, all
#
# Example: ./provision-host-provision.sh aws

RUN_IN_DIR="/mnt/urbalurbadisk/provision-host"

# Store cloud provider argument for passing to cloudproviders script
CLOUD_PROVIDER="${1:-az}"

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# List of provisioning scripts to run
PROVISION_SCRIPTS=(
    "provision-host-00-coresw.sh"
    "provision-host-01-cloudproviders.sh"
    "provision-host-02-kubetools.sh"
    "provision-host-03-net.sh"
    "provision-host-04-helmrepo.sh"
    "provision-host-05-builddocs.sh"
)

# Check if running in a container
is_container() {
    # Check for container-specific indicators
    if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        return 0  # True, is a container
    fi
    return 1  # False, not a container
}

# Function that changes to and ensures the script is run from the correct directory
ensure_correct_directory() {
    echo "Changing to directory: ${RUN_IN_DIR}"
    cd "${RUN_IN_DIR}" || {
        echo "Error: Failed to change to directory: ${RUN_IN_DIR}"
        return 1
    }
    
    if [ "${PWD}" != "${RUN_IN_DIR}" ]; then
        echo "Error: Current directory (${PWD}) does not match required directory (${RUN_IN_DIR})"
        return 1
    fi
    
    echo "Successfully changed to correct directory: ${PWD}"
    return 0
}

# Function to add status
add_status() {
    local script=$1
    local status=$2
    STATUS["$script"]=$status
}

# Function to add error
add_error() {
    local script=$1
    local error=$2
    ERRORS["$script"]="${ERRORS[$script]}${ERRORS[$script]:+$'\n'}$error"
}

# Execute a script with proper error handling
execute_script() {
    local script=$1
    local script_arg=$2
    echo "---------------------------------------------------"
    echo "Running ${script}${script_arg:+ with argument: $script_arg}..."

    # Set container environment variable if in container
    if is_container; then
        export RUNNING_IN_CONTAINER=true
    fi

    if [ -x "./${script}" ]; then
        if [ -n "$script_arg" ]; then
            ./${script} "$script_arg"
        else
            ./${script}
        fi
        local exit_code=$?
        if [ ${exit_code} -ne 0 ]; then
            echo "Error executing ${script}. Continuing with next script."
            ERRORS["${script}"]="Script execution failed with exit code ${exit_code}"
            add_status "${script}" "Failed (Exit code: ${exit_code})"
            return ${exit_code}
        else
            echo "${script} completed successfully."
            add_status "${script}" "Success"
            return 0
        fi
    else
        echo "Error: ${script} not found or not executable. Current directory: $(pwd)"
        ls -la
        ERRORS["${script}"]="Script not found or not executable"
        add_status "${script}" "Not found"
        return 1
    fi
}

# Function to print summary
print_summary() {
    echo "---------- Provisioning Summary: $0 ----------"
    for script in "${PROVISION_SCRIPTS[@]}"; do
        echo "$script: ${STATUS[$script]:-Not executed}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All provisioning scripts completed successfully."
    else
        echo "Errors occurred during provisioning:"
        for script in "${!ERRORS[@]}"; do
            echo "  $script:"
            echo "    ${ERRORS[$script]}"
        done
    fi
}

# Main execution
main() {
    echo "Starting host provisioning on $(hostname)"
    echo "Cloud Provider: ${CLOUD_PROVIDER}"
    echo "---------------------------------------------------"

    if ! ensure_correct_directory; then
        echo "Failed to ensure correct directory. Exiting."
        exit 1
    fi

    local overall_exit_code=0

    for script in "${PROVISION_SCRIPTS[@]}"; do
        # Pass cloud provider argument only to cloudproviders script
        if [[ "$script" == "provision-host-01-cloudproviders.sh" ]]; then
            if execute_script "$script" "$CLOUD_PROVIDER"; then
                echo "$script completed successfully."
            else
                echo "Error executing $script. Continuing with next script."
                overall_exit_code=1
            fi
        else
            if execute_script "$script"; then
                echo "$script completed successfully."
            else
                echo "Error executing $script. Continuing with next script."
                overall_exit_code=1
            fi
        fi
        echo "---------------------------------------------------"
    done

    print_summary

    exit $overall_exit_code
}

# Run the main function
main