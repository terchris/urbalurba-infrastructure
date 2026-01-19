#!/bin/bash
# file: .devcontainer/additions/install-dev-cpp.sh
#
# For usage information, run: ./install-dev-cpp.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# Script metadata - must be at the very top of the configuration section
SCRIPT_ID="dev-cpp"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="C/C++ Development Tools"
SCRIPT_DESCRIPTION="Installs GCC, Clang, build tools, debuggers, and VS Code extensions for C/C++ development"
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="command -v gcc >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="c cpp gcc clang cmake make gdb lldb debugging"
SCRIPT_ABSTRACT="C/C++ development environment with GCC, Clang, CMake, debuggers, and VS Code extensions."
SCRIPT_LOGO="dev-cpp-logo.webp"
SCRIPT_WEBSITE="https://isocpp.org"
SCRIPT_SUMMARY="Complete C/C++ development setup including GCC and Clang compilers, CMake and Make build systems, GDB and LLDB debuggers, Valgrind for memory analysis, and clang-format/clang-tidy for code quality. Includes VS Code extension pack for C/C++ development."
SCRIPT_RELATED="dev-rust dev-fortran dev-golang"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install C/C++ development tools||false|"
    "Action|--uninstall|Uninstall C/C++ development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
PACKAGES_SYSTEM=(
    "build-essential"
    "gcc"
    "g++"
    "clang"
    "clang-format"
    "clang-tidy"
    "cmake"
    "make"
    "ninja-build"
    "gdb"
    "lldb"
    "valgrind"
    "pkg-config"
    "autoconf"
    "automake"
    "libtool"
)

# VS Code extensions
EXTENSIONS=(
    "C/C++ (ms-vscode.cpptools) - C/C++ IntelliSense, debugging, and code browsing"
    "C/C++ Extension Pack (ms-vscode.cpptools-extension-pack) - Popular extensions for C/C++ development"
    "CMake Tools (ms-vscode.cmake-tools) - CMake support for VS Code"
    "CMake (twxs.cmake) - CMake language support"
    "CodeLLDB (vadimcn.vscode-lldb) - Native debugger based on LLDB"
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

        # Check if gcc is already installed
        if command -v gcc >/dev/null 2>&1; then
            echo "✅ GCC is already installed (version: $(gcc --version | head -1))"
        fi

        # Check if clang is already installed
        if command -v clang >/dev/null 2>&1; then
            echo "✅ Clang is already installed (version: $(clang --version | head -1))"
        fi

        echo "✅ Pre-installation setup complete"
    fi
}

# Post-installation notes
post_installation_message() {
    local gcc_version
    gcc_version=$(gcc --version 2>/dev/null | head -1 || echo "not found")

    local clang_version
    clang_version=$(clang --version 2>/dev/null | head -1 || echo "not found")

    local cmake_version
    cmake_version=$(cmake --version 2>/dev/null | head -1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   GCC: $gcc_version"
    echo "   Clang: $clang_version"
    echo "   CMake: $cmake_version"
    echo
    echo "Quick start:"
    echo "  - Compile (GCC):   gcc -o myprogram myprogram.c"
    echo "  - Compile (Clang): clang -o myprogram myprogram.c"
    echo "  - With debug:      gcc -g -o myprogram myprogram.c"
    echo "  - Debug:           gdb ./myprogram"
    echo "  - Memory check:    valgrind ./myprogram"
    echo
    echo "CMake project:"
    echo "  mkdir build && cd build"
    echo "  cmake .."
    echo "  make"
    echo
    echo "Example hello.c:"
    echo "  #include <stdio.h>"
    echo "  int main() {"
    echo "      printf(\"Hello, C!\\n\");"
    echo "      return 0;"
    echo "  }"
    echo
    echo "Docs: https://gcc.gnu.org/onlinedocs/"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ C/C++ development tools removed"
    echo
    echo "Note: Some core build tools may remain if used by other packages"
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
        # During uninstall: reverse order to uninstall dependents before dependencies
        # 1. Extensions (no dependencies)
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
        # 2. System packages (base dependencies, removed last)
        if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
            process_system_packages "PACKAGES_SYSTEM"
        fi
    else
        # During install: use standard processing
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
