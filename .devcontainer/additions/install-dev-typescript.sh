#!/bin/bash
# file: .devcontainer/additions/install-dev-typescript.sh
#
# For usage information, run: ./install-dev-typescript.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-typescript"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="TypeScript Development Tools"
SCRIPT_DESCRIPTION="Adds TypeScript and development tools (Node.js already in devcontainer)"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="command -v tsc >/dev/null 2>&1 || npm list -g typescript 2>/dev/null | grep -q typescript"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="typescript javascript nodejs npm tsc tsx eslint prettier"
SCRIPT_ABSTRACT="TypeScript development environment with compiler, tsx runtime, and essential tooling for modern web development."
SCRIPT_LOGO="dev-typescript-logo.webp"
SCRIPT_WEBSITE="https://www.typescriptlang.org"
SCRIPT_SUMMARY="Complete TypeScript setup including the TypeScript compiler (tsc), tsx for running TypeScript directly, ts-node for Node.js integration, and @types/node for Node.js type definitions. Includes Prettier and ESLint VS Code extensions."
SCRIPT_RELATED="dev-python dev-golang dev-rust"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install TypeScript development tools||false|"
    "Action|--uninstall|Uninstall TypeScript development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# Node.js packages
PACKAGES_NODE=(
    "typescript"
    "tsx"
    "@types/node"
    "ts-node"
)

# VS Code extensions (TypeScript support is built into VS Code)
EXTENSIONS=(
    "Prettier (esbenp.prettier-vscode) - Code formatter for consistent code style"
    "ESLint (dbaeumer.vscode-eslint) - JavaScript and TypeScript linting"
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
        # Note: Node.js already in devcontainer
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local node_version
    node_version=$(node --version 2>/dev/null || echo "not found")

    local npm_version
    npm_version=$(npm --version 2>/dev/null || echo "not found")

    local tsc_version
    tsc_version=$(tsc --version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Node.js: $node_version"
    echo "   npm: $npm_version"
    echo "   TypeScript: $tsc_version"
    echo
    echo "Quick start: tsc --init && tsx index.ts"
    echo "Docs: https://www.typescriptlang.org/docs/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ TypeScript packages removed (Node.js runtime remains in devcontainer)"
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