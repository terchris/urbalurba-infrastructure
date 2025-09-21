#!/bin/bash
# filename: provision-host/kubernetes/07-ai/not-in-use/01-remove-litellm-openwebui.sh
# description: Complete removal of AI infrastructure (LiteLLM + OpenWebUI)
#
# This script removes both LiteLLM and OpenWebUI in the correct order:
# 1. Remove OpenWebUI first (depends on LiteLLM)
# 2. Remove LiteLLM proxy second
# 3. Clean up databases from shared PostgreSQL
#
# Usage: ./01-remove-litellm-openwebui.sh [target-host]
# Example: ./01-remove-litellm-openwebui.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOST=${1:-"rancher-desktop"}

echo "========================================="
echo "AI Infrastructure Complete Removal"
echo "Removing: OpenWebUI + LiteLLM + Databases"
echo "Target: $TARGET_HOST"
echo "========================================="
echo ""

# Step 1: Remove OpenWebUI first
echo "📦 Step 1/2: Removing OpenWebUI..."
echo "----------------------------------------"
if [ -f "$SCRIPT_DIR/02-remove-open-webui.sh" ]; then
    bash "$SCRIPT_DIR/02-remove-open-webui.sh" "$TARGET_HOST"
    OPENWEBUI_EXIT_CODE=$?

    if [ $OPENWEBUI_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "⚠️  Warning: OpenWebUI removal failed with exit code $OPENWEBUI_EXIT_CODE"
        echo "Continuing with LiteLLM removal anyway..."
    else
        echo ""
        echo "✅ OpenWebUI removal completed"
    fi
else
    echo "❌ Error: OpenWebUI removal script not found at $SCRIPT_DIR/02-remove-open-webui.sh"
    echo "Continuing with LiteLLM removal..."
fi

echo ""
echo "📦 Step 2/2: Removing LiteLLM proxy..."
echo "----------------------------------------"

# Step 2: Remove LiteLLM
if [ -f "$SCRIPT_DIR/03-remove-litellm.sh" ]; then
    bash "$SCRIPT_DIR/03-remove-litellm.sh" "$TARGET_HOST"
    LITELLM_EXIT_CODE=$?

    if [ $LITELLM_EXIT_CODE -ne 0 ]; then
        echo ""
        echo "❌ Error: LiteLLM removal failed with exit code $LITELLM_EXIT_CODE"
        exit $LITELLM_EXIT_CODE
    fi

    echo ""
    echo "✅ LiteLLM removal completed"
else
    echo "❌ Error: LiteLLM removal script not found at $SCRIPT_DIR/03-remove-litellm.sh"
    exit 1
fi

echo ""
echo "========================================="
echo "🎉 Complete AI Infrastructure Removed!"
echo "========================================="
echo ""
echo "📌 What was removed:"
echo "• OpenWebUI (frontend and StatefulSet)"
echo "• LiteLLM (proxy deployment)"
echo "• OpenWebUI database and user"
echo "• LiteLLM database and user"
echo "• Tika service (document processing)"
echo ""
echo "📌 What remains:"
echo "• ai namespace (kept for future use)"
echo "• Shared PostgreSQL (used by other services)"
echo "• urbalurba-secrets (may contain other service keys)"
echo "• LiteLLM ConfigMap (managed by kubernetes-secrets.yml)"
echo ""
echo "🔧 Verification Commands:"
echo "• Check remaining pods: kubectl get pods -n ai"
echo "• Check remaining services: kubectl get svc -n ai"
echo "• Check databases: kubectl exec -n default postgresql-0 -- psql -U postgres -c '\\l'"
echo ""
echo "========================================="

exit 0