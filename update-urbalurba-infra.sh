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
# 1. Download the latest release of Urbalurba Infrastructure from GitHub
# 2. Extract the files to the current directory
# 3. Check if prerequisites are installed and offer to run setup if needed
#
# Usage:
#   curl -L https://raw.githubusercontent.com/norwegianredcross/urbalurba-infrastructure/main/update-urbalurba-infra.sh -o update-urbalurba-infra.sh && chmod +x update-urbalurba-infra.sh && ./update-urbalurba-infra.sh
#   
#   or
#   
#   wget https://raw.githubusercontent.com/norwegianredcross/urbalurba-infrastructure/main/update-urbalurba-infra.sh -O update-urbalurba-infra.sh && chmod +x update-urbalurba-infra.sh && ./update-urbalurba-infra.sh
#
# Author: @terchris
# Version: 1.1.0
# License: MIT

# Set error handling
set -e

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function for cleanup
cleanup() {
    echo "Cleaning up temporary files..."
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up trap for cleanup on script exit
trap cleanup EXIT

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

# Get the latest release tag
echo "Fetching latest release information..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/norwegianredcross/urbalurba-infrastructure/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

if [ -z "$LATEST_TAG" ]; then
    handle_error "Failed to get latest release tag. Please check your internet connection and try again."
fi

echo "Latest release version: $LATEST_TAG"

# Define the URL using the latest tag
INFRA_URL="https://github.com/norwegianredcross/urbalurba-infrastructure/releases/download/$LATEST_TAG/urbalurba-infrastructure.zip"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
TEMP_ZIP="$TEMP_DIR/urbalurba-infrastructure.zip"
CURRENT_DIR=$(pwd)

# Download the infrastructure zip file
echo "Downloading Urbalurba Infrastructure (version $LATEST_TAG)..."
if ! curl -L "$INFRA_URL" -o "$TEMP_ZIP"; then
    handle_error "Failed to download the infrastructure zip file. Please check your internet connection and try again."
fi

# Verify the download was successful
if [ ! -f "$TEMP_ZIP" ]; then
    handle_error "Downloaded file not found. Please check your internet connection and try again."
fi

# Check file size to ensure it's not empty or an error page
FILE_SIZE=$(stat -f%z "$TEMP_ZIP" 2>/dev/null || stat -c%s "$TEMP_ZIP" 2>/dev/null)
if [ "$FILE_SIZE" -lt 1000 ]; then  # Less than 1KB is probably an error
    handle_error "Downloaded file is too small. It might be an error response instead of the actual package."
fi

# Create temporary extraction directory
EXTRACT_DIR="$TEMP_DIR/extract"
mkdir -p "$EXTRACT_DIR"

# Extract the zip file
echo "Extracting Urbalurba Infrastructure..."
if ! unzip -q "$TEMP_ZIP" -d "$EXTRACT_DIR"; then
    handle_error "Failed to extract the zip file. The downloaded file might be corrupted."
fi

# Check if the new version of this script is different
if [ -f "update-urbalurba-infra.sh" ]; then
    if ! cmp -s "update-urbalurba-infra.sh" "$EXTRACT_DIR/update-urbalurba-infra.sh" && [ -f "$EXTRACT_DIR/update-urbalurba-infra.sh" ]; then
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
    handle_error "Failed to copy files to current directory. Please check file permissions."
fi

echo "Urbalurba Infrastructure installation completed successfully!"

# Check if prerequisites script exists
if [ ! -f "setup-prerequisites-mac.sh" ]; then
    handle_error "setup-prerequisites-mac.sh not found in the extracted files. The downloaded package might be incomplete."
fi

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

echo "==================================================="
echo "Urbalurba Infrastructure is ready!"
echo "To learn more about available features and usage, see the README.md file."
echo "==================================================="