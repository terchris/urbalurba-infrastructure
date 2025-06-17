#!/bin/bash
# filename: 02-remove-data-science.sh
# Complete Apache Spark Kubernetes Operator Uninstall Script
# This script removes all components for a clean start

set -e  # Exit on any error

echo "🧹 Starting complete Apache Spark Kubernetes Operator uninstall..."
echo "=================================================================="

# Step 1: Delete any running Spark applications first
echo ""
echo "1️⃣ Cleaning up any running Spark applications..."
echo "---------------------------------------------------"

# Check if there are any SparkApplications
SPARK_APPS=$(kubectl get sparkapp -n spark-operator 2>/dev/null | wc -l)
if [ $SPARK_APPS -gt 1 ]; then
    echo "Found Spark applications, deleting them..."
    kubectl delete sparkapp --all -n spark-operator --timeout=60s
    echo "✅ All Spark applications deleted"
else
    echo "✅ No Spark applications found"
fi

# Step 2: Uninstall Helm release
echo ""
echo "2️⃣ Uninstalling Helm release..."
echo "--------------------------------"

if helm list -n spark-operator | grep -q spark-kubernetes-operator; then
    echo "Found Helm release 'spark-kubernetes-operator', uninstalling..."
    helm uninstall spark-kubernetes-operator -n spark-operator --timeout=120s
    echo "✅ Helm release uninstalled"
else
    echo "✅ No Helm release found"
fi

# Step 3: Wait for pods to terminate
echo ""
echo "3️⃣ Waiting for pods to terminate..."
echo "-----------------------------------"

# Wait up to 60 seconds for pods to terminate
WAIT_COUNT=0
while kubectl get pods -n spark-operator 2>/dev/null | grep -v "NAME" | grep -q "." && [ $WAIT_COUNT -lt 12 ]; do
    echo "Waiting for pods to terminate... (${WAIT_COUNT}/12)"
    sleep 5
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

REMAINING_PODS=$(kubectl get pods -n spark-operator 2>/dev/null | grep -v "NAME" | wc -l)
if [ $REMAINING_PODS -eq 0 ]; then
    echo "✅ All pods terminated"
else
    echo "⚠️ Some pods still running, forcing deletion..."
    kubectl delete pods --all -n spark-operator --force --grace-period=0 2>/dev/null || true
fi

# Step 4: Delete Custom Resource Definitions (CRDs)
echo ""
echo "4️⃣ Deleting Custom Resource Definitions..."
echo "-------------------------------------------"

CRD_LIST=(
    "sparkapplications.spark.apache.org"
    "sparkclusters.spark.apache.org"
)

for CRD in "${CRD_LIST[@]}"; do
    if kubectl get crd "$CRD" 2>/dev/null; then
        echo "Deleting CRD: $CRD"
        kubectl delete crd "$CRD" --timeout=30s
        echo "✅ CRD $CRD deleted"
    else
        echo "✅ CRD $CRD not found"
    fi
done

# Step 5: Delete the namespace
echo ""
echo "5️⃣ Deleting spark-operator namespace..."
echo "---------------------------------------"

if kubectl get namespace spark-operator 2>/dev/null; then
    echo "Deleting namespace 'spark-operator'..."
    kubectl delete namespace spark-operator --timeout=60s
    echo "✅ Namespace deleted"
else
    echo "✅ Namespace not found"
fi

# Step 6: Clean up any remaining RBAC resources
echo ""
echo "6️⃣ Cleaning up any remaining RBAC resources..."
echo "-----------------------------------------------"

# Clean up cluster-wide resources that might have been created
CLUSTER_RESOURCES=(
    "clusterroles.rbac.authorization.k8s.io"
    "clusterrolebindings.rbac.authorization.k8s.io"
)

for RESOURCE_TYPE in "${CLUSTER_RESOURCES[@]}"; do
    RESOURCES=$(kubectl get "$RESOURCE_TYPE" -o name 2>/dev/null | grep spark || true)
    if [ -n "$RESOURCES" ]; then
        echo "Found cluster resources to clean up:"
        echo "$RESOURCES"
        echo "$RESOURCES" | xargs kubectl delete 2>/dev/null || true
    fi
done

echo "✅ RBAC cleanup completed"

# Step 7: Remove Helm repository (optional)
echo ""
echo "7️⃣ Helm repository cleanup (optional)..."
echo "-----------------------------------------"

if helm repo list | grep -q spark-kubernetes-operator; then
    read -p "Remove Helm repository 'spark-kubernetes-operator'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm repo remove spark-kubernetes-operator
        echo "✅ Helm repository removed"
    else
        echo "⏭️ Keeping Helm repository"
    fi
else
    echo "✅ Helm repository not found"
fi

# Step 8: Verification
echo ""
echo "8️⃣ Verification..."
echo "------------------"

echo "Checking for any remaining resources..."

# Check for remaining CRDs
REMAINING_CRDS=$(kubectl get crd | grep spark | wc -l)
echo "Remaining Spark CRDs: $REMAINING_CRDS"

# Check for remaining namespaces
SPARK_NS=$(kubectl get namespace | grep spark-operator | wc -l)
echo "Spark-operator namespace exists: $SPARK_NS"

# Check for Helm releases
HELM_RELEASES=$(helm list --all-namespaces | grep spark | wc -l)
echo "Remaining Spark Helm releases: $HELM_RELEASES"

echo ""
echo "=================================================================="
if [ $REMAINING_CRDS -eq 0 ] && [ $SPARK_NS -eq 0 ] && [ $HELM_RELEASES -eq 0 ]; then
    echo "🎉 SUCCESS: Apache Spark Kubernetes Operator completely removed!"
    echo "Your cluster is now clean and ready for a fresh installation."
else
    echo "⚠️ PARTIAL SUCCESS: Some resources may still remain."
    echo "You can manually check and remove any remaining resources."
fi
echo "=================================================================="

echo ""
echo "🚀 Ready for a clean installation!"
echo "To reinstall, run:"
echo "   ./02-setup-data-science.sh rancher-desktop"