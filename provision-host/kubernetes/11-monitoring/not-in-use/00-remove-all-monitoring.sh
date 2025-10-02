#!/bin/bash

# Complete Monitoring Stack Removal Script
# Removes all monitoring components deployed via Helm

set -e

TARGET_HOST=${1:-rancher-desktop}

echo "=========================================="
echo "Complete Monitoring Stack Removal"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""
echo "⚠️  This will remove monitoring components:"
echo "   - OTEL Collector (Helm)"
echo "   - Grafana (Helm)"
echo "   - Loki (Helm)"
echo "   - Tempo (Helm)"
echo "   - Prometheus (Helm)"
echo "   - Pods, services, deployments, PVCs"
echo "   (Preserves namespace, secrets, configmaps)"
echo ""

# Function to remove Helm release safely
remove_helm_release() {
    local release_name=$1
    local namespace=$2

    if helm list -n "$namespace" | grep -q "^$release_name"; then
        echo "🗑️  Removing Helm release: $release_name"
        helm uninstall "$release_name" -n "$namespace" --wait
        echo "✅ $release_name removed"
    else
        echo "ℹ️  $release_name not found, skipping"
    fi
}

# Remove all Helm releases in monitoring namespace
echo "🔄 Removing Helm releases..."
remove_helm_release "otel-collector" "monitoring"
remove_helm_release "grafana" "monitoring"
remove_helm_release "loki" "monitoring"
remove_helm_release "tempo" "monitoring"
remove_helm_release "prometheus" "monitoring"

# Clean up test pods that might be hanging
echo "🔄 Cleaning up test pods..."
kubectl delete pods -n monitoring -l app.kubernetes.io/name=curl-test --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete pods -n monitoring --field-selector=status.phase=Failed --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
kubectl delete pods -n monitoring --field-selector=status.phase=Error --ignore-not-found=true --force --grace-period=0 2>/dev/null || true

# Wait for remaining pods to terminate with timeout
echo "🔄 Waiting for pods to terminate..."
timeout 60s bash -c 'while kubectl get pods -n monitoring 2>/dev/null | grep -q "curl-test\|Error\|Failed"; do sleep 2; done' || true

# Force delete any remaining pods
echo "🔄 Force cleaning remaining pods..."
kubectl get pods -n monitoring --no-headers 2>/dev/null | awk '{print $1}' | xargs -r kubectl delete pod -n monitoring --force --grace-period=0 2>/dev/null || true

# Remove any remaining resources (but preserve secrets and configmaps)
echo "🔄 Cleaning up remaining resources..."
kubectl delete statefulset --all -n monitoring --ignore-not-found=true
kubectl delete deployment --all -n monitoring --ignore-not-found=true
kubectl delete service --all -n monitoring --ignore-not-found=true
kubectl delete pvc --all -n monitoring --ignore-not-found=true

# Note: NOT removing monitoring namespace to preserve secrets and configmaps
echo "ℹ️  Monitoring namespace preserved (contains secrets/configmaps)"

echo ""
echo "✅ Complete monitoring stack removal completed!"
echo ""
echo "Verification:"
echo "  kubectl get namespace monitoring"
echo "  (Should still exist)"
echo ""
echo "  helm list -A | grep monitoring"
echo "  (Should show no monitoring releases)"