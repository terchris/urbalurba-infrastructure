#!/bin/bash
# file: .devcontainer/additions/install-tool-dev-utils.sh
#
# Installs general development utilities useful across multiple programming languages.
# These tools are language-agnostic and can be used with PHP, Python, Node.js, Java, C#, etc.
# For usage information, run: ./install-tool-dev-utils.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-dev-utils"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Development Utilities"
SCRIPT_DESCRIPTION="Database management (SQLTools), API testing (REST Client), and container management (Docker) for multi-language development"
SCRIPT_CATEGORY="INFRA_CONFIG"

# NOTE: We check only the primary extension (SQLTools) instead of all extensions
# to avoid tight coupling between SCRIPT_CHECK_COMMAND and the EXTENSIONS array.
# This makes the script more maintainable - if someone adds/removes extensions,
# they don't need to update this check. The extension installer is idempotent anyway.
SCRIPT_CHECK_COMMAND="code --list-extensions 2>/dev/null | grep -q 'mtxr.sqltools'"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="database sql docker containers rest http utilities"
SCRIPT_ABSTRACT="Development utilities for database management, API testing, and Docker container management."
SCRIPT_LOGO="tool-dev-utils-logo.webp"
SCRIPT_WEBSITE="https://vscode-sqltools.mteixeira.dev"
SCRIPT_SUMMARY="Language-agnostic development utilities including SQLTools for database management (MySQL, PostgreSQL, SQLite, MSSQL, MongoDB), REST Client for HTTP API testing, and Docker extension for container, image, and volume management."
SCRIPT_RELATED="tool-api-dev tool-kubernetes"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install development utilities||false|"
    "Action|--uninstall|Uninstall development utilities||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "docker.io"  # Docker CLI for container management
)

# Node.js packages
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=()

# VS Code extensions
EXTENSIONS=(
    "SQLTools (mtxr.sqltools) - Database management and SQL query tool for MySQL, PostgreSQL, SQLite, MSSQL, MongoDB"
    "REST Client (humao.rest-client) - Send HTTP requests and view responses directly in VS Code"
    "Docker (ms-azuretools.vscode-docker) - Manage containers, images, volumes, networks, and Dockerfiles"
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
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Quick start:"
    echo "  - Test Docker:  docker ps"
    echo "  - Docker UI:    Click Docker icon in VS Code sidebar"
    echo "  - SQLTools:     Click database icon in VS Code sidebar"
    echo "  - REST Client:  Create .http file and write HTTP requests"
    echo
    echo "Example .http file:"
    echo "  GET https://api.github.com/users/octocat"
    echo
    echo "Docs: https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker"
    echo "      https://marketplace.visualstudio.com/items?itemName=mtxr.sqltools"
    echo "      https://marketplace.visualstudio.com/items?itemName=humao.rest-client"
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
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

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
