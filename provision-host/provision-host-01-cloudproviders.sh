#!/bin/bash
# filename: provision-host-01-cloudproviders.sh
# description: Installs software for cloud providers on the provision host.
#
# Usage: This script can be run with a specific cloud provider parameter:
#   az/azure     - Install Azure CLI only (default)
#   oci/oracle   - Install Oracle Cloud CLI only
#   aws          - Install AWS CLI only
#   gcp/google   - Install Google Cloud SDK only
#   tf/terraform - Install Terraform only
#   all          - Install all cloud provider tools
#
# Example: ./provision-host-01-cloudproviders.sh aws

# Run systemctl daemon-reload to address unit file changes
if [ "$RUNNING_IN_CONTAINER" != "true" ]; then
    sudo systemctl daemon-reload
else
    echo "Skipping systemctl daemon-reload in container environment"
fi

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

# Install Azure CLI
install_azure_cli() {
    if [ "$RUNNING_IN_CONTAINER" = "true" ]; then
        echo "Installing Azure CLI in container environment"
        # Skip systemctl operations in container
        if curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; then
            AZ_VERSION=$(az --version | head -n 1 | cut -d' ' -f2)
            add_status "Azure CLI" "Status" "Installed (v${AZ_VERSION})"
            return 0
        else
            add_error "Azure CLI" "Installation failed"
            return 1
        fi
    else
        echo "Installing Azure CLI"
        if curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash; then
            sudo systemctl enable --now azure-cli
            AZ_VERSION=$(az --version | head -n 1 | cut -d' ' -f2)
            add_status "Azure CLI" "Status" "Installed (v${AZ_VERSION})"
            return 0
        else
            add_error "Azure CLI" "Installation failed"
            return 1
        fi
    fi
}

# Install OCI CLI for ansible user
install_oci_cli() {
    OCI_DIR="$HOME/oracle-cli"
    if [ -d "$OCI_DIR/venv" ] && "$OCI_DIR/venv/bin/oci" --version &>/dev/null; then
        OCI_VERSION=$("$OCI_DIR/venv/bin/oci" --version 2>&1)
        add_status "OCI CLI" "Status" "Already installed (${OCI_VERSION})"
    else
        echo "Installing OCI CLI for the current user"
        check_architecture "OCI CLI" || return 1
        
        PYTHON_VERSION=$(python3 --version 2>&1 | cut -d" " -f2 | cut -d. -f1-2)
        sudo apt-get install -qq -y python3-venv python${PYTHON_VERSION}-venv || {
            add_error "OCI CLI" "Failed to install Python venv"
            return 1
        }
        mkdir -p "$OCI_DIR" || {
            add_error "OCI CLI" "Failed to create OCI directory"
            return 1
        }
        python3 -m venv "$OCI_DIR/venv" || {
            add_error "OCI CLI" "Failed to create virtual environment"
            return 1
        }
        "$OCI_DIR/venv/bin/pip" install --upgrade pip oci-cli || {
            add_error "OCI CLI" "Failed to install OCI CLI"
            return 1
        }

        if ! "$OCI_DIR/venv/bin/oci" --version &>/dev/null; then
            add_error "OCI CLI" "OCI CLI installation failed"
            return 1
        fi

        OCI_VERSION=$("$OCI_DIR/venv/bin/oci" --version 2>&1)
        add_status "OCI CLI" "Status" "Installed (${OCI_VERSION})"
    fi

    # Add OCI CLI to PATH in user's .bashrc if not already present
    if ! grep -q "# OCI CLI setup" "$HOME/.bashrc"; then
        echo "" >> "$HOME/.bashrc"
        echo "# OCI CLI setup" >> "$HOME/.bashrc"
        echo "export PATH=\$PATH:$OCI_DIR/venv/bin" >> "$HOME/.bashrc" || {
            add_error "OCI CLI" "Failed to update .bashrc"
            return 1
        }
        echo "OCI CLI added to PATH in .bashrc"
    fi

    # Update .bash_profile to source .bashrc if it exists
    if [ -f "$HOME/.bash_profile" ]; then
        if ! grep -q "source ~/.bashrc" "$HOME/.bash_profile"; then
            echo "" >> "$HOME/.bash_profile"
            echo "# Source .bashrc if it exists" >> "$HOME/.bash_profile"
            echo "if [ -f ~/.bashrc ]; then" >> "$HOME/.bash_profile"
            echo "    source ~/.bashrc" >> "$HOME/.bash_profile"
            echo "fi" >> "$HOME/.bash_profile" || {
                add_error "OCI CLI" "Failed to update .bash_profile"
                return 1
            }
            echo ".bash_profile updated to source .bashrc"
        fi
    else
        echo "# Source .bashrc if it exists" > "$HOME/.bash_profile"
        echo "if [ -f ~/.bashrc ]; then" >> "$HOME/.bash_profile"
        echo "    source ~/.bashrc" >> "$HOME/.bash_profile"
        echo "fi" >> "$HOME/.bash_profile" || {
            add_error "OCI CLI" "Failed to create .bash_profile"
            return 1
        }
        echo ".bash_profile created and set to source .bashrc"
    fi

    # Source .bashrc to update PATH in the current session
    source "$HOME/.bashrc"

    # Verify OCI CLI is in PATH
    if ! command -v oci &>/dev/null; then
        add_error "OCI CLI" "OCI CLI not found in PATH after installation"
        return 1
    fi

    echo "OCI CLI installation and PATH setup completed successfully"
    return 0
}

