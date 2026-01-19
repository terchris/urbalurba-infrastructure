#!/bin/bash
# file: .devcontainer/additions/install-dev-java.sh
#
# For usage information, run: ./install-dev-java.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for the Java script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-java"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Java Runtime & Development Tools"
SCRIPT_DESCRIPTION="Installs Java JDK, Maven, Gradle, and VS Code extensions for Java development."
SCRIPT_CATEGORY="LANGUAGE_DEV"
SCRIPT_CHECK_COMMAND="[ -f /usr/bin/java ] || [ -f /usr/lib/jvm/*/bin/java ] || command -v java >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="java jdk maven gradle spring enterprise"
SCRIPT_ABSTRACT="Java development environment with JDK, Maven, Gradle, and comprehensive VS Code extension pack."
SCRIPT_LOGO="dev-java-logo.webp"
SCRIPT_WEBSITE="https://dev.java"
SCRIPT_SUMMARY="Complete Java development setup including the JDK (supports versions 11, 17, 21), Maven and Gradle build tools, and the VS Code Extension Pack for Java with debugging, test running, Maven integration, and dependency management."
SCRIPT_RELATED="dev-csharp dev-golang dev-typescript"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install Java with default version||false|"
    "Action|--version|Install specific Java version||true|Enter Java version (e.g., 11, 17, 21)"
    "Action|--uninstall|Uninstall Java development tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages (all packages already in base devcontainer - see Dockerfile.base)
PACKAGES_SYSTEM=()

# Java packages (non-version-dependent)
PACKAGES_JAVA=(
    "maven"
    "gradle"
)

# VS Code extensions
EXTENSIONS=(
    "Language Support for Java (redhat.java) - Core Java language support"
    "Debugger for Java (vscjava.vscode-java-debug) - Debugging support"
    "Test Runner for Java (vscjava.vscode-java-test) - Test runner and debugger"
    "Maven for Java (vscjava.vscode-maven) - Maven project support"
    "Dependency Viewer (vscjava.vscode-java-dependency) - View and manage dependencies"
    "Extension Pack for Java (vscjava.vscode-java-pack) - Collection of popular Java extensions"
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
DEFAULT_VERSION="17"  # Default version to install if --version not specified
TARGET_VERSION=""     # Actual version to install (set by --version flag or defaults to DEFAULT_VERSION)

# --- Utility Functions ---
get_installed_java_version() {
    if command -v java > /dev/null; then
        java -version 2>&1 | head -n 1 | grep -oP 'version "\K[^"]+' | cut -d. -f1
    else
        echo ""
    fi
}

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for Java uninstallation..."
        if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION=$(get_installed_java_version)
            if [ -z "$TARGET_VERSION" ]; then
                echo "ℹ️ Could not detect Java version from PATH, will attempt to remove common versions."
            else
                echo "ℹ️ Detected Java version $TARGET_VERSION for uninstallation."
            fi
        else
            echo "ℹ️ Uninstalling Java version $TARGET_VERSION as specified."
        fi
    else
        echo "🔧 Performing pre-installation setup for Java..."
        SYSTEM_ARCH=$(detect_architecture)
        echo "🖥️ Detected system architecture: $SYSTEM_ARCH"

        if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION="$DEFAULT_VERSION"
            echo "ℹ️ No --version specified, using default: $TARGET_VERSION"
        else
            echo "ℹ️ Target Java version specified: $TARGET_VERSION"
        fi

        local current_version=$(get_installed_java_version)
        if [[ "$current_version" == "$TARGET_VERSION" ]]; then
            echo "✅ Java $TARGET_VERSION seems to be already installed."
        elif [ -n "$current_version" ]; then
            echo "⚠️ Java version $current_version is installed. This script will install $TARGET_VERSION alongside it."
            echo "   You may need to use 'update-alternatives' to switch between them."
        fi
    fi
}

