#!/bin/bash
# file: .devcontainer/additions/install-dev-bash.sh
#
# Installs Bash development environment with shellcheck, shfmt, and VS Code extensions.
# For usage information, run: ./install-dev-bash.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-bash"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Bash Development Tools"
SCRIPT_DESCRIPTION="Adds shellcheck, shfmt, bash-language-server, and VS Code extensions for Bash development"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="command -v shellcheck >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="bash shell scripting shellcheck shfmt linting formatting"
SCRIPT_ABSTRACT="Bash scripting environment with shellcheck linting, shfmt formatting, and language server support."
SCRIPT_LOGO="dev-bash-logo.webp"
SCRIPT_WEBSITE="https://www.gnu.org/software/bash/"
SCRIPT_SUMMARY="Complete Bash development setup including shellcheck for static analysis and linting, shfmt for code formatting, and bash-language-server for IDE features like autocomplete and go-to-definition. Includes VS Code extensions for inline warnings and format-on-save."
SCRIPT_RELATED="dev-python dev-typescript"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Bash development tools||false|"
    "Action|--uninstall|Uninstall Bash development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages (apt-get)
PACKAGES_SYSTEM=(
    "shellcheck"    # Static analysis / linting for shell scripts
    "shfmt"         # Shell script formatter
)

# Node.js packages (npm global)
PACKAGES_NODE=(
    "bash-language-server"  # Autocomplete, go-to-definition, hover docs
)

# VS Code extensions
EXTENSIONS=(
    "ShellCheck (timonwong.shellcheck) - Inline shellcheck warnings"
    "shell-format (foxundermoon.shell-format) - Format on save"
    "Bash IDE (mads-hartmann.bash-ide-vscode) - Language server integration"
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
    local shellcheck_version
    shellcheck_version=$(shellcheck --version 2>/dev/null | grep "^version:" | awk '{print $2}' || echo "not found")

    local shfmt_version
    shfmt_version=$(shfmt --version 2>/dev/null || echo "not found")

    local bls_version
    bls_version=$(bash-language-server --version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   shellcheck: $shellcheck_version"
    echo "   shfmt: $shfmt_version"
    echo "   bash-language-server: $bls_version"
    echo
    echo "Quick start: shellcheck script.sh    # Check for issues"
    echo "             shfmt -w script.sh      # Format script in-place"
    echo "             dev-test lint           # Run linting on project"
    echo
    echo "Docs: https://www.shellcheck.net/"
    echo "      https://github.com/mvdan/sh"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Bash development tools removed"
    echo
}

#------------------------------------------------------------------------------
# MAIN SCRIPT EXECUTION - Do not modify below this line
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

# Export mode flags for core scripts
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Source all core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

# Function to process installations
process_installations() {
    # Process standard installations (packages and extensions)
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
