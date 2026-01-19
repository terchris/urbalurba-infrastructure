#!/bin/bash
# file: .devcontainer/additions/install-dev-rust.sh
#
# For usage information, run: ./install-dev-rust.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_ID="dev-rust"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Rust Development Tools"
SCRIPT_DESCRIPTION="Installs Rust (latest stable via rustup), cargo, and sets up Rust development environment"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="[ -f $HOME/.cargo/bin/rustc ] || command -v rustc >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="rust cargo rustup systems programming memory safety"
SCRIPT_ABSTRACT="Rust development environment with rustup, cargo tooling, and rust-analyzer for systems programming."
SCRIPT_LOGO="dev-rust-logo.webp"
SCRIPT_WEBSITE="https://www.rust-lang.org"
SCRIPT_SUMMARY="Complete Rust setup via rustup including the Rust compiler, Cargo package manager, cargo-edit for dependency management, cargo-watch for auto-rebuild, and cargo-outdated for dependency updates. Includes rust-analyzer and CodeLLDB debugger VS Code extensions."
SCRIPT_RELATED="dev-golang dev-cpp dev-typescript"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Rust development tools||false|"
    "Action|--uninstall|Uninstall Rust development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "build-essential"
    "pkg-config"
    "libssl-dev"
)

# Rust packages
PACKAGES_CARGO=(
    "cargo-edit"
    "cargo-watch"
    "cargo-outdated"
)

# VS Code extensions
EXTENSIONS=(
    "Rust Analyzer (rust-lang.rust-analyzer) - Rust language support with rust-analyzer"
    "CodeLLDB (vadimcn.vscode-lldb) - Native debugger for Rust"
    "Dependi (serayuzgur.dependi) - Replacement for Crates; manages Rust dependencies"
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

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Check if Rust is already installed
        if command -v rustc >/dev/null 2>&1; then
            echo "✅ Rust is already installed (version: $(rustc --version))"
        fi

        # Create Rust workspace directories
        mkdir -p $HOME/.cargo/bin
        echo "✅ Rust workspace directories created"
    fi
}

# Custom Rust installation function
install_rust() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️  Removing Rust installation..."
        
        # Remove rustup if it exists
        if command -v rustup >/dev/null 2>&1; then
            rustup self uninstall -y
            echo "✅ Rustup uninstalled"
        fi
        
        # Remove Rust environment from bashrc if it exists
        if grep -q "\.cargo/bin" ~/.bashrc 2>/dev/null; then
            sed -i '/# Rust environment/d' ~/.bashrc 2>/dev/null
            sed -i '/\.cargo\/bin/d' ~/.bashrc 2>/dev/null
            echo "✅ Rust environment removed from ~/.bashrc"
        fi
        
        # Remove cargo directory
        if [ -d "$HOME/.cargo" ]; then
            rm -rf "$HOME/.cargo"
            echo "✅ Cargo directory removed"
        fi
        
        # Remove rustup directory
        if [ -d "$HOME/.rustup" ]; then
            rm -rf "$HOME/.rustup"
            echo "✅ Rustup directory removed"
        fi
        
        return
    fi
    
    # Check if Rust is already installed
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        local current_version=$(rustc --version | awk '{print $2}')
        echo "✅ Rust is already installed (version: ${current_version})"
        
        # Ensure PATH is set
        if [ -d "$HOME/.cargo/bin" ] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
            add_to_bashrc ".cargo/bin" "# Rust environment" "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
        fi
        return
    fi
    
    echo "📦 Installing latest stable Rust via rustup..."
    
    # Download and install rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    
    # Source the cargo environment
    source $HOME/.cargo/env

    # Add to PATH in bashrc if not already there
    add_to_bashrc ".cargo/bin" "# Rust environment" "export PATH=\"\$HOME/.cargo/bin:\$PATH\""
    
    # Verify installation
    if command -v rustc >/dev/null 2>&1 && command -v cargo >/dev/null 2>&1; then
        echo "✅ Rust is now available: $(rustc --version)"
        echo "✅ Cargo is now available: $(cargo --version)"
    else
        echo "❌ Rust installation failed - not found in PATH"
        return 1
    fi

    echo "✅ Rust installation completed"
}

# Post-installation notes
post_installation_message() {
    local rust_version
    rust_version=$(rustc --version 2>/dev/null || echo "not found")

    local cargo_version
    cargo_version=$(cargo --version 2>/dev/null || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Rust: $rust_version"
    echo "   Cargo: $cargo_version"
    echo
    echo "Quick start: cargo new my_project && cd my_project && cargo run"
    echo "Docs: https://doc.rust-lang.org/"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Rustup uninstalled"
    echo "   ✅ Rust environment removed from ~/.bashrc"
    echo "   ✅ Cargo and rustup directories removed"
    echo
    echo "Note: Run 'hash -r' or start a new shell to clear the command hash table"
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
source "${SCRIPT_DIR}/lib/core-install-cargo.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"



#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # During uninstall: reverse order to uninstall dependents before dependencies
        # 1. Extensions (no dependencies)
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        # 2. Cargo packages (requires cargo binary to be present)
        if [ ${#PACKAGES_CARGO[@]} -gt 0 ]; then
            process_cargo_packages "PACKAGES_CARGO"
        fi
        # 3. Rust runtime (removes cargo binary and directories)
        install_rust
        # 4. System packages (base dependencies, removed last)
        if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
            process_system_packages "PACKAGES_SYSTEM"
        fi
    else
        # During install: install Rust runtime first
        install_rust
        # Then install packages and extensions
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
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0