#!/bin/bash
# file: .devcontainer/additions/install-tool-api-dev.sh
#
# Installs VS Code extensions for API development including REST clients and OpenAPI/Swagger tooling.
# For usage information, run: ./install-tool-api-dev.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-api-dev"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="API Development Tools"
SCRIPT_DESCRIPTION="Installs Thunder Client REST API client and OpenAPI Editor for API development, testing, and documentation"
SCRIPT_CATEGORY="CLOUD_TOOLS"
SCRIPT_CHECK_COMMAND="code --list-extensions 2>/dev/null | grep -q 'rangav.vscode-thunder-client'"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="api rest openapi swagger http client testing"
SCRIPT_ABSTRACT="API development tools with Thunder Client REST client and OpenAPI/Swagger editor."
SCRIPT_LOGO="tool-api-dev-logo.webp"
SCRIPT_WEBSITE="https://www.thunderclient.com"
SCRIPT_SUMMARY="VS Code extensions for API development including Thunder Client for REST API testing and the OpenAPI Editor for Swagger/OpenAPI specification editing and validation. Lightweight alternatives to Postman and Swagger UI."
SCRIPT_RELATED="dev-typescript dev-python tool-azure-dev"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install API development tools||false|"
    "Action|--uninstall|Uninstall API development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
# System packages (none needed - extensions only)
PACKAGES_SYSTEM=()

# Node.js packages (none needed - extensions only)
PACKAGES_NODE=()

# Python packages (none needed - extensions only)
PACKAGES_PYTHON=()

# VS Code extensions
EXTENSIONS=(
    "Thunder Client (rangav.vscode-thunder-client) - Lightweight REST API client"
    "OpenAPI Editor (42crunch.vscode-openapi) - OpenAPI/Swagger editing and validation"
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
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Installed VS Code extensions:"
    echo "  • Thunder Client - Lightweight REST API client"
    echo "  • OpenAPI Editor - OpenAPI/Swagger editing and validation"
    echo
    echo "Thunder Client - Quick start:"
    echo "  - Open Thunder Client panel in VS Code sidebar"
    echo "  - Create new request: Click 'New Request'"
    echo "  - Test API endpoints without leaving VS Code"
    echo "  - Save requests to collections for reuse"
    echo "  - Environment variables support for different configs"
    echo
    echo "OpenAPI Editor - Quick start:"
    echo "  - Create or open .yaml/.json OpenAPI spec file"
    echo "  - Get real-time validation and auto-completion"
    echo "  - Preview API documentation"
    echo "  - Navigate API structure easily"
    echo
    echo "Common workflows:"
    echo "  1. Design API with OpenAPI Editor"
    echo "  2. Test endpoints with Thunder Client"
    echo "  3. Iterate based on testing results"
    echo "  4. Share OpenAPI spec with team"
    echo
    echo "Docs:"
    echo "  - Thunder Client:        https://www.thunderclient.com/docs"
    echo "  - OpenAPI:               https://www.openapis.org/"
    echo "  - 42Crunch OpenAPI:      https://marketplace.visualstudio.com/items?itemName=42Crunch.vscode-openapi"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Thunder Client extension uninstalled"
    echo "   ✅ OpenAPI Editor extension uninstalled"
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
