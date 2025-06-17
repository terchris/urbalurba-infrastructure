#!/bin/bash
# filename: 02-setup-data-science.sh
# description: Setup Databricks Replacement Data Science stack on a Kubernetes cluster using Ansible playbook.
# Installs Spark Kubernetes Operator for distributed data processing.
#
# Architecture:
# - Spark Kubernetes Operator: Manages Spark applications and jobs on Kubernetes
# - RBAC configuration: Proper service accounts and permissions for Spark jobs
# - ARM64 compatibility: Runs natively on Apple Silicon hardware
# - SparkApplication CRDs: Submit and manage Spark jobs declaratively
#
# Part of: Databricks Replacement Project - Phase 1 (Processing Engine)
# Namespace: spark-operator
#
# Usage: ./02-setup-data-science.sh [target-host]
# Example: ./02-setup-data-science.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_DATA_SCIENCE="$ANSIBLE_DIR/playbooks/300-setup-data-science.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

# Function to add status
add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

# Function to add error
add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

# Function to check command success
check_command_success() {
    local step=$1
    local result=$2
    if [ ! -z "$result" ] && [ $result -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed with exit code $result"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Function to run Ansible playbook
run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    
    echo "Running playbook for $step..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$TARGET_HOST $extra_args
    local result=$?
    check_command_success "$step" $result
    return $result
}

# Function to check Kubernetes secret (currently not needed for Spark)
check_secret() {
    local namespace="spark-operator"
    local secret_name="urbalurba-secrets"
    
    echo "Checking if $secret_name exists in $namespace namespace..."
    kubectl get secret $secret_name -n $namespace &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Notice: Secret '$secret_name' not found in namespace '$namespace'"
        echo "This is normal - Spark Operator uses default configuration"
        return 0
    fi
    
    echo "Secret '$secret_name' found in namespace '$namespace'"
    return 0
}

# Function to check if Helm repos are added
check_helm_repos() {
    echo "Checking Helm repositories..."
    local required_repos=("spark-kubernetes-operator")
    local missing_repos=()
    
    for repo in "${required_repos[@]}"; do
        if ! helm repo list | grep -q "$repo"; then
            missing_repos+=("$repo")
        fi
    done
    
    if [ ${#missing_repos[@]} -gt 0 ]; then
        echo "Missing Helm repositories: ${missing_repos[*]}"
        echo "The Ansible playbook will attempt to add them"
    else
        echo "All required Helm repositories are present"
    fi
    
    return 0
}

# Function to check if Spark Operator is already running
check_existing_spark() {
    echo "Checking for existing Spark Operator deployment..."
    kubectl get deployment spark-kubernetes-operator -n spark-operator &>/dev/null
    if [ $? -eq 0 ]; then
        echo "WARNING: Spark Operator is already running in spark-operator namespace"
        echo "Please stop the existing deployment before running this script:"
        echo "  helm uninstall spark-kubernetes-operator -n spark-operator"
        echo "  kubectl delete namespace spark-operator"
        return 1
    fi
    
    echo "No existing Spark Operator found - ready to deploy"
    return 0
}

# Main execution
main() {
    echo "Starting Databricks Replacement Data Science setup on $TARGET_HOST"
    echo "---------------------------------------------------"
    
    # Check prerequisites
    check_existing_spark || return 1
    check_secret || return 1
    check_helm_repos
    
    # Run the Ansible playbook to set up Data Science stack
    run_playbook "Setup Databricks Replacement Data Science Stack" "$PLAYBOOK_PATH_SETUP_DATA_SCIENCE" || return 1
    
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "The Databricks Replacement Data Science stack has been deployed to the 'spark-operator' namespace."
        echo ""
        echo "Components installed:"
        echo "- Spark Kubernetes Operator (distributed processing engine)"
        echo "- RBAC configuration (service accounts and permissions)"
        echo "- SparkApplication CRDs (declarative job submission)"
        echo ""
        
        # Verify deployment status
        echo "Verifying deployment status..."
        echo "Note: The Spark Operator should be ready within 1-2 minutes."
        
        # Count running pods
        RUNNING_PODS=$(kubectl get pods -n spark-operator | grep Running | wc -l)
        TOTAL_PODS=$(kubectl get pods -n spark-operator | grep -v NAME | wc -l)
        
        echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"
        
        if [ "$TOTAL_PODS" -eq 0 ]; then
            echo "No pods found. Check if the deployment was successful."
        elif [ "$RUNNING_PODS" -lt "$TOTAL_PODS" ]; then
            echo "Some pods are still starting. This is normal for new deployments."
        fi
        
        echo ""
        echo "Architecture:"
        echo "- Spark Kubernetes Operator manages Spark applications on Kubernetes"
        echo "- Submit jobs using SparkApplication CRDs"
        echo "- Automatic resource management and cleanup"
        echo "- ARM64 compatible (runs on Apple Silicon)"
        echo ""
        echo "Next Steps:"
        echo "1. Test Spark job submission with: kubectl apply -f manifests/331-sample-data-sparkapplication.yaml"
        echo "2. Monitor jobs with: kubectl get sparkapplications -n spark-operator"
        echo "3. Check Spark Operator logs: kubectl logs -n spark-operator deployment/spark-kubernetes-operator"
        echo ""
        echo "You can check the Spark Operator with: kubectl get pods -n spark-operator"
        echo "View Spark applications with: kubectl get sparkapplications -A"
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the 'spark-operator' namespace exists: kubectl get ns spark-operator"
        echo "  - Check if pods are running: kubectl get pods -n spark-operator"
        echo "  - Check Helm releases: helm list -n spark-operator"
        echo "  - Check Spark Operator status: kubectl get deployment spark-kubernetes-operator -n spark-operator"
        echo "  - View Spark Operator logs: kubectl logs -n spark-operator deployment/spark-kubernetes-operator"
        echo "  - Ensure no conflicting Spark installations exist"
    fi
}

# Run the main function and exit with its return code
main
exit $?