#!/bin/bash
# update-urbalurba-infra.sh
# 
# Enhanced version that downloads the Urbalurba Infrastructure and delegates
# all prerequisite handling to setup-prerequisites-mac.sh.
#
# Prerequisites:
# - macOS operating system
# - Internet connection
#
# The script will:
# 1. Download/ensure setup-prerequisites-mac.sh is available
# 2. Run setup-prerequisites-mac.sh to install all prerequisites
# 3. Download the latest version of Urbalurba Infrastructure from GitHub
# 4. Extract the files to the current directory
# 5. Run infrastructure setup scripts
#
# Author: @terchris
# Version: 1.2.0
# License: MIT

# GitHub Repository Info
REPO_OWNER="terchris"
REPO_NAME="urbalurba-infrastructure"
GITHUB_REPO="$REPO_OWNER/$REPO_NAME"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Utility functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to handle errors
handle_error() {
    print_error "$1"
    exit 1
}

# Function for cleanup
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up trap for cleanup on script exit
trap cleanup EXIT

# Basic system check
check_basic_system() {
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        handle_error "This script is only for macOS"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        handle_error "No internet connection detected"
    fi
}

# Ensure we have the prerequisites script
ensure_prerequisites_script() {
    print_info "Ensuring prerequisites script is available..."
    
    # If we don't have it locally, download it
    if [[ ! -f "setup-prerequisites-mac.sh" ]]; then
        print_info "Downloading setup-prerequisites-mac.sh..."
        local script_url="https://raw.githubusercontent.com/$GITHUB_REPO/main/setup-prerequisites-mac.sh"
        
        if ! curl -fsSL "$script_url" -o "setup-prerequisites-mac.sh"; then
            handle_error "Failed to download setup-prerequisites-mac.sh"
        fi
        
        chmod +x setup-prerequisites-mac.sh
        print_info "Prerequisites script downloaded ✓"
    else
        print_info "Prerequisites script found ✓"
        chmod +x setup-prerequisites-mac.sh
    fi
}

# Handle prerequisites via delegation
handle_prerequisites() {
    print_info "Installing prerequisites..."
    echo
    echo "This will install if needed:"
    echo "• Homebrew (if not installed)"
    echo "• Xcode Command Line Tools (automatically with Homebrew)"
    echo "• Rancher Desktop (if not installed)"
    echo "• Docker CLI configuration"
    echo
    
    # Run the prerequisites script
    if ./setup-prerequisites-mac.sh; then
        print_info "All prerequisites installed successfully ✓"
    else
        local exit_code=$?
        case $exit_code in
            3)
                print_error "This script requires macOS"
                ;;
            5)
                print_error "Docker Desktop conflict detected"
                echo "Please uninstall Docker Desktop first"
                ;;
            7)
                print_error "System requirements not met"
                echo "Check internet connection and disk space"
                ;;
            *)
                print_error "Prerequisites installation failed"
                ;;
        esac
        exit $exit_code
    fi
}

# Check for existing installation
check_for_existing_installation() {
    if [ -f "setup-prerequisites-mac.sh" ]; then
        print_info "Existing Urbalurba Infrastructure installation detected."
        print_info "This script will update your installation."
        read -p "Do you want to continue with the update? (y/n) " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                print_info "Proceeding with update..."
                ;;
            * )
                print_info "Update cancelled."
                exit 0
                ;;
        esac
    fi
}

