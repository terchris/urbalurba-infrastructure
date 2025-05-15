#!/bin/bash
# install-urbalurba.sh - Complete Urbalurba Infrastructure Installer
# 
# This is an enhanced version of update-urbalurba-infra.sh that provides:
# - Complete prerequisite handling (Homebrew, Xcode Tools, dependencies)
# - Enhanced Rancher Desktop configuration with optimal settings
# - All functionality of the original update-urbalurba-infra.sh
# - Better error handling, logging, and user control
#
# This script offers three modes:
# 1. Default: Interactive - shows what will happen, asks permission
# 2. --commands: Shows manual commands only (no execution)
# 3. --auto: Automatic installation (no questions asked)
#
# Usage:
#   ./install-urbalurba.sh           # Interactive mode
#   ./install-urbalurba.sh --commands # Show manual commands
#   ./install-urbalurba.sh --auto     # Automatic mode
#
# Compatibility:
# - Replaces update-urbalurba-infra.sh with enhanced functionality
# - Downloads and runs the same infrastructure scripts
# - Adds robust prerequisite management
#
# Author: @terchris
# Version: 2.2.1

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="terchris"
REPO_NAME="urbalurba-infrastructure"
GITHUB_REPO="$REPO_OWNER/$REPO_NAME"
BREWFILE_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/Brewfile"
LOG_FILE="install-urbalurba.log"

# Auto mode flag
AUTO_MODE=false

# Step counter for numbered progress
CURRENT_STEP=0
TOTAL_STEPS=7

# Utility functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}===== Step $CURRENT_STEP/$TOTAL_STEPS: $1 =====${NC}\n" | tee -a "$LOG_FILE"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ask_permission() {
    local message="$1"
    if [[ "$AUTO_MODE" == "true" ]]; then
        print_status "Auto mode: $message - Proceeding automatically"
        return 0
    fi
    echo -e "\n$message"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Stopped by user request."
        exit 0
    fi
}

# Check macOS version compatibility - FUTURE-PROOF VERSION
check_macos_version() {
    # Get macOS version info
    local macos_version=$(sw_vers -productVersion)
    local macos_name=$(sw_vers -productName)
    local build_version=$(sw_vers -buildVersion)
    
    print_status "Checking macOS version: $macos_name $macos_version (Build: $build_version)"
    
    # Parse version components
    local version_parts=($(echo $macos_version | tr '.' ' '))
    local major_version=${version_parts[0]}
    local minor_version=${version_parts[1]:-0}
    local patch_version=${version_parts[2]:-0}
    
    # Define minimum requirements
    local min_major=10
    local min_minor=15
    local min_patch=0
    
    # Helper function to compare versions
    version_compare() {
        local current_maj=$1 current_min=$2 current_pat=$3
        local required_maj=$4 required_min=$5 required_pat=$6
        
        # Compare major version
        if [[ $current_maj -gt $required_maj ]]; then
            return 0  # Current is newer
        elif [[ $current_maj -lt $required_maj ]]; then
            return 1  # Current is older
        fi
        
        # Major versions equal, compare minor
        if [[ $current_min -gt $required_min ]]; then
            return 0
        elif [[ $current_min -lt $required_min ]]; then
            return 1
        fi
        
        # Major and minor equal, compare patch
        if [[ $current_pat -ge $required_pat ]]; then
            return 0
        else
            return 1
        fi
    }
    
    # Check minimum version requirement
    if ! version_compare $major_version $minor_version $patch_version $min_major $min_minor $min_patch; then
        print_error "macOS $macos_version is not supported"
        echo "Rancher Desktop requires macOS 10.15 (Catalina) or later"
        echo "Current version: $macos_version"
        echo "Please update your macOS before running this installer"
        exit 1
    fi
    
    # Provide version-specific guidance
    case $major_version in
        10)
            if [[ $minor_version -eq 15 ]]; then
                print_warning "macOS $macos_version is the minimum supported version"
                echo "Consider updating to a newer macOS version for better compatibility"
                ask_permission "Continue with macOS $macos_version?"
            else
                print_status "macOS $macos_version supported ✓"
            fi
            ;;
        11|12|13|14)
            print_status "macOS $macos_version fully supported ✓"
            ;;
        15|16|17|18|19|20)
            # Future-proofing for likely future versions
            print_status "macOS $macos_version detected - should be compatible ✓"
            print_warning "This is a newer macOS version. If you encounter issues, please report them."
            ;;
        *)
            # Handle unexpected major versions
            if [[ $major_version -gt 20 ]]; then
                print_warning "macOS $macos_version is much newer than tested versions"
                echo "This installer was not tested with macOS $major_version.x"
                echo "Proceed with caution - some features may not work correctly"
                ask_permission "Continue anyway? (Consider checking for updated installer)"
            fi
            ;;
    esac
    
    # Additional checks for specific issues
    check_known_version_issues $major_version $minor_version $patch_version
    
    print_status "macOS version check completed ✓"
}

