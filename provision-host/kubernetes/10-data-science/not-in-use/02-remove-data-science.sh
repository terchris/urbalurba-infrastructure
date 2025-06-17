#!/bin/bash
# filename: 02-remove-data-science.sh
# description: Remove Databricks Replacement Data Science stack from Kubernetes using Ansible playbook.
# Removes both Spark Kubernetes Operator and JupyterHub for complete cleanup.
#
# Architecture:
# - Delegates complex removal logic to Ansible playbook for better control
# - Provides simple interface consistent with setup script
# - Comprehensive cleanup of both processing engine and notebook interface
#
# Part of: Databricks Replacement Project - Complete Stack Removal
# Namespace: spark-operator, jupyterhub
#
# Usage: ./02-remove-data-science.sh [target-host]
# Example: ./02-remove-data-science.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize status tracking
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/300-delete-data-science.yml"

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
run_removal_playbook() {
    local step="Remove Databricks Replacement Stack"
    
    echo "Running removal playbook..."
    echo "Target: $TARGET_HOST"
    echo "Playbook: $PLAYBOOK_PATH"
    echo ""
    
    cd $ANSIBLE_DIR && ansible-playbook $PLAYBOOK_PATH -e kube_context=$TARGET_HOST
    local result=$?
    check_command_success "$step" $result
    return $result
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if playbook exists
    if [ ! -f "$PLAYBOOK_PATH" ]; then
        echo "ERROR: Playbook not found at $PLAYBOOK_PATH"
        add_error "Prerequisites" "Playbook file missing"
        return 1
    fi
    
    # Check if ansible directory exists
    if [ ! -d "$ANSIBLE_DIR" ]; then
        echo "ERROR: Ansible directory not found at $ANSIBLE_DIR"
        add_error "Prerequisites" "Ansible directory missing"
        return 1
    fi
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "WARNING: kubectl not found in PATH"
        echo "Note: This may be normal if running inside provision-host container"
    fi
    
    # Check helm
    if ! command -v helm >/dev/null 2>&1; then
        echo "WARNING: helm not found in PATH"
        echo "Note: This may be normal if running inside provision-host container"
    fi
    
    echo "Prerequisites check completed"
    return 0
}

# Function to verify removal results
verify_removal() {
    echo "Verifying removal results..."
    
    # Quick verification using kubectl (if available)
    if command -v kubectl >/dev/null 2>&1; then
        echo "Checking for remaining resources..."
        
        # Check namespaces
        SPARK_NS=$(kubectl get namespace spark-operator 2>/dev/null | wc -l)
        JUPYTER_NS=$(kubectl get namespace jupyterhub 2>/dev/null | wc -l)
        
        echo "Remaining namespaces:"
        echo "  spark-operator: $((SPARK_NS-1))"  # Subtract header line
        echo "  jupyterhub: $((JUPYTER_NS-1))"     # Subtract header line
        
        # Check for any remaining pods
        REMAINING_PODS=$(kubectl get pods --all-namespaces 2>/dev/null | grep -E "(spark|jupyter)" | wc -l)
        echo "  Remaining pods: $REMAINING_PODS"
        
        if [ $((SPARK_NS-1)) -eq 0 ] && [ $((JUPYTER_NS-1)) -eq 0 ] && [ $REMAINING_PODS -eq 0 ]; then
            echo "✅ Verification successful - all resources removed"
            add_status "Verification" "OK"
            return 0
        else
            echo "⚠️ Some resources may still exist"
            add_status "Verification" "Partial"
            return 1
        fi
    else
        echo "kubectl not available for verification"
        add_status "Verification" "Skipped"
        return 0
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "---------- Removal Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "🎉 Databricks Replacement Stack removal completed!"
        echo ""
        echo "✅ Removed components:"
        echo "   - Spark Kubernetes Operator (processing engine)"
        echo "   - JupyterHub (notebook interface)"
        echo "   - All user sessions and workloads"
        echo "   - Associated namespaces and resources"
        echo ""
        echo "🚀 Ready for fresh installation:"
        echo "   ./02-setup-data-science.sh $TARGET_HOST"
        echo ""
        echo "🌐 After reinstallation, access will be:"
        echo "   JupyterHub: http://jupyterhub.localhost"
        echo "   Login: admin / SecretPassword1"
        
    else
        echo ""
        echo "⚠️ Removal completed with some issues:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   - Check if you have sufficient permissions"
        echo "   - Verify kubectl context: kubectl config current-context"
        echo "   - Manual cleanup: kubectl get all --all-namespaces | grep -E '(spark|jupyter)'"
        echo "   - Check playbook logs above for detailed error information"
    fi
}

# Main execution
main() {
    echo "🧹 Starting Databricks Replacement Stack removal on $TARGET_HOST"
    echo "=================================================================="
    echo "This will remove:"
    echo "  - Spark Kubernetes Operator (processing engine)"
    echo "  - JupyterHub (notebook interface)"  
    echo "  - All user sessions and running workloads"
    echo "  - Associated namespaces and cluster resources"
    echo ""
    
    # Confirmation prompt
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Removal cancelled."
        exit 0
    fi
    
    echo "Proceeding with removal..."
    echo ""
    
    # Check prerequisites
    check_prerequisites || {
        echo "Prerequisites check failed"
        print_summary
        return 1
    }
    
    # Run the removal playbook
    run_removal_playbook || {
        echo "Removal playbook failed"
        print_summary
        return 1
    }
    
    # Verify removal (optional, may not be available in all environments)
    verify_removal
    
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?