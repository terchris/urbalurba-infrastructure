#!/bin/bash
# filename: 02-setup-data-science.sh
# description: Deploy Databricks Replacement Data Science stack to Kubernetes cluster

TARGET_HOST=${1:-"rancher-desktop"}
STATUS=()
ERROR=0

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_DATA_SCIENCE="$ANSIBLE_DIR/playbooks/300-setup-data-science.yml"

echo "Starting Databricks Replacement Data Science setup on $TARGET_HOST"
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

# Step 2: Deploy Data Science Stack
deploy_data_science() {
    echo "🔧 Running Ansible playbook for Data Science deployment..."
    cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH_SETUP_DATA_SCIENCE -e target_host=$TARGET_HOST
    if [ $? -ne 0 ]; then
        STATUS+=("❌ Data Science deployment failed")
        ERROR=1
        return 1
    fi
    STATUS+=("✅ Data Science deployment completed")
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
        echo "✅ Databricks Replacement Data Science stack deployed successfully!"
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
    else
        echo "Some steps failed. Please check the logs."
    fi
}

main() {
    verify_prerequisites || return $ERROR
    deploy_data_science || return $ERROR
    print_summary
}

main "$@"
exit $ERROR