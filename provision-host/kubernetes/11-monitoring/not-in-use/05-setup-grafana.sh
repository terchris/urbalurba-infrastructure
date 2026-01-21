#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/05-setup-grafana.sh
# Description: Deploy Grafana for observability dashboards with datasource validation
# Usage: ./05-setup-grafana.sh [target_host]

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo "Grafana Deployment with Datasource Tests"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""
echo "📊 This will deploy:"
echo "   - Grafana with admin credentials"
echo "   - Prometheus datasource (metrics)"
echo "   - Loki datasource (logs)"
echo "   - Tempo datasource (traces)"
echo "   - Validate all datasource connections"
echo ""

# Call Ansible playbook for heavy lifting
echo "🚀 Deploying Grafana via Ansible..."
ansible-playbook "$PROJECT_ROOT/ansible/playbooks/034-setup-grafana.yml" -e "target_host=$TARGET_HOST"

echo ""
echo "✅ Grafana deployment completed!"
echo ""
echo "🔗 Next steps:"
echo "   kubectl port-forward -n monitoring svc/grafana 3000:80 --context=$TARGET_HOST"
echo "   Open: http://localhost:3000 (admin/SecretPassword1)"