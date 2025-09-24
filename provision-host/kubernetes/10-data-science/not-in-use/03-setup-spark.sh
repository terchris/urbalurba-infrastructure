#!/bin/bash
# filename: 03-setup-spark.sh
# description: Deploy Spark Kubernetes Operator to Kubernetes cluster

TARGET_HOST=${1:-"rancher-desktop"}
STATUS=()
ERROR=0

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_SPARK="$ANSIBLE_DIR/playbooks/330-setup-spark.yml"

echo "Starting Spark Kubernetes Operator setup on $TARGET_HOST"
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

# Step 2: Deploy Spark Operator
deploy_spark() {
    echo "🔧 Running Ansible playbook for Spark Operator deployment..."
    cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_SPARK -e target_host=$TARGET_HOST
    if [ $? -ne 0 ]; then
        STATUS+=("❌ Spark Operator deployment failed")
        ERROR=1
        return 1
    fi
    STATUS+=("✅ Spark Operator deployment completed")
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
        echo "✅ Spark Kubernetes Operator deployed successfully!"
        echo "🎯 Target: $TARGET_HOST"
        echo "📁 Namespace: spark-operator"
        echo ""
        echo "📊 Components installed:"
        echo "   • Spark Kubernetes Operator (distributed processing)"
        echo "   • SparkApplication CRDs (declarative job submission)"
        echo "   • RBAC configuration (service accounts)"
        echo ""
        echo "🚀 Next Steps:"
        echo "   kubectl get pods -n spark-operator"
        echo "   kubectl get sparkapplications -A"
        echo "   Deploy JupyterHub: ./05-setup-jupyterhub.sh"
    else
        echo "Some steps failed. Please check the logs."
    fi
}

main() {
    verify_prerequisites || return $ERROR
    deploy_spark || return $ERROR
    print_summary
}

main "$@"
exit $ERROR