# Check for known issues with specific macOS versions
check_known_version_issues() {
    local maj=$1 min=$2 pat=$3
    
    # Check for Apple Silicon specific issues (if detectable)
    if [[ $(uname -m) == 'arm64' ]] && [[ $maj -eq 10 ]]; then
        print_error "macOS 10.x is not available on Apple Silicon Macs"
        echo "This appears to be an inconsistent system configuration"
        exit 1
    fi
    
    # Example: macOS 11.0 had issues with virtualization
    if [[ $maj -eq 11 && $min -eq 0 ]]; then
        print_warning "macOS 11.0 had known virtualization issues"
        echo "Consider updating to macOS 11.1 or later for better Rancher Desktop compatibility"
    fi
    
    # Note: Add more version-specific checks as needed
}

# Check for Docker Desktop conflicts
check_docker_desktop_conflict() {
    print_status "Checking for Docker Desktop conflicts..."
    
    # Check if Docker Desktop is installed
    if [[ -d "/Applications/Docker.app" ]]; then
        print_error "Docker Desktop detected - CONFLICT!"
        echo
        echo "⚠️  IMPORTANT: Docker Desktop will conflict with Rancher Desktop"
        echo
        echo "Docker Desktop and Rancher Desktop cannot run simultaneously because:"
        echo "• Both try to manage Docker daemon"
        echo "• They use different socket paths"
        echo "• Network configurations conflict"
        echo "• Port bindings interfere with each other"
        echo
        echo "SOLUTION: Uninstall Docker Desktop before proceeding"
        echo
        echo "To uninstall Docker Desktop:"
        echo "1. Quit Docker Desktop completely"
        echo "2. Drag 'Docker.app' from Applications to Trash"
        echo "3. Clean up remaining files:"
        echo "   rm -rf ~/Library/Group\\ Containers/group.com.docker"
        echo "   rm -rf ~/Library/Containers/com.docker.docker"
        echo "   rm -rf ~/.docker"
        echo "4. Restart your Mac (recommended)"
        echo
        print_error "Cannot continue with Docker Desktop installed"
        echo "Please uninstall Docker Desktop and run this script again."
        exit 1
    fi
    
    # Also check if Docker CLI is installed via Homebrew (less critical but worth noting)
    if command_exists docker && brew list docker &>/dev/null; then
        print_warning "Docker CLI installed via Homebrew detected"
        echo "This may cause minor conflicts with Rancher Desktop's Docker."
        echo "Consider uninstalling: brew uninstall docker"
        ask_permission "Continue anyway? (Rancher Desktop will provide its own Docker)"
    fi
    
    print_status "Docker Desktop conflict check passed ✓"
}

