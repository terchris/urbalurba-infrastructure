#!/bin/bash
# ============================================================================
# File: lib/install-common.sh
# Description: Common installation patterns shared across install-*.sh scripts
# Version: 1.0.0
# Date: 2025-11-28
# ============================================================================
#
# This library provides common functions used by install-*.sh scripts to
# reduce code duplication and ensure consistent behavior.
#
# Usage:
#   source "${SCRIPT_DIR}/lib/install-common.sh"
#
# Functions provided:
#   - show_script_help()                  Display script metadata and packages (--help)
#   - verify_installations()              Verify installed tools/packages
#   - process_standard_installations()    Process standard package arrays
#   - ensure_secrets_folder_structure()   Create .devcontainer.secrets folder structure
#   - ensure_secrets_folder_gitignored()  Ensure .devcontainer.secrets/ in .gitignore
#
# Dependencies:
#   - core-install-*.sh (for package processing functions)
#   - Package arrays: PACKAGES_SYSTEM, PACKAGES_NODE, PACKAGES_JAVA, etc.
#
# ============================================================================

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ Error: This script must be sourced, not executed directly"
    echo "Usage: source \"\${SCRIPT_DIR}/lib/install-common.sh\""
    exit 1
fi

# Source categories library for category display names
COMMON_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "${COMMON_LIB_DIR}/categories.sh"

