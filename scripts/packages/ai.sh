#!/bin/bash
# file: scripts/packages/ai.sh

# Script to set up AI environment in the container
# This script runs the Open WebUI installation using docker exec
# the script is to be run on your host computer. It connects to the provision-host and starts the ai install.
#
# Usage:
#   ./ai.sh [deploy_ollama_incluster]
#   deploy_ollama_incluster: true (default) or false (to skip in-cluster Ollama)

DEPLOY_OLLAMA_INCLUSTER=${1:-true}

echo "Checking if setup file exists..."
if ! docker exec provision-host test -f "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"; then
    echo "Error: Setup script not found in container at /mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh"
    exit 1
fi

echo "Starting AI environment setup (deploy_ollama_incluster=$DEPLOY_OLLAMA_INCLUSTER)..."
docker exec -it provision-host bash -c "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh $DEPLOY_OLLAMA_INCLUSTER"

echo "Setup completed. Access OpenWebUI at http://openwebui.localhost or via port-forwarding."