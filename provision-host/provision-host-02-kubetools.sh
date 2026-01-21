#!/bin/bash
# filename: provision-host-02-kubetools.sh
# description: Installs Kubernetes-related software on the provision host using snap where possible.

# Run systemctl daemon-reload to address unit file changes
sudo systemctl daemon-reload

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Global variable for architecture
ARCHITECTURE=$(uname -m)

# Function to add status
add_status() {
    local tool=$1
    local step=$2
    local status=$3
    STATUS["$tool|$step"]=$status
}

# Function to add error
add_error() {
    local tool=$1
    local error=$2
    ERRORS["$tool"]="${ERRORS[$tool]}${ERRORS[$tool]:+$'\n'}$error"
}

# Function to check command success
check_command_success() {
    local tool=$1
    local step=$2
    if [ $? -ne 0 ]; then
        add_status "$tool" "$step" "Fail"
        add_error "$tool" "$step"
        return 1
    else
        add_status "$tool" "$step" "OK"
        return 0
    fi
}

# Function to check supported architecture
check_architecture() {
    local tool=$1
    if [[ "$ARCHITECTURE" != "x86_64" && "$ARCHITECTURE" != "aarch64" ]]; then
        add_error "$tool" "Unsupported architecture: $ARCHITECTURE"
        return 1
    fi
    return 0
}


# Install Ansible and Kubernetes Python module
install_ansible_kubernetes() {
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version 2>&1 | head -n1 | sed -E 's/ansible \[core ([0-9.]+)\].*/\1/')
        add_status "Ansible" "Status" "Already installed (${ANSIBLE_VERSION})"
    else
        echo "Installing Ansible and Kubernetes Python module"
        sudo apt-get update -qq || return 1
        sudo apt-get install -qq -y software-properties-common || return 1
        sudo add-apt-repository --yes --update ppa:ansible/ansible || return 1

        # Install ansible-core (slim) instead of full ansible package (~350MB savings)
        # Then install only the collections we actually use
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq -y ansible-core python3-kubernetes || return 1
        check_command_success "Ansible" "Installation" || return 1

        # Install only required Ansible collections (used in our playbooks)
        echo "Installing required Ansible collections..."
        ansible-galaxy collection install kubernetes.core --force || return 1
        ansible-galaxy collection install community.postgresql --force || return 1
        ansible-galaxy collection install community.general --force || return 1
        add_status "Ansible Collections" "Status" "kubernetes.core, community.postgresql, community.general"

        ANSIBLE_VERSION=$(ansible --version 2>&1 | head -n1 | sed -E 's/ansible \[core ([0-9.]+)\].*/\1/')
        add_status "Ansible" "Status" "Installed (${ANSIBLE_VERSION})"
    fi

    # Verify Kubernetes module installation
    if python3 -c "import kubernetes; print(kubernetes.__version__)" &> /dev/null; then
        K8S_MODULE_VERSION=$(python3 -c "import kubernetes; print(kubernetes.__version__)")
        add_status "Kubernetes Python Module" "Status" "Installed (${K8S_MODULE_VERSION})"
    else
        add_error "Kubernetes Python Module" "Installation failed"
        return 1
    fi

    # Configure Ansible to work from any directory
    echo "Configuring Ansible global settings"

    # Create global Ansible config directory if it doesn't exist
    sudo mkdir -p /etc/ansible

    # Create or update the ansible.cfg file using sudo tee
    sudo tee /etc/ansible/ansible.cfg > /dev/null << 'ENDCONFIG'
[defaults]
inventory = /mnt/urbalurbadisk/ansible/inventory.yml
private_key_file = /mnt/urbalurbadisk/secrets/id_rsa_ansible
host_key_checking = False
roles_path = /mnt/urbalurbadisk/ansible/roles

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
ENDCONFIG

    # Set permissions
    sudo chmod 644 /etc/ansible/ansible.cfg

    add_status "Ansible Config" "Status" "Global configuration created"

    return 0
}

# Install kubectl
install_kubectl() {
    if command -v kubectl &> /dev/null; then
        KUBECTL_VERSION=$(kubectl version --client 2>&1 | grep -oP 'Client Version: v\K[0-9.]+')
        add_status "kubectl" "Status" "Already installed (v${KUBECTL_VERSION})"
        return 0
    fi

    echo "Installing kubectl"
    # Check if we're in a container or if snap is available
    if [ "$RUNNING_IN_CONTAINER" = "true" ] || ! command -v snap &> /dev/null; then
        echo "Installing kubectl directly (not using snap)"
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/$(dpkg --print-architecture)/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        KUBECTL_VERSION=$(kubectl version --client --output=yaml | grep gitVersion | cut -d' ' -f4)
        add_status "kubectl" "Status" "Installed (${KUBECTL_VERSION})"
    else
        echo "Installing kubectl using snap"
        if sudo snap install kubectl --classic; then
            KUBECTL_VERSION=$(kubectl version --client 2>&1 | grep -oP 'Client Version: v\K[0-9.]+')
            add_status "kubectl" "Status" "Installed (v${KUBECTL_VERSION})"
            return 0
        else
            add_error "kubectl" "Installation failed"
            return 1
        fi
    fi
}

