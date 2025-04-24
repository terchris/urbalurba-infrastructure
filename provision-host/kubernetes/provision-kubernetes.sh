#!/bin/bash
# filename: provision-kubernetes.sh
# description: sets up containers on the microk8s cluster.
# It does this by running a series of scripts that install and configure the necessary software.
# The order of execution is important and is as follows:
# in the folder provision-host/kubernetes there are folders that starts with a number
# In each folder there are scripts that are named with a number.

# This scrpt first read the folder with the lowest number. Then all the scripts in that folder are executed.
# Then the script moves to the next folder and executes all the scripts in that folder.
# This is done until all the folders have been processed.

# example folders are 01-default-apps and 02-adm-apps
# example scripts are 04-cloud-setup-log-monitor.sh and 07-setup-elasticsearch.sh

# the script takes one parameter which is the target-host.
# If no parameter is provided, the default target-host is "multipass-microk8s"
# target-host is sent as parameter to all scripts in the folder(s).

# Example of how to run the script:
# ./provision-kubernetes.sh azure-microk8s

RUN_IN_DIR="/mnt/urbalurbadisk/provision-host/kubernetes"

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Get target-host from command line argument or use default
TARGET_HOST="${1:-multipass-microk8s}"

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

# Function to run a script
run_script() {
    local script=$1
    echo "Running $script with target-host: $TARGET_HOST..."
    bash "$script" "$TARGET_HOST"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        add_status "$script" "Failed (Exit code: $exit_code)"
        add_error "$script" "Script execution failed with exit code $exit_code"
        return 1
    else
        add_status "$script" "Success"
        return 0
    fi
}

# Function to print summary
print_summary() {
    echo "---------- Provisioning Summary: $0 ----------"
    
    # Group scripts by folder and maintain order
    declare -A folder_scripts
    folders_order=()
    for script in "${!STATUS[@]}"; do
        folder=$(dirname "$script")
        found=false
        for f in "${folders_order[@]}"; do
            if [[ "$f" == "$folder" ]]; then
                found=true
                break
            fi
        done
        if ! $found; then
            folders_order+=("$folder")
        fi
        folder_scripts["$folder"]+="${script##*/} ${STATUS[$script]}"$'\n'
    done

    # Print grouped summary
    for folder in "${folders_order[@]}"; do
        echo "${folder##*/}:"
        echo "${folder_scripts[$folder]}" | sed 's/^/  /'
        echo ""  # Add an empty line between folders
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All scripts completed successfully."
    else
        echo "Errors occurred during execution:"
        for script in "${!ERRORS[@]}"; do
            folder=$(dirname "$script")
            echo "  ${folder##*/}/${script##*/}:"
            echo "    ${ERRORS[$script]}" | sed 's/^/    /'
        done
    fi
}


# Main execution
main() {
    echo "Starting Kubernetes provisioning on $(hostname) for target-host: $TARGET_HOST"
    echo "---------------------------------------------------"

    if ! ensure_correct_directory; then
        echo "Failed to ensure correct directory. Exiting."
        exit 1
    fi

    local overall_exit_code=0

    # Get all directories starting with a number, sorted numerically
    directories=$(find . -maxdepth 1 -type d -name "[0-9]*" | sort -n)

    for dir in $directories; do
        echo "Processing directory: $dir"
        
        # Get all scripts in the directory, sorted numerically
        scripts=$(find "$dir" -maxdepth 1 -type f -name "[0-9]*.sh" | sort -n)
        
        for script in $scripts; do
            if run_script "$script"; then
                echo "$script completed successfully."
            else
                echo "Error executing $script. Continuing with next script."
                overall_exit_code=1
            fi
            echo "---------------------------------------------------"
        done
    done

    print_summary

    exit $overall_exit_code
}

# Run the main function
main