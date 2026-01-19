#!/bin/bash
# file: .devcontainer/additions/install-tool-azure-ops.sh
#
# Installs Azure operations and infrastructure management tools including PowerShell, Azure CLI,
# and VS Code extensions for Azure resource management, policy, and infrastructure automation.
# For usage information, run: ./install-tool-azure-ops.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-azure-ops"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Azure Operations & Infrastructure Management"
SCRIPT_DESCRIPTION="Installs Azure CLI, PowerShell with Az/Graph modules, and VS Code extensions for Azure resource management, policy, Bicep IaC, and KQL queries"
SCRIPT_CATEGORY="CLOUD_TOOLS"
SCRIPT_CHECK_COMMAND="(command -v az >/dev/null 2>&1 && command -v pwsh >/dev/null 2>&1) || [ -f /usr/bin/pwsh ]"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="azure powershell operations infrastructure management policy graph"
SCRIPT_ABSTRACT="Azure operations tools with PowerShell, Az modules, Microsoft Graph, and KQL support."
SCRIPT_LOGO="tool-azure-ops-logo.webp"
SCRIPT_WEBSITE="https://azure.microsoft.com"
SCRIPT_SUMMARY="Azure infrastructure and operations management toolkit including PowerShell 7, Az and Microsoft.Graph modules, Exchange Online Management, Azure CLI, and VS Code extensions for Bicep IaC, KQL queries, and Azure policy management."
SCRIPT_RELATED="tool-azure-dev tool-iac tool-kubernetes"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Azure operations tools||false|"
    "Action|--uninstall|Uninstall Azure operations tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
DEFAULT_VERSION="7.5.4"  # PowerShell 7.5.4 (latest stable as of October 2025)
TARGET_VERSION=""        # Actual version to install (can be overridden with --version)

# System packages
PACKAGES_SYSTEM=(
    "azure-cli"  # Azure command-line interface for resource management
)

# Node.js packages (not needed for PowerShell)
PACKAGES_NODE=()

# Python packages (not needed for PowerShell)
PACKAGES_PYTHON=()

# PowerShell modules
PACKAGES_PWSH=(
    "Az"                          # Azure cloud automation (Resource Manager, Storage, Compute, etc.)
    "Microsoft.Graph"             # Microsoft 365 and Graph API automation
    "ExchangeOnlineManagement"    # Exchange Online management and connections
    "PSScriptAnalyzer"            # PowerShell script analysis and linting
)

# VS Code extensions
EXTENSIONS=(
    "PowerShell (ms-vscode.powershell) - PowerShell language support and debugging"
    "Azure Tools (ms-vscode.vscode-node-azure-pack) - Complete Azure development toolkit"
    "Azure Account (ms-vscode.azure-account) - Azure subscription management and sign-in"
    "Azure Resources (ms-azuretools.vscode-azureresourcegroups) - View and manage Azure resources"
    "Bicep (ms-azuretools.vscode-bicep) - Bicep language support for IaC"
    "Azure Policy (AzurePolicy.azurepolicyextension) - View and manage Azure Policy definitions"
    "Kusto Syntax Highlighting (josin.kusto-syntax-highlighting) - KQL syntax highlighting for log queries"
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

# Custom PowerShell installation function
install_powershell() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing PowerShell installation..."

        # Remove symbolic links
        if [ -L "/usr/local/bin/pwsh" ]; then
            sudo rm -f /usr/local/bin/pwsh
            echo "✅ Removed /usr/local/bin/pwsh symlink"
        fi
        if [ -L "/usr/bin/pwsh" ]; then
            sudo rm -f /usr/bin/pwsh
            echo "✅ Removed /usr/bin/pwsh symlink"
        fi

        # Remove PowerShell installation directory
        if [ -d "/opt/microsoft/powershell" ]; then
            sudo rm -rf /opt/microsoft/powershell
            echo "✅ Removed PowerShell installation directory"
        fi

        # Remove PowerShell modules directory
        if [ -d "$HOME/.local/share/powershell" ]; then
            rm -rf "$HOME/.local/share/powershell"
            echo "✅ Removed PowerShell modules directory"
        fi

        return
    fi

    # Check if PowerShell is already installed
    if command -v pwsh >/dev/null 2>&1; then
        local current_version=$(pwsh -Version 2>&1 | head -n 1)
        echo "✅ PowerShell is already installed (${current_version})"
        return
    fi

    echo "📦 Installing PowerShell from GitHub releases..."

    # PowerShell version to install (latest stable as of 2025)
    local powershell_version="${TARGET_VERSION:-7.5.4}"

    # Detect architecture using lib function
    local system_arch=$(detect_architecture)
    local ps_arch
    local ps_package_url

    # Map to PowerShell naming convention
    case "$system_arch" in
        amd64)
            ps_arch="x64"
            ps_package_url="https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-linux-x64.tar.gz"
            ;;
        arm64)
            ps_arch="arm64"
            ps_package_url="https://github.com/PowerShell/PowerShell/releases/download/v${powershell_version}/powershell-${powershell_version}-linux-arm64.tar.gz"
            ;;
        *)
            echo "❌ Unsupported architecture: $system_arch"
            return 1
            ;;
    esac

    echo "🖥️  Detected architecture: $system_arch (PowerShell: $ps_arch)"

    echo "⬇️  Downloading PowerShell v${powershell_version} for $ps_arch..."
    local temp_tarball="/tmp/powershell.tar.gz"

    if ! curl -L -o "$temp_tarball" "$ps_package_url" 2>/dev/null; then
        echo "❌ Failed to download PowerShell from $ps_package_url"
        return 1
    fi

    echo "📦 Installing PowerShell..."
    # Create PowerShell installation directory
    sudo mkdir -p /opt/microsoft/powershell/7

    # Extract PowerShell to installation directory
    sudo tar zxf "$temp_tarball" -C /opt/microsoft/powershell/7

    # Set executable permissions
    sudo chmod +x /opt/microsoft/powershell/7/pwsh

    # Create symbolic links for maximum compatibility
    # Link to /usr/local/bin (preferred for user-installed software)
    sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh
    # Link to /usr/bin (system-wide availability)
    sudo ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

    # Clean up
    rm -f "$temp_tarball"

    echo "✅ PowerShell installed successfully"

    # Verify installation
    if command -v pwsh >/dev/null 2>&1; then
        echo "✅ PowerShell is now available: $(pwsh -Version 2>&1 | head -n 1)"
    else
        echo "❌ PowerShell installation failed - not found in PATH"
        return 1
    fi
}

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if PowerShell is already installed
        if command -v pwsh >/dev/null 2>&1; then
            echo "✅ PowerShell is already installed (version: $(pwsh -Version 2>&1 | head -n 1))"
        fi

        # Note: apt-get update is run by install_powershell after repository setup
        echo "✅ Pre-installation setup complete"
    fi
}

