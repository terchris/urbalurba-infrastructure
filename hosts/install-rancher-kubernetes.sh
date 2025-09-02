#!/bin/bash
# filename: hosts/install-rancher-kubernetes.sh
# description: Applies Kubernetes secrets to the Rancher Desktop Kubernetes cluster
# Since Rancher Desktop already provides a Kubernetes cluster, we only need to apply secrets.

set -e  # Exit immediately if a command exits with a non-zero status.

# Variables
STATUS=()
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

# Function to run a script from a specific directory
run_script_from_directory() {
    local directory=$1
    shift
    local script=$1
    shift
    local args=("$@")

    echo "- Script: $0 -----------------> Running $script ${args[*]} in directory: $directory"
    if [ ! -d "$directory" ]; then
        echo "Error: Directory $directory does not exist."
        ERROR=1
        return
    fi
    if [ ! -f "$directory/$script" ]; then
        echo "Error: Script $script does not exist in $directory."
        ERROR=1
        return
    fi
    (cd "$directory" && ./$script "${args[@]}")
    check_command_success "$script in $directory"
}

# Function to run a script but allow it to fail without causing the entire script to exit
run_script_optional() {
    local directory=$1
    shift
    local script=$1
    shift
    local args=("$@")

    echo "- Script: $0 -----------------> Running optional script $script ${args[*]} in directory: $directory"
    if [ ! -d "$directory" ]; then
        echo "Warning: Directory $directory does not exist. Skipping optional script."
        STATUS+=("$script in $directory: Skipped (directory not found)")
        return
    fi
    if [ ! -f "$directory/$script" ]; then
        echo "Warning: Script $script does not exist in $directory. Skipping optional script."
        STATUS+=("$script in $directory: Skipped (script not found)")
        return
    fi
    
    # Run the script and capture its exit code
    (cd "$directory" && ./$script "${args[@]}")
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "Warning: Optional script $script exited with code $exit_code. Continuing anyway."
        STATUS+=("$script in $directory: Skipped (exited with code $exit_code)")
    else
        STATUS+=("$script in $directory: OK")
    fi
}

# Function to ensure the script is run from the root directory of the project
ensure_root_directory() {
    if [ ! -f "README.md" ]; then
        echo "Error: This script must be run from the root directory of the project."
        exit 1
    fi
}

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed. Please install kubectl first."
    echo "You can install kubectl using:"
    echo "  - Homebrew: brew install kubectl"
    echo "  - Direct download: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi

# Check if Rancher Desktop is running
if [ ! rdctl list-settings &> /dev/null ] || [ ! docker images &> /dev/null ]; then
    echo "Error: Rancher Desktop is not running. Please start Rancher Desktop first."
    exit 1
fi

# Check if kubectl is available and configured
if ! kubectl get nodes &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes. Please ensure Rancher Desktop is running and Kubernetes is ready."
    exit 1
fi

# Check if kubernetes-secrets.yml exists
if [ ! -f "../topsecret/kubernetes/kubernetes-secrets.yml" ]; then
    echo "Error: Kubernetes secrets file not found at ../topsecret/kubernetes/kubernetes-secrets.yml"
    echo "Please run: cd topsecret && ./create-kubernetes-secrets.sh new"
    exit 1
fi

echo "==========------------------> Step 1: Create VM - SKIPPED (using Rancher Desktop)"
STATUS+=("Step 1 - Create VM: Skipped (using Rancher Desktop)")

echo "==========------------------> Step 2: Register VM in ansible inventory - SKIPPED (using Rancher Desktop)"
STATUS+=("Step 2 - Register VM: Skipped (using Rancher Desktop)")

echo "==========------------------> Step 3: Install software on VM - SKIPPED (using Rancher Desktop)"
STATUS+=("Step 3 - Install software: Skipped (using Rancher Desktop)")

echo "==========------------------> Step 4: Applying secrets to the Rancher Desktop cluster"
run_script_from_directory "../topsecret" "update-kubernetes-secrets-rancher.sh" 

# Setup Kubernetes environment
echo "==========------------------> Step 4.1: Setting up Kubernetes environment"
run_script_from_directory "rancher-kubernetes" "01-setup-kubernetes-rancher.sh"

# Verify storage class setup
echo "==========------------------> Step 4.2: Verifying storage class setup"
echo "Running storage class verification inside the provision-host container..."

# Check if the container is running
if ! docker ps | grep -q provision-host; then
    echo "Error: provision-host container is not running"
    STATUS+=("Storage class verification: Failed (container not running)")
    ERROR=1
else
    # Apply the storage class alias and run verification in the container
    if docker exec provision-host bash -c "cd /mnt/urbalurbadisk/manifests && kubectl apply -f 000-storage-class-alias.yaml && cd /mnt/urbalurbadisk && /mnt/urbalurbadisk/hosts/rancher-kubernetes/02-verify-storage-class.sh"; then
        STATUS+=("Storage class verification: OK")
    else
        STATUS+=("Storage class verification: Failed")
        ERROR=1
    fi
fi

# Deploy internal DNS configuration for OAuth integration
echo "==========------------------> Step 4.3: Deploying internal DNS configuration"
echo "Setting up CoreDNS rewrite rules for *.localhost hostname resolution..."

# Check if the container is running
if ! docker ps | grep -q provision-host; then
    echo "Error: provision-host container is not running"
    STATUS+=("Internal DNS deployment: Failed (container not running)")
    ERROR=1
else
    # Deploy the internal DNS configuration in the container
    if docker exec provision-host bash -c "cd /mnt/urbalurbadisk/manifests && kubectl apply -f 005-internal-dns.yaml"; then
        echo "✅ Internal DNS configuration deployed successfully"
        echo "⏳ Waiting for CoreDNS to restart and apply changes..."
        
        # Wait for the CoreDNS patch job to complete
        if docker exec provision-host bash -c "kubectl wait --for=condition=complete job/coredns-patch-internal-dns -n kube-system --timeout=300s"; then
            echo "✅ CoreDNS internal DNS configuration applied successfully"
            STATUS+=("Internal DNS deployment: OK")
        else
            echo "⚠️ CoreDNS patch job may still be running or failed, but continuing..."
            STATUS+=("Internal DNS deployment: Partial (CoreDNS patch in progress)")
        fi
    else
        echo "❌ Failed to deploy internal DNS configuration"
        STATUS+=("Internal DNS deployment: Failed")
        ERROR=1
    fi
fi

echo "==========------------------> Step 5: Install local kubeconfig - SKIPPED (using Rancher Desktop config)"
STATUS+=("Step 5 - Install kubeconfig: Skipped (using Rancher Desktop config)")

echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo "---------------- E R R O R --------------------"
    echo "Check the status lines above"
    exit 1
else
    echo "--------------- All OK ------------------------"
    echo "Kubernetes secrets have been successfully applied to Rancher Desktop."
fi

exit $ERROR