#!/bin/bash
# filename: provision-host-vm-create.sh
# description: Create the provision-host VM in multipass, set up initial environment, then call provision-host-provision.sh on the VM to install software

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
VM_NAME="provision-host"
MULTIPASS_DIR="$HOME/multipass"
VM_HOST_DIR="$MULTIPASS_DIR/$VM_NAME"
CLOUD_INIT_FILE="../cloud-init/provision-cloud-init.yml"
STATUS=()
DISK_SIZE="20G"
ERROR=0

# Function to check the success of the last command
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        ERROR=1
    else
        STATUS+=("$1: OK")
    fi
}




# Check if the script is running in the provision-host folder
CURRENT_DIR=${PWD##*/}
if [ "$CURRENT_DIR" != "provision-host" ]; then
    echo "This script must be run in the provision-host directory."
    exit 1
fi

# Check if the VM is already running
if multipass list | grep -q "$VM_NAME"; then
    echo "Error: VM with name $VM_NAME is already running."
    exit 1
fi

# Check if the host directory already exists
if [ -d "$VM_HOST_DIR" ]; then
    echo "Error: The directory $VM_HOST_DIR already exists. Please delete or move it before running this script."
    exit 1
fi

# Check if the cloud-init file exists
if [ ! -f "$CLOUD_INIT_FILE" ]; then
    echo "Error: Cloud-init file $CLOUD_INIT_FILE does not exist."
    exit 1
fi

echo "Create VM: $VM_NAME"
multipass launch --name $VM_NAME --disk $DISK_SIZE --cloud-init $CLOUD_INIT_FILE 
check_command_success "VM creation"

echo "Creating host directory: $VM_HOST_DIR"
mkdir -p $VM_HOST_DIR
check_command_success "Host directory creation"

echo "Mounting host directory: $VM_HOST_DIR to $VM_NAME:/mnt/urbalurbadisk"
if ! multipass mount $VM_HOST_DIR $VM_NAME:/mnt/urbalurbadisk; then
    echo "Error: Failed to mount the host directory. This is a critical error."
    echo "Possible reasons for failure:"
    echo "1. The VM might not be fully initialized yet."
    echo "2. There might be network issues."
    echo "3. The multipass mount command might be failing due to permissions or other system-level issues."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Wait a few minutes and try running the script again."
    echo "2. Check your network connection."
    echo "3. Try manually mounting with 'multipass mount $VM_HOST_DIR $VM_NAME:/mnt/urbalurbadisk' to see more detailed error messages."
    echo "4. Check the Multipass logs for more information."
    echo ""
    echo "Cleaning up: Deleting the VM since we couldn't set it up properly."
    multipass delete $VM_NAME
    multipass purge
    exit 1
fi
check_command_success "Mounting host directory"

multipass info $VM_NAME
check_command_success "Get VM info"

# Copy ansible secret key to VM
SSH_KEY_FILE=""
if [ -f "../.uis.secrets/ssh/id_rsa_ansible" ]; then
    SSH_KEY_FILE="../.uis.secrets/ssh/id_rsa_ansible"
fi

if [ -n "$SSH_KEY_FILE" ]; then
    echo "Now copying ansible secret key to /mnt/urbalurbadisk/.uis.secrets/ssh/id_rsa_ansible"
    multipass exec $VM_NAME -- sudo mkdir -p /mnt/urbalurbadisk/.uis.secrets/ssh
    multipass transfer "$SSH_KEY_FILE" $VM_NAME:/mnt/urbalurbadisk/.uis.secrets/ssh/id_rsa_ansible
    check_command_success "Transferring ansible secret key"
else
    echo "Warning: ansible secret key does not exist. Skipping transfer."
    echo "Looked for: ../.uis.secrets/ssh/id_rsa_ansible"
    echo "Run './uis' first to generate SSH keys."
    STATUS+=("Transferring ansible secret key: Skipped")
    ERROR=1
fi

# set up ssh config so that we can just use ssh $VM_NAME and stop using multipass exec $VM_NAME -- bash
echo "Executing provision-host-sshconf.sh"
./provision-host-sshconf.sh "$VM_NAME" "ansible"
check_command_success "Executing provision-host-sshconf.sh"



# Function to create directory and copy files using SSH as ansible user
create_and_copy() {
    local src_dir=$1
    local dest_dir=$2
    local description=$3

    if [ -d "$src_dir" ]; then
        echo "Copying $description to $dest_dir on VM: $VM_NAME"
        ssh $VM_NAME "mkdir -p $dest_dir"
        scp -r $src_dir/* $VM_NAME:$dest_dir
        check_command_success "Transferring $description"
    else
        echo "Warning: $src_dir does not exist. Skipping transfer."
        STATUS+=("Transferring $description: Skipped")
        ERROR=1
    fi
}

# Copy necessary directories
create_and_copy "../ansible" "/mnt/urbalurbadisk/ansible" "ansible directory"
create_and_copy "../manifests" "/mnt/urbalurbadisk/manifests" "manifests folder"
create_and_copy "../hosts" "/mnt/urbalurbadisk/hosts" "hosts folder"
create_and_copy "../cloud-init" "/mnt/urbalurbadisk/cloud-init" "cloud-init folder"
create_and_copy "../networking" "/mnt/urbalurbadisk/networking" "networking folder"
create_and_copy "../provision-host" "/mnt/urbalurbadisk/provision-host" "provision-host folder"

# Copy files to VM
echo "Copy files to VM"
rsync -av --delete ../provision-host/ $VM_NAME:/mnt/urbalurbadisk/provision-host/
rsync -av --delete ../ansible/ $VM_NAME:/mnt/urbalurbadisk/ansible/
rsync -av --delete ../kubernetes/ $VM_NAME:/mnt/urbalurbadisk/kubernetes/
rsync -av --delete ../manifests/ $VM_NAME:/mnt/urbalurbadisk/manifests/
# Copy secrets - prefer new path, fall back to legacy
if [ -d "../.uis.secrets" ]; then
    rsync -av --delete ../.uis.secrets/ $VM_NAME:/mnt/urbalurbadisk/.uis.secrets/
fi
if [ -d "../topsecret" ]; then
    rsync -av --delete ../topsecret/ $VM_NAME:/mnt/urbalurbadisk/topsecret/
fi
check_command_success "Copy files to VM"

# Execute provision-host-provision.sh on the VM
echo "Executing provision-host-provision.sh on the VM"
ssh $VM_NAME "bash /mnt/urbalurbadisk/provision-host/provision-host-provision.sh"
check_command_success "Executing provision-host-provision.sh"

# Test SSH login and execute whoami
echo "Testing SSH login to the VM: $VM_NAME"
if ssh $VM_NAME whoami; then
    echo "SSH login test successful."
    STATUS+=("SSH test: OK")
else
    echo "Error: SSH login test failed."
    STATUS+=("SSH test: Fail")
    ERROR=1
fi


# Update the summary section
echo "------ Summary of installation status for: $0  ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo "---------------- E R R O R --------------------"
    echo "Check the status lines above"
else
    echo "--------------- All OK ------------------------"
    echo "Login to the VM: $VM_NAME from your host:"
    echo "ssh $VM_NAME"
    echo
    echo "Shared folders:"
    echo "In the VM $VM_NAME there is a folder /mnt/urbalurbadisk/ansible" 
    echo "The same folder is mapped to your host here: $VM_HOST_DIR"
    echo
fi

exit $ERROR