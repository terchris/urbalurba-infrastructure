#!/bin/bash
# file: .devcontainer/additions/install-dev-golang.sh
#
# For usage information, run: ./install-dev-golang.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for the Go script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-golang"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Go Runtime & Development Tools"
SCRIPT_DESCRIPTION="Installs Go runtime, common tools, and VS Code extensions for Go development."
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="[ -f /usr/local/go/bin/go ] || [ -f /usr/bin/go ] || command -v go >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="go golang gopls delve staticcheck protobuf"
SCRIPT_ABSTRACT="Go development environment with runtime, language server, debugger, and static analysis tools."
SCRIPT_LOGO="dev-golang-logo.webp"
SCRIPT_WEBSITE="https://go.dev"
SCRIPT_SUMMARY="Complete Go development setup including the Go runtime, gopls language server for IDE features, Delve debugger, and staticcheck for code analysis. Includes VS Code extensions for Go development, test running, and Protocol Buffer support."
SCRIPT_RELATED="dev-rust dev-typescript dev-python"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Go with default version||false|"
    "Action|--version|Install specific Go version||true|Enter Go version (e.g., 1.21.0)"
    "Action|--uninstall|Uninstall Go development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Go packages
PACKAGES_GO=(
    "golang.org/x/tools/gopls@latest"
    "github.com/go-delve/delve/cmd/dlv@latest"
    "honnef.co/go/tools/cmd/staticcheck@latest"
)

# VS Code extensions
EXTENSIONS=(
    "Go (golang.go) - Core Go language support"
    "Go Test Explorer (premparihar.gotestexplorer) - Test runner and debugger"
    "Protocol Buffers (zxh404.vscode-proto3) - Protocol Buffer support"
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

# --- Default Configuration ---
# Standard version variables (for scripts that support --version flag)
DEFAULT_VERSION="1.21.0"  # Default version to install if --version not specified
TARGET_VERSION=""         # Actual version to install (set by --version flag or defaults to DEFAULT_VERSION)


# Set up Go installation directories (needed for both install and uninstall)
GO_INSTALL_DIR="/usr/local/go"
GO_BIN_DIR="/usr/local/go/bin"

# --- Utility Functions ---
get_installed_go_version() {
    if command -v go > /dev/null; then
        go version | grep -oP 'go\K[0-9.]+'
    else
        echo ""
    fi
}

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for Go uninstallation..."
        if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION=$(get_installed_go_version)
            if [ -z "$TARGET_VERSION" ]; then
                echo "ℹ️ Could not detect Go version from PATH, will remove installation from $GO_INSTALL_DIR if present."
            else
                echo "ℹ️ Detected Go version $TARGET_VERSION for uninstallation."
            fi
        else
            echo "ℹ️ Uninstalling Go version $TARGET_VERSION as specified."
        fi
    else
        echo "🔧 Performing pre-installation setup for Go..."
        SYSTEM_ARCH=$(detect_architecture)
        echo "🖥️ Detected system architecture: $SYSTEM_ARCH"

        if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION="$DEFAULT_VERSION"
            echo "ℹ️ No --version specified, using default: $TARGET_VERSION"
        else
            echo "ℹ️ Target Go version specified: $TARGET_VERSION"
        fi

        local current_version=$(get_installed_go_version)
        if [[ "$current_version" == "$TARGET_VERSION" ]]; then
            echo "✅ Go $TARGET_VERSION seems to be already installed."
        elif [ -n "$current_version" ]; then
            echo "⚠️ Go version $current_version is installed. This script will install $TARGET_VERSION alongside it."
            echo "   You may need to update your PATH to use the new version."
        fi
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local go_version
    go_version=$(get_installed_go_version)

    if [ -z "$go_version" ]; then
        go_version="not found"
    fi

    echo
    echo "🎉 Installation complete!"
    echo "   Go: $go_version"
    echo "   Workspace: $GOPATH"
    echo
    echo "Quick start: go mod init example.com/hello"
    echo "Docs: https://golang.org/doc/"
    echo
}

