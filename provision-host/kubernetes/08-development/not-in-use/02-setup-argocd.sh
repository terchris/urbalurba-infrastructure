#!/bin/bash
# filename: 02-setup-argocd.sh
# description: Deploy ArgoCD to Kubernetes cluster

TARGET_HOST=${1:-"rancher-desktop"}
STATUS=()
ERROR=0

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_ARGOCD="$ANSIBLE_DIR/playbooks/220-setup-argocd.yml"

echo "Starting ArgoCD setup on $TARGET_HOST"
echo "---------------------------------------------------"

# Step 1: Verify prerequisites
verify_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        STATUS+=("❌ kubectl not found")
        ERROR=1
        return 1
    fi

    if ! command -v ansible-playbook &> /dev/null; then
        STATUS+=("❌ ansible-playbook not found")
        ERROR=1
        return 1
    fi

    # Test Kubernetes connection
    if ! kubectl config get-contexts "$TARGET_HOST" &>/dev/null; then
        STATUS+=("❌ Kubernetes context $TARGET_HOST not found")
        ERROR=1
        return 1
    fi

    kubectl config use-context "$TARGET_HOST" >/dev/null 2>&1
    if ! kubectl get nodes &>/dev/null; then
        STATUS+=("❌ Cannot connect to Kubernetes API")
        ERROR=1
        return 1
    fi

    STATUS+=("✅ Prerequisites verified")
    return 0
}

# Step 2: Deploy ArgoCD
deploy_argocd() {
    echo "🔧 Running Ansible playbook for ArgoCD deployment..."
    cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_ARGOCD -e target_host=$TARGET_HOST
    if [ $? -ne 0 ]; then
        STATUS+=("❌ ArgoCD deployment failed")
        ERROR=1
        return 1
    fi
    STATUS+=("✅ ArgoCD deployment completed")
    return 0
}

print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${STATUS[@]}"; do
        echo "$step"
    done
    if [ $ERROR -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "✅ ArgoCD setup completed successfully!"
        echo "🎯 Target: $TARGET_HOST"
        echo "🌐 Access: http://argocd.localhost"
        echo "🔐 Login: admin / SecretPassword2"
    else
        echo "Some steps failed. Please check the logs."
    fi
}

main() {
    verify_prerequisites || return $ERROR
    deploy_argocd || return $ERROR
    print_summary
}

main "$@"
exit $ERROR