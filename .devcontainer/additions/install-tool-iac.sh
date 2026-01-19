#!/bin/bash
# file: .devcontainer/additions/install-tool-iac.sh
#
# Installs tools and extensions for Infrastructure as Code (IaC) and configuration management (Ansible).
# For usage information, run: ./install-tool-iac.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-iac"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Infrastructure as Code Tools"
SCRIPT_DESCRIPTION="Installs Infrastructure as Code and configuration management tools: Ansible, Terraform, and Bicep"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="command -v ansible >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1 || command -v bicep >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="terraform ansible bicep infrastructure devops automation"
SCRIPT_ABSTRACT="Infrastructure as Code tools with Terraform, Ansible, and Azure Bicep support."
SCRIPT_LOGO="tool-iac-logo.webp"
SCRIPT_WEBSITE="https://www.terraform.io"
SCRIPT_SUMMARY="Complete Infrastructure as Code toolkit including Terraform for multi-cloud provisioning, Ansible for configuration management and automation, ansible-lint for playbook validation, and Azure Bicep for ARM template development with VS Code extensions."
SCRIPT_RELATED="tool-kubernetes tool-azure-ops tool-azure-dev"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Infrastructure as Code tools||false|"
    "Action|--uninstall|Uninstall Infrastructure as Code tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "ansible"
    "ansible-lint"
    "terraform"  # Installed from HashiCorp APT repository
)

# Node.js packages
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=()

# VS Code extensions
EXTENSIONS=(
    "Ansible (redhat.ansible) - Ansible language support and tools"
    "Terraform (hashicorp.terraform) - Terraform language support and IntelliSense"
    "Bicep (ms-azuretools.vscode-bicep) - Azure Bicep language support"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Add HashiCorp repository for Terraform
        add_hashicorp_repository
    fi
}

# --- Add HashiCorp Repository ---
add_hashicorp_repository() {
    echo "➕ Adding HashiCorp repository..."

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="$keyring_dir/hashicorp-archive-keyring.gpg"
    local repo_file="/etc/apt/sources.list.d/hashicorp.list"

    # Check if repository already configured
    if [ -f "$repo_file" ] && grep -q "apt.releases.hashicorp.com" "$repo_file" 2>/dev/null; then
        echo "✅ HashiCorp repository already configured"
        sudo apt-get update -y > /dev/null 2>&1
        return
    fi

    # Create keyrings directory if needed
    sudo mkdir -p "$keyring_dir"

    # Download and install HashiCorp signing key
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
        sudo gpg --dearmor -o "$keyring_file"

    # Add HashiCorp repository
    local distro_codename=$(lsb_release -cs)
    echo "deb [signed-by=$keyring_file] https://apt.releases.hashicorp.com ${distro_codename} main" | \
        sudo tee "$repo_file"

    # Update package lists
    sudo apt-get update -y > /dev/null 2>&1
    echo "✅ HashiCorp repository added successfully"
}

# --- Custom Bicep Installation ---
install_bicep() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Uninstalling Bicep..."
        sudo rm -f /usr/local/bin/bicep
        echo "✅ Bicep removed"
        return
    fi

    # Check if bicep is already installed
    if command -v bicep >/dev/null 2>&1; then
        local current_version=$(bicep --version 2>/dev/null || echo "unknown")
        echo "✅ Bicep is already installed (version: ${current_version})"
        return
    fi

    echo ""
    echo "📦 Installing Bicep CLI..."

    # Detect architecture using lib function
    local system_arch=$(detect_architecture)

    # Map to Bicep naming convention
    local bicep_arch
    case "$system_arch" in
        amd64)
            bicep_arch="x64"
            ;;
        arm64)
            bicep_arch="arm64"
            ;;
        *)
            echo "❌ Unsupported architecture: $system_arch"
            return 1
            ;;
    esac

    echo "   System architecture: $system_arch (Bicep: $bicep_arch)"

    # Download latest Bicep CLI for Linux
    local bicep_url="https://github.com/Azure/bicep/releases/latest/download/bicep-linux-${bicep_arch}"
    local temp_file=$(mktemp)

    if curl -fsSL "$bicep_url" -o "$temp_file"; then
        sudo install -m 755 "$temp_file" /usr/local/bin/bicep
        rm -f "$temp_file"

        # Verify installation
        if command -v bicep >/dev/null 2>&1; then
            local version=$(bicep --version 2>/dev/null || echo "unknown")
            echo "✅ Bicep installed successfully (version: ${version})"
        else
            echo "❌ Bicep installation verification failed"
            return 1
        fi
    else
        echo "❌ Failed to download Bicep"
        rm -f "$temp_file"
        return 1
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Quick start commands:"
    echo "  - Check Ansible:   ansible --version"
    echo "  - Check Terraform: terraform version"
    echo "  - Check Bicep:     bicep --version"
    echo "  - Ansible playbook: ansible-playbook playbook.yml"
    echo "  - Terraform init:   terraform init"
    echo "  - Bicep build:      bicep build main.bicep"
    echo
    echo "Docs: https://docs.ansible.com"
    echo "      https://developer.hashicorp.com/terraform/docs"
    echo "      https://learn.microsoft.com/azure/azure-resource-manager/bicep/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo
    echo "Note: Configuration files remain in ~/.ansible and ~/.terraform.d"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Custom Bicep installation first
    install_bicep || exit 1

    # Then use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
