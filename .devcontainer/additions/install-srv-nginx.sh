#!/bin/bash
# file: .devcontainer/additions/install-srv-nginx.sh
#
# Install nginx as reverse proxy for Claude Code ↔ LiteLLM with Host header injection.
# For usage information, run: ./install-srv-nginx.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="srv-nginx"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Nginx Reverse Proxy"
SCRIPT_DESCRIPTION="Install nginx as reverse proxy for Claude Code ↔ LiteLLM with Host header injection"
SCRIPT_CATEGORY="BACKGROUND_SERVICES"
SCRIPT_CHECK_COMMAND="command -v nginx >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="nginx reverse proxy web server http load balancer"
SCRIPT_ABSTRACT="Nginx reverse proxy for routing requests between Claude Code and LiteLLM services."
SCRIPT_LOGO="srv-nginx-logo.webp"
SCRIPT_WEBSITE="https://nginx.org"
SCRIPT_SUMMARY="Nginx configured as a reverse proxy to route requests between Claude Code and LiteLLM. Handles Host header injection for proper API routing in the devcontainer environment. Uses nginx-light for minimal footprint."
SCRIPT_RELATED="srv-otel dev-ai-claudecode"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install nginx reverse proxy||false|"
    "Action|--uninstall|Uninstall nginx||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "nginx-light"
)

# VS Code extensions
EXTENSIONS=()

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if nginx is already installed
        if command -v nginx >/dev/null 2>&1; then
            echo "✅ Nginx is already installed (version: $(nginx -v 2>&1 | cut -d'/' -f2))"
        fi

        # Update package lists
        sudo apt-get update -qq
    fi
}

# Post-installation notes
post_installation_message() {
    local nginx_version
    nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Nginx: $nginx_version"
    echo
    echo "Quick start: nginx -v && sudo systemctl status nginx"
    echo "Config: /etc/nginx/"
    echo "Docs: https://nginx.org/en/docs/"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    if command -v nginx >/dev/null 2>&1; then
        echo "   ⚠️  Nginx still found in PATH"
    else
        echo "   ✅ Nginx removed"
    fi
    echo
    echo "Note: Configuration files in /etc/nginx/ may remain"
    echo "Remove with: sudo rm -rf /etc/nginx/"
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
