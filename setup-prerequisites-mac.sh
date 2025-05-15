#!/bin/bash
# setup-prerequisites-mac.sh
# 
# This script checks and installs prerequisites for the Urbalurba Infrastructure on macOS.
# 
# Usage:
#   ./setup-prerequisites-mac.sh [--auto]
#
# Exit codes:
#   0 - Success (all prerequisites installed)
#   1 - Installation failed
#   3 - Script is not running on macOS
#   5 - Docker Desktop conflict detected
#   7 - System requirements not met
#
# Author: @terchris
# Version: 1.3.0
# License: MIT

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Auto mode flag
AUTO_MODE=false

# Parse arguments
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Utility functions
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if command exists
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Ask permission (skip in auto mode)
ask_permission() {
    [[ "$AUTO_MODE" == "true" ]] && return 0
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# System checks
check_system_requirements() {
    print_info "Checking system requirements..."
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is only for macOS"
        exit 3
    fi
    
    # Check for Docker Desktop conflict (CRITICAL)
    if [[ -d "/Applications/Docker.app" ]]; then
        print_error "Docker Desktop detected - CONFLICT!"
        echo "Docker Desktop conflicts with Rancher Desktop and must be uninstalled first."
        echo
        echo "To uninstall Docker Desktop:"
        echo "1. Quit Docker Desktop completely"
        echo "2. Drag 'Docker.app' from Applications to Trash"
        echo "3. Clean up remaining files:"
        echo "   rm -rf ~/Library/Group\\ Containers/group.com.docker"
        echo "   rm -rf ~/Library/Containers/com.docker.docker"
        echo "   rm -rf ~/.docker"
        echo "4. Restart your Mac (recommended)"
        exit 5
    fi
    
    # Check internet connectivity
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        print_error "No internet connection detected"
        exit 7
    fi
    
    # Check available disk space (require at least 8GB free)
    local available_space_kb available_space_gb
    available_space_kb=$(df -k . | awk 'NR==2 {print $4}')
    available_space_gb=$((available_space_kb / 1024 / 1024))
    
    if [[ $available_space_gb -lt 8 ]]; then
        print_error "Insufficient disk space: ${available_space_gb}GB available, 8GB required"
        exit 7
    fi
    
    print_info "System requirements met ✓"
}

# Check and install Homebrew
check_homebrew() {
    print_info "Checking Homebrew..."
    
    if command_exists brew; then
        print_info "Homebrew already installed ✓"
        
        # Ensure it's in PATH for current session
        local brew_path
        if [[ $(uname -m) == 'arm64' ]]; then
            brew_path="/opt/homebrew"
        else
            brew_path="/usr/local"
        fi
        export PATH="$brew_path/bin:$PATH"
        eval "$($brew_path/bin/brew shellenv)" 2>/dev/null || true
        
        # Update Homebrew
        print_info "Updating Homebrew..."
        brew update >/dev/null 2>&1 || print_warn "Failed to update Homebrew"
        return 0
    fi
    
    # Install Homebrew
    print_info "Installing Homebrew..."
    echo "Homebrew is the package manager for macOS"
    echo "It will also install Xcode Command Line Tools if needed"
    
    if ask_permission "Install Homebrew?"; then
        # Install Homebrew (this handles Xcode tools automatically)
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            print_error "Failed to install Homebrew"
            return 1
        fi
        
        # Configure PATH for current session
        local brew_path
        if [[ $(uname -m) == 'arm64' ]]; then
            brew_path="/opt/homebrew"
        else
            brew_path="/usr/local"
        fi
        
        # Add to PATH and shell environment
        export PATH="$brew_path/bin:$PATH"
        eval "$($brew_path/bin/brew shellenv)" 2>/dev/null || true
        
        # Add to shell config for future sessions
        local shell_config
        if [[ "$SHELL" == *"zsh"* ]]; then
            shell_config="$HOME/.zshrc"
        else
            shell_config="$HOME/.bash_profile"
        fi
        
        if ! grep -q "brew shellenv" "$shell_config" 2>/dev/null; then
            echo 'eval "$('$brew_path'/bin/brew shellenv)"' >> "$shell_config"
        fi
        
        # Verify installation
        if command_exists brew; then
            print_info "Homebrew installed successfully ✓"
            return 0
        else
            print_error "Homebrew installation failed"
            return 1
        fi
    else
        print_error "Homebrew is required for installation"
        return 1
    fi
}

# Check and install Rancher Desktop
check_rancher() {
    print_info "Checking Rancher Desktop..."
    
    if brew list --cask rancher &> /dev/null; then
        print_info "Rancher Desktop already installed ✓"
        return 0
    fi
    
    # Install Rancher Desktop
    print_info "Installing Rancher Desktop..."
    echo "Rancher Desktop provides:"
    echo "• Kubernetes cluster"
    echo "• Docker runtime"  
    echo "• kubectl, helm, and other tools"
    
    if ask_permission "Install Rancher Desktop?"; then
        # Ensure Homebrew is available first
        if ! command_exists brew; then
            print_error "Homebrew not found - installing Homebrew first"
            if ! check_homebrew; then
                return 1
            fi
        fi
        
        # Install Rancher Desktop via Homebrew
        if brew install --cask rancher; then
            print_info "Rancher Desktop installed ✓"
            return 0
        else
            print_error "Failed to install Rancher Desktop"
            return 1
        fi
    else
        print_error "Rancher Desktop is required"
        return 1
    fi
}

# Setup Docker CLI
setup_docker_cli() {
    print_info "Setting up Docker CLI access..."
    
    if command_exists docker; then
        print_info "Docker CLI already available ✓"
        return 0
    fi
    
    # Add Rancher Desktop paths to shell config
    print_info "Adding Rancher Desktop to PATH..."
    
    local shell_config
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.bash_profile"
    fi
    
    local docker_path="/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin"
    
    # Add to PATH for current session
    export PATH="$docker_path:$PATH"
    
    # Add to shell config for future sessions
    if ! grep -q "$docker_path" "$shell_config" 2>/dev/null; then
        echo "export PATH=\"$docker_path:\$PATH\"" >> "$shell_config"
        print_info "Added Rancher Desktop to PATH in $shell_config"
    fi
    
    print_info "Docker CLI setup complete ✓"
    print_warn "Note: Docker CLI will be available after starting Rancher Desktop"
    return 0
}

# Main function
main() {
    echo "Installing Urbalurba Infrastructure Prerequisites"
    echo "==============================================="
    echo
    
    # Parse auto mode
    if [[ "$AUTO_MODE" == "true" ]]; then
        print_info "Running in automatic mode"
    fi
    
    # Check system requirements (exits on failure)
    check_system_requirements
    
    # Install prerequisites (fail if any installation fails)
    local failed=false
    
    check_homebrew || failed=true
    check_rancher || failed=true
    setup_docker_cli || failed=true
    
    if [[ "$failed" == "true" ]]; then
        print_error "Some prerequisites failed to install"
        exit 1
    fi
    
    echo
    print_info "All prerequisites installed successfully! ✓"
    echo
    echo "Next steps:"
    echo "1. Start Rancher Desktop from Applications folder"
    echo "2. Wait for Kubernetes to show 'Running' status"
    echo "3. Restart your terminal or run: source ~/.zshrc"
    echo
    echo "Your system is now ready for Urbalurba Infrastructure!"
    exit 0
}

# Error handling
handle_error() {
    print_error "$1"
    exit 1
}

# Set up error handling
trap 'handle_error "An unexpected error occurred"' ERR

# Run main function with arguments
main "$@"
