#!/bin/bash
# install-opentofu.sh - OpenTofu installer
#
# Installs OpenTofu (open-source Terraform fork) in the UIS container.
# Required by platforms/azure-aks/ provisioning scripts.

# === Tool Metadata ===
TOOL_ID="opentofu"
TOOL_NAME="OpenTofu"
TOOL_DESCRIPTION="Open-source infrastructure-as-code (Terraform fork)"
TOOL_CATEGORY="CLOUD_TOOLS"
TOOL_CHECK_COMMAND="command -v tofu"
TOOL_SIZE="~30MB"
TOOL_WEBSITE="https://opentofu.org/"

# Contract:
#   - do_install MUST exit non-zero on any failure (set -euo pipefail).
#   - Idempotency is enforced by the wrapper (tool-installation.sh:194) via
#     TOOL_CHECK_COMMAND — do not add an "already installed" guard here.

# Install the tool
do_install() {
    set -euo pipefail
    echo "Installing OpenTofu..."
    echo "Uses the official installer with --install-method deb (sets up apt repo, then installs system-wide)"

    # Run the official installer; --install-method deb adds the OpenTofu apt repo and runs apt install.
    # DEBIAN_FRONTEND=noninteractive silences the debconf frontend fallback chain inside docker exec
    # (no controlling tty → debconf otherwise tries Dialog → Readline → Teletype before settling).
    if [[ $EUID -eq 0 ]]; then
        curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | DEBIAN_FRONTEND=noninteractive bash -s -- --install-method deb
    else
        echo "Installing OpenTofu (requires sudo)..."
        curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sudo DEBIAN_FRONTEND=noninteractive bash -s -- --install-method deb
    fi
}

# Uninstall the tool
do_uninstall() {
    set -euo pipefail
    echo "Removing OpenTofu..."
    if [[ $EUID -eq 0 ]]; then
        apt-get remove -y tofu
        rm -f /etc/apt/sources.list.d/opentofu.list /etc/apt/keyrings/opentofu.gpg
    else
        sudo apt-get remove -y tofu
        sudo rm -f /etc/apt/sources.list.d/opentofu.list /etc/apt/keyrings/opentofu.gpg
    fi
}
