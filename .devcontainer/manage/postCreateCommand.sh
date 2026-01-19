#!/bin/bash
# File: .devcontainer/manage/postCreateCommand.sh
# Purpose: Main orchestration script for devcontainer post-creation setup
# Called by: devcontainer.json postCreateCommand
#
# This is the FRAMEWORK script - DO NOT modify for project-specific needs.
# For project customizations, edit: .devcontainer.extend/project-installs.sh

set -e

# Get script directory for library sourcing
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ADDITIONS_DIR="$SCRIPT_DIR/../additions"

# Source common installation library for helper functions
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/install-common.sh"

# Source component scanner library
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/component-scanner.sh"

# Source prerequisite check library
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

# Source tool installation library
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/tool-installation.sh"

# Source environment utilities library
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/environment-utils.sh"

# Source display utilities library
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/display-utils.sh"

#------------------------------------------------------------------------------
# Configuration Restoration
#------------------------------------------------------------------------------

# Restore all configurations from .devcontainer.secrets folder
restore_all_configurations() {
    # Source component scanner library
    # shellcheck source=/dev/null
    source "$ADDITIONS_DIR/lib/component-scanner.sh"

    echo ""
    echo "📋 Scanning for configuration scripts..."

    local restored_count=0
    local scanned_count=0

    # Discover all config scripts
    while IFS=$'\t' read -r script_basename config_name config_desc config_cat check_cmd; do
        ((scanned_count++))

        local config_path="$ADDITIONS_DIR/$script_basename"

        # Check if script supports --verify flag (non-interactive restore)
        if grep -q '= "--verify"' "$config_path" 2>/dev/null; then
            # Run with --verify flag (non-interactive, just restore from .devcontainer.secrets)
            # Silent if not found - user might not need this config
            if bash "$config_path" --verify 2>/dev/null; then
                echo "   ✅ $config_name restored"
                ((restored_count++))
            fi
            # Else: Silent - don't warn about missing configs
            # Tool installation will warn if a REQUIRED config is missing
        fi
    done < <(scan_config_scripts "$ADDITIONS_DIR")

    echo ""
    if [ $scanned_count -eq 0 ]; then
        echo "ℹ️  No configuration scripts found"
    elif [ $restored_count -eq 0 ]; then
        echo "ℹ️  No configurations found in .devcontainer.secrets (this is normal for new users)"
    else
        echo "📊 Configuration Restoration Summary:"
        echo "   ✅ Restored: $restored_count"
    fi
    echo ""
}

