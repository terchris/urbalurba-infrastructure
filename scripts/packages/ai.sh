#!/bin/bash

# Script to set up AI environment in the container
# This script runs the Open WebUI installation using docker exec

echo "Checking if setup file exists..."
if ! docker exec provision-host test -f "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"; then
    echo "Error: Setup script not found in container at /mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"
    exit 1
fi

echo "Starting AI environment setup..."
docker exec -it provision-host bash -c "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh && bash"