# Comprehensive system check
check_prerequisites() {
    print_step "Checking System Prerequisites"
    
    # Check if running on macOS
    if [[ "${OSTYPE}" != "darwin"* ]]; then
        print_error "This installer is for macOS only"
        echo "Detected OS: $OSTYPE"
        exit 1
    fi
    
    # Check macOS version compatibility
    check_macos_version
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        exit 1
    fi
    
    # Check internet connectivity
    print_status "Checking internet connectivity..."
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        print_error "No internet connection detected"
        echo "Please check your internet connection and try again."
        exit 1
    fi
    
    # Check available disk space (require at least 8GB free)
    print_status "Checking available disk space..."
    local available_space_kb
    available_space_kb=$(df -k . | awk 'NR==2 {print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    
    if [[ $available_space_gb -lt 8 ]]; then
        print_error "Insufficient disk space"
        echo "At least 8GB free space required, found: ${available_space_gb}GB"
        exit 1
    fi
    
    # Check if we can write to current directory
    if ! touch test_write_permissions 2>/dev/null; then
        print_error "Cannot write to current directory"
        echo "Please run this script from a directory you have write permissions to."
        exit 1
    fi
    rm -f test_write_permissions
    
    # Check for Docker Desktop conflicts before proceeding
    check_docker_desktop_conflict
    
    print_status "All system prerequisites passed ✓"
}

# Function to print manual commands
print_manual_commands() {
    cat << 'EOF'
# Manual Installation Commands for Urbalurba Infrastructure

# Step 0: Check for Docker Desktop conflicts (IMPORTANT!)
# Docker Desktop conflicts with Rancher Desktop - must be uninstalled first
if [[ -d "/Applications/Docker.app" ]]; then
    echo "ERROR: Docker Desktop detected!"
    echo "Docker Desktop conflicts with Rancher Desktop and must be uninstalled first."
    echo "See the installer script for detailed uninstall instructions."
    exit 1
fi

# Step 1: Check if Xcode Command Line Tools are installed
# If not installed, Homebrew will prompt you to install them
xcode-select -p >/dev/null 2>&1 || echo "Xcode Command Line Tools not installed"

# Step 2: Install Homebrew (package manager for macOS)
# Note: If Xcode Command Line Tools aren't installed, this will trigger
# their installation (large download 500MB-1GB+, takes 5-15 minutes)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Step 3: Add Homebrew to your current shell session
if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Step 4: Install all dependencies via Brewfile
curl -fsSL https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/Brewfile | brew bundle --file=-

# Step 5: Download and extract Urbalurba Infrastructure
# Get latest release info
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/terchris/urbalurba-infrastructure/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)

# Download and extract
curl -L "https://github.com/terchris/urbalurba-infrastructure/releases/download/$LATEST_RELEASE/urbalurba-infrastructure.zip" -o urbalurba-infrastructure.zip
unzip urbalurba-infrastructure.zip
rm urbalurba-infrastructure.zip

# Step 6: Configure Rancher Desktop (via GUI or rdctl)
# GUI Method: Open Rancher Desktop and configure:
# - Virtual Machine: VZ (Apple Virtualization)
# - Enable Rosetta support
# - Memory: 8GB, CPUs: 4
# - Volumes: virtiofs
# - Container Engine: Docker
# - Auto-start: DISABLED (to avoid unexpected resource usage)

# CLI Method (if rdctl is available):
rdctl start --container-engine.name=moby --virtual-machine.memory-in-gb=8 --virtual-machine.number-cpus=4 --application.auto-start=false

# Step 7: Wait for Kubernetes to be ready
kubectl cluster-info
kubectl get nodes

# Step 8: Run infrastructure setup scripts (if present)
# Look for and run setup scripts in the extracted directory
ls -la setup-*.sh install-*.sh

# You're done! Check the README.md for next steps.
EOF
}

# Function to check Xcode Command Line Tools
check_xcode_tools() {
    print_step "Checking Xcode Command Line Tools"
    
    # More comprehensive check for Xcode tools
    if xcode-select -p &> /dev/null && [[ -d "$(xcode-select -p)" ]] && [[ -f "$(xcode-select -p)/usr/bin/git" ]]; then
        print_status "Xcode Command Line Tools already installed ✓"
        return 0
    fi
    
    # Not installed - warn user
    print_warning "Xcode Command Line Tools not found"
    echo
    echo "📦 IMPORTANT: Homebrew will need to install Xcode Command Line Tools"
    echo "   • This is a LARGE download (500MB-1GB+)"
    echo "   • Installation typically takes 5-15 minutes"
    echo "   • You may see a popup asking you to install - click 'Install'"
    echo "   • The process may appear to hang - this is normal!"
    echo
    echo "   These tools include essential development utilities:"
    echo "   • C/C++ compiler (clang)"
    echo "   • Git version control"
    echo "   • Build tools (make, etc.)"
    echo
    print_status "Homebrew will handle the installation automatically"
}

