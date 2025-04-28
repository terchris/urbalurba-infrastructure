#!/bin/bash

# update-urbalurba-infra.sh
# 
# This script downloads the Urbalurba Infrastructure and unzips it in the current directory.
# It then gives the user the option to run the prerequisites setup if the prerequisites are not already installed.
#
# Prerequisites:
# - macOS operating system
# - Internet connection
#
# The script will:
# 1. Download the Urbalurba Infrastructure
# 2. Ask the user if they want to run the prerequisites setup
#
# Usage:
#   wget https://raw.githubusercontent.com/norwegianredcross/urbalurba-infrastructure/main/update-urbalurba-infra.sh -O update-urbalurba-infra.sh && chmod +x update-urbalurba-infra.sh && ./update-urbalurba-infra.sh
#
# Author: @terchris
# Version: 1.0.0
# License: MIT

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    handle_error "This script is only for macOS"
fi

# Check if this is an update
if [ -f "setup-prerequisites-mac.sh" ]; then
    echo "Existing Urbalurba Infrastructure installation detected."
    echo "This script will update your installation."
    read -p "Do you want to continue with the update? (y/n) " -n 1 -r
    echo
    case $REPLY in
        [Yy]* )
            echo "Proceeding with update..."
            ;;
        * )
            echo "Update cancelled."
            exit 0
            ;;
    esac
fi

echo "Starting Urbalurba Infrastructure download..."

# Define the URL
INFRA_URL="https://github.com/norwegianredcross/urbalurba-infrastructure/releases/download/latest/urbalurba-infrastructure.zip"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
TEMP_ZIP="$TEMP_DIR/urbalurba-infrastructure.zip"
CURRENT_DIR=$(pwd)

# Function for cleanup
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Set up trap for cleanup on script exit
trap cleanup EXIT

# Download the infrastructure zip file
echo "Downloading Urbalurba Infrastructure..."
if ! curl -L "$INFRA_URL" -o "$TEMP_ZIP"; then
    handle_error "Failed to download the infrastructure zip file"
fi

# Create temporary extraction directory
EXTRACT_DIR="$TEMP_DIR/extract"
mkdir -p "$EXTRACT_DIR"

# Extract the zip file
echo "Extracting Urbalurba Infrastructure..."
if ! unzip -q "$TEMP_ZIP" -d "$EXTRACT_DIR"; then
    handle_error "Failed to extract the zip file"
fi

# Check if the new version of this script is different
if [ -f "update-urbalurba-infra.sh" ]; then
    if ! cmp -s "update-urbalurba-infra.sh" "$EXTRACT_DIR/update-urbalurba-infra.sh"; then
        echo "New version of update script detected."
        echo "Running the new version..."
        cp "$EXTRACT_DIR/update-urbalurba-infra.sh" "update-urbalurba-infra.sh"
        chmod +x "update-urbalurba-infra.sh"
        exec "./update-urbalurba-infra.sh"
    fi
fi

# Copy all contents to current directory
echo "Installing Urbalurba Infrastructure..."
if ! cp -r "$EXTRACT_DIR"/* "$CURRENT_DIR/"; then
    handle_error "Failed to copy files to current directory"
fi

echo "Urbalurba Infrastructure installation completed successfully!"

# Make the prerequisites script executable
chmod +x setup-prerequisites-mac.sh

# Check if prerequisites are installed
echo "Checking prerequisites..."
if ./setup-prerequisites-mac.sh test; then
    echo "All prerequisites are already installed!"
else
    # Ask user if they want to run the prerequisites setup
    read -p "Do you want to run the prerequisites setup now? (y/n) " -n 1 -r
    echo
    case $REPLY in
        [Yy]* )
            echo "Running prerequisites setup..."
            ./setup-prerequisites-mac.sh
            ;;
        * )
            echo "You can run the prerequisites setup later by executing:"
            echo "./setup-prerequisites-mac.sh"
            ;;
    esac
fi 