# ============================================================================
# Function: show_script_help
# Description: Display comprehensive help information for install scripts
#
# Usage:
#   show_script_help
#
# Parameters: None
#
# Dependencies:
#   Reads metadata variables from calling script:
#   - SCRIPT_ID, SCRIPT_NAME, SCRIPT_DESCRIPTION, SCRIPT_CATEGORY
#   - SCRIPT_CHECK_COMMAND, SCRIPT_PREREQUISITES
#   - SCRIPT_COMMANDS - Commands array for dynamic help generation
#   - PACKAGES_SYSTEM, PACKAGES_NODE, PACKAGES_PYTHON, PACKAGES_PWSH
#   - PACKAGES_GO, PACKAGES_CARGO, PACKAGES_DOTNET, PACKAGES_JAVA
#   - EXTENSIONS
#
# Output:
#   Formatted help text showing:
#   - Script metadata
#   - Installation check command
#   - Prerequisites
#   - Available options (generated from SCRIPT_COMMANDS or fallback)
#   - Packages to be installed
#   - Verification commands
#
# Examples:
#   # At start of install script
#   if [[ "$1" == "--help" ]]; then
#       show_script_help
#       exit 0
#   fi
# ============================================================================
show_script_help() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 ${SCRIPT_NAME:-Script Help}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Script Information
    [[ -n "$SCRIPT_ID" ]] && echo "ID:           $SCRIPT_ID"
    [[ -n "$SCRIPT_NAME" ]] && echo "Name:         $SCRIPT_NAME"
    [[ -n "${SCRIPT_VER:-}" ]] && echo "Script version: $SCRIPT_VER"
    if [[ -n "$SCRIPT_CATEGORY" ]]; then
        local category_display=$(get_category_display_name "$SCRIPT_CATEGORY")
        echo "Category:     $SCRIPT_CATEGORY, $category_display"
    fi
    [[ -n "$SCRIPT_DESCRIPTION" ]] && echo "Description:  $SCRIPT_DESCRIPTION"
    [[ -n "$DEFAULT_VERSION" ]] && echo "Default:      Version $DEFAULT_VERSION"
    echo ""

    # Prerequisites
    if [[ -n "$SCRIPT_PREREQUISITES" ]]; then
        echo "Prerequisites:"
        IFS=',' read -ra PREREQS <<< "$SCRIPT_PREREQUISITES"
        for prereq in "${PREREQS[@]}"; do
            echo "  - $prereq"
        done
        echo ""
    fi

    # Usage - generate from SCRIPT_COMMANDS if available
    echo "Usage:"
    if [[ ${#SCRIPT_COMMANDS[@]} -gt 0 ]]; then
        # Generate usage from SCRIPT_COMMANDS array
        local script_basename
        script_basename=$(basename "$0")
        local current_category=""

        for cmd_def in "${SCRIPT_COMMANDS[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Print category header when category changes
            if [[ "$category" != "$current_category" && -n "$category" ]]; then
                echo ""
                echo "  $category:"
                current_category="$category"
            fi

            # Build usage line
            local usage_line="  $script_basename"
            if [[ -n "$flag" ]]; then
                if [[ "$requires_arg" == "true" ]]; then
                    usage_line="$usage_line $flag <arg>"
                else
                    usage_line="$usage_line $flag"
                fi
            fi
            # Pad to align descriptions
            printf "    %-35s # %s\n" "$usage_line" "$description"
        done
    else
        # Default usage pattern if nothing else defined
        echo "  $(basename "$0")              # Install"
        echo "  $(basename "$0") --help       # Show this help"
        echo "  $(basename "$0") --uninstall  # Uninstall (if supported)"
    fi
    echo ""

    # Packages to Install
    local has_packages=false

    # Check for both naming conventions: SYSTEM_PACKAGES and PACKAGES_SYSTEM
    if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
        has_packages=true
        echo "System Packages (APT):"
        if [ ${#SYSTEM_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${SYSTEM_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_SYSTEM[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#NODE_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_NODE[@]} -gt 0 ]; then
        has_packages=true
        echo "Node.js Packages (NPM):"
        if [ ${#NODE_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${NODE_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_NODE[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#PYTHON_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_PYTHON[@]} -gt 0 ]; then
        has_packages=true
        echo "Python Packages (pip):"
        if [ ${#PYTHON_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${PYTHON_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_PYTHON[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#PWSH_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_PWSH[@]} -gt 0 ]; then
        has_packages=true
        echo "PowerShell Modules:"
        if [ ${#PWSH_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${PWSH_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_PWSH[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#GO_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_GO[@]} -gt 0 ]; then
        has_packages=true
        echo "Go Packages (go install):"
        if [ ${#GO_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${GO_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_GO[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#CARGO_PACKAGES[@]} -gt 0 ] || [ ${#PACKAGES_CARGO[@]} -gt 0 ]; then
        has_packages=true
        echo "Rust Packages (cargo install):"
        if [ ${#CARGO_PACKAGES[@]} -gt 0 ]; then
            for pkg in "${CARGO_PACKAGES[@]}"; do
                echo "  - $pkg"
            done
        else
            for pkg in "${PACKAGES_CARGO[@]}"; do
                echo "  - $pkg"
            done
        fi
        echo ""
    fi

    if [ ${#PACKAGES_DOTNET[@]} -gt 0 ]; then
        has_packages=true
        echo ".NET Tools (dotnet tool install --global):"
        for pkg in "${PACKAGES_DOTNET[@]}"; do
            echo "  - $pkg"
        done
        echo ""
    fi

    if [ ${#PACKAGES_JAVA[@]} -gt 0 ]; then
        has_packages=true
        echo "Java Build Tools (APT):"
        for pkg in "${PACKAGES_JAVA[@]}"; do
            echo "  - $pkg"
        done
        echo ""
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        has_packages=true
        echo "VS Code Extensions:"
        for ext in "${EXTENSIONS[@]}"; do
            echo "  - $ext"
        done
        echo ""
    fi

    if [ "$has_packages" = false ]; then
        echo "Packages: Custom installation (see script for details)"
        echo ""
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# Function: verify_installations
# Description: Execute verification commands for installed tools/packages
#
# Usage:
#   verify_installations                 # Silent mode (default)
#   verify_installations "true"          # Verbose mode (show commands)
#
# Parameters:
#   $1 (optional): Verbosity flag ("true"/"false", default: "false")
#
# Dependencies:
#   VERIFY_COMMANDS array must be defined in calling script
#
# Examples:
#   VERIFY_COMMANDS+=("command -v docker")
#   VERIFY_COMMANDS+=("docker --version")
#   verify_installations
# ============================================================================
verify_installations() {
    local verbose="${1:-false}"  # Optional: "true" to show commands, default "false"

    if [ ${#VERIFY_COMMANDS[@]} -gt 0 ]; then
        echo
        echo "🔍 Verifying installations..."

        for cmd in "${VERIFY_COMMANDS[@]}"; do
            if [ "$verbose" = "true" ]; then
                echo "  Running: $cmd"
            fi

            if ! eval "$cmd" 2>/dev/null; then
                echo "  ❌ Verification failed for: $cmd"
            fi
        done
    fi
}

# ============================================================================
# Function: process_standard_installations
# Description: Process standard package arrays (SYSTEM, NODE, PYTHON, PWSH, DOTNET, EXTENSIONS)
#
# Usage:
#   process_standard_installations
#
# Parameters: None
#
# Dependencies:
#   - Package arrays (optional, only processed if not empty):
#     * PACKAGES_SYSTEM - APT packages
#     * PACKAGES_NODE - NPM global packages
#     * PACKAGES_PYTHON - Python packages (pip/pipx)
#     * PACKAGES_PWSH - PowerShell modules
#     * PACKAGES_DOTNET - .NET global tools
#     * EXTENSIONS - VS Code extensions
#   - Processing functions from core-install-*.sh:
#     * process_system_packages()
#     * process_node_packages()
#     * process_python_packages()
#     * process_pwsh_modules()
#     * process_dotnet_tools()
#     * process_extensions()
#
# Examples:
#   # Simple script - just call the function
#   process_installations() {
#       process_standard_installations
#   }
#
#   # Complex script - custom logic then standard processing
#   process_installations() {
#       install_custom_tool
#       setup_custom_config
#       process_standard_installations
#   }
# ============================================================================
process_standard_installations() {
    # STEP 1: Common setup for ALL install scripts
    # Ensure .devcontainer.secrets folder is properly configured
    ensure_secrets_folder_gitignored
    ensure_secrets_folder_structure
    create_secrets_local_gitignore

    # Copy general README if it doesn't exist
    if [ ! -f /workspace/.devcontainer.secrets/README.md ]; then
        copy_secrets_readme
    fi

    # STEP 2: Process each package type if array is not empty
    if [ ${#PACKAGES_SYSTEM[@]} -gt 0 ]; then
        process_system_packages "PACKAGES_SYSTEM"
    fi

    if [ ${#PACKAGES_NODE[@]} -gt 0 ]; then
        process_node_packages "PACKAGES_NODE"
    fi

    if [ ${#PACKAGES_PYTHON[@]} -gt 0 ]; then
        process_python_packages "PACKAGES_PYTHON"
    fi

    if [ ${#PACKAGES_PWSH[@]} -gt 0 ]; then
        process_pwsh_modules "PACKAGES_PWSH"
    fi

    if [ ${#PACKAGES_GO[@]} -gt 0 ]; then
        process_go_packages "PACKAGES_GO"
    fi

    if [ ${#PACKAGES_CARGO[@]} -gt 0 ]; then
        process_cargo_packages "PACKAGES_CARGO"
    fi

    if [ ${#PACKAGES_DOTNET[@]} -gt 0 ]; then
        process_dotnet_tools "PACKAGES_DOTNET"
    fi

    if [ ${#EXTENSIONS[@]} -gt 0 ]; then
        process_extensions "EXTENSIONS"
    fi
}

# ============================================================================
# Function: ensure_secrets_folder_structure
# Description: Creates standard .devcontainer.secrets folder structure
#
# Usage:
#   ensure_secrets_folder_structure
#
# Parameters: None
#
# Returns:
#   0 - Always succeeds (idempotent)
#
# Purpose:
#   Creates the standard folder structure for storing sensitive data:
#   - /workspace/.devcontainer.secrets/ (parent folder)
#   - /workspace/.devcontainer.secrets/env-vars/ (environment variables)
#
#   This is the standard location for:
#   - Environment variable files (.claude-code-env, .host-info, etc.)
#   - API keys and credentials
#   - Any sensitive configuration
#
# Examples:
#   # In install script that needs to store env vars or credentials
#   ensure_secrets_folder_structure
#
# Scripts using this:
#   - install-dev-ai-claudecode.sh (stores .claude-code-env)
#   - install-kubectl.sh (stores kubeconfig)
#   - install-srv-otel-monitoring.sh (references .host-info)
# ============================================================================
ensure_secrets_folder_structure() {
    # Create parent directory
    mkdir -p /workspace/.devcontainer.secrets

    # Create env-vars subdirectory (standard location for environment files)
    mkdir -p /workspace/.devcontainer.secrets/env-vars

    # Note: We don't echo anything here to avoid noise
    # Scripts that need it will call this silently as part of setup
}

# ============================================================================
# Function: copy_secrets_readme
# Description: Copies the README template to .devcontainer.secrets folder
#              explaining what the folder is for and what can be stored there
#
# Usage:
#   copy_secrets_readme
#
# Parameters: None
#
# Returns:
#   0 - README copied successfully
#   1 - Template file not found
#
# Notes:
#   - Copies from addition-templates/README-secrets.md
#   - Creates /workspace/.devcontainer.secrets/README.md
#   - General documentation for all secrets, not tool-specific
#   - Tool-specific documentation should go in subdirectories
# ============================================================================
copy_secrets_readme() {
    local template_file="${SCRIPT_DIR}/addition-templates/README-secrets.md"
    local target_file="/workspace/.devcontainer.secrets/README.md"

    if [ ! -f "$template_file" ]; then
        echo "⚠️  Warning: README template not found at $template_file"
        return 1
    fi

    cp "$template_file" "$target_file"
    return 0
}

# ============================================================================
# Function: create_secrets_local_gitignore
# Description: Creates local .gitignore inside .devcontainer.secrets/
#              for double protection - ignores everything with no exceptions
#
# Usage:
#   create_secrets_local_gitignore
#
# Parameters: None
#
# Returns:
#   0 - Always succeeds (idempotent)
#
# Purpose:
#   Second layer of protection against committing secrets
#   Ensures entire folder is ignored even if root .gitignore is modified
#
# Notes:
#   - Creates /workspace/.devcontainer.secrets/.gitignore
#   - Safe to call multiple times (won't recreate if exists)
#   - No exceptions - ignores all files in this folder
# ============================================================================
create_secrets_local_gitignore() {
    local gitignore_file="/workspace/.devcontainer.secrets/.gitignore"

    # Skip if already exists
    if [ -f "$gitignore_file" ]; then
        return 0
    fi

    cat > "$gitignore_file" <<'EOF'
# Ignore everything in .devcontainer.secrets/
# No exceptions - this folder should never be committed
*
EOF
}

# ============================================================================
# Function: ensure_secrets_folder_gitignored
# Description: Ensures .devcontainer.secrets/ is in root .gitignore
#
# Usage:
#   ensure_secrets_folder_gitignored
#
# Parameters: None
#
# Returns:
#   0 - If already present or successfully added
#   0 - Always succeeds (idempotent)
#
# Purpose:
#   Prevents accidental commit of credentials stored in .devcontainer.secrets/
#   Used by scripts that store sensitive data (API keys, credentials, etc.)
#
# Examples:
#   # In install script that stores credentials
#   ensure_secrets_folder_gitignored
#
# Scripts using this:
#   - install-dev-ai-claudecode.sh (stores Claude Code API keys)
#   - install-kubectl.sh (sets up .devcontainer.secrets folder structure)
# ============================================================================
ensure_secrets_folder_gitignored() {
    local gitignore_file="/workspace/.gitignore"
    local gitignore_pattern=".devcontainer.secrets/"
    local gitignore_comment="# Top secret folder - contains credentials (NEVER commit)"

    # Create .gitignore if it doesn't exist
    if [ ! -f "$gitignore_file" ]; then
        echo "$gitignore_comment" > "$gitignore_file"
        echo "$gitignore_pattern" >> "$gitignore_file"
        echo "✅ Created .gitignore with .devcontainer.secrets/"
        return 0
    fi

    # Check if already present (check both pattern and comment for robustness)
    if grep -q "^${gitignore_pattern}" "$gitignore_file" 2>/dev/null || \
       grep -q "^${gitignore_comment}" "$gitignore_file" 2>/dev/null; then
        echo "✅ .devcontainer.secrets/ already in .gitignore"
        return 0
    fi

    # Add to .gitignore
    echo "" >> "$gitignore_file"
    echo "$gitignore_comment" >> "$gitignore_file"
    echo "$gitignore_pattern" >> "$gitignore_file"
    echo "✅ Added .devcontainer.secrets/ to .gitignore for credential safety"
    return 0
}

# ============================================================================
# Function: detect_architecture
# Description: Detects system architecture and returns standardized name
#
# Usage:
#   arch=$(detect_architecture)
#
# Parameters: None
#
# Returns:
#   Standardized architecture string: "amd64", "arm64", or original value
#
# Purpose:
#   Provides consistent architecture detection across all install scripts.
#   Maps various architecture names to standard Go/Docker conventions:
#   - x86_64 → amd64
#   - aarch64/arm64 → arm64
#
# Examples:
#   # In install script
#   SYSTEM_ARCH=$(detect_architecture)
#   echo "Detected architecture: $SYSTEM_ARCH"
#
# Scripts using this:
#   - install-dev-golang.sh (Go binary downloads)
#   - install-dev-csharp.sh (Azure Functions Core Tools)
# ============================================================================
detect_architecture() {
    local arch

    # Try dpkg first (Debian/Ubuntu standard)
    if command -v dpkg > /dev/null 2>&1; then
        arch=$(dpkg --print-architecture)
    # Fallback to uname
    elif command -v uname > /dev/null 2>&1; then
        local unamem=$(uname -m)
        case "$unamem" in
            aarch64|arm64) arch="arm64" ;;
            x86_64) arch="amd64" ;;
            *) arch="$unamem" ;;
        esac
    else
        arch="unknown"
    fi

    echo "$arch"
}

# ============================================================================
# Function: add_to_bashrc
# Description: Adds environment variables/exports to ~/.bashrc if not present
#
# Usage:
#   add_to_bashrc "CHECK_PATTERN" "COMMENT" "LINE1" ["LINE2" ...]
#
# Parameters:
#   $1 - Pattern to check for (grep pattern to detect if already present)
#   $2 - Comment line (e.g., "# Java environment")
#   $3+ - One or more lines to add (export statements, aliases, etc.)
#
# Returns:
#   0 - Always succeeds (idempotent)
#
# Purpose:
#   Provides consistent way to add environment configuration to .bashrc
#   across all install scripts. Prevents duplicate entries and ensures
#   proper formatting with comment headers.
#
# Examples:
#   # Add JAVA_HOME
#   add_to_bashrc "JAVA_HOME" "# Java environment" \
#       "export JAVA_HOME=\"/usr/lib/jvm/java-17\"" \
#       "export PATH=\"\$JAVA_HOME/bin:\$PATH\""
#
#   # Add single Go PATH entry
#   add_to_bashrc "GOPATH" "# Go environment" \
#       "export GOPATH=\"$HOME/go\"" \
#       "export PATH=\"\$GOPATH/bin:\$PATH\""
#
#   # Add kubectl config
#   add_to_bashrc "KUBECONFIG" "# kubectl configuration" \
#       "export KUBECONFIG=/workspace/.devcontainer.secrets/.kube/config"
#
# Scripts using this:
#   - install-dev-java.sh (JAVA_HOME)
#   - install-dev-golang.sh (Go PATH, GOPATH)
#   - install-dev-csharp.sh (DOTNET_ROOT)
#   - install-dev-rust.sh (Rust cargo PATH)
#   - install-kubectl.sh (KUBECONFIG)
# ============================================================================
add_to_bashrc() {
    local check_pattern="$1"
    local comment="$2"
    shift 2
    local lines_to_add=("$@")

    local bashrc="$HOME/.bashrc"

    # Check if configuration already present
    if grep -q "$check_pattern" "$bashrc" 2>/dev/null; then
        echo "ℹ️ Configuration already present in ~/.bashrc"
        return 0
    fi

    # Add blank line, comment, and all lines
    echo "" >> "$bashrc"
    echo "$comment" >> "$bashrc"
    for line in "${lines_to_add[@]}"; do
        echo "$line" >> "$bashrc"
    done

    echo "✅ Added configuration to ~/.bashrc"
    return 0
}

# ============================================================================
# Function: show_install_header
# Description: Display standardized header for install/uninstall operations
#
# Usage:
#   show_install_header              # For installation
#   show_install_header "uninstall"  # For uninstallation
#
# Parameters:
#   $1 (optional): Mode - "install" (default) or "uninstall"
#
# Dependencies:
#   Reads metadata variables from calling script:
#   - SCRIPT_NAME - Name of the script/tool
#   - SCRIPT_DESCRIPTION - Description of what the script does
#   - SCRIPT_VER - Version of the script
#
# Output:
#   Formatted header showing script name, description, and version
#
# Examples:
#   # In install script main execution
#   if [ "${UNINSTALL_MODE}" -eq 1 ]; then
#       show_install_header "uninstall"
#   else
#       show_install_header
#   fi
# ============================================================================
show_install_header() {
    local mode="${1:-install}"

    if [ "$mode" = "uninstall" ]; then
        echo "🔄 Starting uninstallation process for: $SCRIPT_NAME"
    else
        echo "🔄 Starting installation process for: $SCRIPT_NAME"
    fi
    echo "Purpose: $SCRIPT_DESCRIPTION"
    [[ -n "${SCRIPT_VER:-}" ]] && echo "Script version: $SCRIPT_VER"
}

# ============================================================================
# End of lib/install-common.sh
# ============================================================================