# Install k9s
install_k9s() {
    if command -v k9s &> /dev/null; then
        K9S_VERSION=$(k9s version 2>&1 | grep "Version:" | tr -d '\r')
        add_status "k9s" "Status" "Already installed (${K9S_VERSION})"
        return 0
    fi

    echo "Installing k9s"
    check_architecture "k9s" || return 1

    if [ "$ARCHITECTURE" = "x86_64" ]; then
        ARCH_NAME="amd64"
    elif [ "$ARCHITECTURE" = "aarch64" ]; then
        ARCH_NAME="arm64"
    else
        add_error "k9s" "Unsupported architecture: $ARCHITECTURE"
        return 1
    fi

    LATEST_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    if [ -z "$LATEST_VERSION" ]; then
        add_error "k9s" "Failed to retrieve latest version"
        return 1
    fi

    TEMP_DIR=$(mktemp -d)
    curl -L "https://github.com/derailed/k9s/releases/download/${LATEST_VERSION}/k9s_Linux_${ARCH_NAME}.tar.gz" -o "${TEMP_DIR}/k9s.tar.gz" || {
        add_error "k9s" "Failed to download k9s"
        rm -rf "${TEMP_DIR}"
        return 1
    }

    tar -xzf "${TEMP_DIR}/k9s.tar.gz" -C "${TEMP_DIR}" || {
        add_error "k9s" "Failed to extract k9s"
        rm -rf "${TEMP_DIR}"
        return 1
    }

    sudo mv "${TEMP_DIR}/k9s" /usr/local/bin/ || {
        add_error "k9s" "Failed to move k9s to /usr/local/bin/"
        rm -rf "${TEMP_DIR}"
        return 1
    }

    sudo chmod +x /usr/local/bin/k9s || {
        add_error "k9s" "Failed to make k9s executable"
        return 1
    }

    rm -rf "${TEMP_DIR}"

    K9S_VERSION=$(k9s version 2>&1 | grep "Version:" | tr -d '\r')
    if [ -z "$K9S_VERSION" ]; then
        add_error "k9s" "Failed to verify k9s installation"
        return 1
    fi

    add_status "k9s" "Status" "Installed (${K9S_VERSION})"
    return 0
}

# Install Helm
install_helm() {
    if command -v helm &> /dev/null; then
        HELM_VERSION=$(helm version --short 2>&1 | cut -d'v' -f2)
        add_status "Helm" "Status" "Already installed (v${HELM_VERSION})"
        return 0
    fi

    echo "Installing Helm"
    check_architecture "Helm" || return 1

    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 || return 1
    chmod 700 get_helm.sh || return 1
    ./get_helm.sh || return 1
    rm get_helm.sh

    HELM_VERSION=$(helm version --short 2>&1 | cut -d'v' -f2)
    add_status "Helm" "Status" "Installed (v${HELM_VERSION})"
    return 0
}

# Cleanup function
cleanup() {
    echo "Performing cleanup..."
    sudo apt-get clean -qq
    sudo apt-get autoremove -qq -y
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    echo "System Architecture: $ARCHITECTURE"
    echo "---------------------------------------------------"

    for tool in "Ansible" "Kubernetes Python Module" "kubectl" "k9s" "Helm"; do
        echo "$tool: ${STATUS[$tool|Status]:-Not installed}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All installations completed successfully."
    else
        echo "Errors occurred during installation:"
        for tool in "${!ERRORS[@]}"; do
            echo "  $tool: ${ERRORS[$tool]}"
        done
    fi
}

# Main execution
main() {
    echo "Starting Kubernetes tools installation on $(hostname)"
    echo "System Architecture: $ARCHITECTURE"
    echo "---------------------------------------------------"

    trap cleanup EXIT

    # Run apt update once at the beginning
    sudo apt-get update -qq || return 1

    # Install curl; skip snapd in containers (not needed and saves ~91MB)
    if [ "$RUNNING_IN_CONTAINER" = "true" ]; then
        sudo apt-get install -qq -y curl || return 1
    else
        sudo apt-get install -qq -y curl snapd || return 1
    fi

    install_ansible_kubernetes || return 1
    install_kubectl || return 1
    install_k9s || return 1
    install_helm || return 1

    print_summary

    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?