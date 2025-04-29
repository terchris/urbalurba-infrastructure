#!/bin/bash
# filename: provision-host-container-create.sh
# description: Creates and starts the provision host container

set -e

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        echo "Error occurred, cleaning up..."
        # Keep container around for debugging if KEEP_ON_ERROR is set
        if [ "${KEEP_ON_ERROR}" != "true" ]; then
            docker compose down
        else
            echo "Keeping container for debugging. Run 'docker compose down' to clean up."
        fi
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Initialize status tracking
# Use simple arrays instead of associative arrays for better compatibility
STATUS=()
ERRORS=()

# Function to add status
add_status() {
    local step=$1
    local status=$2
    STATUS+=("$step: $status")
}

# Function to add error
add_error() {
    local step=$1
    local error=$2
    ERRORS+=("$step: $error")
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        add_error "Prerequisites" "Docker not found. Please install Docker or Rancher Desktop"
        return 1
    fi
    
    # Check if docker compose is available
    if ! docker compose version >/dev/null 2>&1; then
        add_error "Prerequisites" "Docker Compose not found"
        return 1
    fi

    # Check if required directories exist
    echo "Checking required directories..."
    local workspace_root
    workspace_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    
    # Create .ssh directory if it doesn't exist
    if [ ! -d "$HOME/.ssh" ]; then
        echo "Creating .ssh directory..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        add_status "Creating .ssh directory" "OK"
    fi
    
    for dir in "$workspace_root/ansible" "$workspace_root/secrets" "$HOME/.kube" "$HOME/.ssh"; do
        echo "Checking $dir..."
        if [ ! -d "$dir" ]; then
            add_error "Prerequisites" "Required directory $dir not found"
            echo "Note: If you're missing .kube directory, make sure Rancher Desktop is running and configured"
            return 1
        fi
    done
    echo "All required directories found"

    # Check for kubernetes-secrets.yml
    if [ ! -f "$workspace_root/topsecret/kubernetes/kubernetes-secrets.yml" ]; then
        echo "Warning: kubernetes-secrets.yml not found in $workspace_root/topsecret/kubernetes/"
        echo "You should copy and edit kubernetes-secrets-template.yml to add your own secrets."
        read -p "Do you want to continue with default values? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Please copy and edit kubernetes-secrets-template.yml before continuing."
            echo "After editing the file, run './install-rancher.sh' again to continue the installation."
            return 1
        fi
        echo "Using default values from kubernetes-secrets-template.yml"
        cp "$workspace_root/topsecret/kubernetes/kubernetes-secrets-template.yml" "$workspace_root/topsecret/kubernetes/kubernetes-secrets.yml"
        add_status "Creating kubernetes-secrets.yml" "OK (using template)"
    fi

    add_status "Prerequisites" "OK"
}

# Function to create directory and copy files to container
create_and_copy() {
    local src_dir=$1
    local dest_dir=$2
    local description=$3

    if [ -d "$src_dir" ]; then
        echo "Copying $description to $dest_dir in container"
        docker exec provision-host mkdir -p "$dest_dir"
        docker cp "$src_dir/." "provision-host:$dest_dir"
        add_status "Transferring $description" "OK"
    else
        echo "Warning: $src_dir does not exist. Skipping transfer."
        add_status "Transferring $description" "Skipped"
        return 1
    fi
}

# Verify container and tools
verify_setup() {
    echo "Verifying setup..."
    echo "Testing container access..."
    if docker exec provision-host whoami; then
        echo "Container access test successful."
        add_status "Container test" "OK"
    else
        echo "Error: Container access test failed."
        add_status "Container test" "Fail"
        return 1
    fi
}

# Print summary
print_summary() {
    echo "---------- Setup Summary ----------"
    for status in "${STATUS[@]}"; do
        echo "$status"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo -e "\nSetup completed successfully!"
        echo -e "\nYou can now:"
        echo "1. Access the container with:"
        echo "   docker exec -it provision-host bash"
        echo "2. Run commands directly with:"
        echo "   docker exec provision-host <command>"
    else
        echo -e "\nErrors occurred during setup:"
        for error in "${ERRORS[@]}"; do
            echo "  $error"
        done
        return 1
    fi
}

# Main execution
main() {
    echo "Starting provision host container setup"
    echo "---------------------------------------------------"

    check_prerequisites || exit 1
    
    # Create and start container
    echo "Creating container..."
    if ! docker compose up -d --build; then
        add_error "Container creation" "Failed to create container"
        return 1
    fi
    add_status "Container creation" "OK"

    # Transfer directories to the container
    echo "Copying required directories to container..."
    create_and_copy "$workspace_root/ansible" "/mnt/urbalurbadisk/ansible" "ansible directory"
    create_and_copy "$workspace_root/manifests" "/mnt/urbalurbadisk/manifests" "manifests directory"
    create_and_copy "$workspace_root/hosts" "/mnt/urbalurbadisk/hosts" "hosts directory"
    create_and_copy "$workspace_root/cloud-init" "/mnt/urbalurbadisk/cloud-init" "cloud-init directory"
    create_and_copy "$workspace_root/networking" "/mnt/urbalurbadisk/networking" "networking directory"
    create_and_copy "$workspace_root/provision-host" "/mnt/urbalurbadisk/provision-host" "provision-host directory"
    create_and_copy "$workspace_root/secrets" "/mnt/urbalurbadisk/secrets" "secrets directory"
    create_and_copy "$workspace_root/topsecret" "/mnt/urbalurbadisk/topsecret" "topsecret directory"
    create_and_copy "$workspace_root/testdata" "/mnt/urbalurbadisk/testdata" "testdata directory"
    create_and_copy "$workspace_root/scripts" "/mnt/urbalurbadisk/scripts" "scripts directory"

    # Fix ownership
    docker exec -u root provision-host chown -R ansible:ansible /mnt/urbalurbadisk

    # Execute provision-host-provision.sh in container
    echo "Executing provision-host-provision.sh in container"
    if ! docker exec provision-host bash /mnt/urbalurbadisk/provision-host/provision-host-provision.sh "$1"; then
        add_error "Provisioning" "Failed to execute provision-host-provision.sh"
        return 1
    fi
    add_status "Provisioning" "OK"

    verify_setup || exit 1
    print_summary
}

# Run main function
main "$1" 