#!/bin/bash
# file: scripts/packages/ai.sh

# Script to set up AI environment in the container
# This script runs the Open WebUI installation using docker exec
# the script is to be run on your host computer. It connects to the provision-host and starts the ai install.

echo "Checking if setup file exists..."
if ! docker exec provision-host test -f "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"; then
    echo "Error: Setup script not found in container at /mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"
    exit 1
fi

echo "Starting AI environment setup..."
docker exec -it provision-host bash -c "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"

echo "Setup completed. Access OpenWebUI at http://openwebui.localhost or via port-forwarding."