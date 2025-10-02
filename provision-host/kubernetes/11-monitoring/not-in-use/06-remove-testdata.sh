#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/06-remove-testdata.sh
# Description: Remove test data generators and validation dashboards
# Usage: ./06-remove-testdata.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}

echo "=========================================="
echo "Test Data Cleanup"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""

echo "🧹 Removing telemetrygen jobs..."
kubectl delete jobs -n monitoring -l app=telemetrygen --context=$TARGET_HOST --ignore-not-found=true

echo "🧹 Removing installation test dashboards..."
kubectl delete configmap installation-test-dashboards -n monitoring --context=$TARGET_HOST --ignore-not-found=true

echo "🧹 Cleaning up any remaining test pods..."
kubectl delete pods -n monitoring -l app=telemetrygen --context=$TARGET_HOST --ignore-not-found=true --force --grace-period=0 2>/dev/null || true

echo ""
echo "✅ Test data cleanup completed!"
echo ""
echo "Verification:"
echo "  kubectl get jobs -n monitoring -l app=telemetrygen --context=$TARGET_HOST"
echo "  kubectl get configmaps -n monitoring -l grafana_dashboard=1 --context=$TARGET_HOST"