# Function to install Homebrew with retry logic
install_homebrew() {
    print_step "Installing Homebrew"
    
    # Check if already installed
    if command_exists brew; then
        print_status "Homebrew already installed ✓"
        # Still need to ensure it's in PATH for current session
        local brew_path
        if [[ $(uname -m) == 'arm64' ]]; then
            brew_path="/opt/homebrew"
        else
            brew_path="/usr/local"
        fi
        export PATH="$brew_path/bin:$PATH"
        eval "$($brew_path/bin/brew shellenv)" 2>/dev/null || true
        return 0
    fi
    
    echo "Homebrew is the package manager for macOS. It will install and manage all dependencies."
    echo "If Xcode Command Line Tools are missing, they'll be installed first."
    echo
    echo "This will execute: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo
    
    # Ask permission unless in auto mode
    ask_permission "Install Homebrew?"
    
    # Retry logic for Homebrew installation
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        print_status "Installing Homebrew (attempt $((retry_count + 1))/$max_retries)..."
        
        # Force non-interactive mode and handle potential prompts
        export CI=1
        export HOMEBREW_INSTALL_FROM_API=1
        
        if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            break
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                print_warning "Homebrew installation failed, retrying in 10 seconds..."
                sleep 10
            else
                print_error "Homebrew installation failed after $max_retries attempts"
                echo "Please check the error messages above and try again."
                return 1
            fi
        fi
    done
    
    # Configure Homebrew PATH for current session
    local brew_path
    if [[ $(uname -m) == 'arm64' ]]; then
        brew_path="/opt/homebrew"
    else
        brew_path="/usr/local"
    fi
    
    # Add to PATH and export environment
    export PATH="$brew_path/bin:$PATH"
    eval "$($brew_path/bin/brew shellenv)" 2>/dev/null || true
    
    # Verify Homebrew is working
    if ! command_exists brew; then
        print_error "Homebrew installation completed but 'brew' command not found in PATH"
        echo "You may need to restart your terminal or manually run:"
        echo "  eval \"\$($brew_path/bin/brew shellenv)\""
        return 1
    fi
    
    # Test brew functionality
    if ! brew --version >/dev/null 2>&1; then
        print_error "Homebrew is installed but not functioning correctly"
        echo "Try running: brew doctor"
        return 1
    fi
    
    print_status "Homebrew installed successfully ✓"
    print_status "Homebrew added to current session PATH ✓"
}