# Install AWS CLI
install_aws_cli() {
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version 2>&1)
        add_status "AWS CLI" "Status" "Already installed (${AWS_VERSION})"
        return 0
    fi

    echo "Installing AWS CLI"
    check_architecture "AWS CLI" || return 1
    
    # Ensure unzip is installed
    if ! command -v unzip &> /dev/null; then
        echo "Installing unzip..."
        sudo apt-get update && sudo apt-get install -y unzip || {
            add_error "AWS CLI" "Failed to install unzip"
            return 1
        }
    fi
    
    rm -rf aws awscliv2.zip

    if [ "$ARCHITECTURE" = "x86_64" ]; then
        AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    elif [ "$ARCHITECTURE" = "aarch64" ]; then
        AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
    else
        add_error "AWS CLI" "Unsupported architecture: $ARCHITECTURE"
        return 1
    fi

    curl "$AWS_CLI_URL" -o "awscliv2.zip" || {
        add_error "AWS CLI" "Failed to download AWS CLI"
        return 1
    }
    unzip -q awscliv2.zip || {
        add_error "AWS CLI" "Failed to unzip AWS CLI"
        return 1
    }
    sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update || {
        add_error "AWS CLI" "Failed to install AWS CLI"
        return 1
    }
    rm -rf aws awscliv2.zip

    AWS_VERSION=$(aws --version 2>&1)
    add_status "AWS CLI" "Status" "Installed (${AWS_VERSION})"
    return 0
}

# Install Terraform
install_terraform() {
    if command -v terraform &> /dev/null; then
        TERRAFORM_VERSION=$(terraform --version | head -n 1)
        add_status "Terraform" "Status" "Already installed (${TERRAFORM_VERSION})"
        return 0
    fi

    echo "Installing Terraform"
    check_architecture "Terraform" || return 1
    
    if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
        curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg || return 1
    fi

    if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null || return 1
    fi

    sudo apt-get update -qq || return 1
    sudo apt-get install -qq -y terraform || return 1

    TERRAFORM_VERSION=$(terraform --version | head -n 1)
    add_status "Terraform" "Status" "Installed (${TERRAFORM_VERSION})"
    return 0
}

# Install Google Cloud SDK
install_gcloud_sdk() {
    if command -v gcloud &> /dev/null; then
        GCLOUD_VERSION=$(gcloud --version 2>/dev/null | head -n 1)
        add_status "Google Cloud SDK" "Status" "Already installed (${GCLOUD_VERSION})"
        return 0
    fi

    echo "Installing Google Cloud SDK"
    check_architecture "Google Cloud SDK" || return 1
    
    if [ ! -f /usr/share/keyrings/cloud.google.gpg ]; then
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloud.google.gpg || return 1
    fi

    if [ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list ]; then
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list || return 1
    fi

    sudo apt-get update -qq || return 1
    sudo apt-get install -qq -y google-cloud-sdk || return 1

    GCLOUD_VERSION=$(gcloud --version 2>/dev/null | head -n 1)
    add_status "Google Cloud SDK" "Status" "Installed (${GCLOUD_VERSION})"
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

    for tool in "Azure CLI" "OCI CLI" "AWS CLI" "Terraform" "Google Cloud SDK"; do
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
    echo "Cloud Provider Installation Script"
    echo "================================="
    echo "Available options:"
    echo "  az/azure     - Install Azure CLI only (default)"
    echo "  oci/oracle   - Install Oracle Cloud CLI only"
    echo "  aws          - Install AWS CLI only"
    echo "  gcp/google   - Install Google Cloud SDK only"
    echo "  tf/terraform - Install Terraform only"
    echo "  all          - Install all cloud provider tools"
    echo "---------------------------------------------------"
    echo "Starting cloud provider tools installation on $(hostname)"
    echo "System Architecture: ${ARCHITECTURE}"
    echo "Cloud Provider Selection: ${1:-az}"
    echo "---------------------------------------------------"

    trap cleanup EXIT

    # Run apt update once at the beginning
    sudo apt-get update -qq || return 1
    sudo apt-get install -qq -y gnupg software-properties-common curl apt-transport-https ca-certificates || return 1

    # Handle selective installation based on parameter
    case "${1:-az}" in
        "az"|"azure")
            install_azure_cli || echo "Azure CLI installation failed"
            ;;
        "oci"|"oracle")
            install_oci_cli || echo "OCI CLI installation failed"
            ;;
        "aws")
            install_aws_cli || echo "AWS CLI installation failed"
            ;;
        "gcp"|"google")
            install_gcloud_sdk || echo "Google Cloud SDK installation failed"
            ;;
        "tf"|"terraform")
            install_terraform || echo "Terraform installation failed"
            ;;
        "all")
            install_azure_cli || echo "Azure CLI installation failed but continuing"
            install_oci_cli || echo "OCI CLI installation failed but continuing"
            install_aws_cli || echo "AWS CLI installation failed but continuing"
            install_terraform || echo "Terraform installation failed but continuing"
            install_gcloud_sdk || echo "Google Cloud SDK installation failed but continuing"
            ;;
        *)
            echo "Unknown cloud provider: $1"
            echo "Supported options: az/azure (default), oci/oracle, aws, gcp/google, tf/terraform, all"
            return 1
            ;;
    esac

    print_summary
    return 0
}

# Run the main function with the provided parameter
main "$1"
exit $?