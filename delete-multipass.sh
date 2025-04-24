#!/bin/bash
# filename: delete-multipass.sh
# description: Deletes all VMs and associated directories

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
PROVISION_HOST_DIR="$HOME/multipass/provision-host"
MICROK8S_HOST_DIR="$HOME/multipass/multipass-microk8s"

# Function to delete a VM
delete_vm() {
    local vm_name=$1
    if multipass list | grep -q "$vm_name"; then
        echo "Deleting VM: $vm_name"
        multipass delete "$vm_name"
    else
        echo "VM $vm_name does not exist."
    fi
}

# Confirm deletion
read -p "Are you sure you want to delete all VMs and their associated directories? (yes/no): " confirmation

if [ "$confirmation" = "yes" ]; then
    # Delete VMs
    delete_vm "provision-host"
    delete_vm "multipass-microk8s"

    # Purge deleted VMs
    echo "Purging deleted VMs"
    multipass purge

    # Delete host directories
    if [ -d "$PROVISION_HOST_DIR" ]; then
        echo "Deleting host directory: $PROVISION_HOST_DIR"
        rm -rf "$PROVISION_HOST_DIR"
    else
        echo "Host directory $PROVISION_HOST_DIR does not exist."
    fi

    if [ -d "$MICROK8S_HOST_DIR" ]; then
        echo "Deleting host directory: $MICROK8S_HOST_DIR"
        rm -rf "$MICROK8S_HOST_DIR"
    else
        echo "Host directory $MICROK8S_HOST_DIR does not exist."
    fi

    echo "All specified VMs and directories have been deleted."
    echo " Now purging them"
    multipass purge
    echo " now ---- REMEMBER ---- that you must delete the hosts from tailscale network as well"
    
else
    echo "Deletion process aborted."
fi
