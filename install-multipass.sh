#!/bin/bash
# install-multipass.sh - install all cluster and all software.
# Must be started in the root folder of the project.

# this file is created the first time
CLOUD_INIT_FILE="cloud-init/provision-cloud-init.yml"
VM_NAME="provision-host"
CLOUD_INIT_TEMPLATE="provision"

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check the success of the last command and exit if failed
check_command_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed."
        exit 1
    fi
    echo "$1 completed successfully."
}

# Function to ensure the script is run from the root directory of the project
ensure_root_directory() {
    if [ ! -f "README.md" ]; then  # Replace "README.md" with a file that exists only in the root of your project
        echo "This script must be run from the root directory of the project."
        exit 1
    fi
}

# Function to run a script from a specific directory
run_script_from_directory() {
    local directory=$1
    shift
    local script=$1
    shift
    local args=("$@")

    echo "- Script:$0 -----------------> Running $script ${args[*]} in directory: $directory"
    cd "$directory"
    ./$script "${args[@]}"
    check_command_success "$script in $directory"
    cd - > /dev/null  # Return to the previous directory and suppress output
}

# Function to run a script on a specific host directory
run_script_on_host_directory() {
    local host_directory=$1
    local script_name=$2
    local target_host=$3
    shift 3
    local args=("$@")

    local full_script_path="/mnt/urbalurbadisk/$host_directory/$script_name"

    echo "------------------> Running $script_name ${args[*]} on provision-host for target: $target_host"
    multipass exec provision-host -- sudo bash "$full_script_path" "$target_host" "${args[@]}"
    check_command_success "$script_name on provision-host for $target_host"
}


# Function to run a script on provision-host as the ansible user
run_script_as_ansible_on_provision_host() {
    local host_directory=$1
    local script_name=$2
    local target_host=$3
    shift 3
    local args=("$@")

    local full_script_path="/mnt/urbalurbadisk/$host_directory/$script_name"

    echo "- Script: $0 -----------------> Running $script_name ${args[*]} on provision-host for target: $target_host"
    ssh ansible@provision-host "bash $full_script_path $target_host ${args[*]}"
    check_command_success "$script_name on provision-host for $target_host"
}
# Ensure the script is run from the root directory
ensure_root_directory

# Check and create secrets if they don't exist
if [ ! -f "secrets/id_rsa_ansible.pub" ] || [ ! -f "secrets/id_rsa_ansible" ]; then
    echo "==========------------------> Step 0.1: Create secrets"
    run_script_from_directory "secrets" "create-secrets.sh"
fi

# Check and create cloud-init file if it doesn't exist
if [ ! -f "$CLOUD_INIT_FILE" ]; then
    echo "==========------------------> Step 0.2: Create cloud-init file for $VM_NAME"
    run_script_from_directory "cloud-init" "create-cloud-init.sh" "$VM_NAME" "$CLOUD_INIT_TEMPLATE"
fi

# Check for existing VM disks
PROVISION_HOST_DIR="$HOME/multipass/provision-host"
MICROK8S_HOST_DIR="$HOME/multipass/multipass-microk8s"
if [ -d "$PROVISION_HOST_DIR" ] || [ -d "$MICROK8S_HOST_DIR" ]; then
    echo "Previous VM disk(s) present. Please remove them before running this script."
    exit 1
fi

echo "==========------------------> Step 1: Create multipass VM named: provision-host"
run_script_from_directory "provision-host" "provision-host-vm-create.sh"


echo "==========------------------> Step 2: Create multipass VM named: multipass-microk8s"
run_script_from_directory "hosts" "install-multipass-microk8s.sh"


echo "==========------------------> Step 3: Install local kubeconfig"
run_script_from_directory "topsecret" "kubeconf-copy2local.sh" "multipass-microk8s"


echo "----------------------> Start the installation of kubernetes systems <----------------------"

run_script_as_ansible_on_provision_host "provision-host/kubernetes" "provision-kubernetes.sh" "multipass-microk8s"



echo "xxxxxxxxxxxxx xxxxxx xxxxxx Install all steps completed successfully."
exit 1
#echo "----------------------> Start networking <----------------------"

#echo "------------------> Net 1: Set up tailscale on provision-host"
#run_script_from_directory "networking" "net1-setup-tailscale.sh" "provision-host"

#echo "------------------> Net 2: Set up tailscale on multipass-microk8s"
#run_script_from_directory "networking" "net1-setup-tailscale.sh" "multipass-microk8s"

echo "----------------------> Continue the installation of the default apps <----------------------"

echo "------------------> App E: Setup Gravitee API Management Platform"
run_script_from_directory "kubernetes/default-apps" "08-setup-gravitee.sh" "GRAVITEE_TEST" "multipass-microk8s"

echo "------------------> Store config and status files for: multipass-microk8s"
run_script_from_directory "" "cluster-status.sh" "multipass-microk8s"

echo "### Cloudflare setup (TODO: fix or move)"
echo "------------------> Net 3: Set Cloudflare tunnel and DNS for multipass-microk8s"
run_script_from_directory "networking" "net3-setup-cloudflare.sh" "CLOUDFLARE_TEST"

echo "------------------> Net 4: Deploy the tunnel and expose domains on the internet for multipass-microk8s"
run_script_from_directory "networking" "net4-deploy-cloudflare-tunnel.sh" "CLOUDFLARE_TEST" "multipass-microk8s"


echo "All steps completed successfully."