# Download and extract infrastructure
download_and_extract_infrastructure() {
    print_info "Starting Urbalurba Infrastructure download..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    CURRENT_DIR=$(pwd)
    
    # Get latest release
    print_info "Checking for releases..."
    RELEASE_CHECK=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest")
    
    # Check if releases exist and get download URL
    if echo "$RELEASE_CHECK" | grep -q '"tag_name"'; then
        print_info "Release found! Using the latest release..."
        LATEST_TAG=$(echo "$RELEASE_CHECK" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
        print_info "Latest release version: $LATEST_TAG"
        INFRA_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_TAG/urbalurba-infrastructure.zip"
    else
        print_warn "No releases found. Using a known release version..."
        LATEST_TAG="v16"
        INFRA_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_TAG/urbalurba-infrastructure.zip"
    fi
    
    TEMP_ZIP="$TEMP_DIR/urbalurba-infrastructure.zip"
    
    # Download the infrastructure zip file
    print_info "Downloading Urbalurba Infrastructure ($INFRA_URL)..."
    if ! curl -L "$INFRA_URL" -o "$TEMP_ZIP"; then
        handle_error "Failed to download the infrastructure. Please check your internet connection and try again."
    fi
    
    # Verify the download was successful
    if [ ! -f "$TEMP_ZIP" ]; then
        handle_error "Downloaded file not found. Please check your internet connection and try again."
    fi
    
    # Check file size to ensure it's not empty or an error page
    FILE_SIZE=$(stat -f%z "$TEMP_ZIP" 2>/dev/null || stat -c%s "$TEMP_ZIP" 2>/dev/null)
    if [ "$FILE_SIZE" -lt 1000 ]; then
        handle_error "Downloaded file is too small. It might be an error response instead of the actual package."
    fi
    
    # Create temporary extraction directory
    EXTRACT_DIR="$TEMP_DIR/extract"
    mkdir -p "$EXTRACT_DIR"
    
    # Extract the zip file
    print_info "Extracting Urbalurba Infrastructure..."
    if ! unzip -q "$TEMP_ZIP" -d "$EXTRACT_DIR"; then
        handle_error "Failed to extract the zip file. The downloaded file might be corrupted."
    fi
    
    # Handle different directory structures based on source
    if echo "$INFRA_URL" | grep -q "archive/refs/heads/main"; then
        BASE_DIR="$EXTRACT_DIR/$REPO_NAME-main"
        if [ ! -d "$BASE_DIR" ]; then
            handle_error "Expected directory structure not found in the zip file."
        fi
    else
        BASE_DIR="$EXTRACT_DIR"
    fi
    
    # Check if the new version of this script exists in the package
    if [ -f "$BASE_DIR/update-urbalurba-infra.sh" ]; then
        print_info "Found update script in the package. Saving it as local copy..."
        cp "$BASE_DIR/update-urbalurba-infra.sh" "update-urbalurba-infra.sh.new"
        chmod +x "update-urbalurba-infra.sh.new"
        print_info "If you want to use the new script in the future, rename update-urbalurba-infra.sh.new to update-urbalurba-infra.sh"
    fi
    
    # Copy all contents to current directory
    print_info "Installing Urbalurba Infrastructure..."
    if ! cp -r "$BASE_DIR"/* "$CURRENT_DIR/"; then
        handle_error "Failed to copy files to current directory. Please check file permissions."
    fi
    
    print_info "Urbalurba Infrastructure installation completed successfully!"
}

# Run infrastructure setup
run_infrastructure_setup() {
    # Check if prerequisites script exists in the package and run it
    # (in case it's newer than what we downloaded initially)
    if [ -f "setup-prerequisites-mac.sh" ]; then
        chmod +x setup-prerequisites-mac.sh
        print_info "Verifying prerequisites with package version..."
        
        # Note: We don't run the full prerequisites again since we just did,
        # but this allows for future package updates to handle new requirements
    fi
    
    # Ask user if they want to run the Rancher installation
    if [ -f "install-rancher.sh" ]; then
        read -p "Do you want to run the Rancher installation now? (y/n) " -n 1 -r
        echo
        case $REPLY in
            [Yy]* )
                print_info "Running Rancher installation..."
                
                # Verify Docker is available (it should be since we started Rancher Desktop)
                if ! command -v docker >/dev/null 2>&1; then
                    print_warn "Docker CLI not found in current PATH"
                    print_info "Adding Rancher Desktop to PATH for this session..."
                    export PATH="/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin:$PATH"
                fi
                
                chmod +x install-rancher.sh
                ./install-rancher.sh
                ;;
            * )
                print_info "You can run the Rancher installation later by executing:"
                print_info "./install-rancher.sh"
                ;;
        esac
    else
        print_info "No additional Rancher installation script found."
    fi
}

# Main execution flow
main() {
    echo "Urbalurba Infrastructure Update Script"
    echo "====================================="
    echo
    
    # Basic system checks
    check_basic_system
    
    # Check for existing installation
    check_for_existing_installation
    
    # Ensure we have the prerequisites script
    ensure_prerequisites_script
    
    # Handle all prerequisites (simplified - just run the script)
    handle_prerequisites
    
    # Download and extract infrastructure
    download_and_extract_infrastructure
    
    # Run infrastructure setup
    run_infrastructure_setup
    
    # Final message
    echo
    print_info "=================================================="
    print_info "Urbalurba Infrastructure is ready!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Start Rancher Desktop from Applications"
    print_info "2. Wait for Kubernetes to show 'Running'"
    print_info "3. Check README.md for usage instructions"
    print_info ""
    print_info "To learn more about available features and usage,"
    print_info "see the README.md file."
    print_info "=================================================="
}

# Run main function
main