post_uninstallation_message() {
    local go_version
    go_version=$(get_installed_go_version)

    echo
    echo "🏁 Uninstallation complete!"
    if [ -n "$go_version" ]; then
        echo "   ⚠️  Go $go_version still found in PATH"
    else
        echo "   ✅ Go removed"
    fi
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
        --version)
            if [[ -n "$2" && "$2" != --* ]]; then
                TARGET_VERSION="$2"
                shift 2
            else
                echo "Error: --version requires a value (e.g., 1.21.0)" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force] [--version X.Y.Z]"
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
CORE_SCRIPT_DIR="$(dirname "$0")"
source "${CORE_SCRIPT_DIR}/lib/core-install-system.sh"
source "${CORE_SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${CORE_SCRIPT_DIR}/lib/core-install-go.sh"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to install Go from official binaries
install_go_binary() {
    local version="$1"
    local arch="$2"
    local install_dir="$3"

    echo "📦 Downloading Go $version for $arch..."

    # Download Go binary
    local download_url="https://go.dev/dl/go${version}.linux-${arch}.tar.gz"
    local temp_file="/tmp/go${version}.linux-${arch}.tar.gz"

    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        echo "❌ Failed to download Go from $download_url"
        return 1
    fi

    echo "📦 Extracting Go to $install_dir..."

    # Remove existing installation if present
    if [ -d "$install_dir" ]; then
        echo "🗑️  Removing existing Go installation..."
        sudo rm -rf "$install_dir"
    fi

    # Extract to /usr/local
    if ! sudo tar -C /usr/local -xzf "$temp_file"; then
        echo "❌ Failed to extract Go"
        rm -f "$temp_file"
        return 1
    fi

    rm -f "$temp_file"
    echo "✅ Go $version installed successfully"
    return 0
}

# Function to setup Go environment
setup_go_environment() {
    local go_bin_dir="$1"

    # Add Go to PATH in .bashrc if not already present
    add_to_bashrc "$go_bin_dir" "# Go environment" "export PATH=\"$go_bin_dir:\$PATH\""

    # Setup GOPATH
    local gopath="$HOME/go"
    if [ ! -d "$gopath" ]; then
        mkdir -p "$gopath"/{bin,src,pkg}
        echo "✅ Created GOPATH directory structure at $gopath"
    fi

    add_to_bashrc "GOPATH" "# Go workspace" "export GOPATH=\"$gopath\"" "export PATH=\"\$GOPATH/bin:\$PATH\""
}

# Function to process installations
process_installations() {
    # Custom Go binary installation/uninstallation first
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Uninstall Go binary
        if [ -d "$GO_INSTALL_DIR" ]; then
            echo "🗑️  Removing Go installation from $GO_INSTALL_DIR..."
            sudo rm -rf "$GO_INSTALL_DIR"
            echo "✅ Go removed"
        else
            echo "ℹ️  No Go installation found at $GO_INSTALL_DIR"
        fi

        # Note: We don't remove .bashrc entries to avoid breaking user's shell config
        echo "ℹ️  Note: PATH entries in ~/.bashrc were not removed"

        # Uninstall only Go-specific items (NOT system packages)
        # System packages (curl, gnupg, etc.) are prerequisites that other tools use
        if [ ${#PACKAGES_GO[@]} -gt 0 ]; then
            process_go_packages "PACKAGES_GO"
        fi

        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
    else
        # Install Go binary
        SYSTEM_ARCH=$(detect_architecture)

        # Map architecture names
        case "$SYSTEM_ARCH" in
            amd64|x86_64) SYSTEM_ARCH="amd64" ;;
            arm64|aarch64) SYSTEM_ARCH="arm64" ;;
        esac

        if ! install_go_binary "$TARGET_VERSION" "$SYSTEM_ARCH" "$GO_INSTALL_DIR"; then
            echo "❌ Go installation failed"
            exit 1
        fi

        setup_go_environment "$GO_BIN_DIR"

        # Source the environment so we can use go commands
        export PATH="$GO_BIN_DIR:$PATH"
        export GOPATH="$HOME/go"

        # Then use standard processing from lib/install-common.sh
        # This handles: PACKAGES_SYSTEM, PACKAGES_GO, EXTENSIONS
        process_standard_installations
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

    # Ensure Go is in PATH for post-installation message
    export PATH="$GO_BIN_DIR:$PATH"
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0 