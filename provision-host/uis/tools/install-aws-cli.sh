#!/bin/bash
# install-aws-cli.sh - AWS CLI installer
#
# Installs the AWS command-line interface in the UIS container.

# === Tool Metadata ===
TOOL_ID="aws-cli"
TOOL_NAME="AWS CLI"
TOOL_DESCRIPTION="Command-line interface for Amazon Web Services"
TOOL_CATEGORY="CLOUD_TOOLS"
TOOL_CHECK_COMMAND="command -v aws"
TOOL_SIZE="~200MB"
TOOL_WEBSITE="https://aws.amazon.com/cli/"

# Contract:
#   - do_install MUST exit non-zero on any failure (set -euo pipefail).
#   - Idempotency is enforced by the wrapper (tool-installation.sh:194) via
#     TOOL_CHECK_COMMAND — do not add an "already installed" guard here.

# Install the tool
do_install() {
    set -euo pipefail
    echo "Installing AWS CLI v2..."
    echo "This may take a few minutes (~200MB download)"

    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT
    cd "$tmpdir"

    # Download AWS CLI v2
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

    # Install unzip if needed
    if ! command -v unzip &>/dev/null; then
        if [[ $EUID -eq 0 ]]; then
            apt-get update
            apt-get install -y unzip
        else
            sudo apt-get update
            sudo apt-get install -y unzip
        fi
    fi

    # Extract and install
    unzip -q awscliv2.zip

    if [[ $EUID -eq 0 ]]; then
        ./aws/install
    else
        sudo ./aws/install
    fi
}

# Uninstall the tool (if possible)
do_uninstall() {
    set -euo pipefail
    echo "Removing AWS CLI..."
    if [[ $EUID -eq 0 ]]; then
        rm -rf /usr/local/aws-cli
        rm -f /usr/local/bin/aws
        rm -f /usr/local/bin/aws_completer
    else
        sudo rm -rf /usr/local/aws-cli
        sudo rm -f /usr/local/bin/aws
        sudo rm -f /usr/local/bin/aws_completer
    fi
}
