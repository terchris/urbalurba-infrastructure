#!/bin/bash
# File: scripts/argocd/argocd-remove-app.sh
# Description: This script removes an application from ArgoCD and the cluster by calling the Ansible playbook.
#              It is designed to run inside the provision-host container and is called by the host machine script.
#
# Required Parameters:
#   REPO_NAME - Name of the GitHub repository to remove (same as namespace)
#
# Usage:
#   REPO_NAME=your_repo \
#   ./argocd-remove-app.sh
#
# Exit Codes:
#   0 - Success
#   1 - Missing required parameters
#   2 - Failed to run Ansible playbook

# Check for missing parameters
if [ -z "$REPO_NAME" ]; then
    echo "❌ Error: REPO_NAME is not set"
    echo ""
    echo "Usage:"
    echo "REPO_NAME=your_repo \\"
    echo "./argocd-remove-app.sh"
    exit 1
fi

# Display current parameters
echo "🔍 Current Parameters:"
echo "REPO_NAME: $REPO_NAME"
echo ""

echo "🔧 Will remove the following resources:"
echo "   - ArgoCD Application: $REPO_NAME in argocd namespace"
echo "   - Secret: github-$REPO_NAME in argocd namespace"
echo "   - Namespace: $REPO_NAME and all its resources"
echo ""

echo "Removing $REPO_NAME from ArgoCD and cluster..."

# Run the Ansible playbook
ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/argocd-remove-app.yml \
  -e "repo_name=$REPO_NAME"

# Check the exit status of the Ansible playbook
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to remove application from ArgoCD"
    exit 2
fi

echo "✅ Application $REPO_NAME removed successfully!"
