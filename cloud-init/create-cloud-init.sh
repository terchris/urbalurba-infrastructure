#!/bin/bash
# filename: create-cloud-init.sh
# description: Script that creates a cloud-init file for a specific template in the cloud-init directory
# The script takes two parameters: hostname and template name
# The template filename should end with -cloud-init-template.yml
# The script reads the template file and replaces the placeholders with the actual values
# Then creates the cloud-init file with the -template removed from the filename
# The script also reads the kubernetes secrets file to get the secrets needed for the cloud-init file
# Existing cloud-init files will not be overwritten, so you must delete them before running this script
# The script must be run in the cloud-init directory
# usage: ./create-cloud-init.sh <hostname> <template-name>
# example: ./create-cloud-init.sh provision-host provision

set -eo pipefail

# Source centralized path library for backwards-compatible path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../provision-host/uis/lib/paths.sh" ]]; then
    source "$SCRIPT_DIR/../provision-host/uis/lib/paths.sh"
    # Use backwards-compatible path resolution
    KUBERNETES_SECRETS_PATH=$(get_kubernetes_secrets_path)
    KUBERNETES_SECRETS_FILE="$KUBERNETES_SECRETS_PATH/kubernetes-secrets.yml"
    SSH_KEY_PATH=$(get_ssh_key_path)
    SSH_PUBLIC_KEY_FILE="$SSH_KEY_PATH/id_rsa_ansible.pub"
else
    # Fallback to old hardcoded paths if paths.sh not available
    KUBERNETES_SECRETS_FILE="../topsecret/kubernetes/kubernetes-secrets.yml"
    SSH_PUBLIC_KEY_FILE="../secrets/id_rsa_ansible.pub"
fi

# Function to check if a file exists
check_file_exists() {
    if [[ ! -f "$1" ]]; then
        echo "Error: File $1 not found." >&2
        exit 1
    fi
}

# Function to read SSH public key
read_ssh_public_key() {
    check_file_exists "$SSH_PUBLIC_KEY_FILE"
    SSH_PUBLIC_KEY=$(cat "$SSH_PUBLIC_KEY_FILE")
}

# Function to extract a variable from KUBERNETES_SECRETS_FILE
extract_kubernetes_secret() {
    local secret_name="$1"
    local secret_value

    check_file_exists "$KUBERNETES_SECRETS_FILE"
    secret_value=$(grep "${secret_name}:" "$KUBERNETES_SECRETS_FILE" | awk '{print $2}')
    
    if [[ -z "$secret_value" ]]; then
        echo "Error: ${secret_name} not found in $KUBERNETES_SECRETS_FILE" >&2
        exit 1
    fi
    
    echo "$secret_value"
}

# Arrays to store variable names and values
variable_names=()
variable_values=()

# Function to add a variable
add_variable() {
    variable_names+=("$1")
    variable_values+=("$2")
}

# Function to initialize all variables
initialize_variables() {
    local hostname="$1"
    local template_file="$2"
    local cloud_init_file="${template_file/-template/}"
    
    add_variable "URB_CREATION_DATE" "$(date)"
    add_variable "URB_HOSTNAME_VARIABLE" "$hostname"
    add_variable "URB_TIMEZONE_VARIABLE" "Europe/Oslo"
    add_variable "URB_SSH_AUTHORIZED_KEY_VARIABLE" "$SSH_PUBLIC_KEY"
    add_variable "URB_CLOUD_INIT_FILE" "$cloud_init_file"
    add_variable "URB_TEMPLATE_FILE" "$template_file"

    # Add Kubernetes secrets
    add_variable "URB_TAILSCALE_SECRET_VARIABLE" "$(extract_kubernetes_secret "TAILSCALE_SECRET")"
    
    add_variable "URB_WIFI_SSID_VARIABLE" "$(extract_kubernetes_secret "WIFI_SSID")"
    add_variable "URB_WIFI_PASSWORD_VARIABLE" "$(extract_kubernetes_secret "WIFI_PASSWORD")"
    add_variable "URB_TEC_PASSWORD_VARIABLE" "$(extract_kubernetes_secret "UBUNTU_VM_USER_PASSWORD")"
    add_variable "URB_TEC_USER_VARIABLE" "$(extract_kubernetes_secret "UBUNTU_VM_USER")"
    # Add more Kubernetes secrets here as needed, e.g.:
    # add_variable "URB_ANOTHER_SECRET_VARIABLE" "$(extract_kubernetes_secret "ANOTHER_SECRET_NAME")"
}

# Function to create a cloud-init file from a template
create_cloud_init_file() {
    local template_file="$1"
    local cloud_init_file="${template_file/-template/}"
    
    if [[ -f "$cloud_init_file" ]]; then
        echo "Error: $cloud_init_file already exists. Please delete it before running this script." >&2
        exit 1
    fi

    # Create the new file using the template
    cp "$template_file" "$cloud_init_file"

    # Replace placeholders in the new file
    local i
    for i in "${!variable_names[@]}"; do
        sed -i '' "s|${variable_names[$i]}|${variable_values[$i]}|g" "$cloud_init_file"
    done

    echo "Successfully created $cloud_init_file"
}

# Main execution
main() {
    # Check if both hostname and template name are provided
    if [ $# -ne 2 ]; then
        echo "Error: Incorrect number of arguments. Usage: $0 <hostname> <template-name>" >&2
        echo "Example: $0 provision-host provision" >&2
        exit 1
    fi

    local hostname="$1"
    local template_name="$2"
    local template_file="${template_name}-cloud-init-template.yml"

    # Check if we're in the correct directory
    if [[ ! $(pwd) =~ /cloud-init$ ]]; then
        echo "Error: This script must be run from the cloud-init directory." >&2
        exit 1
    fi

    # Check if the template file exists
    check_file_exists "$template_file"

    read_ssh_public_key
    initialize_variables "$hostname" "$template_file"
    create_cloud_init_file "$template_file"
}

main "$@"