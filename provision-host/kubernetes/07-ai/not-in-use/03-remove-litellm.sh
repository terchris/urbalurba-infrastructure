#!/bin/bash
# filename: provision-host/kubernetes/07-ai/not-in-use/03-remove-litellm.sh
# description: Remove LiteLLM proxy from the cluster
#
# This script removes:
# - LiteLLM Helm chart and deployment
# - LiteLLM database and user from shared PostgreSQL
# - LiteLLM ConfigMap and related resources
# - Related ingress configurations
#
# Usage: ./03-remove-litellm.sh [target-host]
# Example: ./03-remove-litellm.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
TARGET_HOST=${1:-"rancher-desktop"}
AI_NAMESPACE="ai"

echo "========================================="
echo "LiteLLM Removal"
echo "Target: $TARGET_HOST"
echo "Namespace: $AI_NAMESPACE"
echo "========================================="
echo ""

# Step 1: Remove LiteLLM Helm chart
echo "📦 Step 1/3: Removing LiteLLM Helm chart..."
echo "----------------------------------------"
if helm list -n $AI_NAMESPACE | grep -q "^litellm"; then
    echo "🔄 Uninstalling LiteLLM Helm chart..."
    helm uninstall litellm --namespace $AI_NAMESPACE
    if [ $? -eq 0 ]; then
        echo "✅ LiteLLM Helm chart removed successfully"
    else
        echo "❌ Failed to remove LiteLLM Helm chart"
        exit 1
    fi
else
    echo "ℹ️  LiteLLM Helm chart not found, skipping..."
fi

# Step 2: Clean up remaining LiteLLM resources
echo ""
echo "📦 Step 2/3: Cleaning up remaining resources..."
echo "----------------------------------------"

# ConfigMap is managed by kubernetes-secrets.yml - do not remove
echo "ℹ️  LiteLLM ConfigMap is managed by kubernetes-secrets.yml - preserving for next deployment"

# Remove ingress routes
echo "🔄 Removing LiteLLM ingress routes..."
kubectl delete ingressroute litellm-ingressroute -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  LiteLLM ingress route not found"

# Remove any remaining services
echo "🔄 Removing LiteLLM services..."
kubectl delete svc litellm -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  LiteLLM service not found"

# Remove any remaining deployments
echo "🔄 Removing LiteLLM deployments..."
kubectl delete deployment litellm -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  LiteLLM deployment not found"

# Remove any migration jobs
echo "🔄 Removing LiteLLM migration jobs..."
kubectl delete job -n $AI_NAMESPACE -l app.kubernetes.io/name=litellm 2>/dev/null || echo "ℹ️  LiteLLM migration jobs not found"

# Step 3: Remove LiteLLM database from shared PostgreSQL
echo ""
echo "📦 Step 3/3: Removing LiteLLM database..."
echo "----------------------------------------"

echo "🔄 Deleting LiteLLM database and user from shared PostgreSQL..."

# Get PostgreSQL admin password
PGPASSWORD=$(kubectl get secret urbalurba-secrets -n default -o jsonpath="{.data.PGPASSWORD}" 2>/dev/null | base64 --decode 2>/dev/null)

if [ -n "$PGPASSWORD" ]; then
    # Terminate active connections first
    echo "🔄 Terminating active connections to litellm database..."
    kubectl exec -n default postgresql-0 -- env PGPASSWORD="$PGPASSWORD" psql -U postgres -c "
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = 'litellm' AND pid <> pg_backend_pid();
    " 2>/dev/null || echo "ℹ️  No active connections to terminate"

    # Drop database
    kubectl exec -n default postgresql-0 -- env PGPASSWORD="$PGPASSWORD" psql -U postgres -c "DROP DATABASE IF EXISTS litellm;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ LiteLLM database dropped successfully"
    else
        echo "⚠️  Warning: Could not drop LiteLLM database"
    fi

    # Drop user
    kubectl exec -n default postgresql-0 -- env PGPASSWORD="$PGPASSWORD" psql -U postgres -c "DROP USER IF EXISTS litellm;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ LiteLLM user dropped successfully"
    else
        echo "⚠️  Warning: Could not drop LiteLLM user"
    fi
else
    echo "⚠️  Warning: Could not retrieve PostgreSQL admin password - database cleanup skipped"
fi

# Final status check
echo ""
echo "========================================="
echo "🔍 Verification"
echo "========================================="

echo "📊 Remaining pods in $AI_NAMESPACE namespace:"
kubectl get pods -n $AI_NAMESPACE

echo ""
echo "📊 Remaining services in $AI_NAMESPACE namespace:"
kubectl get svc -n $AI_NAMESPACE

echo ""
echo "📊 Remaining ConfigMaps in $AI_NAMESPACE namespace:"
kubectl get configmap -n $AI_NAMESPACE

echo ""
echo "========================================="
echo "✅ LiteLLM Removal Completed"
echo "========================================="
echo ""
echo "📌 What was removed:"
echo "• LiteLLM Helm chart and deployment"
echo "• LiteLLM database and user from PostgreSQL"
echo "• Related ingress routes and services"
echo "• Migration jobs and other related resources"
echo ""
echo "📌 What remains:"
echo "• ai namespace (may contain other services)"
echo "• Shared PostgreSQL (used by other services)"
echo "• urbalurba-secrets (may contain keys for other services)"
echo "• LiteLLM ConfigMap (managed by kubernetes-secrets.yml)"
echo ""

exit 0