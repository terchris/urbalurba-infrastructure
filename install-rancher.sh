#!/bin/bash
# File: install-rancher.sh
# Description: Sets up a Docker container with Ansible and required tools for Kubernetes management
# Must be started in the root folder of the project
#
# Usage: ./install-rancher.sh [options]
# Options can be provided in any order:
#   rancher-desktop  : Target environment (default)
#   microk8s        : Alternative environment
#   
#   Cloud Provider Options (default: az):
#     az/azure     : Install Azure CLI only
#     oci/oracle   : Install Oracle Cloud CLI only
#     aws         : Install AWS CLI only
#     gcp/google  : Install Google Cloud SDK only
#     tf/terraform: Install Terraform only
#     all         : Install all cloud provider tools
#
# Examples:
#   ./install-rancher.sh                    # Uses defaults (rancher-desktop, az)
#   ./install-rancher.sh aws                # Default environment with AWS CLI
#   ./install-rancher.sh microk8s           # MicroK8s with default cloud provider (az)
#   ./install-rancher.sh microk8s all       # MicroK8s with all cloud tools
#   ./install-rancher.sh aws microk8s       # MicroK8s with AWS CLI (order doesn't matter)

# Exit immediately if a command exits with a non-zero status
set -e

# Initialize default values
ENVIRONMENT="rancher-desktop"
CLOUD_PROVIDER="az"

# Process arguments in any order
for arg in "$@"; do
    case $arg in
        "rancher-desktop"|"microk8s")
            ENVIRONMENT="$arg"
            ;;
        "az"|"azure"|"oci"|"oracle"|"aws"|"gcp"|"google"|"tf"|"terraform"|"all")
            CLOUD_PROVIDER="$arg"
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Valid options:"
            echo "  Environments: rancher-desktop (default), microk8s"
            echo "  Cloud providers: az/azure (default), oci/oracle, aws, gcp/google, tf/terraform, all"
            exit 1
            ;;
    esac
done

echo "Installing for environment: $ENVIRONMENT"
echo "Cloud provider selection: $CLOUD_PROVIDER"

# Function to check the success of the last command and exit if failed
check_command_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed."
        exit 1
    fi
    echo "$1 completed successfully."
}

# Function to ensure the script is run from the root directory of the project
ensure_root_directory() {
    if [ ! -f "README.md" ]; then
        echo "This script must be run from the root directory of the project."
        exit 1
    fi
}

# Function to run a script from a specific directory
run_script_from_directory() {
    local directory=$1
    shift
    local script=$1
    shift
    local args=("$@")

    echo "- Script:$0 -----------------> Running $script ${args[*]} in directory: $directory"
    cd "$directory"
    ./$script "${args[@]}"
    check_command_success "$script in $directory"
    cd - > /dev/null
}

# Ensure the script is run from the root directory
ensure_root_directory

# Check if provision-host container already exists
if docker ps -a --format '{{.Names}}' | grep -q '^provision-host$'; then
    echo "Error: provision-host container already exists. Please remove it first."
    exit 1
fi

# Create Kubernetes secrets
run_script_from_directory "topsecret" "create-kubernetes-secrets.sh"

# Check and create secrets if they don't exist
if [ ! -f "secrets/id_rsa_ansible.pub" ] || [ ! -f "secrets/id_rsa_ansible" ]; then
    echo "==========------------------> Step 0.1: Create secrets"
    run_script_from_directory "secrets" "create-secrets.sh"
fi

# Check if Rancher Desktop is running and Kubernetes is enabled
if ! rdctl list-settings &> /dev/null; then
    echo "Error: Rancher Desktop is not running. Please start Rancher Desktop first."
    exit 1
fi

# Check if kubectl is available and configured
if ! kubectl get nodes &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes. Please ensure Rancher Desktop is running and Kubernetes is ready."
    exit 1
fi

echo "==========------------------> Step 1: Create provision-host container"
run_script_from_directory "provision-host-rancher" "provision-host-container-create.sh" "$CLOUD_PROVIDER"


echo "==========------------------> Step 2: Setup Kubernetes environment (using Rancher Desktop)"
run_script_from_directory "hosts" "install-rancher-kubernetes.sh"


echo "==========------------------> Step 3: Install local kubeconfig - SKIPPED (using Rancher Desktop config)"

# Set up Tailscale for secure networking
echo "==========------------------> Step 4: Setting up Tailscale for secure networking"
echo "Starting and configuring Tailscale..."
docker exec provision-host bash -c "cd /mnt/urbalurbadisk/networking && ./net1-setup-tailscale.sh"
check_command_success "Setting up Tailscale"

# Verify Tailscale connectivity
echo "Verifying Tailscale connectivity..."
docker exec provision-host bash -c "cd /mnt/urbalurbadisk/networking && ./net1-check-tailscale.sh"
check_command_success "Verifying Tailscale connectivity"




echo "----------------------> Start the installation of kubernetes systems <----------------------"

# Prepare the Rancher Desktop environment
echo "Preparing Rancher Desktop environment..."
docker exec provision-host bash -c "chmod +x /mnt/urbalurbadisk/provision-host-rancher/prepare-rancher-environment.sh"
docker exec provision-host bash -c "/mnt/urbalurbadisk/provision-host-rancher/prepare-rancher-environment.sh"

# Run Kubernetes setup commands inside the container
docker exec provision-host bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes && ./provision-kubernetes.sh rancher-desktop default"
check_command_success "Provisioning Kubernetes"


echo "====================  F I N I S H E D  ===================="
echo "The provision-host container is all set up and you can log in to it using: docker exec -it provision-host bash"
echo "."
echo "Kubernetes in Rancher Desktop is all set up and these are the installed systems:"
docker exec provision-host bash -c 'kubectl get pods --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,CLUSTER-IP:.status.podIP,PORTS:.spec.containers[*].ports[*].containerPort"'
echo "."
echo "Tailscale networking is set up for secure access to your infrastructure."
echo "Tailscale IP: $(docker exec provision-host bash -c 'tailscale ip -4')"
echo "."
echo "Connected Tailscale network devices:"
docker exec provision-host bash -c 'tailscale status --json | jq -r "if .Peer != null then .Peer | to_entries[] | .value.HostName + \": \" + (.value.TailscaleIPs[0] // \"No IP\") + \" (\" + (if .value.Online then \"online\" else \"offline\" end) + \")\" else \"No peers connected\" end"'
docker exec provision-host bash -c 'tailscale status --json | jq -r "if .Self != null then .Self | .HostName + \": \" + (.TailscaleIPs[0] // \"No IP\") + \" (self)\" else \"Self status not available\" end"'
echo "."
echo "====================  E N D  O F  I N S T A L L A T I O N  ===================="
exit 0



echo "xxxxxxxxxxxxx xxxxxx xxxxxx Install all steps completed successfully."
exit 1


echo "----------------------> Continue the installation of the default apps <----------------------"


echo "------------------> Store config and status files for: multipass-microk8s"
run_script_from_directory "" "cluster-status.sh" "multipass-microk8s"

echo "### Cloudflare setup (TODO: fix or move)"
echo "------------------> Net 3: Set Cloudflare tunnel and DNS for multipass-microk8s"
run_script_from_directory "networking" "net3-setup-cloudflare.sh" "CLOUDFLARE_TEST"

echo "------------------> Net 4: Deploy the tunnel and expose domains on the internet for multipass-microk8s"
run_script_from_directory "networking" "net4-deploy-cloudflare-tunnel.sh" "CLOUDFLARE_TEST" "multipass-microk8s"



echo "All steps completed successfully."