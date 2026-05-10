#!/bin/bash
# install-azure-cli.sh - Azure CLI installer
#
# Installs the Azure command-line interface in the UIS container.

# === Tool Metadata ===
TOOL_ID="azure-cli"
TOOL_NAME="Azure CLI"
TOOL_DESCRIPTION="Command-line interface for Microsoft Azure"
TOOL_CATEGORY="CLOUD_TOOLS"
TOOL_CHECK_COMMAND="command -v az"
TOOL_SIZE="~637MB"
TOOL_WEBSITE="https://docs.microsoft.com/en-us/cli/azure/"

# Contract:
#   - do_install MUST exit non-zero on any failure (set -euo pipefail).
#   - Idempotency is enforced by the wrapper (tool-installation.sh:194) via
#     TOOL_CHECK_COMMAND — do not add an "already installed" guard here.

# Install the tool
do_install() {
    set -euo pipefail
    echo "Installing Azure CLI..."
    echo "This may take several minutes (~637MB download)"

    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        # Install dependencies
        apt-get update
        apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

        # Add Microsoft GPG key
        curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null

        # Add Azure CLI repository
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list

        # Install Azure CLI
        apt-get update
        apt-get install -y azure-cli
    else
        # Try with sudo
        echo "Installing Azure CLI (requires sudo)..."
        curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
}

# Uninstall the tool (if possible)
do_uninstall() {
    set -euo pipefail
    echo "Removing Azure CLI..."
    if [[ $EUID -eq 0 ]]; then
        apt-get remove -y azure-cli
        rm -f /etc/apt/sources.list.d/azure-cli.list
    else
        sudo apt-get remove -y azure-cli
        sudo rm -f /etc/apt/sources.list.d/azure-cli.list
    fi
}
