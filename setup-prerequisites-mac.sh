#!/bin/bash
# setup-prerequisites-mac.sh
# 
# This script checks and installs prerequisites for the Urbalurba Infrastructure on macOS.
# It can be run in two modes:
# 1. Test mode: Checks if prerequisites are installed and returns exit code
# 2. Install mode: Installs prerequisites if they are not present
#
# Usage:
#   Test mode: ./setup-prerequisites-mac.sh test
#   Install mode: ./setup-prerequisites-mac.sh
#
# Exit codes:
#   0 - All prerequisites are installed
#   1 - Homebrew is not installed
#   2 - Rancher Desktop is not installed
#   3 - Script is not running on macOS
#   4 - Docker CLI is not found in PATH
#
# Author: @terchris
# Version: 1.1.0
# License: MIT


#TODO: This script is not working as expected. The way it installs rancher and test that rancher is installed is not good enugh.




# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    if [[ "$1" == "test" ]]; then
        exit 3
    else
        handle_error "This script is only for macOS"
    fi
fi

# Function to check if Homebrew is installed
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        if [[ "$1" == "test" ]]; then
            return 1
        else
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            # Add Homebrew to PATH if it's not already there
            if [[ ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
    else
        echo "Homebrew is already installed"
    fi
}

# Function to check if Rancher Desktop is installed
check_rancher() {
    if ! brew list --cask rancher &> /dev/null; then
        if [[ "$1" == "test" ]]; then
            return 2
        else
            echo "Installing Rancher Desktop..."
            brew install --cask rancher
        fi
    else
        echo "Rancher Desktop is already installed"
    fi
}

# Function to check if Docker CLI is available
check_docker_cli() {
    if ! command -v docker &> /dev/null; then
        if [[ "$1" == "test" ]]; then
            return 4
        else
            echo "Docker CLI not found in PATH. Adding Rancher Desktop paths..."
            
            # Add Rancher Desktop paths to PATH
            if [[ ":$PATH:" != *":/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin:"* ]]; then
                echo 'export PATH="/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin:$PATH"' >> ~/.zshrc
                export PATH="/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin:$PATH"
            fi
            
            # Verify Docker CLI is now available
            if ! command -v docker &> /dev/null; then
                echo "Warning: Docker CLI still not found after updating PATH"
                echo "Please restart your terminal or run: source ~/.zshrc"
            else
                echo "Docker CLI is now available"
            fi
        fi
    else
        echo "Docker CLI is already available"
    fi
}

# Main script logic
if [[ "$1" == "test" ]]; then
    echo "Testing prerequisites..."
    
    # Check Homebrew
    if ! check_homebrew test; then
        echo "Homebrew is not installed"
        exit 1
    fi
    
    # Check Rancher Desktop
    if ! check_rancher test; then
        echo "Rancher Desktop is not installed"
        exit 2
    fi
    
    # Check Docker CLI
    if ! check_docker_cli test; then
        echo "Docker CLI is not found in PATH"
        exit 4
    fi
    
    echo "All prerequisites are installed"
    exit 0
else
    echo "Installing prerequisites..."
    
    # Install Homebrew if needed
    check_homebrew
    
    # Update Homebrew
    echo "Updating Homebrew..."
    brew update
    
    # Install Rancher Desktop if needed
    check_rancher
    
    # Check and setup Docker CLI
    check_docker_cli
    
    echo "All prerequisites have been installed successfully!"
    echo "Please start Rancher Desktop from your Applications folder to complete the setup."
    echo "If Docker CLI was not found, please restart your terminal or run: source ~/.zshrc"
fi 