#!/bin/bash
# File: .devcontainer/additions/lib/tool-installation.sh
# Purpose: Shared library for tool installation logic
# Used by: postCreateCommand.sh (automated) and dev-setup.sh (interactive)
#
# This library provides common functions for installing tools from install-*.sh scripts
# with prerequisite checking, status validation, and consistent reporting.
#
# Functions:
#   install_single_tool()   - Install one tool with full validation
#   install_enabled_tools() - Install all tools from enabled-tools.conf

#------------------------------------------------------------------------------
# Dependencies Check
#------------------------------------------------------------------------------

# This library requires component-scanner.sh and prerequisite-check.sh
if ! declare -F scan_install_scripts &>/dev/null; then
    echo "ERROR: tool-installation.sh requires component-scanner.sh to be sourced first" >&2
    return 1
fi

if ! declare -F check_prerequisite_configs &>/dev/null; then
    echo "ERROR: tool-installation.sh requires prerequisite-check.sh to be sourced first" >&2
    return 1
fi

#------------------------------------------------------------------------------
# Core Functions
#------------------------------------------------------------------------------

# Install a single tool with validation
#
# Parameters:
#   $1 - tool_name: Display name of the tool (e.g., "Python Development Tools")
#   $2 - script_name: Basename of install script (e.g., "install-dev-python.sh")
#   $3 - check_command: Command to verify installation (e.g., "command -v python")
#   $4 - prerequisite_configs: Space-separated list of required config scripts
#   $5 - additions_dir: Path to .devcontainer/additions directory
#
# Returns:
#   0 - Tool installed successfully
#   1 - Tool already installed (skipped)
#   2 - Prerequisites not met (installation blocked)
#   3 - Installation failed
#
# Output:
#   Prints status messages with emoji indicators
#   ✅ Success, ⏸️ Skipped, ⚠️ Warning, ❌ Error
#
install_single_tool() {
    local tool_name="$1"
    local script_name="$2"
    local check_command="$3"
    local prerequisite_configs="$4"
    local additions_dir="$5"

    # Validate parameters
    if [[ -z "$tool_name" ]] || [[ -z "$script_name" ]] || [[ -z "$additions_dir" ]]; then
        echo "❌ ERROR: install_single_tool() requires tool_name, script_name, and additions_dir" >&2
        return 3
    fi

    local script_path="$additions_dir/$script_name"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "❌ $tool_name - installation script not found: $script_name" >&2
        return 3
    fi

    # Check if already installed
    if [[ -n "$check_command" ]] && eval "$check_command" 2>/dev/null; then
        echo "✅ $tool_name - already installed (skipping)"
        return 1
    fi

    # Check prerequisites before installing
    local prerequisites_met=true
    if [[ -n "$prerequisite_configs" ]]; then
        if ! check_prerequisite_configs "$prerequisite_configs" "$additions_dir"; then
            echo "⚠️  $tool_name - missing prerequisites"
            show_missing_prerequisites "$prerequisite_configs" "$additions_dir"
            echo ""
            echo "  💡 To fix:"
            echo "     1. Run: dev-check (configures all missing items)"
            echo "     2. Or run each config script listed above"
            echo "     3. Then retry the installation"
            echo ""
            echo "❌ $tool_name - installation skipped (prerequisites not met)"
            echo ""
            return 2
        fi
    fi

    # Install tool
    echo "📦 Installing $tool_name..."

    # Disable exit on error for this command
    set +e
    bash "$script_path"
    local exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
        echo "✅ $tool_name - installed successfully"
        return 0
    else
        echo "❌ $tool_name - installation failed (exit code: $exit_code)"
        return 3
    fi
}

#------------------------------------------------------------------------------
# Batch Installation Functions
#------------------------------------------------------------------------------

