#!/bin/bash
# file: scripts/packages/ai.sh

# Script to set up complete AI environment with LiteLLM integration
# This script uses minimal orchestration that coordinates existing Ansible-based scripts
# Architecture: OpenWebUI → LiteLLM → LLM Providers (including Mac Ollama)
# The script is to be run on your host computer. It connects to the provision-host and starts the AI install.
#
# Usage:
#   ./ai.sh [target-host]
#   target-host: Kubernetes context/host (default: rancher-desktop)

TARGET_HOST=${1:-"rancher-desktop"}

echo "Checking if orchestration script exists..."
if ! docker exec provision-host test -f "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/01-setup-litellm-openwebui.sh"; then
    echo "Error: Orchestration script not found in container at /mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/01-setup-litellm-openwebui.sh"
    echo ""
    echo "Alternative: Use individual scripts:"
    echo "1. LiteLLM: docker exec -it provision-host bash -c \"/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/03-setup-litellm.sh $TARGET_HOST\""
    echo "2. OpenWebUI: docker exec -it provision-host bash -c \"/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/02-setup-open-webui.sh $TARGET_HOST false\""
    exit 1
fi

echo "Starting AI infrastructure setup using orchestration script..."
echo "Architecture: OpenWebUI → LiteLLM → LLM Providers"
echo ""

docker exec -it provision-host bash -c "/mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use/01-setup-litellm-openwebui.sh $TARGET_HOST"

echo ""
echo "Host script completed. Check output above for access instructions."