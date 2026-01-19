#!/bin/bash
# file: .devcontainer/additions/install-tool-databricks.sh
#
# Installs Databricks CLI, SDK, and development tools for Asset Bundles.
# For usage information, run: ./install-tool-databricks.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-databricks"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Databricks Development Tools"
SCRIPT_DESCRIPTION="Installs Databricks CLI, Python SDK, Connect, and related tooling for Asset Bundles development"
SCRIPT_CATEGORY="DATA_ANALYTICS"
SCRIPT_CHECK_COMMAND="command -v databricks >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="databricks spark pyspark delta lake data engineering"
SCRIPT_ABSTRACT="Databricks development tools with CLI, SDK, Connect, PySpark, and Delta Lake support."
SCRIPT_LOGO="tool-databricks-logo.webp"
SCRIPT_WEBSITE="https://www.databricks.com"
SCRIPT_SUMMARY="Complete Databricks development environment including Databricks CLI, Python SDK, Databricks Connect for remote development, PySpark and Delta Lake for data processing, and VS Code extensions for Asset Bundles development and workspace integration."
SCRIPT_RELATED="tool-dataanalytics dev-python"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Databricks development tools||false|"
    "Action|--uninstall|Uninstall Databricks development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=()

# Node.js packages
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=(
    "databricks-sdk"
    "databricks-connect"
    "pyspark"
    "delta-spark"
    "pyarrow"
    "sqlparse"
)

# VS Code extensions
EXTENSIONS=(
    "Databricks (databricks.databricks) - Databricks workspace integration and Asset Bundles"
    "Jupyter (ms-toolsai.jupyter) - Notebook support for Databricks notebooks"
    "Python (ms-python.python) - Python language support"
    "Pylance (ms-python.vscode-pylance) - Python language server"
    "YAML (redhat.vscode-yaml) - YAML support for databricks.yml"
    "REST Client (humao.rest-client) - Test Databricks REST APIs"
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

# --- Databricks CLI Installation (Go binary, not pip) ---
install_databricks_cli() {
    echo "📦 Installing Databricks CLI..."
    
    if command -v databricks >/dev/null 2>&1; then
        echo "  ✓ Databricks CLI already installed: $(databricks --version)"
        if [ "${FORCE_MODE}" -eq 0 ]; then
            return 0
        fi
        echo "  → Force mode: reinstalling..."
    fi

    # Install using official installer script
    curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
    
    # Verify installation
    if command -v databricks >/dev/null 2>&1; then
        echo "  ✓ Databricks CLI installed: $(databricks --version)"
    else
        # Try adding to PATH if installed to ~/.databricks/bin
        if [ -f "$HOME/.databricks/bin/databricks" ]; then
            echo 'export PATH="$HOME/.databricks/bin:$PATH"' >> "$HOME/.bashrc"
            export PATH="$HOME/.databricks/bin:$PATH"
            echo "  ✓ Databricks CLI installed: $(databricks --version)"
        else
            echo "  ✗ Databricks CLI installation failed"
            return 1
        fi
    fi
}

uninstall_databricks_cli() {
    echo "🗑️  Removing Databricks CLI..."
    
    # Remove binary locations
    rm -f /usr/local/bin/databricks 2>/dev/null
    rm -rf "$HOME/.databricks" 2>/dev/null
    
    # Remove from PATH in bashrc
    sed -i '/\.databricks\/bin/d' "$HOME/.bashrc" 2>/dev/null
    
    echo "  ✓ Databricks CLI removed"
}

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
        uninstall_databricks_cli
    else
        echo "🔧 Performing pre-installation setup..."
        install_databricks_cli
    fi
}

# --- Setup Databricks configuration template ---
setup_databricks_config() {
    local config_file="$HOME/.databrickscfg"
    
    if [ ! -f "$config_file" ]; then
        echo "📝 Creating Databricks config template..."
        cat > "$config_file" << 'EOF'
; Databricks CLI configuration
; Run 'databricks configure' to set up interactively
; Or use 'databricks auth login --host <workspace-url>' for OAuth

[DEFAULT]
; host = https://adb-xxxx.azuredatabricks.net
; token = dapi...

; Add additional profiles for different workspaces
; [PROD]
; host = https://adb-yyyy.azuredatabricks.net
; token = dapi...
EOF
        chmod 600 "$config_file"
        echo "  ✓ Config template created at $config_file"
    else
        echo "  ✓ Databricks config already exists"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Quick start:"
    echo "  1. Configure authentication:"
    echo "     databricks configure                     # Interactive setup"
    echo "     databricks auth login --host <url>       # OAuth (recommended)"
    echo
    echo "  2. Verify connection:"
    echo "     databricks clusters list"
    echo "     databricks workspace list /"
    echo
    echo "  3. Asset Bundles (DABs):"
    echo "     databricks bundle init                   # Create new project"
    echo "     databricks bundle validate               # Validate config"
    echo "     databricks bundle deploy -t dev          # Deploy to target"
    echo "     databricks bundle run -t dev <job>       # Run a job"
    echo
    echo "  4. Databricks Connect (local Spark):"
    echo "     from databricks.connect import DatabricksSession"
    echo "     spark = DatabricksSession.builder.getOrCreate()"
    echo
    echo "Docs: https://docs.databricks.com/dev-tools/cli/"
    echo "      https://docs.databricks.com/dev-tools/bundles/"
    echo "      https://docs.databricks.com/dev-tools/databricks-connect/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo
    echo "Note: Configuration file remains at ~/.databrickscfg"
    echo "      Remove manually if no longer needed"
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
    
    # Setup config template after Python packages
    if [ "${UNINSTALL_MODE}" -eq 0 ]; then
        setup_databricks_config
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