#------------------------------------------------------------------------------

# --- Post-installation/Uninstallation Messages ---

# Post-installation notes
post_installation_message() {
    local pwsh_version az_version
    pwsh_version=$(pwsh -Version 2>&1 | head -n 1 || echo "not found")
    az_version=$(az version --output tsv 2>/dev/null | head -n 1 | cut -f2 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   PowerShell: $pwsh_version"
    echo "   Azure CLI: $az_version"
    echo
    echo "Installed tools:"
    echo "  • Azure CLI - Azure resource management via command line"
    echo "  • PowerShell 7 - Cross-platform automation and scripting"
    echo
    echo "Installed PowerShell modules:"
    echo "  • Az - Azure cloud automation (Resource Manager, Storage, Compute, etc.)"
    echo "  • Microsoft.Graph - Microsoft 365 and Graph API automation"
    echo "  • ExchangeOnlineManagement - Exchange Online management and connections"
    echo "  • PSScriptAnalyzer - PowerShell script analysis and linting"
    echo
    echo "Installed VS Code extensions:"
    echo "  • PowerShell - Language support and debugging"
    echo "  • Azure Tools - Complete Azure development toolkit"
    echo "  • Azure Account - Azure subscription management and sign-in"
    echo "  • Azure Resources - View and manage Azure resources"
    echo "  • Bicep - Bicep language support for IaC"
    echo "  • Azure Policy - View and manage Azure Policy definitions"
    echo "  • Kusto Syntax Highlighting - KQL syntax highlighting for log queries"
    echo
    echo "Quick start - Azure CLI:"
    echo "  - Login to Azure:         az login"
    echo "  - List subscriptions:     az account list"
    echo "  - List resource groups:   az group list"
    echo "  - List VMs:               az vm list"
    echo "  - Get help:               az --help"
    echo
    echo "Quick start - PowerShell:"
    echo "  - Launch PowerShell:      pwsh"
    echo "  - Import Az:              Import-Module Az"
    echo "  - Connect to Azure:       Connect-AzAccount"
    echo "  - List subscriptions:     Get-AzSubscription"
    echo
    echo "Infrastructure as Code - Bicep:"
    echo "  - Create main.bicep file and use VS Code extension for authoring"
    echo "  - Deploy:                 az deployment group create --resource-group <rg> --template-file main.bicep"
    echo "  - Build to ARM:           az bicep build --file main.bicep"
    echo "  - Bicep docs:             https://learn.microsoft.com/azure/azure-resource-manager/bicep/"
    echo
    echo "Azure Policy management:"
    echo "  - List policies:          az policy definition list"
    echo "  - Assign policy:          az policy assignment create"
    echo "  - Policy docs:            https://learn.microsoft.com/azure/governance/policy/"
    echo
    echo "Log Analytics - KQL queries:"
    echo "  - Create .kql files for syntax highlighting in VS Code"
    echo "  - Run queries in Azure Portal Log Analytics workspace"
    echo "  - KQL docs:               https://learn.microsoft.com/azure/data-explorer/kusto/query/"
    echo
    echo "Docs:"
    echo "  - Azure CLI:              https://learn.microsoft.com/cli/azure/"
    echo "  - PowerShell:             https://learn.microsoft.com/powershell/"
    echo "  - Az Module:              https://learn.microsoft.com/powershell/azure/"
    echo "  - Microsoft.Graph:        https://learn.microsoft.com/powershell/microsoftgraph/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Azure CLI removed"
    echo "   ✅ PowerShell removed from /opt/microsoft/powershell"
    echo "   ✅ PowerShell modules removed from ~/.local/share/powershell"
    echo "   ✅ Symbolic links removed from /usr/local/bin and /usr/bin"
    echo "   ✅ VS Code extensions uninstalled"
    echo
    echo "Note: Run 'hash -r' or start a new shell to clear the command hash table"
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
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # During uninstall: only process VS Code extensions
        # PowerShell modules will be removed when we delete the directories
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        # Remove PowerShell runtime and all its modules
        install_powershell
    else
        # During install: install PowerShell runtime first
        install_powershell
        # Then install modules and extensions (now that PowerShell is available)
        process_standard_installations
    fi
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
