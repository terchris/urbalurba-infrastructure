#!/bin/bash
# filename: update-kubernetes-secrets-v2.sh
# Script that pushes Kubernetes secrets to the specified context
#
# This script performs the following actions:
# 1. Verifies the Kubernetes secrets file exists
# 2. Checks if kubectl is installed
# 3. Applies the secrets to the Kubernetes cluster
# 4. Verifies the secrets were created successfully
#
# Usage:
#   ./update-kubernetes-secrets-v2.sh [context]
#
# Arguments:
#   context: (Required) The Kubernetes context to use (e.g., azure-microk8s, rancher-desktop)
#
# Requirements:
#   - kubectl installed and configured with access to the specified context
#   - Kubernetes secrets file located at ./kubernetes/kubernetes-secrets.yml
#
# Example usage:
#   ./update-kubernetes-secrets-v2.sh azure-microk8s
#   ./update-kubernetes-secrets-v2.sh rancher-desktop

# Initialize status tracking arrays
STATUS=()
ERRORS=()

# Variables
NAMESPACE="default"
KUBERNETES_SECRETS_FILE="./kubernetes/kubernetes-secrets.yml"

# Function to add status to our tracking array
add_status() {
    local step=$1
    local status=$2
    STATUS+=("$step: $status")
}

# Function to add error details to our tracking array
add_error() {
    local step=$1
    local error=$2
    ERRORS+=("$step: $error")
}

# Function to check command success and update status accordingly
check_command_success() {
    local step=$1
    if [ $? -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Function to print summary of operations
print_summary() {
    echo "---------- Update Kubernetes Secrets Summary ----------"
    for status in "${STATUS[@]}"; do
        echo "$status"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo "Kubernetes secrets have been successfully updated in context: $CONTEXT"
    else
        echo "Errors occurred during update:"
        for error in "${ERRORS[@]}"; do
            echo "  $error"
        done
    fi

    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Check for context parameter
if [ $# -eq 0 ]; then
    echo "Error: No context provided."
    echo "Usage: $0 <context>"
    echo "Example: $0 azure-microk8s"
    exit 1
else
    CONTEXT="$1"
    echo "Using provided context: $CONTEXT"
fi

# Main execution
main() {
    echo "Starting the process to update Kubernetes secrets to cluster: $CONTEXT..."

    # Step 1: Check if kubectl is installed
    echo "1: Checking if kubectl is installed..."
    if ! command -v kubectl &> /dev/null; then
        add_status "kubectl installation" "Fail"
        add_error "kubectl installation" "kubectl command not found"
        print_summary
        exit 1
    fi
    add_status "kubectl installation" "OK"

    # Step 2: Check if the Kubernetes secrets file exists
    echo "2: Checking if the Kubernetes secrets file exists..."
    if [ ! -f "$KUBERNETES_SECRETS_FILE" ]; then
        add_status "Kubernetes secrets file existence" "Fail"
        add_error "Kubernetes secrets file existence" "File not found: $KUBERNETES_SECRETS_FILE"
        print_summary
        exit 1
    fi
    add_status "Kubernetes secrets file existence" "OK"

    # Step 3: Check if the context exists
    echo "3: Checking if the context $CONTEXT exists..."
    if ! kubectl config get-contexts -o name | grep -q "^$CONTEXT$"; then
        add_status "Context check" "Fail"
        add_error "Context check" "Context $CONTEXT does not exist"
        print_summary
        exit 1
    fi
    add_status "Context check" "OK"

    # Step 4: Set the context
    echo "4: Setting the context to $CONTEXT..."
    kubectl config use-context "$CONTEXT"
    check_command_success "Set context" || { print_summary; exit 1; }

    # Step 5: Check if the namespace exists in the context, and if not, create it
    echo "5: Checking if the namespace $NAMESPACE exists in the context $CONTEXT..."
    if ! kubectl get namespace $NAMESPACE --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null; then
        echo "Namespace $NAMESPACE not found in context $CONTEXT. Creating it..."
        kubectl create namespace $NAMESPACE
        check_command_success "Create namespace" || { print_summary; exit 1; }
    fi
    add_status "Namespace check/creation" "OK"

    # Step 6: Apply the secrets
    echo "6: Applying secrets to Kubernetes cluster for context $CONTEXT..."
    kubectl apply -f "$KUBERNETES_SECRETS_FILE"
    check_command_success "Apply secrets" || { print_summary; exit 1; }

    # Step 7: Verify secrets exist
    echo "7: Verifying secrets were created in namespace $NAMESPACE for context $CONTEXT..."
    kubectl get secrets -n "$NAMESPACE"
    check_command_success "Verify secrets" || { print_summary; exit 1; }

    # Print summary
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?