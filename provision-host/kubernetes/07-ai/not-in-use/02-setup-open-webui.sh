#!/bin/bash
# filename: 02-setup-open-webui.sh
# description: Setup Open WebUI on a Kubernetes cluster using Ansible playbook.
# Also installs the dependencies for the open-webui: 
# - storage : persistent storage for all systems
# - tika : Apache Tika server for document extraction and processing
# - qdrant : Qdrant as a vector database for Open WebUI, replacing the default ChromaDB
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

# Function to check Kubernetes secret
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
        echo "  --from-literal=OPENWEBUI_QDRANT_API_KEY=your-qdrant-api-key"
        return 1
    fi
    
    echo "Secret '$secret_name' found in namespace '$namespace'"
    return 0
}

# Function to check if Helm repos are added
check_helm_repos() {
    echo "Checking Helm repositories..."
    local required_repos=("tika" "qdrant" "ollama-helm" "open-webui")
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

# Main execution
main() {
    echo "Starting Open WebUI AI Stack setup on $TARGET_HOST"
    echo "---------------------------------------------------"
    
    # Check prerequisites
    check_secret || return 1
    check_helm_repos
    
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
        echo "- Qdrant (vector database)"
        echo "- Ollama (local LLM in cluster)"
        echo "- Open WebUI (frontend with direct connections to Ollama instances)"
        echo ""
        
        # Verify deployment status
        echo "Verifying deployment status..."
        echo "Note: Some pods might still be initializing."
        
        # Count running pods
        RUNNING_PODS=$(kubectl get pods -n ai | grep Running | wc -l)
        TOTAL_PODS=$(kubectl get pods -n ai | grep -v NAME | wc -l)
        INIT_PODS=$(kubectl get pods -n ai | grep -E 'ContainerCreating|Init:' | wc -l)
        
        echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"
        echo "Initializing pods: $INIT_PODS"
        
        if [ "$INIT_PODS" -gt 0 ]; then
            echo "Some pods are still initializing. This is normal for first-time deployments."
            
            # Check specifically for Ollama status
            OLLAMA_STATUS=$(kubectl get pods -n ai | grep ollama | awk '{print $3}')
            if [ "$OLLAMA_STATUS" = "ContainerCreating" ]; then
                echo "Note: Ollama is still initializing and may take 10-15 minutes to become ready."
                echo "In the meantime, you can still use models from your host Ollama through OpenWebUI."
            fi
        fi
        
        echo ""
        echo "Architecture:"
        echo "- OpenWebUI connects directly to the in-cluster Ollama model (qwen3:0.6b)"
        echo "- OpenWebUI connects directly to your host Ollama on Mac"
        echo "- You can download and manage models on your host through the OpenWebUI interface"
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