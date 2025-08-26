#!/bin/bash
# file: scripts/packages/auth.sh

# Script to set up Authentication environment in the container
# This script runs the Authentik installation using docker exec
# the script is to be run on your host computer. It connects to the provision-host and starts the auth install.
#
# Usage:
#   ./auth.sh [target_host] [deploy_test_apps]
#   target_host: Kubernetes context/host (default: rancher-desktop)
#   deploy_test_apps: true (default) or false (to skip test applications)

TARGET_HOST=${1:-"rancher-desktop"}
DEPLOY_TEST_APPS=${2:-true}

echo "Checking if setup file exists..."
if ! docker exec provision-host test -f "/mnt/urbalurbadisk/provision-host/kubernetes/12-auth/not-in-use/01-setup-authentik.sh"; then
    echo "Error: Setup script not found in container at /mnt/urbalurbadisk/provision-host/kubernetes/12-auth/not-in-use/01-setup-authentik.sh"
    exit 1
fi

echo "Starting Authentication environment setup (target_host=$TARGET_HOST, deploy_test_apps=$DEPLOY_TEST_APPS)..."
docker exec -it provision-host bash -c "/mnt/urbalurbadisk/provision-host/kubernetes/12-auth/not-in-use/01-setup-authentik.sh $TARGET_HOST $DEPLOY_TEST_APPS"

echo "Setup completed. Access Authentik at http://authentik.localhost or via port-forwarding."

