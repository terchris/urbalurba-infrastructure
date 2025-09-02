#!/bin/bash
# file: scripts/packages/auth.sh

# Script to manage Authentication environment in the container
# This script runs Authentik installation or removal using docker exec
# the script is to be run on your host computer. It connects to the provision-host and starts the auth operation.
#
# Usage:
#   ./auth.sh                           # Install Authentik (default behavior)
#   ./auth.sh remove                    # Remove Authentik
#   ./auth.sh setup                     # Install Authentik (explicit)
#   ./auth.sh [target_host] [deploy_test_apps]  # Install with custom parameters
#   ./auth.sh remove [target_host]      # Remove with custom target
#
# Parameters:
#   operation: setup (default) or remove
#   target_host: Kubernetes context/host (default: rancher-desktop)
#   deploy_test_apps: true (default) or false (to skip test applications, only used with setup)

# Check if first parameter is an operation
if [[ "$1" == "remove" ]]; then
    OPERATION="remove"
    TARGET_HOST=${2:-"rancher-desktop"}
    DEPLOY_TEST_APPS="true"  # Not used for remove, but set for consistency
elif [[ "$1" == "setup" ]]; then
    OPERATION="setup"
    TARGET_HOST=${2:-"rancher-desktop"}
    DEPLOY_TEST_APPS=${3:-true}
else
    # Default behavior: install with provided parameters
    OPERATION="setup"
    TARGET_HOST=${1:-"rancher-desktop"}
    DEPLOY_TEST_APPS=${2:-true}
fi

# Set script paths based on operation
if [[ "$OPERATION" == "setup" ]]; then
    SCRIPT_PATH="/mnt/urbalurbadisk/provision-host/kubernetes/12-auth/not-in-use/01-setup-authentik.sh"
    SCRIPT_NAME="01-setup-authentik.sh"
else
    SCRIPT_PATH="/mnt/urbalurbadisk/provision-host/kubernetes/12-auth/not-in-use/01-remove-authentik.sh"
    SCRIPT_NAME="01-remove-authentik.sh"
fi

echo "Checking if $OPERATION script exists..."
if ! docker exec provision-host test -f "$SCRIPT_PATH"; then
    echo "Error: $OPERATION script not found in container at $SCRIPT_PATH"
    exit 1
fi

echo "Starting Authentication environment $OPERATION (target_host=$TARGET_HOST, deploy_test_apps=$DEPLOY_TEST_APPS)..."
if [[ "$OPERATION" == "setup" ]]; then
    docker exec -it provision-host bash -c "$SCRIPT_PATH $TARGET_HOST $DEPLOY_TEST_APPS"
else
    docker exec -it provision-host bash -c "$SCRIPT_PATH $TARGET_HOST"
fi

if [[ "$OPERATION" == "setup" ]]; then
    echo "Setup completed. Access Authentik at http://authentik.localhost or via port-forwarding."
else
    echo "Removal completed. Authentik has been completely removed from the cluster."
fi

