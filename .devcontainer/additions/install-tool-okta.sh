#!/bin/bash
# file: .devcontainer/additions/install-tool-okta.sh
#
# Installs Okta CLI and VS Code extensions for Okta identity management.
# Okta is a cloud-based identity and access management platform for secure authentication and authorization.
# For usage information, run: ./install-tool-okta.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-okta"
SCRIPT_VER="0.0.3"
SCRIPT_NAME="Okta Identity Management Tools"
SCRIPT_DESCRIPTION="Installs Okta CLI and VS Code extensions for Okta identity and access management"
SCRIPT_CATEGORY="CLOUD_TOOLS"
SCRIPT_CHECK_COMMAND="command -v okta-cli >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="okta identity authentication sso iam security"
SCRIPT_ABSTRACT="Okta identity management tools with CLI and VS Code Okta Explorer extension."
SCRIPT_LOGO="tool-okta-logo.webp"
SCRIPT_WEBSITE="https://www.okta.com"
SCRIPT_SUMMARY="Okta identity and access management toolkit including the Okta CLI for managing users, groups, and applications, plus the Okta Explorer VS Code extension for browsing and managing Okta organizations directly from the IDE."
SCRIPT_RELATED="tool-azure-ops"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Okta identity management tools||false|"
    "Action|--uninstall|Uninstall Okta tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
# System packages (Python already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Node.js packages (not needed for Okta tools)
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=(
    "okta-cli"  # Okta command-line interface for identity management
)

# PowerShell modules (not needed for Okta tools)
PACKAGES_PWSH=()

# VS Code extensions
EXTENSIONS=(
    "Okta Explorer (OktaDcp.okta-explorer) - Browse and manage Okta organizations, users, and groups"
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
        # Note: Python already in devcontainer
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Installed VS Code extensions:"
    echo "  • Okta Explorer - Browse and manage Okta organizations, users, and groups"
    echo
    echo "Quick start:"
    echo "  - Configure Okta:        okta-cli login"
    echo "  - List organizations:    okta-cli orgs list"
    echo "  - List users:            okta-cli users list"
    echo "  - List groups:           okta-cli groups list"
    echo "  - Get help:              okta-cli --help"
    echo
    echo "Infrastructure as Code:"
    echo "  - Terraform provider:    https://registry.terraform.io/providers/okta/okta/latest/docs"
    echo "  - Pulumi provider:       https://www.pulumi.com/registry/packages/okta/"
    echo
    echo "Docs:"
    echo "  - Okta CLI:              https://pypi.org/project/okta-cli/"
    echo "  - Okta GitHub:           https://github.com/flypenguin/okta-cli"
    echo "  - Okta Developer:        https://developer.okta.com/"
    echo "  - Okta API:              https://developer.okta.com/docs/reference/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Okta CLI removed"
    echo "   ✅ VS Code extensions uninstalled"
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