# Install all tools from enabled-tools.conf
#
# Parameters:
#   $1 - additions_dir: Path to .devcontainer/additions directory
#   $2 - enabled_tools_conf: Path to enabled-tools.conf file (optional)
#        Defaults to: /workspace/.devcontainer.extend/enabled-tools.conf
#
# Returns:
#   0 - Success (even if some tools skipped)
#   1 - Configuration file not found or no tools enabled
#
# Output:
#   Prints detailed installation progress and final summary
#
install_enabled_tools() {
    local additions_dir="$1"
    local enabled_tools_conf="${2:-/workspace/.devcontainer.extend/enabled-tools.conf}"

    echo "🛠️ Installing project-specific tools..."
    echo ""

    # Validate additions directory
    if [[ ! -d "$additions_dir" ]]; then
        echo "❌ ERROR: Additions directory not found: $additions_dir" >&2
        return 1
    fi

    # Check if enabled-tools.conf exists
    if [[ ! -f "$enabled_tools_conf" ]]; then
        echo "⚠️  No enabled-tools.conf found - skipping automated tool installation"
        return 1
    fi

    # Arrays for discovered tools
    local -a TOOL_NAMES=()
    local -a TOOL_SCRIPTS=()
    local -a TOOL_CHECK_COMMANDS=()
    local -a TOOL_PREREQUISITES=()

    # Load enabled tools list
    local -a ENABLED_TOOLS=()

    echo "📋 Loading enabled tools from enabled-tools.conf..."
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        ENABLED_TOOLS+=("$line")
    done < "$enabled_tools_conf"

    echo "   Found ${#ENABLED_TOOLS[@]} enabled tools"

    # Check if any tools are enabled
    if [[ ${#ENABLED_TOOLS[@]} -eq 0 ]]; then
        echo ""
        echo "ℹ️  No tools enabled for installation"
        return 0
    fi

    # Discover available install scripts using component-scanner library
    echo ""
    echo "🔍 Discovering available tools..."

    while IFS=$'\t' read -r script_basename script_id script_name script_desc script_cat check_cmd prereq_configs; do
        # Use SCRIPT_ID directly (no conversion needed)
        local tool_id="$script_id"

        # Check if enabled
        local is_enabled=false
        for enabled in "${ENABLED_TOOLS[@]}"; do
            if [[ "$enabled" == "$tool_id" ]]; then
                is_enabled=true
                break
            fi
        done

        if [[ "$is_enabled" == true ]]; then
            TOOL_NAMES+=("$script_name")
            TOOL_SCRIPTS+=("$script_basename")
            TOOL_CHECK_COMMANDS+=("$check_cmd")
            TOOL_PREREQUISITES+=("$prereq_configs")
            echo "   ✅ $script_name - ENABLED"
        else
            echo "   ⏸️  $script_name - disabled"
        fi
    done < <(scan_install_scripts "$additions_dir")

    # Check if any enabled tools were found
    if [[ ${#TOOL_NAMES[@]} -eq 0 ]]; then
        echo ""
        echo "⚠️  No matching tools found for enabled IDs"
        return 0
    fi

    # Install enabled tools
    echo ""
    echo "📦 Installing enabled tools..."
    echo ""

    local installed_count=0
    local skipped_count=0
    local prereq_failed_count=0
    local install_failed_count=0

    # Disable set -e for the loop to prevent early exit
    set +e

    for i in "${!TOOL_NAMES[@]}"; do
        local tool_name="${TOOL_NAMES[$i]}"
        local script_name="${TOOL_SCRIPTS[$i]}"
        local check_command="${TOOL_CHECK_COMMANDS[$i]}"
        local prerequisite_configs="${TOOL_PREREQUISITES[$i]}"

        # Install tool using core function
        install_single_tool "$tool_name" "$script_name" "$check_command" "$prerequisite_configs" "$additions_dir"
        local result=$?

        case $result in
            0)
                ((installed_count++)) || true
                ;;
            1)
                ((skipped_count++)) || true
                ;;
            2)
                ((prereq_failed_count++)) || true
                ;;
            3)
                ((install_failed_count++)) || true
                ;;
        esac

        echo ""
    done

    # Re-enable set -e after loop
    set -e

    # Print summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Installation Summary:"
    echo "   Installed: $installed_count"
    echo "   Skipped (already installed): $skipped_count"
    if [[ $prereq_failed_count -gt 0 ]]; then
        echo "   Failed (prerequisites not met): $prereq_failed_count"
    fi
    if [[ $install_failed_count -gt 0 ]]; then
        echo "   Failed (installation error): $install_failed_count"
    fi
    echo "   Total enabled: ${#TOOL_NAMES[@]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    return 0
}

#------------------------------------------------------------------------------
# Integration with Supervisor (for service-based tools)
#------------------------------------------------------------------------------

# Start supervisor and reload configurations after tool installation
# This is typically called after install_enabled_tools() completes
#
# Parameters:
#   $1 - additions_dir: Path to .devcontainer/additions directory
#
# Returns:
#   0 - Success or supervisor not available
#
# Note: Runs silently to avoid cluttering installation output
#
start_supervisor_services() {
    local additions_dir="$1"

    # Check if supervisor is available
    if ! command -v supervisord >/dev/null 2>&1; then
        return 0
    fi

    # Disable exit on error for supervisor operations
    set +e

    # Run config generation silently
    if [[ -f "$additions_dir/config-supervisor.sh" ]]; then
        bash "$additions_dir/config-supervisor.sh" > /dev/null 2>&1
    fi

    # Start supervisor if configs exist and it's not running
    if [ -d /etc/supervisor/conf.d ] && [ "$(ls -A /etc/supervisor/conf.d/*.conf 2>/dev/null)" ]; then
        if ! pgrep supervisord > /dev/null 2>&1; then
            # Start supervisord in background
            sudo supervisord -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &
            sleep 3
        else
            # Reload to pick up any new configs
            sudo supervisorctl reread > /dev/null 2>&1
            sudo supervisorctl update > /dev/null 2>&1
        fi
    fi

    set -e

    # Reset terminal state completely (config-supervisor.sh uses tee which corrupts terminal)
    # The tee command in logging.sh leaves terminal without proper CR/LF
    # Send carriage return + newline to reset cursor position
    printf "\r\n"
    # Force terminal to process the reset
    sleep 0.1

    return 0
}

#------------------------------------------------------------------------------
# Helper Functions for Interactive Use (dev-setup.sh)
#------------------------------------------------------------------------------

# Check if a tool is installed (for status display)
#
# Parameters:
#   $1 - check_command: Command to verify installation
#
# Returns:
#   0 - Tool is installed
#   1 - Tool is not installed
#
check_tool_installed() {
    local check_command="$1"

    if [[ -z "$check_command" ]]; then
        return 1
    fi

    eval "$check_command" 2>/dev/null
    return $?
}

# Get installation status emoji for display
#
# Parameters:
#   $1 - check_command: Command to verify installation
#
# Output:
#   Prints: "✅" if installed, "❌" if not installed
#
get_tool_status_emoji() {
    local check_command="$1"

    if check_tool_installed "$check_command"; then
        echo "✅"
    else
        echo "❌"
    fi
}
