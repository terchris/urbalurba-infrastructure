#!/bin/bash
# filename: kubeconf-copy2local
# Script to copy the kubeconfig file from the multipass provision-host VM
# to the local topsecret/kubernetes folder and then to the .kube folder, and set the KUBECONFIG environment variable

# Variables
VM_NAME="provision-host"
REMOTE_FILE="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
TOPSECRET_DIR="kubernetes"
TOPSECRET_FILE="$TOPSECRET_DIR/kubeconf-all"
LOCAL_DIR="$HOME/.kube"
LOCAL_FILE="$LOCAL_DIR/config"
ERROR=0
STATUS=()

# Function to check the success of the last command
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        ERROR=1
    else
        STATUS+=("$1: OK")
    fi
}

# Check if the script is run from the topsecret folder
if [ "$(basename $PWD)" != "topsecret" ]; then
    echo "Error: Script must be run from the topsecret folder."
    exit 1
fi

# Check if the VM is running
echo "Checking if the VM $VM_NAME is running..."
MULTIPASS_LIST=$(multipass list)
if echo "$MULTIPASS_LIST" | grep -q "$VM_NAME"; then
    STATUS+=("Multipass VM check: OK")
else
    echo "Error: VM with name $VM_NAME is not running."
    STATUS+=("Multipass VM check: Fail")
    ERROR=1
fi

# Create topsecret/kubernetes directory if it does not exist
if [ $ERROR -eq 0 ]; then
    if [ ! -d "$TOPSECRET_DIR" ]; then
        echo "Creating topsecret directory $TOPSECRET_DIR..."
        mkdir -p "$TOPSECRET_DIR"
        check_command_success "Create topsecret directory $TOPSECRET_DIR"
    else
        STATUS+=("Topsecret directory $TOPSECRET_DIR existence: OK")
    fi
fi

# Copy the kubeconfig file from the VM to the topsecret/kubernetes directory
if [ $ERROR -eq 0 ]; then
    echo "Copying kubeconfig file from VM to topsecret/kubernetes directory..."
    multipass copy-files $VM_NAME:$REMOTE_FILE $TOPSECRET_FILE
    check_command_success "Copy kubeconfig file from VM to topsecret/kubernetes directory"
fi

# Create local .kube directory if it does not exist
if [ $ERROR -eq 0 ]; then
    if [ ! -d "$LOCAL_DIR" ]; then
        echo "Creating local .kube directory $LOCAL_DIR..."
        mkdir -p "$LOCAL_DIR"
        check_command_success "Create local .kube directory $LOCAL_DIR"
    else
        STATUS+=("Local .kube directory $LOCAL_DIR existence: OK")
    fi
fi

# Copy the kubeconfig file from the topsecret/kubernetes directory to the .kube directory
if [ $ERROR -eq 0 ]; then
    echo "Copying kubeconfig file from topsecret/kubernetes directory to .kube directory..."
    cp $TOPSECRET_FILE $LOCAL_FILE
    check_command_success "Copy kubeconfig file from topsecret/kubernetes directory to .kube directory"
fi

# Set the KUBECONFIG environment variable to point to the standard config file
if [ $ERROR -eq 0 ]; then
    echo "Setting KUBECONFIG environment variable..."
    export KUBECONFIG=$LOCAL_FILE
    STATUS+=("Set KUBECONFIG environment variable: OK")
fi

echo "------ Summary of kubeconf-copy statuses: ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo "---------------- E R R O R --------------------"
    echo "Check the error messages above"
else
    echo "--------------- All OK ------------------------"
fi

exit $ERROR