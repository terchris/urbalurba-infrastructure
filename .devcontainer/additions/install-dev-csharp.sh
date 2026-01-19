#!/bin/bash
# file: .devcontainer/additions/install-dev-csharp.sh
#
# For usage information, run: ./install-dev-csharp.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-csharp"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="C# Development Tools"
SCRIPT_DESCRIPTION="Installs .NET SDK, ASP.NET Core Runtime, and VS Code extensions for C# development"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="[ -f $HOME/.dotnet/dotnet ] || [ -f /usr/bin/dotnet ] || command -v dotnet >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="csharp dotnet aspnet microsoft visual-studio sdk"
SCRIPT_ABSTRACT="C# and .NET development environment with SDK, ASP.NET Core runtime, and VS Code C# Dev Kit."
SCRIPT_LOGO="dev-csharp-logo.webp"
SCRIPT_WEBSITE="https://dotnet.microsoft.com"
SCRIPT_SUMMARY="Complete C# and .NET development setup including the .NET SDK, ASP.NET Core runtime for web development, and the C# Dev Kit for VS Code providing IntelliSense, debugging, and project management. Supports .NET 8.0 and other versions."
SCRIPT_RELATED="dev-java dev-typescript dev-python"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install C# / .NET development tools||false|"
    "Action|--uninstall|Uninstall C# / .NET development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# --- Default Configuration ---
DEFAULT_VERSION="8.0"
TARGET_VERSION=""

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# VS Code extensions
EXTENSIONS=(
    "C# Dev Kit (ms-dotnettools.csdevkit) - Complete C# development experience"
    "C# (ms-dotnettools.csharp) - C# language support"
    ".NET Runtime (ms-dotnettools.vscode-dotnet-runtime) - .NET runtime support"
)

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Add Microsoft Repository ---
add_microsoft_repository() {
    echo "➕ Adding Microsoft .NET repository..."

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="$keyring_dir/microsoft-archive-keyring.gpg"
    local repo_file="/etc/apt/sources.list.d/microsoft-prod.list"

    # Check if repository already configured
    if [ -f "$repo_file" ] && grep -q "packages.microsoft.com" "$repo_file" 2>/dev/null; then
        echo "✅ Microsoft repository already configured"
        sudo apt-get update -y > /dev/null 2>&1
        return
    fi

    # Create keyrings directory if needed
    sudo mkdir -p "$keyring_dir"

    # Download and install Microsoft GPG key
    wget -qO - https://packages.microsoft.com/keys/microsoft.asc | \
        sudo gpg --dearmor -o "$keyring_file"

    # Detect distribution
    local distro_id=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    local distro_version=$(lsb_release -rs)
    local distro_codename=$(lsb_release -cs)

    # Add repository based on distribution
    if [[ "$distro_id" == "debian" ]]; then
        # Debian repository
        echo "deb [arch=amd64,arm64,armhf signed-by=$keyring_file] https://packages.microsoft.com/debian/${distro_version%%.*}/prod ${distro_codename} main" | \
            sudo tee "$repo_file"
    else
        # Ubuntu repository
        echo "deb [arch=amd64,arm64,armhf signed-by=$keyring_file] https://packages.microsoft.com/repos/microsoft-ubuntu-${distro_codename}-prod ${distro_codename} main" | \
            sudo tee "$repo_file"
    fi

    # Update package lists
    sudo apt-get update -y > /dev/null 2>&1
    echo "✅ Microsoft repository added successfully"
}

# --- Install .NET SDK ---
install_dotnet() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        if command -v dotnet >/dev/null 2>&1; then
            echo "Removing .NET SDK..."

            # Determine version to remove
            local version="${TARGET_VERSION:-$DEFAULT_VERSION}"

            # Remove apt-installed packages
            sudo apt-get remove -y "dotnet-sdk-${version}" "aspnetcore-runtime-${version}" 2>/dev/null || true

            # Remove user installation if it exists
            if [ -d "$HOME/.dotnet" ]; then
                rm -rf "$HOME/.dotnet" 2>/dev/null || true
                echo "✅ User .NET installation removed"
            fi

            echo "✅ .NET SDK removed"
        else
            echo "✅ .NET SDK not installed, skipping"
        fi
        return
    fi

    # Determine version to install
    local version="${TARGET_VERSION:-$DEFAULT_VERSION}"
    echo "Installing .NET SDK ${version}..."

    # Method 1: Try apt installation
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        "dotnet-sdk-${version}" \
        "aspnetcore-runtime-${version}" 2>/dev/null; then
        echo "✅ .NET SDK ${version} installed via apt"
    else
        echo "⚠️  apt installation failed, trying Microsoft install script..."

        # Method 2: Fallback to Microsoft install script
        curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel "${version}"

        # Add to PATH for current session
        export DOTNET_ROOT=$HOME/.dotnet
        export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools

        # Add to bashrc if not already there
        if ! grep -q "DOTNET_ROOT" ~/.bashrc; then
            {
                echo ''
                echo '# .NET SDK configuration'
                echo 'export DOTNET_ROOT=$HOME/.dotnet'
                echo 'export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools'
            } >> ~/.bashrc
        fi

        echo "✅ .NET SDK ${version} installed via Microsoft script"
    fi

    # Verify installation
    if command -v dotnet >/dev/null 2>&1; then
        local installed_version=$(dotnet --version)
        echo "✅ .NET SDK verification successful: ${installed_version}"
    else
        echo "❌ .NET SDK installation failed - dotnet not found in PATH"
        exit 1
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local dotnet_version

    # Ensure .NET is in PATH
    export DOTNET_ROOT=$HOME/.dotnet
    export PATH=$PATH:$HOME/.dotnet:$HOME/.dotnet/tools

    dotnet_version=$(dotnet --version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   .NET SDK: $dotnet_version"
    echo
    echo "Quick start commands:"
    echo "  - Create console app:    dotnet new console"
    echo "  - Create web API:        dotnet new webapi"
    echo "  - Run project:           dotnet run"
    echo "  - Build project:         dotnet build"
    echo "  - Run tests:             dotnet test"
    echo
    echo "Note: For Azure Functions development, install Azure tools:"
    echo "  .devcontainer/additions/install-tool-azure.sh"
    echo
    echo "Docs: https://learn.microsoft.com/dotnet/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ .NET SDK and runtime removed"
    echo
    echo "Note: The following may remain:"
    echo "  - Global .NET tools in ~/.dotnet/tools"
    echo "  - NuGet package cache in ~/.nuget"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Uninstall order: extensions → .NET
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        install_dotnet
    else
        # Install order: STEP 1 → 2 → 3 → 4

        # STEP 1: Install system prerequisites FIRST
        if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
            process_system_packages "PACKAGES_SYSTEM"
        fi

        # STEP 2: Add Microsoft repository (now we have wget and gnupg)
        add_microsoft_repository

        # STEP 3: Install .NET SDK
        install_dotnet

        # STEP 4: Process VS Code extensions
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
    fi
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
