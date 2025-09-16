#!/bin/bash
# filename: provision-host/kubernetes/07-ai/not-in-use/01-setup-litellm-openwebui.sh
# description: Orchestration script for complete AI infrastructure setup
#
# This script coordinates the deployment of LiteLLM and OpenWebUI in the correct order:
# 1. Deploy LiteLLM proxy first (using 03-setup-litellm.sh)
# 2. Deploy OpenWebUI configured for LiteLLM integration (using 02-setup-open-webui.sh)
#
# Architecture: OpenWebUI → LiteLLM → LLM Providers
#
# Usage: ./01-setup-litellm-openwebui.sh [target-host]
# Example: ./01-setup-litellm-openwebui.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOST=${1:-"rancher-desktop"}

echo "========================================="
echo "AI Infrastructure Setup Orchestration"
echo "Architecture: OpenWebUI → LiteLLM → LLM Providers"
echo "Target: $TARGET_HOST"
echo "========================================="
echo ""

# Step 1: Deploy LiteLLM first
echo "📦 Step 1/2: Deploying LiteLLM proxy..."
echo "----------------------------------------"
if [ -f "$SCRIPT_DIR/03-setup-litellm.sh" ]; then
    bash "$SCRIPT_DIR/03-setup-litellm.sh" "$TARGET_HOST"
    LITELLM_EXIT_CODE=$?

    if [ $LITELLM_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Error: LiteLLM deployment failed with exit code $LITELLM_EXIT_CODE"
        echo "Cannot proceed with OpenWebUI deployment without LiteLLM running."
        echo ""
        echo "Troubleshooting:"
        echo "• Check LiteLLM pods: kubectl get pods -n ai | grep litellm"
        echo "• Check LiteLLM logs: kubectl logs -f deployment/litellm -n ai"
        echo "• Verify secrets exist: kubectl get secret urbalurba-secrets -n ai"
        exit $LITELLM_EXIT_CODE
    fi

    echo ""
    echo "✅ LiteLLM deployment completed successfully"
else
    echo "❌ Error: LiteLLM setup script not found at $SCRIPT_DIR/03-setup-litellm.sh"
    exit 1
fi

echo ""
echo "📦 Step 2/2: Deploying OpenWebUI with LiteLLM integration..."
echo "----------------------------------------"

# Step 2: Deploy OpenWebUI configured for LiteLLM
# Note: The 02-setup-open-webui.sh needs to be updated to use our new OpenWebUI config
# that integrates with LiteLLM instead of direct Ollama connection
if [ -f "$SCRIPT_DIR/02-setup-open-webui.sh" ]; then
    # Call OpenWebUI setup with deploy_ollama_incluster=false since we're using LiteLLM
    bash "$SCRIPT_DIR/02-setup-open-webui.sh" "$TARGET_HOST" false
    OPENWEBUI_EXIT_CODE=$?

    if [ $OPENWEBUI_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Error: OpenWebUI deployment failed with exit code $OPENWEBUI_EXIT_CODE"
        echo ""
        echo "Troubleshooting:"
        echo "• Check OpenWebUI pods: kubectl get pods -n ai | grep open-webui"
        echo "• Check OpenWebUI logs: kubectl logs -f statefulset/open-webui -n ai"
        echo "• Verify LiteLLM is running: kubectl get pods -n ai | grep litellm"
        exit $OPENWEBUI_EXIT_CODE
    fi

    echo ""
    echo "✅ OpenWebUI deployment completed successfully"
else
    echo "❌ Error: OpenWebUI setup script not found at $SCRIPT_DIR/02-setup-open-webui.sh"
    exit 1
fi

echo ""
echo "========================================="
echo "🎉 Complete AI Infrastructure Ready!"
echo "========================================="
echo ""
echo "📌 Access Points:"
echo "• OpenWebUI: http://openwebui.localhost"
echo "• LiteLLM Admin: http://litellm.localhost"
echo ""
echo "🔧 OpenWebUI Configuration Required:"
echo "1. Access OpenWebUI and create admin user"
echo "2. Go to Settings → Connections"
echo "3. Configure LiteLLM connection:"
echo "   • URL: http://litellm.ai.svc.cluster.local:4000/v1"
echo "   • Auth: Bearer"
echo "   • API Key: sk-1234567890abcdef"
echo "4. Save and refresh to see models"
echo ""
echo "🤖 Available Models:"
echo "• mac-gpt-oss-balanced (Mac Ollama, Temperature: 0.7)"
echo "• mac-gpt-oss-creative (Mac Ollama, Temperature: 0.9)"
echo "• mac-gpt-oss-precise (Mac Ollama, Temperature: 0.3)"
echo "• Plus cloud models with Mac fallbacks"
echo ""
echo "🥊 Arena Mode:"
echo "Select 'Arena' from model dropdown to compare responses"
echo ""
echo "📊 Status Check Commands:"
echo "• kubectl get pods -n ai"
echo "• kubectl get svc -n ai"
echo "• kubectl logs -f deployment/litellm -n ai"
echo "• kubectl logs -f statefulset/open-webui -n ai"
echo ""
echo "========================================="

exit 0