# Function to install dependencies with validation
install_dependencies() {
    print_step "Installing Dependencies"
    
    # Ensure brew is available
    if ! command_exists brew; then
        print_error "Homebrew not found in PATH"
        echo "Please ensure Homebrew is properly installed and in PATH."
        return 1
    fi
    
    echo "This will install all required tools using the Brewfile from GitHub:"
    echo "- Rancher Desktop (Kubernetes + Docker + kubectl + helm)"
    echo "- k9s (Terminal-based Kubernetes UI)"
    echo
    echo "Command: curl -fsSL $BREWFILE_URL | brew bundle --file=-"
    echo
    
    ask_permission "Install dependencies via Brewfile?"
    
    # Update Homebrew first
    print_status "Updating Homebrew..."
    if ! brew update >/dev/null 2>&1; then
        print_warning "Failed to update Homebrew, continuing with installation..."
    fi
    
    # Download and validate Brewfile first
    print_status "Downloading and validating Brewfile..."
    local brewfile_content
    if ! brewfile_content=$(curl -fsSL "$BREWFILE_URL"); then
        print_error "Failed to download Brewfile from $BREWFILE_URL"
        echo "Please check your internet connection and try again."
        return 1
    fi
    
    # Basic validation of Brewfile content
    if [[ ${#brewfile_content} -lt 100 ]]; then
        print_error "Downloaded Brewfile appears invalid (${#brewfile_content} bytes)"
        echo "Expected a larger file with package definitions."
        return 1
    fi
    
    # Install via brew bundle with error handling
    print_status "Installing packages via Brewfile..."
    
    # Handle the fact that bundle tap is now built into Homebrew
    # and cask tap is automatic - no need to explicitly tap them
    if echo "$brewfile_content" | HOMEBREW_NO_INSTALL_CLEANUP=1 brew bundle --file=-; then
        print_status "Dependencies installed successfully ✓"
    else
        print_warning "Some packages failed to install via Brewfile"
        print_status "Attempting individual package installation as fallback..."
        
        # Try installing critical packages individually
        local critical_packages=("rancher" "k9s")
        local failed_packages=()
        
        for package in "${critical_packages[@]}"; do
            print_status "Installing $package individually..."
            if brew install "$package" 2>/dev/null; then
                print_status "$package installed ✓"
            else
                failed_packages+=("$package")
                print_warning "Failed to install $package"
            fi
        done
        
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
            print_error "Failed to install: ${failed_packages[*]}"
            echo "You may need to install these manually or check 'brew doctor'"
            return 1
        else
            print_status "All critical packages installed successfully ✓"
        fi
    fi
    
    # Verify critical tools were installed
    print_status "Verifying critical tools installation..."
    local critical_tools=("kubectl" "docker")
    local missing_tools=()
    
    for tool in "${critical_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warning "The following critical tools were not found: ${missing_tools[*]}"
        echo "Note: kubectl and docker are included with Rancher Desktop and will be"
        echo "available once Rancher Desktop is running. This is normal."
    else
        print_status "All expected tools are available ✓"
    fi
}

# Function to download infrastructure with validation
download_infrastructure() {
    print_step "Downloading Urbalurba Infrastructure"
    
    echo "Downloading the latest release from GitHub..."
    
    ask_permission "Download Urbalurba Infrastructure package?"
    
    # Get latest release with better error handling
    print_status "Fetching latest release information..."
    local latest_response
    if ! latest_response=$(curl -s --max-time 30 "https://api.github.com/repos/$GITHUB_REPO/releases/latest"); then
        print_error "Failed to fetch release information from GitHub"
        return 1
    fi
    
    # Extract tag name
    local latest_tag
    latest_tag=$(echo "$latest_response" | grep '"tag_name"' | cut -d'"' -f4)
    
    if [[ -z "$latest_tag" ]]; then
        print_warning "Could not determine latest release, using fallback version"
        latest_tag="v16"  # Updated fallback version
        print_status "Using fallback version: $latest_tag"
    else
        print_status "Found latest version: $latest_tag"
    fi
    
    # Construct download URL
    local download_url="https://github.com/$GITHUB_REPO/releases/download/$latest_tag/urbalurba-infrastructure.zip"
    
    # Download with progress and validation
    print_status "Downloading from: $download_url"
    local temp_zip="urbalurba-infrastructure.zip.tmp"
    
    if ! curl -L --progress-bar --max-time 300 "$download_url" -o "$temp_zip"; then
        print_error "Failed to download infrastructure package"
        echo "URL: $download_url"
        [[ -f "$temp_zip" ]] && rm -f "$temp_zip"
        return 1
    fi
    
    # Verify download
    if [[ ! -f "$temp_zip" ]]; then
        print_error "Download completed but file not found"
        return 1
    fi
    
    # Check file size (basic validation)
    local file_size
    file_size=$(wc -c < "$temp_zip" 2>/dev/null || echo 0)
    if [[ $file_size -lt 1000 ]]; then
        print_error "Downloaded file is too small ($file_size bytes)"
        echo "This might be an error page instead of the actual package."
        rm -f "$temp_zip"
        return 1
    fi
    
    # Move to final location
    mv "$temp_zip" "urbalurba-infrastructure.zip"
    
    # Extract with error checking (overwrite without prompting)
    print_status "Extracting infrastructure..."
    if ! unzip -o -q urbalurba-infrastructure.zip; then
        print_error "Failed to extract zip file"
        echo "The downloaded file might be corrupted. Please try again."
        return 1
    fi
    
    # Clean up zip file
    rm urbalurba-infrastructure.zip
    
    print_status "Infrastructure downloaded and extracted ✓"
}

# Function to find rdctl in various locations
find_rancher_rdctl() {
    local rdctl_paths=(
        "/Applications/Rancher Desktop.app/Contents/Resources/resources/darwin/bin/rdctl"
        "/Applications/Rancher Desktop.app/Contents/Resources/resources/linux/bin/rdctl"
        "$HOME/.rd/bin/rdctl"
        "/usr/local/bin/rdctl"
        "/opt/homebrew/bin/rdctl"
    )
    
    for path in "${rdctl_paths[@]}"; do
        if [[ -x "$path" ]]; then
            export PATH="$(dirname "$path"):$PATH"
            return 0
        fi
    done
    
    return 1
}

# Function to setup Rancher Desktop with improved automation
setup_rancher() {
    print_step "Setting up Rancher Desktop"
    
    echo "Rancher Desktop provides Kubernetes and Docker runtime for development."
    echo "We'll configure it with optimal settings for your infrastructure."
    echo
    echo "Configuration:"
    echo "• Virtual Machine: VZ (Apple Virtualization framework)"
    echo "• Enable Rosetta support (for Intel compatibility)"
    echo "• Volumes: virtiofs (high performance file sharing)"
    echo "• Memory: 8GB, CPUs: 4 cores"
    echo "• Container Engine: Docker/Moby"
    echo
    print_warning "RESOURCE USAGE NOTICE:"
    echo "• Rancher Desktop will use ~8GB RAM and 4 CPU cores when running"
    echo "• It will NOT auto-start (you must start it manually when needed)"
    echo "• You can quit Rancher Desktop to free resources when not developing"
    echo "• To start/stop: Applications > Rancher Desktop"
    echo
    
    ask_permission "Configure and start Rancher Desktop?"
    
    # Enhanced rdctl detection
    if ! command_exists rdctl; then
        if find_rancher_rdctl; then
            print_status "Found rdctl in Rancher Desktop installation"
        else
            print_warning "rdctl not found, using GUI setup method"
            
            # GUI fallback
            if [[ -d "/Applications/Rancher Desktop.app" ]]; then
                print_status "Opening Rancher Desktop for manual configuration..."
                open -a "Rancher Desktop"
                echo
                print_warning "Please configure Rancher Desktop manually with these settings:"
                echo "  Virtual Machine > Emulation: VZ (Apple Virtualization)"
                echo "  Virtual Machine > Enable Rosetta support: ✓"
                echo "  Virtual Machine > Hardware: 8GB Memory, 4 CPUs"
                echo "  Virtual Machine > Volumes: virtiofs"
                echo "  Container Engine: Docker"
                echo "  Application > Auto-start: LEAVE UNCHECKED (manual control)"
                echo "  Wait for 'Running' status"
                ask_permission "Complete setup in GUI and press Enter when Kubernetes shows 'Running'"
                return 0
            else
                print_error "Rancher Desktop not found in /Applications/"
                echo "Please ensure Rancher Desktop was installed via Homebrew."
                return 1
            fi
        fi
    fi
    
    # Automated setup with rdctl
    print_status "Starting Rancher Desktop with optimized configuration..."
    
    # Core configuration arguments
    local rdctl_args=(
        "--container-engine.name=moby"
        "--application.path-management-strategy=rcfiles"
        "--virtual-machine.memory-in-gb=8"
        "--virtual-machine.number-cpus=4"
        "--application.auto-start=false"  # Explicitly disable auto-start
    )
    
    # Try with experimental VZ flags first
    print_status "Attempting advanced configuration with VZ virtualization..."
    if rdctl start "${rdctl_args[@]}" \
        --experimental.virtual-machine.type=vz \
        --experimental.virtual-machine.use-rosetta=true \
        --experimental.virtual-machine.mount-type=virtiofs \
        2>/dev/null; then
        
        print_status "Rancher Desktop started with VZ virtualization ✓"
    else
        print_warning "VZ virtualization flags not supported, using standard configuration..."
        
        # Fallback to basic configuration
        if rdctl start "${rdctl_args[@]}" 2>/dev/null; then
            print_status "Rancher Desktop started with standard configuration ✓"
        else
            print_warning "rdctl configuration failed, manual setup may be required"
            echo "Rancher Desktop has been installed but may need manual configuration."
            echo "Open Rancher Desktop from Applications and configure manually."
            return 1
        fi
    fi
    
    # Enhanced Kubernetes readiness check
    wait_for_kubernetes_ready
    
    # Display final configuration
    if command_exists rdctl; then
        print_status "Final Rancher Desktop configuration:"
        rdctl list-settings 2>/dev/null | grep -E "(virtualMachine|containerEngine|application)" | head -10 || echo "Configuration details not available"
    fi
    
    print_status "Rancher Desktop setup completed ✓"
    echo
    print_warning "REMEMBER: Rancher Desktop is configured but:"
    echo "• It will NOT auto-start when you log in (saves resources)"
    echo "• Start it manually when you need to develop: open 'Rancher Desktop' from Applications"
    echo "• Quit it when done developing to free up 8GB RAM and 4 CPU cores"
    echo "• You can change auto-start in Preferences > Application if desired"
}

# Advanced Kubernetes readiness check
wait_for_kubernetes_ready() {
    print_status "Waiting for Kubernetes to be fully ready..."
    local attempts=0
    local max_attempts=60  # 5 minutes total
    local ready_checks=0
    local required_ready_checks=3  # Require 3 consecutive successful checks
    
    while [[ $attempts -lt $max_attempts ]]; do
        local cluster_ready=false
        local nodes_ready=false
        local system_pods_ready=false
        
        # Check cluster connectivity
        if kubectl cluster-info >/dev/null 2>&1; then
            cluster_ready=true
            
            # Check if all nodes are ready
            if kubectl get nodes --no-headers 2>/dev/null | grep -v "NotReady" | grep -q "Ready"; then
                nodes_ready=true
                
                # Check system pods are running
                local pending_pods
                pending_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l || echo "0")
                if [[ $pending_pods -eq 0 ]]; then
                    system_pods_ready=true
                fi
            fi
        fi
        
        if [[ "$cluster_ready" == "true" && "$nodes_ready" == "true" && "$system_pods_ready" == "true" ]]; then
            ready_checks=$((ready_checks + 1))
            if [[ $ready_checks -ge $required_ready_checks ]]; then
                print_status "✓ Kubernetes is fully ready and stable"
                
                # Show cluster info
                print_status "Kubernetes cluster information:"
                kubectl cluster-info | head -3
                kubectl get nodes
                return 0
            fi
        else
            ready_checks=0
        fi
        
        printf "."
        sleep 5
        attempts=$((attempts + 1))
    done
    
    print_warning "Kubernetes readiness check timed out"
    echo "Cluster may still be starting. Check status manually:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -n kube-system"
    return 1
}

# Function to run infrastructure setup scripts (enhanced version)
setup_infrastructure() {
    print_step "Setting up Urbalurba Infrastructure"
    
    echo "Now we'll run the infrastructure setup scripts that come with the package."
    echo "These scripts set up the specific infrastructure components and configurations."
    echo
    
    # Check for and run setup-prerequisites-mac.sh first
    if [[ -f "setup-prerequisites-mac.sh" ]]; then
        chmod +x setup-prerequisites-mac.sh
        
        print_status "Found setup-prerequisites-mac.sh"
        
        # Test if prerequisites are already installed
        if ./setup-prerequisites-mac.sh test 2>/dev/null; then
            print_status "Prerequisites test passed - all requirements already met ✓"
        else
            print_warning "Prerequisites test indicates some items may need installation"
            if ask_permission "Run setup-prerequisites-mac.sh?"; then
                print_status "Running setup-prerequisites-mac.sh..."
                if ./setup-prerequisites-mac.sh; then
                    print_status "Prerequisites setup completed ✓"
                else
                    print_warning "Prerequisites setup had issues, but continuing..."
                fi
            fi
        fi
    else
        print_warning "setup-prerequisites-mac.sh not found in infrastructure package"
    fi
    
    # Check for and run install-rancher.sh
    if [[ -f "install-rancher.sh" ]]; then
        chmod +x install-rancher.sh
        
        print_status "Found install-rancher.sh"
        if ask_permission "Run install-rancher.sh for additional Rancher configuration?"; then
            print_status "Running install-rancher.sh..."
            if ./install-rancher.sh; then
                print_status "Rancher installation script completed ✓"
            else
                print_warning "Rancher installation script had issues"
                echo "This may be normal if Rancher was already configured by our setup."
            fi
        fi
    else
        print_status "install-rancher.sh not found - using our built-in Rancher setup ✓"
    fi
    
    # Look for and run other infrastructure setup scripts
    local other_scripts=()
    for script in setup-*.sh install-*.sh configure-*.sh deploy-*.sh; do
        if [[ -f "$script" && "$script" != "setup-prerequisites-mac.sh" && "$script" != "install-rancher.sh" ]]; then
            other_scripts+=("$script")
        fi
    done
    
    if [[ ${#other_scripts[@]} -gt 0 ]]; then
        print_status "Found additional setup scripts: ${other_scripts[*]}"
        for script in "${other_scripts[@]}"; do
            chmod +x "$script"
            if ask_permission "Run $script?"; then
                print_status "Running $script..."
                if ./"$script"; then
                    print_status "$script completed ✓"
                else
                    print_warning "$script had issues, but continuing..."
                fi
            fi
        done
    fi
    
    # Check for any template or example scripts
    if compgen -G "*.sh" >/dev/null; then
        print_status "All infrastructure setup scripts processed"
    fi
    
    # Check for README or documentation
    if [[ -f "README.md" ]]; then
        print_status "📖 Check README.md for detailed usage instructions"
    fi
    
    print_status "Infrastructure setup completed ✓"
}

# Error handling and cleanup
cleanup_on_error() {
    local exit_code=$?
    echo | tee -a "$LOG_FILE"
    print_error "Installation failed with exit code $exit_code"
    
    # Clean up partial downloads
    [[ -f "urbalurba-infrastructure.zip" ]] && rm -f urbalurba-infrastructure.zip
    [[ -f "urbalurba-infrastructure.zip.tmp" ]] && rm -f urbalurba-infrastructure.zip.tmp
    
    print_status "Cleaned up temporary files"
    
    # Provide troubleshooting suggestions
    echo "Troubleshooting suggestions:" | tee -a "$LOG_FILE"
    echo "1. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "2. Verify internet connection" | tee -a "$LOG_FILE"
    echo "3. Ensure sufficient disk space (8GB+)" | tee -a "$LOG_FILE"
    echo "4. Try running: brew doctor" | tee -a "$LOG_FILE"
    echo "5. Restart terminal and try again" | tee -a "$LOG_FILE"
    echo "6. For manual installation: ./install-urbalurba.sh --commands" | tee -a "$LOG_FILE"
    
    exit $exit_code
}

# Set up error handling
trap cleanup_on_error ERR

# Interactive installation - fixed flow to avoid duplicates
interactive_install() {
    # Reset step counter for interactive mode
    CURRENT_STEP=0
    TOTAL_STEPS=7
    
    echo "Urbalurba Infrastructure Complete Installer"
    echo "==========================================="
    echo
    echo "This installer provides a more comprehensive setup compared to update-urbalurba-infra.sh:"
    echo "• It first ensures all prerequisites are met (including Docker Desktop conflicts)"
    echo "• Then downloads the infrastructure package"
    echo "• Finally runs the infrastructure-specific setup scripts"
    echo
    echo "The installation includes:"
    echo "• Xcode Command Line Tools (if needed)"
    echo "• Homebrew (if not installed)"
    echo "• Rancher Desktop (Kubernetes + Docker + kubectl + helm)"
    echo "• k9s (Terminal Kubernetes UI)"
    echo "• Urbalurba Infrastructure components and scripts"
    echo
    echo "Log file: $LOG_FILE"
    echo
    
    ask_permission "Ready to start the installation?"
    
    # Check for existing installation
    if [[ -f "setup-prerequisites-mac.sh" ]]; then
        echo
        print_warning "Existing Urbalurba Infrastructure installation detected."
        echo "This installer will update your installation with enhanced prerequisite handling."
        ask_permission "Continue with the enhanced installation?"
    fi
    
    # Run infrastructure setup in the proper order
    check_prerequisites
    check_xcode_tools
    install_homebrew
    install_dependencies  # Install dependencies before downloading to have tools ready
    download_infrastructure  # Download infrastructure package
    setup_rancher  # Set up Rancher with our enhanced configuration
    setup_infrastructure  # Run the infrastructure's own setup scripts
    
    # Final success message
    print_step "Installation Complete!"
    echo "✨ Urbalurba Infrastructure is ready!"
    echo
    echo "Installation Summary:"
    echo "✓ Prerequisites installed and verified"
    echo "✓ Dependencies installed via Homebrew"
    echo "✓ Infrastructure package downloaded and extracted"
    echo "✓ Rancher Desktop configured optimally"
    echo "✓ Infrastructure scripts executed"
    echo
    echo "Next steps:"
    echo "1. Check README.md for specific infrastructure usage"
    echo "2. Start developing with cloud-native tools locally!"
    echo
    echo "To manage Rancher Desktop:"
    echo "• Start: Open 'Rancher Desktop' from Applications"
    echo "• Stop: Quit Rancher Desktop to free up 8GB RAM and 4 CPU cores"
    echo
    echo "Log file saved at: $LOG_FILE"
}

# Automatic installation
install_everything_automatically() {
    # Reset step counter for automatic mode
    CURRENT_STEP=0
    TOTAL_STEPS=7
    
    echo "Urbalurba Infrastructure Automatic Installer"
    echo "==========================================="
    print_warning "Running in automatic mode - minimal user interaction"
    echo "Log file: $LOG_FILE"
    echo
    
    AUTO_MODE=true
    
    # Run all installation steps automatically
    check_prerequisites
    check_xcode_tools
    install_homebrew
    install_dependencies
    download_infrastructure
    setup_rancher
    setup_infrastructure
    
    # Final success message
    print_step "Installation Complete!"
    echo "✨ Urbalurba Infrastructure installed automatically!"
    echo
    echo "Next steps:"
    echo "1. Rancher Desktop is configured and should be running"
    echo "2. Check README.md for infrastructure usage instructions"
    echo "3. Start developing with cloud-native tools!"
    echo
    echo "Log file saved at: $LOG_FILE"
}

# Main function
main() {
    # Create log file
    echo "# Urbalurba Infrastructure Installation Log" > "$LOG_FILE"
    echo "# Started: $(date)" >> "$LOG_FILE"
    echo "# Command: $0 $*" >> "$LOG_FILE"
    echo >> "$LOG_FILE"
    
    case "${1:-default}" in
        --commands)
            echo "Manual Installation Commands"
            echo "==========================="
            print_manual_commands
            ;;
        --auto)
            install_everything_automatically
            ;;
        --help)
            echo "Urbalurba Infrastructure Installer"
            echo "Usage:"
            echo "  $0              # Interactive mode (default)"
            echo "  $0 --commands   # Show manual commands only"
            echo "  $0 --auto       # Automatic installation"
            echo "  $0 --help       # Show this help"
            ;;
        *)
            interactive_install
            ;;
    esac
    
    # Log completion
    echo "# Completed: $(date)" >> "$LOG_FILE"
}

# Run main function with all arguments
main "$@"
