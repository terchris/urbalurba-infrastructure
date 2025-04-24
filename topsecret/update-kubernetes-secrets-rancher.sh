#!/bin/bash
# filename: update-kubernetes-secrets-rancher.sh
# Script that pushes Kubernetes secrets to the specified context via the provision-host container
#
# This script performs the following actions:
# 1. Verifies the Kubernetes secrets file exists
# 2. Checks if the provision-host container is running
# 3. Applies the secrets to the Kubernetes cluster
# 4. Verifies the secrets were created successfully
#
# Usage:
#   ./update-kubernetes-secrets-rancher.sh [context]
#
# Arguments:
#   context: (Optional) The Kubernetes context to use. If not provided, uses the default context.
#
# Requirements:
#   - Docker with provision-host container running
#   - kubectl configured in the container with access to the specified context
#   - Kubernetes secrets file located at ./kubernetes/kubernetes-secrets.yml
#
# Example usage:
#   ./update-kubernetes-secrets-rancher.sh 
#   ./update-kubernetes-secrets-rancher.sh rancher-desktop

# Variables
CONTAINER_NAME="provision-host"
NAMESPACE="default"
KUBERNETES_SECRETS_FILE="./kubernetes/kubernetes-secrets.yml"
DEFAULT_CONTEXT="rancher-desktop"
STATUS=()

# Function to check the success of the last command
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        echo "Error: $1 failed."
        return 1
    else
        STATUS+=("$1: OK")
        return 0
    fi
}

# Function to exit script on error
exit_on_error() {
    echo "Error: $1"
    exit 1
}

# Check for context parameter
if [ $# -eq 0 ]; then
    CONTEXT=$DEFAULT_CONTEXT
    echo "No context provided. Using default context: $CONTEXT"
else
    CONTEXT="$1"
    echo "Using provided context: $CONTEXT"
fi

echo "Starting the process to update Kubernetes secrets to cluster: $CONTEXT..."

# Test 1: Check if the Kubernetes secrets file exists
echo "1: Checking if the Kubernetes secrets file exists"
if [ -f "$KUBERNETES_SECRETS_FILE" ]; then
    STATUS+=("Kubernetes secrets file existence: OK")
else
    exit_on_error "Kubernetes secrets file does not exist."
fi

# Test 2: Check if container is running
echo "2: Checking if container is running..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    exit_on_error "Container $CONTAINER_NAME is not running"
fi
STATUS+=("Container running: OK")

# Test 3: Check if the context exists in the container
echo "3: Checking if the context $CONTEXT exists in the container..."
CONTEXT_EXISTS=$(docker exec "$CONTAINER_NAME" kubectl config get-contexts -o name | grep -q "^$CONTEXT$" && echo "yes" || echo "no")
if [ "$CONTEXT_EXISTS" != "yes" ]; then
    exit_on_error "Context $CONTEXT does not exist in the container."
fi
STATUS+=("Context check: OK")

# Test 4: Check if the namespace exists in the context, and if not, create it
echo "4: Checking if the namespace $NAMESPACE exists in the context $CONTEXT..."
if ! docker exec "$CONTAINER_NAME" kubectl --context=$CONTEXT get namespace $NAMESPACE --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null; then
    echo "Namespace $NAMESPACE not found in context $CONTEXT. Creating it..."
    if ! docker exec "$CONTAINER_NAME" kubectl --context=$CONTEXT create namespace $NAMESPACE; then
        exit_on_error "Failed to create namespace $NAMESPACE in context $CONTEXT."
    fi
fi
STATUS+=("Namespace check/creation: OK")

# Test 5: Apply the secrets
echo "5: Applying secrets to Kubernetes cluster for context $CONTEXT..."
if ! docker exec "$CONTAINER_NAME" kubectl --context=$CONTEXT apply -f "/mnt/urbalurbadisk/topsecret/$KUBERNETES_SECRETS_FILE"; then
    exit_on_error "Failed to apply Kubernetes secrets to context $CONTEXT."
fi
STATUS+=("Apply secrets: OK")

# Test 6: Verify secrets exist
echo "6: Verifying secrets were created in namespace $NAMESPACE for context $CONTEXT..."
if ! docker exec "$CONTAINER_NAME" kubectl --context=$CONTEXT get secrets -n "$NAMESPACE"; then
    exit_on_error "Failed to verify secrets creation in namespace $NAMESPACE for context $CONTEXT."
fi
STATUS+=("Verify secrets: OK")

echo "------ Summary of test statuses ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

echo "--------------- All OK ------------------------"
echo "Kubernetes secrets have been successfully updated."

exit 0 