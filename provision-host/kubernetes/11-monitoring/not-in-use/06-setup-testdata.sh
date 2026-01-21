#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/06-setup-testdata.sh
# Description: Deploy test data generators and validation dashboards for monitoring stack
# Usage: ./06-setup-testdata.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}

echo "=========================================="
echo "Test Data Generation and Dashboard Setup"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""
echo "📊 This will deploy:"
echo "   - Telemetrygen containers for logs, metrics, and traces"
echo "   - Validation dashboards in Grafana"
echo "   - End-to-end pipeline verification"
echo ""

# Change to the repository root directory
cd /mnt/urbalurbadisk/

# Run the Ansible playbook
echo "🚀 Running Ansible playbook for test data generation..."
ansible-playbook ansible/playbooks/035-setup-testdata.yml \
    -e "target_host=$TARGET_HOST" \
    --tags "all"

echo ""
echo "✅ Test data generation and installation validation dashboards deployed!"
echo ""
echo "🔗 Next steps:"
echo "   1. Open Installation Test Suite: http://grafana.localhost/d/installation-test-suite"
echo "   2. Or use port-forward: kubectl port-forward -n monitoring svc/grafana 3000:80"
echo "   3. Click links in the test suite to view:"
echo "      - Test Data - Logs (900+ log entries)"
echo "      - Test Data - Metrics (Prometheus up metrics)"
echo "      - Test Data - Traces (link to Tempo Explore)"
echo ""
echo "📊 Manual verification:"
echo "   kubectl get jobs -n monitoring -l app=telemetrygen"
echo "   kubectl get configmap installation-test-dashboards -n monitoring"
echo ""
echo "🧹 Cleanup after validation:"
echo "   kubectl delete configmap installation-test-dashboards -n monitoring"
echo "   kubectl delete jobs -n monitoring -l app=telemetrygen"