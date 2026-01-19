#!/bin/bash
# file: .devcontainer/additions/install-tool-azure-dev.sh
#
# Installs Azure development tools including Azure CLI, Functions Core Tools, Azurite,
# and VS Code extensions for building Azure applications, APIs, and data solutions.
# For usage information, run: ./install-tool-azure-dev.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-azure-dev"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Azure Application Development"
SCRIPT_DESCRIPTION="Installs Azure CLI, Functions Core Tools, Azurite, and VS Code extensions for building Azure applications, APIs, Service Bus, and Cosmos DB solutions"
SCRIPT_CATEGORY="CLOUD_TOOLS"
SCRIPT_CHECK_COMMAND="[ -f /usr/bin/az ] || [ -f /usr/local/bin/az ] || command -v az >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="azure microsoft cloud functions azurite cosmosdb servicebus bicep"
SCRIPT_ABSTRACT="Azure application development with CLI, Functions, Azurite emulator, and VS Code extensions."
SCRIPT_LOGO="tool-azure-dev-logo.webp"
SCRIPT_WEBSITE="https://azure.microsoft.com"
SCRIPT_SUMMARY="Complete Azure development toolkit including Azure CLI, Functions Core Tools v4, Azurite storage emulator, and VS Code extensions for App Service, Functions, Storage, Service Bus, Cosmos DB, and Bicep infrastructure as code."
SCRIPT_RELATED="tool-azure-ops tool-kubernetes tool-iac"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Azure development tools||false|"
    "Action|--uninstall|Uninstall Azure development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "azure-cli"  # Installed from Microsoft APT repository
)

# Node.js packages (cross-platform: works on x86_64 and ARM64)
PACKAGES_NODE=(
    "azure-functions-core-tools@4"  # Azure Functions runtime v4 (latest)
    "azurite"  # Azure Storage emulator for local development
)

# VS Code extensions
EXTENSIONS=(
    "Azure Account (ms-vscode.azure-account) - Azure account management"
    "Azure Resources (ms-azuretools.vscode-azureresourcegroups) - View and manage Azure resources"
    "Azure App Service (ms-azuretools.vscode-azureappservice) - Deploy to Azure App Service"
    "Azure Functions (ms-azuretools.vscode-azurefunctions) - Create and deploy Azure Functions"
    "Azure Storage (ms-azuretools.vscode-azurestorage) - Manage Azure Storage accounts"
    "Service Bus Explorer (digital-molecules.service-bus-explorer) - Browse queues, topics, and messages"
    "Azure Cosmos DB (ms-azuretools.vscode-cosmosdb) - Cosmos DB and database support"
    "Bicep (ms-azuretools.vscode-bicep) - Bicep language support for IaC"
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

        # Add Azure CLI repository before package installation
        add_azure_cli_repository
    fi
}

# --- Add Azure CLI Repository ---
add_azure_cli_repository() {
    echo "➕ Adding Azure CLI repository..."

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="$keyring_dir/microsoft-azure-cli.gpg"
    local repo_file="/etc/apt/sources.list.d/azure-cli.list"

    # Check if repository already configured
    if [ -f "$repo_file" ] && grep -q "packages.microsoft.com/repos/azure-cli" "$repo_file" 2>/dev/null; then
        echo "✅ Azure CLI repository already configured"
        sudo apt-get update -y > /dev/null 2>&1
        return
    fi

    # Create keyrings directory if needed
    sudo mkdir -p "$keyring_dir"

    # Download and install Microsoft signing key
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor -o "$keyring_file"

    # Add Azure CLI repository
    local distro_codename=$(lsb_release -cs)
    echo "deb [arch=amd64 signed-by=$keyring_file] https://packages.microsoft.com/repos/azure-cli/ ${distro_codename} main" | \
        sudo tee "$repo_file"

    # Update package lists
    sudo apt-get update -y > /dev/null 2>&1
    echo "✅ Azure CLI repository added successfully"
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Installed VS Code extensions:"
    echo "  • Azure Account, Resources, App Service, Functions, Storage"
    echo "  • Service Bus Explorer - Browse queues, topics, and messages"
    echo "  • Azure Cosmos DB - Database management and queries"
    echo "  • Bicep - Infrastructure as Code authoring"
    echo
    echo "Quick start - Azure CLI:"
    echo "  - Login to Azure:        az login"
    echo "  - List subscriptions:    az account list --output table"
    echo "  - Check version:         az version"
    echo
    echo "Quick start - Azure Functions:"
    echo "  - Create Function:       func new"
    echo "  - Init project (C#):     func init --worker-runtime dotnet"
    echo "  - Init project (Python): func init --worker-runtime python"
    echo "  - Init project (Node):   func init --worker-runtime node"
    echo "  - Start locally:         func start"
    echo
    echo "Quick start - Azurite (local storage emulator):"
    echo "  - Start emulator:        azurite"
    echo "  - Connect string:        DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;..."
    echo
    echo "Service Bus development:"
    echo "  - Use Service Bus Explorer extension in VS Code to browse queues/topics"
    echo "  - Connection string:     From Azure Portal → Service Bus → Shared access policies"
    echo
    echo "Cosmos DB development:"
    echo "  - Use Azure Cosmos DB extension to browse and query databases"
    echo "  - Local emulator:        https://learn.microsoft.com/azure/cosmos-db/local-emulator"
    echo
    echo "Infrastructure as Code - Bicep:"
    echo "  - Create main.bicep file and use VS Code extension for authoring"
    echo "  - Deploy:                az deployment group create --resource-group <rg> --template-file main.bicep"
    echo "  - Build to ARM:          az bicep build --file main.bicep"
    echo
    echo "Docs:"
    echo "  - Azure CLI:             https://docs.microsoft.com/cli/azure/"
    echo "  - Azure Functions:       https://learn.microsoft.com/azure/azure-functions/"
    echo "  - Service Bus:           https://learn.microsoft.com/azure/service-bus-messaging/"
    echo "  - Cosmos DB:             https://learn.microsoft.com/azure/cosmos-db/"
    echo "  - Bicep:                 https://learn.microsoft.com/azure/azure-resource-manager/bicep/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
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
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Use standard processing from lib/install-common.sh
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
