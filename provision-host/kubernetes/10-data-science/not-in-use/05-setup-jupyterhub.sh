#!/bin/bash
# filename: 05-setup-jupyterhub.sh
# description: Deploy JupyterHub with PySpark integration to Kubernetes cluster

TARGET_HOST=${1:-"rancher-desktop"}
STATUS=()
ERROR=0

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_JUPYTERHUB="$ANSIBLE_DIR/playbooks/350-setup-jupyterhub.yml"

echo "Starting JupyterHub setup on $TARGET_HOST"
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

    if ! command -v helm &> /dev/null; then
        STATUS+=("❌ helm not found")
        ERROR=1
        return 1
    fi

    STATUS+=("✅ Prerequisites verified")
    return 0
}

# Step 2: Deploy JupyterHub
deploy_jupyterhub() {
    echo "🔧 Running Ansible playbook for JupyterHub deployment..."
    cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_JUPYTERHUB -e target_host=$TARGET_HOST
    if [ $? -ne 0 ]; then
        STATUS+=("❌ JupyterHub deployment failed")
        ERROR=1
        return 1
    fi
    STATUS+=("✅ JupyterHub deployment completed")
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
        echo "✅ JupyterHub deployed successfully!"
        echo "🎯 Target: $TARGET_HOST"
        echo "📁 Namespace: jupyterhub"
        echo ""
        echo "📊 Components installed:"
        echo "   • JupyterHub web interface"
        echo "   • PySpark integration"
        echo "   • Traefik ingress routing"
        echo ""
        echo "🌐 Access Information:"
        echo "   URL: http://jupyterhub.localhost"
        echo "   Username: admin"
        echo "   Password: SecretPassword2"
        echo ""
        echo "🚀 Verification Commands:"
        echo "   kubectl get pods -n jupyterhub"
        echo "   kubectl get ingress -n jupyterhub"
    else
        echo "Some steps failed. Please check the logs."
    fi
}

main() {
    verify_prerequisites || return $ERROR
    deploy_jupyterhub || return $ERROR
    print_summary
}

main "$@"
exit $ERROR