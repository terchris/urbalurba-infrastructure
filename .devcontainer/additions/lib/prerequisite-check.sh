#!/bin/bash
# file: .devcontainer/additions/lib/prerequisite-check.sh
# version: 1.0.0
#
# DESCRIPTION: Library for checking tool installation prerequisites
# PURPOSE: Provides reusable functions for validating configuration requirements before tool installation
#
# This library provides functions to:
#   - Check if required config scripts have been executed
#   - Validate configuration files exist and have required values
#   - Generate consistent error messages for missing prerequisites
#
# USAGE:
#   source /workspace/.devcontainer/additions/lib/prerequisite-check.sh
#
#   # Check if a config script has been run (using its SCRIPT_CHECK_COMMAND)
#   if check_prerequisite_config "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions"; then
#       echo "Identity is configured"
#   else
#       echo "Identity not configured"
#   fi
#
#   # Check multiple configs
#   check_prerequisite_configs "config-identity.sh config-git.sh" "/workspace/.devcontainer/additions"
#   # Returns 0 only if ALL are configured
#
#------------------------------------------------------------------------------
# LIBRARY VERSION
#------------------------------------------------------------------------------

PREREQUISITE_CHECK_VERSION="1.0.0"

#------------------------------------------------------------------------------
# PREREQUISITE CHECK FUNCTIONS
#------------------------------------------------------------------------------

# Check if a single prerequisite configuration has been completed
#
# Usage: check_prerequisite_config <config_script_name> <additions_dir>
#
# Arguments:
#   config_script_name - Name of the config script (e.g., "config-devcontainer-identity.sh")
#   additions_dir      - Directory containing config scripts
#
# Returns: 0 if configured, 1 if not configured or script not found
#
# Example:
#   if check_prerequisite_config "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions"; then
#       echo "Identity is configured"
#   fi
#
check_prerequisite_config() {
    local config_script_name="$1"
    local additions_dir="$2"

    # Validate inputs
    if [[ -z "$config_script_name" || -z "$additions_dir" ]]; then
        return 1
    fi

    # Build full path to config script
    local config_script_path="$additions_dir/$config_script_name"

    # Check if script exists
    if [[ ! -f "$config_script_path" ]]; then
        echo "Warning: Config script not found: $config_script_name" >&2
        return 1
    fi

    # Extract SCRIPT_CHECK_COMMAND from the config script
    local check_command=$(grep -m 1 "^SCRIPT_CHECK_COMMAND=" "$config_script_path" 2>/dev/null | cut -d'"' -f2)

    # If no check command, assume not configured
    if [[ -z "$check_command" ]]; then
        return 1
    fi

    # Execute the check command
    eval "$check_command" 2>/dev/null
    return $?
}

# Check multiple prerequisite configurations
#
# Usage: check_prerequisite_configs <config_scripts_list> <additions_dir>
#
# Arguments:
#   config_scripts_list - Space-separated list of config script names
#   additions_dir       - Directory containing config scripts
#
# Returns: 0 if ALL are configured, 1 if ANY are not configured
#
# Example:
#   if check_prerequisite_configs "config-identity.sh config-git.sh" "/workspace/.devcontainer/additions"; then
#       echo "All prerequisites met"
#   fi
#
check_prerequisite_configs() {
    local config_scripts_list="$1"
    local additions_dir="$2"

    # Validate inputs
    if [[ -z "$config_scripts_list" || -z "$additions_dir" ]]; then
        return 1
    fi

    # Check each config script
    local all_met=true
    for config_script in $config_scripts_list; do
        if ! check_prerequisite_config "$config_script" "$additions_dir"; then
            all_met=false
            break
        fi
    done

    if [[ "$all_met" = true ]]; then
        return 0
    else
        return 1
    fi
}

# Get the friendly name of a config script
#
# Usage: get_config_name <config_script_name> <additions_dir>
#
# Arguments:
#   config_script_name - Name of the config script
#   additions_dir      - Directory containing config scripts
#
# Returns: SCRIPT_NAME value via stdout (or script name if not found)
#
# Example:
#   name=$(get_config_name "config-devcontainer-identity.sh" "/workspace/.devcontainer/additions")
#   # Returns: "Developer Identity"
#
get_config_name() {
    local config_script_name="$1"
    local additions_dir="$2"

    # Build full path
    local config_script_path="$additions_dir/$config_script_name"

    # Check if script exists
    if [[ ! -f "$config_script_path" ]]; then
        echo "$config_script_name"
        return 0
    fi

    # Extract SCRIPT_NAME
    local config_name=$(grep -m 1 "^SCRIPT_NAME=" "$config_script_path" 2>/dev/null | cut -d'"' -f2)

    # Return SCRIPT_NAME or fallback to script name
    if [[ -n "$config_name" ]]; then
        echo "$config_name"
    else
        echo "$config_script_name"
    fi

    return 0
}

# Show which prerequisite configs are missing
#
# Usage: show_missing_prerequisites <config_scripts_list> <additions_dir>
#
# Arguments:
#   config_scripts_list - Space-separated list of config script names
#   additions_dir       - Directory containing config scripts
#
# Output: Lists missing configs to stdout
# Returns: 0 if none missing, 1 if any missing
#
# Example:
#   show_missing_prerequisites "config-identity.sh config-git.sh" "/workspace/.devcontainer/additions"
#
show_missing_prerequisites() {
    local config_scripts_list="$1"
    local additions_dir="$2"
    local any_missing=false

    # Check each config script
    for config_script in $config_scripts_list; do
        if ! check_prerequisite_config "$config_script" "$additions_dir"; then
            local config_name=$(get_config_name "$config_script" "$additions_dir")
            echo "  ❌ $config_name (run: bash $additions_dir/$config_script)"
            any_missing=true
        fi
    done

    if [[ "$any_missing" = true ]]; then
        return 1
    else
        return 0
    fi
}

#------------------------------------------------------------------------------
# LIBRARY INITIALIZATION
#------------------------------------------------------------------------------

# Mark library as loaded
PREREQUISITE_CHECK_LOADED=1
