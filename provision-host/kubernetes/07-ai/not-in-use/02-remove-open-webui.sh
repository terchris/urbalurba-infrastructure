#!/bin/bash
# filename: provision-host/kubernetes/07-ai/not-in-use/02-remove-open-webui.sh
# description: Remove OpenWebUI and its dependencies from the cluster
#
# This script removes:
# - OpenWebUI Helm chart and StatefulSet
# - Apache Tika document processing service
# - OpenWebUI database and user from shared PostgreSQL
# - Related ingress configurations
#
# Usage: ./02-remove-open-webui.sh [target-host]
# Example: ./02-remove-open-webui.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
TARGET_HOST=${1:-"rancher-desktop"}
AI_NAMESPACE="ai"

echo "========================================="
echo "OpenWebUI Removal"
echo "Target: $TARGET_HOST"
echo "Namespace: $AI_NAMESPACE"
echo "========================================="
echo ""

# Step 1: Remove OpenWebUI Helm chart
echo "📦 Step 1/4: Removing OpenWebUI Helm chart..."
echo "----------------------------------------"
if helm list -n $AI_NAMESPACE | grep -q "^open-webui"; then
    echo "🔄 Uninstalling OpenWebUI Helm chart..."
    helm uninstall open-webui --namespace $AI_NAMESPACE
    if [ $? -eq 0 ]; then
        echo "✅ OpenWebUI Helm chart removed successfully"
    else
        echo "❌ Failed to remove OpenWebUI Helm chart"
        exit 1
    fi
else
    echo "ℹ️  OpenWebUI Helm chart not found, skipping..."
fi

# Step 2: Remove Tika service
echo ""
echo "📦 Step 2/4: Removing Apache Tika service..."
echo "----------------------------------------"
if helm list -n $AI_NAMESPACE | grep -q "^tika"; then
    echo "🔄 Uninstalling Tika Helm chart..."
    helm uninstall tika --namespace $AI_NAMESPACE
    if [ $? -eq 0 ]; then
        echo "✅ Tika service removed successfully"
    else
        echo "⚠️  Warning: Failed to remove Tika service"
    fi
else
    echo "ℹ️  Tika Helm chart not found, skipping..."
fi

# Step 3: Remove any remaining OpenWebUI resources
echo ""
echo "📦 Step 3/4: Cleaning up remaining resources..."
echo "----------------------------------------"

# Remove ingress routes
echo "🔄 Removing OpenWebUI ingress routes..."
kubectl delete ingressroute openwebui-ingressroute -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  OpenWebUI ingress route not found"

# Remove any remaining services
echo "🔄 Removing OpenWebUI services..."
kubectl delete svc open-webui -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  OpenWebUI service not found"

# Remove any remaining StatefulSets
echo "🔄 Removing OpenWebUI StatefulSets..."
kubectl delete statefulset open-webui -n $AI_NAMESPACE 2>/dev/null || echo "ℹ️  OpenWebUI StatefulSet not found"

# Remove PVCs (persistent volume claims)
echo "🔄 Removing OpenWebUI PVCs..."
kubectl delete pvc -n $AI_NAMESPACE -l app=open-webui 2>/dev/null || echo "ℹ️  OpenWebUI PVCs not found"

# Step 4: Remove OpenWebUI database from shared PostgreSQL
echo ""
echo "📦 Step 4/4: Removing OpenWebUI database..."
echo "----------------------------------------"

echo "🔄 Deleting OpenWebUI database and user from shared PostgreSQL..."

# Get PostgreSQL admin password
PGPASSWORD=$(kubectl get secret urbalurba-secrets -n default -o jsonpath="{.data.PGPASSWORD}" 2>/dev/null | base64 --decode 2>/dev/null)

if [ -n "$PGPASSWORD" ]; then
    # Drop database and user
    kubectl exec -n default postgresql-0 -- env PGPASSWORD="$PGPASSWORD" psql -U postgres -c "DROP DATABASE IF EXISTS openwebui;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ OpenWebUI database dropped successfully"
    else
        echo "⚠️  Warning: Could not drop OpenWebUI database"
    fi

    kubectl exec -n default postgresql-0 -- env PGPASSWORD="$PGPASSWORD" psql -U postgres -c "DROP USER IF EXISTS openwebui;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ OpenWebUI user dropped successfully"
    else
        echo "⚠️  Warning: Could not drop OpenWebUI user"
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
echo "========================================="
echo "✅ OpenWebUI Removal Completed"
echo "========================================="
echo ""
echo "📌 What was removed:"
echo "• OpenWebUI Helm chart and StatefulSet"
echo "• Apache Tika document processing service"
echo "• OpenWebUI database and user from PostgreSQL"
echo "• Related ingress routes and services"
echo "• Persistent Volume Claims"
echo ""
echo "📌 What remains:"
echo "• ai namespace (may contain other services)"
echo "• Shared PostgreSQL (used by other services)"
echo ""

exit 0