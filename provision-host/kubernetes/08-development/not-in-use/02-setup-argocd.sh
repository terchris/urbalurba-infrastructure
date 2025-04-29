#!/bin/bash
# filename: 02-setup-argocd.sh
# description: Setup ArgoCD on a Kubernetes cluster using Ansible playbook.
# Also configures ArgoCD with appropriate settings for your environment.
#
# ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes.
# It enables automated deployment, monitoring, and management of applications,
# making it easier to maintain consistency across environments.
#
# Usage: ./02-setup-argocd.sh [target-host]
# Example: ./02-setup-argocd.sh rancher-desktop

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_ARGOCD="$ANSIBLE_DIR/playbooks/220-setup-argocd.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

# Main execution
echo "Starting ArgoCD setup on $TARGET_HOST"
echo "-----------------------------------"

# Run the Ansible playbook to set up ArgoCD
cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_ARGOCD -e kube_context=$TARGET_HOST
RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "---------- Installation Summary ----------"
    echo "ArgoCD setup completed successfully!"
    echo ""
    echo "ArgoCD has been deployed to the 'argocd' namespace."
    
    # Display login credentials
    echo ""
    echo "ArgoCD login credentials:"
    echo "Username: admin"
    # Check if we're using pre-created secret with known password
    if kubectl get secret argocd-secret -n argocd &>/dev/null; then
        echo "Password: SecretPassword1 (using pre-created secret)"
    else 
        echo "To get the ArgoCD initial admin password, run:"
        echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    fi
    
    # Access instructions
    echo ""
    echo "To access ArgoCD UI:"
    echo "1. Using the local ingress (recommended):"
    echo "   Visit: http://argocd.localhost"
    echo ""
    echo "2. Using port forwarding (alternative method):"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:80"
    echo "   Then visit: http://localhost:8080"
    
    # Delete initial admin secret reminder
    echo ""
    echo "NOTE: For security reasons, you should delete the initial admin secret after login:"
    echo "kubectl -n argocd delete secret argocd-initial-admin-secret"
else
    echo "---------- Installation Summary ----------"
    echo "ArgoCD setup encountered errors. Please check the playbook output above."
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Check if the 'argocd' namespace exists: kubectl get ns argocd"
    echo "  - Check if pods are running: kubectl get pods -n argocd"
    echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n argocd"
    echo "  - Check Helm release: helm list -n argocd"
fi

exit $RESULT