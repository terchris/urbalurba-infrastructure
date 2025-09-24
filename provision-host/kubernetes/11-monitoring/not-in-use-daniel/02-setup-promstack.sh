#!/bin/bash
# filename: 02-setup-promstack.sh
# description: Setup Prometheus stack on a Kubernetes cluster using Ansible playbook.
# Prometheus Stack is a collection of tools for monitoring and alerting in Kubernetes.
#
# Usage: ./02-setup-promstack.sh [target-host]
# Example: ./02-setup-promstack.sh rancher-desktop

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_PROMSTACK="$ANSIBLE_DIR/playbooks/230-setup-promstack.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

# Main execution
echo "Starting PromStack setup on $TARGET_HOST"
echo "-----------------------------------"

# Run the Ansible playbook to set up PromStack
cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_PROMSTACK -e kube_context=$TARGET_HOST
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "---------- Installation Summary ----------"
    echo "PromStack setup completed successfully!"
    echo ""
    echo "PromStack has been deployed to the 'monitoring' namespace."
    
    # Display login credentials
    echo ""
    echo "Grafana login credentials:"
    echo "Username: $(kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-user}" | base64 -d)"
    echo "Password: $(kubectl get secret prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d)"
    
    # Access instructions
    echo ""
    echo "PromStack access UIs:"
    echo "1. Using the local ingress (recommended):"
    echo "   Visit: http://grafana.localhost"
    echo "   Visit: http://prometheus.localhost"
    echo "   Visit: http://alertmanager.localhost"
    echo ""
    echo "2. Using port forwarding (alternative method):"
    echo "   kubectl port-forward svc/prometheus-stack-grafana -n monitoring 8080:80"
    echo "   Then visit: http://localhost:8080"
    echo ""
    echo "   kubectl port-forward svc/prometheus-stack-prometheus -n monitoring 9090:9090"
    echo "   Then visit: http://localhost:9090"
    echo ""
    echo "   kubectl port-forward svc/prometheus-stack-alertmanager -n monitoring 9093:9093"
    echo "   Then visit: http://localhost:9093"
    
else
    echo "---------- Installation Summary ----------"
    echo "PromStack setup encountered errors. Please check the playbook output above."
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Check if the 'monitoring' namespace exists: kubectl get ns monitoring"
    echo "  - Check if pods are running: kubectl get pods -n monitoring"
    echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n monitoring"
    echo "  - Check Helm release: helm list -n monitoring"
fi

exit $RESULT