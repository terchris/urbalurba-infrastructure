#!/bin/bash
# file: .devcontainer/additions/install-tool-dataanalytics.sh
#
# Installs Python data analysis libraries, Jupyter notebooks, and related VS Code extensions.
# For usage information, run: ./install-tool-dataanalytics.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="tool-dataanalytics"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Data & Analytics Tools"
SCRIPT_DESCRIPTION="Installs Python data analysis libraries, Jupyter notebooks, and related VS Code extensions"
SCRIPT_CATEGORY="DATA_ANALYTICS"
SCRIPT_CHECK_COMMAND="[ -f /usr/local/bin/jupyter ] || [ -f $HOME/.local/bin/jupyter ] || command -v jupyter >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="jupyter pandas numpy matplotlib data science analytics dbt"
SCRIPT_ABSTRACT="Data analytics stack with Jupyter, pandas, numpy, matplotlib, scikit-learn, and dbt."
SCRIPT_LOGO="tool-dataanalytics-logo.webp"
SCRIPT_WEBSITE="https://jupyter.org"
SCRIPT_SUMMARY="Complete data analytics toolkit including Jupyter notebooks and JupyterLab, pandas for data manipulation, numpy for numerical computing, matplotlib and seaborn for visualization, scikit-learn for machine learning, and dbt for data transformation."
SCRIPT_RELATED="tool-databricks dev-python"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install data analytics tools||false|"
    "Action|--uninstall|Uninstall data analytics tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Node.js packages
PACKAGES_NODE=()

# Python packages
PACKAGES_PYTHON=(
    "pandas"
    "numpy"
    "matplotlib"
    "seaborn"
    "scikit-learn"
    "jupyter"
    "jupyterlab"
    "notebook"
    "dbt-core"
    "dbt-postgres"
)

# VS Code extensions
EXTENSIONS=(
    "Python (ms-python.python) - Python language support"
    "Jupyter (ms-toolsai.jupyter) - Jupyter notebook support"
    "Pylance (ms-python.vscode-pylance) - Python language server"
    "DBT (bastienboutonnet.vscode-dbt) - DBT language support"
    "DBT Power User (innoverio.vscode-dbt-power-user) - Enhanced DBT support"
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
    echo "Quick start commands:"
    echo "  - Start Jupyter Lab:      jupyter lab"
    echo "  - Start Jupyter Notebook: jupyter notebook"
    echo "  - Initialize DBT project: dbt init [project_name]"
    echo "  - Python data analysis:   import pandas as pd"
    echo
    echo "Docs: https://pandas.pydata.org/docs/"
    echo "      https://scikit-learn.org/stable/"
    echo "      https://jupyter.org/documentation"
    echo "      https://docs.getdbt.com/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo
    echo "Note: Python remains installed as it's part of the base container"
    echo "      Configuration files may remain in ~/.jupyter/"
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
