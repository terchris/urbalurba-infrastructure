#!/bin/bash
# filename: create-kubernetes-secrets.sh
# description: Checks if kubernetes-secrets.yml exists and provides instructions if it doesn't
# Future improvement: Make the script so that it copies the template file and prompt the user to set all parameters.
#                    It should be dynamically so that any new parameter in the secrets file is automatically handled.

# Exit codes:
# 0 - Success
# 1 - Error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATE_FILE="kubernetes/kubernetes-secrets-template.yml"
SECRETS_FILE="kubernetes/kubernetes-secrets.yml"
FULL_TEMPLATE_PATH="$SCRIPT_DIR/$TEMPLATE_FILE"
FULL_SECRETS_PATH="$SCRIPT_DIR/$SECRETS_FILE"

# Check if template exists
if [ ! -f "$FULL_TEMPLATE_PATH" ]; then
    echo "Error: Template file not found at: $FULL_TEMPLATE_PATH"
    exit 1
fi

# Check if secrets file exists
if [ ! -f "$FULL_SECRETS_PATH" ]; then
    echo "Kubernetes secrets file not found at: $FULL_SECRETS_PATH"
    echo ""
    echo "There is a template file that contains default values."    
    echo "You should copy and edit it to add your own secrets."
    echo "Read doc/kubernetes-secrets-readme.md for more information."
    echo ""
    echo "But if you just want the system to run, you can continue with default values."
    echo ""

    read -p "Do you want to continue with default values? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "To create the secrets file:"
        echo "1. Copy the template:"
        echo "   cp topsecret/$TEMPLATE_FILE topsecret/$SECRETS_FILE"
        echo ""
        echo "2. Edit the file with your values:"
        echo "   # The file contains all necessary variables with descriptions"
        echo "   # Each variable has a comment explaining its purpose"
        echo "   # Replace the placeholder values with your actual values"
        echo ""
        echo "For detailed information about the secrets and their default values,"
        echo "please read doc/kubernetes-secrets-readme.md"
        echo ""
        echo "After editing the file, run './install-rancher.sh' again to continue the installation."
        exit 1
    fi
    echo "Using default values from kubernetes-secrets-template.yml"
    cp "$FULL_TEMPLATE_PATH" "$FULL_SECRETS_PATH"
    echo "Kubernetes secrets file created at: $FULL_SECRETS_PATH"
    exit 0
fi

echo "Kubernetes secrets file exists at: $FULL_SECRETS_PATH"
exit 0 