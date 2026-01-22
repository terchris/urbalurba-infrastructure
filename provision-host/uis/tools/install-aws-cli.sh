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

# Install the tool
do_install() {
    echo "Installing AWS CLI v2..."
    echo "This may take a few minutes (~200MB download)"

    local tmpdir
    tmpdir=$(mktemp -d)
    cd "$tmpdir" || exit 1

    # Download AWS CLI v2
    curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

    # Install unzip if needed
    if ! command -v unzip &>/dev/null; then
        if [[ $EUID -eq 0 ]]; then
            apt-get update && apt-get install -y unzip
        else
            sudo apt-get update && sudo apt-get install -y unzip
        fi
    fi

    # Extract and install
    unzip -q awscliv2.zip

    if [[ $EUID -eq 0 ]]; then
        ./aws/install
    else
        sudo ./aws/install
    fi

    local status=$?

    # Cleanup
    cd /
    rm -rf "$tmpdir"

    return $status
}

# Uninstall the tool (if possible)
do_uninstall() {
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
    return $?
}
