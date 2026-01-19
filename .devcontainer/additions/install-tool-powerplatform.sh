#!/bin/bash
# file: .devcontainer/additions/install-tool-powerplatform.sh
#
# Installs Microsoft Power Platform CLI (pac) and VS Code extensions for Power Platform development.
# Power Platform is Microsoft's cloud platform for building business apps, workflows, and custom components.
# For usage information, run: ./install-tool-powerplatform.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-powerplatform"
SCRIPT_VER="0.0.3"
SCRIPT_NAME="Microsoft Power Platform Tools"
SCRIPT_DESCRIPTION="Installs Power Platform CLI (pac - dotnet global tool), Power Platform Tools VS Code extension. Requires .NET SDK and x64 (AMD64) architecture."
SCRIPT_CATEGORY="CLOUD_TOOLS"
SCRIPT_CHECK_COMMAND="[ -f $HOME/.dotnet/tools/pac ] || command -v pac >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="powerplatform powerapps powerautomate microsoft lowcode pcf"
SCRIPT_ABSTRACT="Microsoft Power Platform CLI (pac) for Power Apps, Power Automate, and PCF development."
SCRIPT_LOGO="tool-powerplatform-logo.webp"
SCRIPT_WEBSITE="https://powerplatform.microsoft.com"
SCRIPT_SUMMARY="Microsoft Power Platform development toolkit including the Power Platform CLI (pac) as a .NET global tool for managing Power Apps, Power Automate flows, Dataverse solutions, and Power Platform Component Framework (PCF) controls. Requires .NET SDK."
SCRIPT_RELATED="tool-azure-dev dev-csharp"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Power Platform tools||false|"
    "Action|--uninstall|Uninstall Power Platform tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
# System packages (not needed - .NET SDK handled by prerequisite)
PACKAGES_SYSTEM=()

# Node.js packages (PCF development uses pac pcf commands)
PACKAGES_NODE=()

# Python packages (not needed for Power Platform)
PACKAGES_PYTHON=()

# PowerShell modules (not needed for Power Platform)
PACKAGES_PWSH=()

# .NET global tools
PACKAGES_DOTNET=(
    "Microsoft.PowerApps.CLI.Tool"
)

# VS Code extensions
EXTENSIONS=(
    "Power Platform Tools (microsoft-IsvExpTools.powerplatform-vscode) - Power Platform CLI integration and development tools"
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

        # Check for .NET SDK prerequisite
        if ! command -v dotnet >/dev/null 2>&1; then
            echo "❌ .NET SDK is required but not installed"
            echo ""
            echo "Power Platform CLI requires .NET SDK to install and run."
            echo "Please install .NET SDK first:"
            echo "  .devcontainer/additions/install-dev-csharp.sh"
            echo ""
            exit 1
        fi

        local dotnet_version=$(dotnet --version 2>/dev/null)
        echo "✅ .NET SDK detected (version: $dotnet_version)"

        # Check architecture - Power Platform CLI only supports x64 on Linux
        local system_arch=$(detect_architecture)
        if [ "$system_arch" != "amd64" ]; then
            echo "❌ Power Platform CLI only supports x64 (AMD64) on Linux"
            echo "   Current architecture: $system_arch"
            echo ""
            echo "Microsoft Power Platform CLI packages are only available for linux-x64."
            echo "ARM64 support is not currently available."
            echo ""
            echo "Alternatives:"
            echo "  - Use a Windows or macOS (Intel) machine for Power Platform development"
            echo "  - Use GitHub Codespaces or Azure DevOps with x64 Linux agents"
            echo "  - Use a VM with x64 architecture"
            echo ""
            exit 1
        fi

        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Installed VS Code extensions:"
    echo "  • Power Platform Tools - CLI integration and development tools"
    echo
    echo "What works in Linux devcontainer (80-90% of development):"
    echo "  ✅ Solution ALM (export/import/pack/unpack) - version control"
    echo "  ✅ PCF development (custom UI components)"
    echo "  ✅ Power Pages development"
    echo "  ✅ Plugin scaffolding (C# code structure)"
    echo "  ✅ Environment management"
    echo "  ✅ CI/CD automation"
    echo "  ✅ Canvas app source control"
    echo "  ✅ Custom connectors"
    echo
    echo "What does NOT work (Windows-only, occasional use):"
    echo "  ❌ Plugin Registration Tool (PRT) - needed once per plugin"
    echo "  ❌ Configuration Migration Tool (CMT) - occasional admin task"
    echo "  ❌ pac data commands - .NET Framework dependency"
    echo "  ❌ pac package deploy/show - .NET Framework dependency"
    echo
    echo "Quick start:"
    echo "  - Authenticate:          pac auth create --deviceCode"
    echo "  - List environments:     pac org list"
    echo "  - Select environment:    pac org select --environment <url>"
    echo "  - Export solution:       pac solution export --name <solution>"
    echo "  - Create PCF project:    pac pcf init --namespace <ns> --name <name>"
    echo "  - Get help:              pac --help"
    echo
    echo "Common workflows:"
    echo "  - Solution development:  pac solution [export|import|pack|unpack]"
    echo "  - PCF components:        pac pcf [init|push|version]"
    echo "  - Power Pages:           pac paportal [download|upload]"
    echo "  - Plugin scaffolding:    pac plugin init"
    echo "  - Environment admin:     pac admin [create|delete|backup|restore]"
    echo
    echo "Related tools (install separately if needed):"
    echo "  - C# development:        .devcontainer/additions/install-dev-csharp.sh"
    echo "  - TypeScript (PCF):      .devcontainer/additions/install-dev-typescript.sh"
    echo "  - Azure integration:     .devcontainer/additions/install-tool-azure.sh"
    echo
    echo "Docs:"
    echo "  - Power Platform CLI:    https://learn.microsoft.com/power-platform/developer/cli/introduction"
    echo "  - Power Apps:            https://learn.microsoft.com/power-apps/"
    echo "  - Dataverse:             https://learn.microsoft.com/power-apps/developer/data-platform/"
    echo "  - PCF:                   https://learn.microsoft.com/power-apps/developer/component-framework/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Power Platform CLI removed"
    echo "   ✅ Environment removed from ~/.bashrc"
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
source "${SCRIPT_DIR}/lib/core-install-dotnet.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

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
