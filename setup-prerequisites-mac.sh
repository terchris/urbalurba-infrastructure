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
#   2 - kubectl is not installed
#   3 - Rancher Desktop is not installed
#   4 - Script is not running on macOS
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
    if [[ "$1" == "test" ]]; then
        exit 4
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

# Function to check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        if [[ "$1" == "test" ]]; then
            return 2
        else
            echo "Installing kubectl..."
            brew install kubectl
        fi
    else
        echo "kubectl is already installed"
    fi
}

# Function to check if Rancher Desktop is installed
check_rancher() {
    if ! brew list --cask rancher &> /dev/null; then
        if [[ "$1" == "test" ]]; then
            return 3
        else
            echo "Installing Rancher Desktop..."
            brew install --cask rancher
        fi
    else
        echo "Rancher Desktop is already installed"
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
    
    # Check kubectl
    if ! check_kubectl test; then
        echo "kubectl is not installed"
        exit 2
    fi
    
    # Check Rancher Desktop
    if ! check_rancher test; then
        echo "Rancher Desktop is not installed"
        exit 3
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
    
    # Install kubectl if needed
    check_kubectl
    
    # Install Rancher Desktop if needed
    check_rancher
    
    echo "All prerequisites have been installed successfully!"
    echo "Please start Rancher Desktop from your Applications folder to complete the setup."
fi 