# Check if critical configurations are missing and warn user
check_missing_configs() {
    local missing_configs=()

    # Check Git identity
    if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
        missing_configs+=("Git Identity")
    fi

    # Show warning if any critical configs are missing
    if [ ${#missing_configs[@]} -gt 0 ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  IMPORTANT: Required Configuration Missing"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "The following configurations need to be set up:"
        for config in "${missing_configs[@]}"; do
            echo "   ❌ $config"
        done
        echo ""
        echo "📋 To configure these settings, run:"
        echo "   dev-check"
        echo ""
        echo "This will guide you through setting up your developer identity"
        echo "and other required configurations."
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    else
        echo ""
        echo "✅ All required configurations are set"
        echo ""
    fi
}

#------------------------------------------------------------------------------
# Version Checks (using environment-utils.sh)
#------------------------------------------------------------------------------

# Note: Version checking functions moved to environment-utils.sh library
# Available functions:
#   - check_node_version()
#   - check_python_version()
#   - check_npm_packages()
#   - check_command_version(cmd, flag)

#------------------------------------------------------------------------------
# Environment Setup (using environment-utils.sh)
#------------------------------------------------------------------------------

# Note: Environment setup functions moved to environment-utils.sh library
# Available functions:
#   - setup_devcontainer_path()
#   - setup_command_symlinks()
#   - setup_git_infrastructure()

#------------------------------------------------------------------------------
# Git Infrastructure Setup (using environment-utils.sh)
#------------------------------------------------------------------------------
# NOTE: This is infrastructure setup, NOT user configuration (that's in config-git.sh)
#
# WHY THIS IS HERE AND NOT IN config-git.sh:
# - Must run BEFORE any git commands (including config-git.sh which uses git)
# - These are container infrastructure settings, not personal user preferences
# - Same for all users, not personal (unlike name/email in config-git.sh)
#
# WHAT IT DOES:
# - safe.directory: Allows git to work with mounted volumes (security requirement)
# - core.fileMode: Ignores file permission changes (mounted volumes issue)
# - core.hideDotFiles: Shows dotfiles properly (cross-platform compatibility)
#------------------------------------------------------------------------------

# Note: mark_git_folder_as_safe() moved to environment-utils.sh as setup_git_infrastructure()
# Keeping wrapper for backwards compatibility
mark_git_folder_as_safe() {
    setup_git_infrastructure
}

#------------------------------------------------------------------------------
# Tool Installation (using tool-installation.sh)
#------------------------------------------------------------------------------

# Run project-specific installations
# Note: install_project_tools() now uses tool-installation.sh library
install_project_tools() {
    # Install all tools from enabled-tools.conf using library function
    install_enabled_tools "$ADDITIONS_DIR"

    # NOTE: Service starting moved to postStartCommand.sh
    # Services are started there so they restart on every container start
    # (not just on first creation)
}

#------------------------------------------------------------------------------
# Main Execution Flow
#------------------------------------------------------------------------------

main() {
    echo "🚀 Starting devcontainer post-creation setup..."

    # Setup PATH to include devcontainer commands
    setup_devcontainer_path

    # Create command symlinks for easy access
    setup_command_symlinks

    # Install welcome message for new terminals
    # Note: Using /etc/bash.bashrc because VS Code terminal is non-login shell
    if [[ -f "$SCRIPT_DIR/dev-welcome.sh" ]]; then
        # Append source command to system bashrc if not already there
        if ! grep -q "dev-welcome.sh" /etc/bash.bashrc 2>/dev/null; then
            echo "" | sudo tee -a /etc/bash.bashrc > /dev/null
            echo "# DevContainer Toolbox welcome message" | sudo tee -a /etc/bash.bashrc > /dev/null
            echo "source /etc/profile.d/dev-welcome.sh 2>/dev/null || true" | sudo tee -a /etc/bash.bashrc > /dev/null
        fi
        sudo cp "$SCRIPT_DIR/dev-welcome.sh" /etc/profile.d/dev-welcome.sh
        sudo chmod +x /etc/profile.d/dev-welcome.sh
    fi

    # Mark the git folder as safe
    mark_git_folder_as_safe

    # Restore all configurations from .devcontainer.secrets (non-interactive)
    echo "🔐 Restoring configurations from .devcontainer.secrets..."
    restore_all_configurations

    # Check if critical configurations are missing and warn user
    check_missing_configs

    # Version checks
    echo "🔍 Verifying installed versions..."
    check_node_version
    check_python_version
    check_npm_packages

    # Install enabled tools automatically
    install_project_tools

    # Force terminal reset before custom installations (supervisor may have corrupted it)
    reset_terminal

    # Call project-specific custom installations
    local PROJECT_INSTALLS="/workspace/.devcontainer.extend/project-installs.sh"
    if [[ -f "$PROJECT_INSTALLS" ]]; then
        echo ""
        echo "🔧 Running project-specific custom installations..."
        bash "$PROJECT_INSTALLS"
    fi

    # Reset terminal again before final message
    reset_terminal

    # Show completion message with helpful commands
    printf "\r\n"
    printf_line 61
    printf_msg "🎉 Post-creation setup complete!"
    printf_line 61
    printf "\r\n"
    printf_msg "📋 Quick Start:"
    printf "\r\n"
    printf_msg "   dev-setup                 Main menu - install tools, manage services"
    printf_msg "   dev-check             Configure required settings (Git identity, etc.)"
    printf_msg "   dev-template              Initialize project from template"
    printf_msg "   dev-env          Show detailed environment status"
    printf "\r\n"
    printf_line 61
    printf "\r\n"

    # Check if Git identity is configured and show warning at the BOTTOM
    if ! git config --global user.name >/dev/null 2>&1 || ! git config --global user.email >/dev/null 2>&1; then
        printf_line 61
        printf_msg "⚠️  FIRST TIME SETUP REQUIRED"
        printf_line 61
        printf "\r\n"
        printf_msg "   Your Git identity is not configured yet."
        printf_msg "   This is required before you can make Git commits."
        printf "\r\n"
        printf_msg "   Run this command to configure it:"
        printf_msg "     dev-check"
        printf "\r\n"
        printf_line 61
        printf "\r\n"
    fi
}

# Execute main with error handling to prevent container creation failure
set +e
main
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "⚠️  Setup completed with warnings/errors (exit code: $exit_code)"
    echo "🔍 Check the logs above for details"
    echo "🚀 Container creation will continue despite errors"
    echo ""
fi

# Always exit successfully to allow container creation to complete
exit 0
