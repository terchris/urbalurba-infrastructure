#!/bin/bash
# file: .devcontainer/additions/install-dev-ai-claudecode.sh
#
# Installs Claude Code, Anthropic's terminal-based AI coding assistant.
# For usage information, run: ./install-dev-ai-claudecode.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_NAME="Claude Code"
SCRIPT_ID="dev-ai-claudecode"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Installs Claude Code, Anthropic's terminal-based AI coding assistant with agentic capabilities and LSP integration"
SCRIPT_CATEGORY="AI_TOOLS"
SCRIPT_CHECK_COMMAND="[ -f /home/vscode/.local/bin/claude ] || [ -f /usr/local/bin/claude ] || command -v claude >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="claude anthropic ai coding assistant agentic terminal"
SCRIPT_ABSTRACT="Claude Code - Anthropic's terminal-based AI coding assistant with agentic capabilities."
SCRIPT_LOGO="dev-ai-claudecode-logo.webp"
SCRIPT_WEBSITE="https://claude.ai/code"
SCRIPT_SUMMARY="Claude Code is Anthropic's terminal-based AI coding assistant with agentic capabilities. Features include codebase understanding, multi-file editing, shell command execution, and LSP integration for intelligent code assistance directly in your terminal."
SCRIPT_RELATED="tool-api-dev"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Claude Code||false|"
    "Action|--uninstall|Uninstall Claude Code||false|"
    "Info|--help|Show help and usage information||false|"
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

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        echo "✅ Pre-installation setup complete"
    fi
}

# Define package arrays (remove any empty arrays that aren't needed)
PACKAGES_SYSTEM=(
    "curl"
)

PACKAGES_NODE=(
    "@anthropic-ai/claude-code"
)

PACKAGES_PYTHON=()

# Define VS Code extensions (format: "Name (extension-id) - Description")
EXTENSIONS=()

# Define verification commands
VERIFY_COMMANDS=(
    "command -v claude >/dev/null && echo '✅ Claude Code binary is available' || echo '❌ Claude Code binary not found'"
    "test -L /home/vscode/.claude-code-env && echo '✅ Environment config symlink exists' || echo '⚠️  Environment config symlink not found'"
    "test -d /workspace/.devcontainer.secrets/env-vars && echo '✅ Environment directory exists in .devcontainer.secrets/' || echo '❌ Environment directory not found'"
    "test -d /workspace/.claude/skills && echo '✅ Skills directory exists' || echo '⚠️  Skills directory not found'"
    "grep -q '.devcontainer.secrets/' /workspace/.gitignore && echo '✅ .devcontainer.secrets/ is gitignored' || echo '❌ .devcontainer.secrets/ NOT gitignored (SECURITY RISK!)'"
    "grep -q 'Claude Code environment' /home/vscode/.bashrc && echo '✅ Environment loading added to bashrc' || echo '⚠️  bashrc not configured'"
    "claude --version >/dev/null 2>&1 && echo '✅ Claude Code is functional' || echo '⚠️  Claude Code installed'"
)

# Post-installation notes
post_installation_message() {

    echo
    echo "🎉 Installation process complete for: $SCRIPT_NAME!"
    echo "Purpose: $SCRIPT_DESCRIPTION"
    echo
    echo "Important Notes:"
    echo "1. Claude Code has been installed"
    echo "2. Environment configuration should be set up in .devcontainer.secrets/"
    echo "3. Skills directory is available at /workspace/.claude/skills"
    echo
    echo "Quick Start:"
    echo "- Check installation: claude --version"
    echo "- Configure environment variables in .devcontainer.secrets/env-vars/"
    echo
    echo "Documentation Links:"
    echo "- Claude Code: https://claude.com/claude-code"
}

# Post-uninstallation notes
post_uninstallation_message() {

    # Remove from auto-enable config
    auto_disable_tool
    echo
    echo "🏁 Uninstallation process complete for: $SCRIPT_NAME!"
    echo
    echo "Additional Notes:"
    echo "1. Claude Code has been removed"
    echo "2. Environment configuration in .devcontainer.secrets/ remains"
    echo "3. Skills directory remains at /workspace/.claude/skills"
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



# Main execution
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
    verify_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi
