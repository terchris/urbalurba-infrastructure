#!/bin/bash
# install-gcp-cli.sh - Google Cloud CLI installer
#
# Installs the Google Cloud SDK in the UIS container.

# === Tool Metadata ===
TOOL_ID="gcp-cli"
TOOL_NAME="Google Cloud CLI"
TOOL_DESCRIPTION="Command-line interface for Google Cloud Platform"
TOOL_CATEGORY="CLOUD_TOOLS"
TOOL_CHECK_COMMAND="command -v gcloud"
TOOL_SIZE="~500MB"
TOOL_WEBSITE="https://cloud.google.com/sdk/docs/install"

# Install the tool
do_install() {
    echo "Installing Google Cloud CLI..."
    echo "This may take several minutes (~500MB download)"

    # Add Google Cloud SDK repository
    if [[ $EUID -eq 0 ]]; then
        apt-get update
        apt-get install -y apt-transport-https ca-certificates gnupg curl

        # Add Google Cloud GPG key
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

        # Add repository
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list

        # Install
        apt-get update
        apt-get install -y google-cloud-cli
    else
        # Try with sudo
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates gnupg curl

        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

        sudo apt-get update
        sudo apt-get install -y google-cloud-cli
    fi

    return $?
}

# Uninstall the tool (if possible)
do_uninstall() {
    echo "Removing Google Cloud CLI..."
    if [[ $EUID -eq 0 ]]; then
        apt-get remove -y google-cloud-cli
        rm -f /etc/apt/sources.list.d/google-cloud-sdk.list
    else
        sudo apt-get remove -y google-cloud-cli
        sudo rm -f /etc/apt/sources.list.d/google-cloud-sdk.list
    fi
    return $?
}
