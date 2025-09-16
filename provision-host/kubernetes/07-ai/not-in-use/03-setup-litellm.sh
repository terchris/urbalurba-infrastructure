#!/bin/bash
# filename: provision-host/kubernetes/07-ai/not-in-use/03-setup-litellm.sh
# description: Setup LiteLLM proxy on a Kubernetes cluster using Ansible playbook.
#
# This script deploys the LiteLLM proxy in the 'ai' namespace using the Ansible playbook 210-setup-litellm.yml.
# It checks for required secrets, runs the playbook, and summarizes the deployment status.
#
# Usage: ./03-setup-litellm.sh [target-host]
# Example: ./03-setup-litellm.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_LITELLM="$ANSIBLE_DIR/playbooks/210-setup-litellm.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

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

check_secret() {
    local namespace="ai"
    local secret_name="urbalurba-secrets"
    echo "Checking if $secret_name exists in $namespace namespace..."
    kubectl get secret $secret_name -n $namespace &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Secret '$secret_name' not found in namespace '$namespace'"
        echo "Please create the secret before running this script"
        echo ""
        echo "Example:"
        echo "kubectl create secret generic $secret_name -n $namespace \\" 
        echo "  --from-literal=LITELLM_PROXY_MASTER_KEY=your-master-key"
        return 1
    fi
    echo "Secret '$secret_name' found in namespace '$namespace'"
    return 0
}

main() {
    echo "Starting LiteLLM proxy setup on $TARGET_HOST"
    echo "---------------------------------------------"
    check_secret || return 1
    run_playbook "Setup LiteLLM proxy" "$PLAYBOOK_PATH_SETUP_LITELLM" || return 1
    print_summary
    return ${#ERRORS[@]}
}

print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "LiteLLM proxy has been deployed to the 'ai' namespace."
        echo ""
        echo "You can check the LiteLLM pods with: kubectl get pods -n ai | grep litellm"
        echo "You can check the LiteLLM service with: kubectl get svc -n ai | grep litellm"
        echo ""
        echo "To access LiteLLM:"
        echo "- Port-forward: kubectl port-forward svc/litellm 4000:4000 -n ai"
        echo "- Ingress: http://litellm.localhost"
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check pod status: kubectl get pods -n ai"
        echo "  - View logs: kubectl logs -f <pod-name> -n ai"
        echo "  - Restart deployment: kubectl rollout restart deployment/litellm -n ai"
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the 'ai' namespace exists: kubectl get ns ai"
        echo "  - Check if pods are running: kubectl get pods -n ai"
        echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n ai"
        echo "  - Check Helm releases: helm list -n ai"
        echo "  - Make sure the 'urbalurba-secrets' secret exists and has all required keys"
    fi
}

main
exit $? 