# Function to add Adoptium repository
add_adoptium_repository() {
    echo "➕ Adding Adoptium repository..."

    local keyring_dir="/etc/apt/keyrings"
    local keyring_file="$keyring_dir/adoptium-archive-keyring.gpg"

    if ! grep -q "adoptium" /etc/apt/sources.list.d/adoptium.list 2>/dev/null; then
        # Create keyrings directory if it doesn't exist
        sudo mkdir -p "$keyring_dir"

        # Download and install GPG key using modern approach
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
            sudo gpg --dearmor -o "$keyring_file"

        # Add repository with signed-by option
        echo "deb [signed-by=$keyring_file] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
            sudo tee /etc/apt/sources.list.d/adoptium.list
    else
        echo "ℹ️ Adoptium repository already added."
    fi

    echo "🔄 Updating package lists after adding repository..."
    sudo apt-get update -y > /dev/null 2>&1
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local java_version
    java_version=$(java -version 2>&1 | head -n 1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   Java: $java_version"
    echo "   Maven: $(mvn --version 2>/dev/null | head -n 1 || echo 'not found')"
    echo "   Gradle: $(gradle --version 2>/dev/null | grep "^Gradle" || echo 'not found')"
    echo
    echo "Quick start: mvn archetype:generate"
    echo "Docs: https://docs.oracle.com/en/java/"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    if command -v java >/dev/null; then
        echo "   ⚠️  Java still found in PATH"
    else
        echo "   ✅ Java removed"
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
                echo "Error: --version requires a value (e.g., 17, 21)" >&2
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force] [--version X]"
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

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to install/uninstall Java JDK and build tools
install_java() {
    local jdk_package="temurin-${TARGET_VERSION}-jdk"

    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🗑️ Removing Java installation..."

        # Remove JDK
        if dpkg -l "$jdk_package" 2>/dev/null | grep -q "^ii"; then
            echo "  Removing $jdk_package..."
            sudo apt-get remove -y "$jdk_package" > /dev/null 2>&1 || true
        fi

        # Remove build tools using PACKAGES_JAVA array
        for package in "${PACKAGES_JAVA[@]}"; do
            if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
                echo "  Removing $package..."
                sudo apt-get remove -y "$package" > /dev/null 2>&1 || true
            fi
        done

        # Clean up
        sudo apt-get autoremove -y > /dev/null 2>&1 || true
        echo "✅ Java removed"
    else
        echo "📦 Installing Java $TARGET_VERSION..."

        # Install JDK
        if sudo apt-get install -y "$jdk_package" > /dev/null 2>&1; then
            echo "  ✅ Installed $jdk_package"
        else
            echo "  ⚠️  Failed to install $jdk_package"
            return 1
        fi

        # Install build tools using PACKAGES_JAVA array
        for package in "${PACKAGES_JAVA[@]}"; do
            if sudo apt-get install -y "$package" > /dev/null 2>&1; then
                echo "  ✅ Installed $package"
            else
                echo "  ⚠️  Failed to install $package"
            fi
        done

        echo "✅ Java installation completed"
    fi
}

# Function to setup JAVA_HOME
setup_java_environment() {
    local java_home=""

    # Find JAVA_HOME
    if command -v java >/dev/null 2>&1; then
        java_home=$(dirname $(dirname $(readlink -f $(which java))))
    fi

    if [ -n "$java_home" ]; then
        # Add JAVA_HOME to .bashrc using library function
        add_to_bashrc "JAVA_HOME" "# Java environment" "export JAVA_HOME=\"$java_home\"" "export PATH=\"\$JAVA_HOME/bin:\$PATH\""

        # Export for current session
        export JAVA_HOME="$java_home"
        export PATH="$JAVA_HOME/bin:$PATH"
    fi
}

# Function to process installations
process_installations() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        # Uninstall only Java-specific items (NOT system packages)
        install_java

        # Process VS Code extensions
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
    else
        # STEP 1: Install system prerequisites FIRST (wget, gnupg needed for repository)
        if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
            process_system_packages "PACKAGES_SYSTEM"
        fi

        # STEP 2: Add Adoptium repository (now we have wget and gnupg)
        add_adoptium_repository

        # STEP 3: Install Java JDK and build tools
        install_java
        setup_java_environment

        # STEP 4: Process VS Code extensions
        if [ ${#EXTENSIONS[@]} -gt 0 ]; then
            process_extensions "EXTENSIONS"
        fi
    fi
}

# Function to verify installations
# Note: Using common implementation from lib/install-common.sh (sourced above)
# No local definition needed - library function is used directly

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