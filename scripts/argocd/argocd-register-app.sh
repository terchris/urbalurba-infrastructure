#!/bin/bash
# File: scripts/argocd/argocd-register-app.sh
# Description: This script registers an application with ArgoCD by calling the Ansible playbook.
#              It is designed to run inside the provision-host container and is called by the host machine script.
#              All the logic for app registration and verification is in the Ansible playbook.
#
# Required Parameters:
#   GITHUB_USERNAME - GitHub username for repository access
#   REPO_NAME      - Name of the GitHub repository to register (will be used as namespace)
#   GITHUB_PAT     - GitHub Personal Access Token for authentication
#
# Optional Parameters:
#   WAIT_TIMEOUT   - Maximum time to wait for deployment in seconds (default: 300)
#
# Usage:
#   GITHUB_USERNAME=your_username \
#   REPO_NAME=your_repo \
#   GITHUB_PAT=your_token \
#   [WAIT_TIMEOUT=300] \
#   ./argocd-register-app.sh

# Set default timeout if not provided
WAIT_TIMEOUT=${WAIT_TIMEOUT:-300}

# Check for missing parameters
missing_params=0
if [ -z "$GITHUB_USERNAME" ]; then
    echo "❌ Error: GITHUB_USERNAME is not set"
    missing_params=1
fi

if [ -z "$REPO_NAME" ]; then
    echo "❌ Error: REPO_NAME is not set"
    missing_params=1
fi

if [ -z "$GITHUB_PAT" ]; then
    echo "❌ Error: GITHUB_PAT is not set"
    missing_params=1
fi

if [ $missing_params -eq 1 ]; then
    echo ""
    echo "Usage:"
    echo "GITHUB_USERNAME=your_username \\"
    echo "REPO_NAME=your_repo \\"
    echo "GITHUB_PAT=your_token \\"
    echo "[WAIT_TIMEOUT=300] \\"
    echo "./argocd-register-app.sh"
    exit 1
fi

# Display current parameters
echo "🔍 Current Parameters:"
echo "GITHUB_USERNAME: $GITHUB_USERNAME"
echo "REPO_NAME: $REPO_NAME"
echo "GITHUB_PAT: [hidden]"
echo "WAIT_TIMEOUT: $WAIT_TIMEOUT seconds"
echo ""

echo "🚀 Registering $GITHUB_USERNAME/$REPO_NAME with ArgoCD..."

# Start time tracking
start_time=$(date +%s)

# Run the Ansible playbook with the timeout variable
ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/argocd-register-app.yml \
  -e "github_username=$GITHUB_USERNAME" \
  -e "repo_name=$REPO_NAME" \
  -e "github_pat=$GITHUB_PAT" \
  -e "wait_timeout=$WAIT_TIMEOUT"

# Check the exit status of the Ansible playbook
ansible_exit_code=$?
if [ $ansible_exit_code -ne 0 ]; then
    echo "❌ Error: Failed to register application with ArgoCD. Check the output above for details."
    exit 2
fi

# Calculate elapsed time
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

echo ""
echo "⏱️ Registration completed in $elapsed_time seconds"
echo ""
echo "✅ Application $REPO_NAME registered successfully!"
echo ""
