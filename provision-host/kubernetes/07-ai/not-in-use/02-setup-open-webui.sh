#!/bin/bash
# filename: 02-setup-open-webui.sh
# ⚠️ IMPORTANT: This script is for MANUAL TROUBLESHOOTING ONLY
# DO NOT move to auto-execute directory - use 01-setup-litellm-openwebui.sh for automatic provisioning
# Reason: Prevents redundant deployments during cluster rebuild
#
# description: Setup Open WebUI on a Kubernetes cluster using Ansible playbook.
# Also installs the dependencies for the open-webui: 
# - storage : persistent storage for all systems
# - tika : Apache Tika server for document extraction and processing
# - ollama: install a minimal LLM (qwen3:0.6b) in the cluster. The model is so small so it is mainly there to prove that it works. Remove it when you have a real model.
#
# Architecture:
# - OpenWebUI connects directly to both Ollama instances (in-cluster and on host)
# - Users can download and manage models on the host Ollama through the UI
# - The in-cluster Ollama provides a stable, minimal model for testing
#
# All the services are set up in the namespace named: ai and requires you to set secrets needed for the services to work.
#
# Usage: ./02-setup-open-webui.sh [target-host] [deploy_ollama_incluster]
# Example: ./02-setup-open-webui.sh rancher-desktop false
#   target-host: Kubernetes context/host (default: rancher-desktop)
#   deploy_ollama_incluster: true (default) or false (to skip in-cluster Ollama)

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
PLAYBOOK_PATH_SETUP_OPEN_WEBUI="$ANSIBLE_DIR/playbooks/200-setup-open-webui.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}
DEPLOY_OLLAMA_INCLUSTER=${2:-true}

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
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$TARGET_HOST -e deploy_ollama_incluster=$DEPLOY_OLLAMA_INCLUSTER $extra_args
    local result=$?
    check_command_success "$step" $result
    return $result
}

# Removed check_secret and check_helm_repos functions
# These checks are handled by the Ansible playbook

# Main execution
main() {
    echo "Starting Open WebUI AI Stack setup on $TARGET_HOST"
    echo "---------------------------------------------------"

    # Run the Ansible playbook to set up Open WebUI
    run_playbook "Setup Open WebUI and AI Stack" "$PLAYBOOK_PATH_SETUP_OPEN_WEBUI" || return 1
    
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
        echo "The Open WebUI AI Stack has been deployed to the 'ai' namespace."
        echo ""
        echo "Components installed:"
        echo "- Persistent storage for all services"
        echo "- Apache Tika (document extraction)"
        echo "- LiteLLM (proxy for model access) - via separate deployment"
        echo "- Open WebUI (frontend connecting to LiteLLM proxy)"
        echo "- Note: In-cluster Ollama skipped (deploy_ollama_incluster=false)"
        echo ""

        # Deployment verification is handled by the Ansible playbook

        echo ""
        echo "Architecture:"
        echo "- OpenWebUI connects to LiteLLM proxy for all model access"
        echo "- LiteLLM provides unified access to Mac Ollama and cloud providers"
        echo "- Models are served through LiteLLM from your configured providers"
        echo ""
        echo "You can check the OpenWebUI pods with: kubectl get pods -n ai"
        echo "You can access OpenWebUI by port-forwarding: kubectl port-forward svc/open-webui 8080:8080 -n ai"
        echo "Then visit: http://localhost:8080"
        echo "Or use the ingress at: http://openwebui.localhost"
        echo ""
        echo "To make the OpenWebUI available from the outside world, you can run the networking/net2-tailscale-host-setup.sh script."
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the 'ai' namespace exists: kubectl get ns ai"
        echo "  - Check if pods are running: kubectl get pods -n ai"
        echo "  - Check persistent volumes: kubectl get pvc -n ai"
        echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n ai"
        echo "  - Check Helm releases: helm list -n ai"
        echo "  - Check Ollama status: kubectl get pods -n ai | grep ollama"
        echo "  - View Ollama logs: kubectl logs -f \$(kubectl get pods -n ai -l app.kubernetes.io/name=ollama -o name) -n ai"
        echo "  - Make sure the 'urbalurba-secrets' secret exists and has all required keys"
    fi
}

# Run the main function and exit with its return code
main
exit $?