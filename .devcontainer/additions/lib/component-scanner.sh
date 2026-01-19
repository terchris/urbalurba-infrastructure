#!/bin/bash
# file: .devcontainer/additions/lib/component-scanner.sh
# version: 1.2.0
#
# DESCRIPTION: Shared library for discovering and querying devcontainer components
# PURPOSE: Provides reusable functions for scanning install-*.sh, start-*.sh, service-*.sh, config-*.sh, and cmd-*.sh scripts
#
# This library provides functions to:
#   - Extract metadata from install, service, and config scripts
#   - Check component installation/running/configured status
#   - Scan directories for available components, services, and configurations
#
# USAGE:
#   source /workspace/.devcontainer/additions/lib/component-scanner.sh
#
#   # Scan all install scripts
#   while IFS=$'\t' read -r script_basename script_name script_desc script_cat check_cmd; do
#       echo "Found component: $script_name"
#   done < <(scan_install_scripts "/workspace/.devcontainer/additions")
#
#   # Scan all config scripts
#   while IFS=$'\t' read -r script_basename config_name config_desc config_cat check_cmd; do
#       echo "Found config: $config_name"
#   done < <(scan_config_scripts "/workspace/.devcontainer/additions")
#
#   # Check if a component is installed
#   check_cmd='command -v python3 >/dev/null 2>&1'
#   if check_component_installed "$check_cmd"; then
#       echo "Python is installed"
#   fi
#
#   # Check if a config is configured
#   check_cmd='[ -f ~/.devcontainer-identity ]'
#   if check_config_configured "$check_cmd"; then
#       echo "Identity is configured"
#   fi
#
#   # Extract single metadata field
#   script_name=$(extract_script_metadata "/path/to/install-python.sh" "SCRIPT_NAME")
#   config_name=$(extract_config_metadata "/path/to/config-identity.sh" "SCRIPT_NAME")
#
#------------------------------------------------------------------------------
# LIBRARY VERSION
#------------------------------------------------------------------------------

COMPONENT_SCANNER_VERSION="1.2.0"

#------------------------------------------------------------------------------
# INSTALL SCRIPT FUNCTIONS
#------------------------------------------------------------------------------

# Extract metadata from a single install script file
#
# Usage: extract_script_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the install-*.sh script
#   metadata_field   - Field name to extract (SCRIPT_NAME, SCRIPT_DESCRIPTION,
#                      SCRIPT_CATEGORY, SCRIPT_CHECK_COMMAND)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   script_name=$(extract_script_metadata "/path/to/install-python.sh" "SCRIPT_NAME")
#   # Returns: "Python Development Tools"
#
extract_script_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Check if a component is installed using its check command
#
# Usage: check_component_installed <check_command_string>
#
# Arguments:
#   check_command_string - Shell command to execute (from SCRIPT_CHECK_COMMAND)
#
# Returns: 0 (success) if installed, 1 if not installed
#
# Example:
#   if check_component_installed "command -v python3 >/dev/null 2>&1"; then
#       echo "Python is installed"
#   fi
#
check_component_installed() {
    local check_command="$1"

    # If no check command provided, assume not installed
    if [[ -z "$check_command" ]]; then
        return 1
    fi

    # Execute the check command, suppressing all output
    eval "$check_command" 2>/dev/null
    return $?
}

# Scan all install-*.sh scripts and output structured data
#
# Usage: scan_install_scripts <additions_dir>
#
# Arguments:
#   additions_dir - Directory containing install-*.sh scripts
#
# Output format (tab-separated, one line per component):
#   script_basename<TAB>SCRIPT_ID<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>SCRIPT_CHECK_COMMAND<TAB>SCRIPT_PREREQUISITES
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r basename script_id name desc cat check prereqs; do
#       echo "Component: $name (ID: $script_id, category: $cat, prerequisites: $prereqs)"
#   done < <(scan_install_scripts "/workspace/.devcontainer/additions")
#
scan_install_scripts() {
    local additions_dir="$1"

    # Validate input
    if [[ -z "$additions_dir" ]]; then
        echo "Error: additions_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$additions_dir" ]]; then
        echo "Error: Directory not found: $additions_dir" >&2
        return 1
    fi

    # Scan for install scripts (excluding templates and subdirectories)
    for script in "$additions_dir"/install-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue

        # Skip template files
        [[ "$script" =~ _template ]] && continue

        # Extract metadata
        local script_basename=$(basename "$script")
        local script_id=$(extract_script_metadata "$script" "SCRIPT_ID")
        local script_name=$(extract_script_metadata "$script" "SCRIPT_NAME")
        local script_description=$(extract_script_metadata "$script" "SCRIPT_DESCRIPTION")
        local script_category=$(extract_script_metadata "$script" "SCRIPT_CATEGORY")
        local check_command=$(extract_script_metadata "$script" "SCRIPT_CHECK_COMMAND")
        local prerequisite_configs=$(extract_script_metadata "$script" "SCRIPT_PREREQUISITES")

        # Skip if no SCRIPT_ID or SCRIPT_NAME found (invalid component)
        if [[ -z "$script_id" || -z "$script_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$script_category" ]]; then
            script_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$script_description" ]]; then
            script_description="No description available"
        fi

        # Output tab-separated values (prerequisite_configs may be empty)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$script_basename" \
            "$script_id" \
            "$script_name" \
            "$script_description" \
            "$script_category" \
            "$check_command" \
            "$prerequisite_configs"
    done

    return 0
}

#------------------------------------------------------------------------------
# SERVICE SCRIPT FUNCTIONS
#------------------------------------------------------------------------------

# Extract SERVICE metadata from a script file
#
# Usage: extract_service_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the start-*.sh script
#   metadata_field   - Field name to extract (SERVICE_NAME, SERVICE_DESCRIPTION,
#                      SERVICE_CATEGORY, CHECK_RUNNING_COMMAND)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   service_name=$(extract_service_metadata "/path/to/start-otel.sh" "SERVICE_NAME")
#   # Returns: "OTel Monitoring"
#
extract_service_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Scan all start-*.sh scripts and output structured data
#
# Usage: scan_service_scripts <additions_dir>
#
# Arguments:
#   additions_dir - Directory containing start-*.sh and stop-*.sh scripts
#
# Output format (tab-separated, one line per service):
#   start_script<TAB>stop_script<TAB>SERVICE_NAME<TAB>SERVICE_DESCRIPTION<TAB>SERVICE_CATEGORY<TAB>CHECK_RUNNING_COMMAND
#   (stop_script will be empty string if not found)
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r start stop name desc cat check; do
#       echo "Service: $name (start: $start, stop: $stop)"
#   done < <(scan_service_scripts "/workspace/.devcontainer/additions")
#
scan_service_scripts() {
    local additions_dir="$1"

    # Validate input
    if [[ -z "$additions_dir" ]]; then
        echo "Error: additions_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$additions_dir" ]]; then
        echo "Error: Directory not found: $additions_dir" >&2
        return 1
    fi

    # Scan for start-*.sh scripts (excluding templates and subdirectories)
    for start_script in "$additions_dir"/start-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$start_script" ]] && continue

        # Skip template files
        [[ "$start_script" =~ _template ]] && continue

        # Extract metadata from start script
        local service_name=$(extract_service_metadata "$start_script" "SERVICE_NAME")
        local service_description=$(extract_service_metadata "$start_script" "SERVICE_DESCRIPTION")
        local service_category=$(extract_service_metadata "$start_script" "SERVICE_CATEGORY")
        local check_running_command=$(extract_service_metadata "$start_script" "CHECK_RUNNING_COMMAND")

        # Skip if no SERVICE_NAME found (invalid service)
        if [[ -z "$service_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$service_category" ]]; then
            service_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$service_description" ]]; then
            service_description="No description available"
        fi

        # Look for corresponding stop script
        local start_basename=$(basename "$start_script")
        local stop_basename="${start_basename/start-/stop-}"
        local stop_script_path="$additions_dir/$stop_basename"
        local stop_script=""

        # Check if stop script exists
        if [[ -f "$stop_script_path" ]]; then
            stop_script="$stop_basename"
        fi

        # Output tab-separated values
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$start_basename" \
            "$stop_script" \
            "$service_name" \
            "$service_description" \
            "$service_category" \
            "$check_running_command"
    done

    return 0
}

# Extract SERVICE_SCRIPT metadata from a service-*.sh file
#
# Usage: extract_service_script_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the service-*.sh script
#   metadata_field   - Field name to extract (SCRIPT_NAME, SCRIPT_DESCRIPTION,
#                      SCRIPT_CATEGORY, SCRIPT_PREREQUISITES)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   service_name=$(extract_service_script_metadata "/path/to/service-nginx.sh" "SCRIPT_NAME")
#   # Returns: "Nginx Reverse Proxy"
#
extract_service_script_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Extract SCRIPT_COMMANDS array from service-*.sh script
#
# Usage: extract_service_commands <script_path>
#
# Arguments:
#   script_path - Absolute path to the service-*.sh script
#
# Returns: SCRIPT_COMMANDS array entries, one per line
# Exit code: 0 on success, 1 if script not found or SCRIPT_COMMANDS array not found
#
# Example:
#   while IFS= read -r cmd_def; do
#       echo "Command: $cmd_def"
#   done < <(extract_service_commands "/path/to/service-nginx.sh")
#
extract_service_commands() {
    local script_path="$1"

    # Validate input
    if [[ -z "$script_path" ]]; then
        echo "Error: script_path parameter is required" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "Error: Script not found: $script_path" >&2
        return 1
    fi

    # Extract SCRIPT_COMMANDS array from file
    # Find lines between SCRIPT_COMMANDS=( and closing )
    sed -n '/^SCRIPT_COMMANDS=(/,/^)/p' "$script_path" 2>/dev/null | \
        grep -v '^SCRIPT_COMMANDS=(' | \
        grep -v '^)' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/"$//' | \
        sed 's/^"//'
}

# Scan all service-*.sh scripts and output structured data (NEW PATTERN)
#
# Usage: scan_service_scripts_new <additions_dir>
#
# Arguments:
#   additions_dir - Directory containing service-*.sh scripts
#
# Output format (tab-separated, one line per script):
#   script_basename<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>script_path<TAB>SCRIPT_PREREQUISITES
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r basename name desc cat path prereqs; do
#       echo "Service script: $name (category: $cat)"
#   done < <(scan_service_scripts_new "/workspace/.devcontainer/additions")
#
scan_service_scripts_new() {
    local additions_dir="$1"

    # Validate input
    if [[ -z "$additions_dir" ]]; then
        echo "Error: additions_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$additions_dir" ]]; then
        echo "Error: Directory not found: $additions_dir" >&2
        return 1
    fi

    # Scan for service scripts (excluding templates and subdirectories)
    for script in "$additions_dir"/service-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue

        # Skip template files
        [[ "$script" =~ _template ]] && continue

        # Extract metadata
        local script_basename=$(basename "$script")
        local script_path=$(cd "$(dirname "$script")" && pwd)/$(basename "$script")
        local service_name=$(extract_service_script_metadata "$script" "SCRIPT_NAME")
        local service_description=$(extract_service_script_metadata "$script" "SCRIPT_DESCRIPTION")
        local service_category=$(extract_service_script_metadata "$script" "SCRIPT_CATEGORY")
        local prerequisite_configs=$(extract_service_script_metadata "$script" "SCRIPT_PREREQUISITES")

        # Skip if no SCRIPT_NAME found (invalid service script)
        if [[ -z "$service_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$service_category" ]]; then
            service_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$service_description" ]]; then
            service_description="No description available"
        fi

        # Output tab-separated values (prerequisite_configs may be empty)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$script_basename" \
            "$service_name" \
            "$service_description" \
            "$service_category" \
            "$script_path" \
            "$prerequisite_configs"
    done

    return 0
}

#------------------------------------------------------------------------------
# CONFIG SCRIPT FUNCTIONS
#------------------------------------------------------------------------------

# Extract CONFIG metadata from a script file
#
# Usage: extract_config_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the config-*.sh script
#   metadata_field   - Field name to extract (SCRIPT_NAME, SCRIPT_DESCRIPTION,
#                      SCRIPT_CATEGORY, SCRIPT_CHECK_COMMAND)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   config_name=$(extract_config_metadata "/path/to/config-identity.sh" "SCRIPT_NAME")
#   # Returns: "Developer Identity"
#
extract_config_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Check if a configuration is completed using its check command
#
# Usage: check_config_configured <check_command_string>
#
# Arguments:
#   check_command_string - Shell command to execute (from SCRIPT_CHECK_COMMAND)
#
# Returns: 0 (success) if configured, 1 if not configured
#
# Example:
#   if check_config_configured "[ -f ~/.devcontainer-identity ]"; then
#       echo "Identity is configured"
#   fi
#
check_config_configured() {
    local check_command="$1"

    # If no check command provided, assume not configured
    if [[ -z "$check_command" ]]; then
        return 1
    fi

    # Execute the check command, suppressing all output
    eval "$check_command" 2>/dev/null
    return $?
}

# Scan all config-*.sh scripts and output structured data
#
# Usage: scan_config_scripts <additions_dir>
#
# Arguments:
#   additions_dir - Directory containing config-*.sh scripts
#
# Output format (tab-separated, one line per config):
#   script_basename<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>SCRIPT_CHECK_COMMAND<TAB>SCRIPT_PREREQUISITES
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r basename name desc cat check prereqs; do
#       echo "Config: $name (category: $cat)"
#   done < <(scan_config_scripts "/workspace/.devcontainer/additions")
#
scan_config_scripts() {
    local additions_dir="$1"

    # Validate input
    if [[ -z "$additions_dir" ]]; then
        echo "Error: additions_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$additions_dir" ]]; then
        echo "Error: Directory not found: $additions_dir" >&2
        return 1
    fi

    # Scan for config scripts (excluding templates and subdirectories)
    for script in "$additions_dir"/config-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue

        # Skip template files
        [[ "$script" =~ _template ]] && continue

        # Extract metadata
        local script_basename=$(basename "$script")
        local config_name=$(extract_config_metadata "$script" "SCRIPT_NAME")
        local config_description=$(extract_config_metadata "$script" "SCRIPT_DESCRIPTION")
        local config_category=$(extract_config_metadata "$script" "SCRIPT_CATEGORY")
        local check_command=$(extract_config_metadata "$script" "SCRIPT_CHECK_COMMAND")
        local prerequisites=$(extract_config_metadata "$script" "SCRIPT_PREREQUISITES")

        # Skip if no SCRIPT_NAME found (invalid config)
        if [[ -z "$config_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$config_category" ]]; then
            config_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$config_description" ]]; then
            config_description="No description available"
        fi

        # Output tab-separated values
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$script_basename" \
            "$config_name" \
            "$config_description" \
            "$config_category" \
            "$check_command" \
            "$prerequisites"
    done

    return 0
}

#------------------------------------------------------------------------------
# CMD SCRIPT FUNCTIONS
#------------------------------------------------------------------------------

# Extract CMD metadata from a script file
#
# Usage: extract_cmd_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the cmd-*.sh script
#   metadata_field   - Field name to extract (SCRIPT_NAME, SCRIPT_DESCRIPTION,
#                      SCRIPT_CATEGORY, SCRIPT_PREREQUISITES)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   cmd_name=$(extract_cmd_metadata "/path/to/cmd-ai.sh" "SCRIPT_NAME")
#   # Returns: "AI Management"
#
extract_cmd_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Extract SCRIPT_COMMANDS array from any script
#
# Usage: extract_script_commands <script_path>
#
# Arguments:
#   script_path - Absolute path to the script (install-*.sh, cmd-*.sh, service-*.sh)
#
# Returns: SCRIPT_COMMANDS array entries, one per line
# Exit code: 0 on success, 1 if script not found or SCRIPT_COMMANDS array not found
#
# Example:
#   while IFS= read -r cmd_def; do
#       echo "Command: $cmd_def"
#   done < <(extract_script_commands "/path/to/install-dev-fortran.sh")
#
extract_script_commands() {
    local script_path="$1"

    # Validate input
    if [[ -z "$script_path" ]]; then
        echo "Error: script_path parameter is required" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "Error: Script not found: $script_path" >&2
        return 1
    fi

    # Extract SCRIPT_COMMANDS array from file
    # Find lines between SCRIPT_COMMANDS=( and closing )
    sed -n '/^SCRIPT_COMMANDS=(/,/^)/p' "$script_path" 2>/dev/null | \
        grep -v '^SCRIPT_COMMANDS=(' | \
        grep -v '^)' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/"$//' | \
        sed 's/^"//'
}

# Legacy alias for backward compatibility
extract_cmd_commands() {
    extract_script_commands "$@"
}

# Scan all cmd-*.sh scripts and output structured data
#
# Usage: scan_cmd_scripts <additions_dir>
#
# Arguments:
#   additions_dir - Directory containing cmd-*.sh scripts
#
# Output format (tab-separated, one line per script):
#   script_basename<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>script_path<TAB>SCRIPT_PREREQUISITES
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r basename name desc cat path prereqs; do
#       echo "Command script: $name (category: $cat, prerequisites: $prereqs)"
#   done < <(scan_cmd_scripts "/workspace/.devcontainer/additions")
#
scan_cmd_scripts() {
    local additions_dir="$1"

    # Validate input
    if [[ -z "$additions_dir" ]]; then
        echo "Error: additions_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$additions_dir" ]]; then
        echo "Error: Directory not found: $additions_dir" >&2
        return 1
    fi

    # Scan for cmd scripts (excluding templates and subdirectories)
    for script in "$additions_dir"/cmd-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue

        # Skip template files
        [[ "$script" =~ _template ]] && continue

        # Extract metadata
        local script_basename=$(basename "$script")
        local script_path=$(cd "$(dirname "$script")" && pwd)/$(basename "$script")
        local cmd_name=$(extract_cmd_metadata "$script" "SCRIPT_NAME")
        local cmd_description=$(extract_cmd_metadata "$script" "SCRIPT_DESCRIPTION")
        local cmd_category=$(extract_cmd_metadata "$script" "SCRIPT_CATEGORY")
        local prerequisite_configs=$(extract_cmd_metadata "$script" "SCRIPT_PREREQUISITES")

        # Skip if no SCRIPT_NAME found (invalid cmd script)
        if [[ -z "$cmd_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$cmd_category" ]]; then
            cmd_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$cmd_description" ]]; then
            cmd_description="No description available"
        fi

        # Output tab-separated values (prerequisite_configs may be empty)
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$script_basename" \
            "$cmd_name" \
            "$cmd_description" \
            "$cmd_category" \
            "$script_path" \
            "$prerequisite_configs"
    done

    return 0
}

#------------------------------------------------------------------------------
# MANAGE SCRIPT FUNCTIONS
#------------------------------------------------------------------------------

# Extract metadata from a manage script file
#
# Usage: extract_manage_metadata <script_path> <metadata_field>
#
# Arguments:
#   script_path      - Absolute path to the dev-*.sh script
#   metadata_field   - Field name to extract (SCRIPT_ID, SCRIPT_NAME, SCRIPT_DESCRIPTION,
#                      SCRIPT_CATEGORY, SCRIPT_CHECK_COMMAND)
#
# Returns: The value of the requested field via stdout (empty if not found)
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   script_name=$(extract_manage_metadata "/path/to/dev-help.sh" "SCRIPT_NAME")
#   # Returns: "Help"
#
extract_manage_metadata() {
    local script_path="$1"
    local field_name="$2"

    # Validate inputs
    if [[ -z "$script_path" || -z "$field_name" ]]; then
        echo "" >&2
        return 1
    fi

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    # Extract the field value (first match only)
    local value=$(grep -m 1 "^${field_name}=" "$script_path" 2>/dev/null | cut -d'"' -f2)

    # Output the value (may be empty)
    echo "$value"
    return 0
}

# Scan manage scripts (dev-*.sh) and return metadata
#
# Usage: scan_manage_scripts <manage_dir>
#
# Arguments:
#   manage_dir - Directory containing dev-*.sh scripts
#
# Output format (tab-separated, one line per script):
#   script_basename<TAB>SCRIPT_ID<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>SCRIPT_CHECK_COMMAND
#
# Excludes:
#   - dev-welcome.sh (internal, runs on container start)
#   - dev-setup.sh (excluded to avoid recursion when called from menu)
#   - postStartCommand.sh, postCreateCommand.sh (devcontainer hooks)
#
# Exit code: 0 on success, 1 if directory not found
#
# Example:
#   while IFS=$'\t' read -r basename script_id name desc cat check; do
#       echo "Manage script: $name (ID: $script_id, category: $cat)"
#   done < <(scan_manage_scripts "/workspace/.devcontainer/manage")
#
scan_manage_scripts() {
    local manage_dir="$1"

    # Validate input
    if [[ -z "$manage_dir" ]]; then
        echo "Error: manage_dir parameter is required" >&2
        return 1
    fi

    # Check if directory exists
    if [[ ! -d "$manage_dir" ]]; then
        echo "Error: Directory not found: $manage_dir" >&2
        return 1
    fi

    # Scan for dev-*.sh scripts
    for script in "$manage_dir"/dev-*.sh; do
        # Skip if it's a directory or doesn't exist
        [[ ! -f "$script" ]] && continue

        local script_basename=$(basename "$script")

        # Skip excluded scripts
        case "$script_basename" in
            dev-welcome.sh)     continue ;;  # internal, runs on container start
            dev-setup.sh)       continue ;;  # excluded to avoid recursion
        esac

        # Extract metadata
        local script_id=$(extract_manage_metadata "$script" "SCRIPT_ID")
        local script_name=$(extract_manage_metadata "$script" "SCRIPT_NAME")
        local script_description=$(extract_manage_metadata "$script" "SCRIPT_DESCRIPTION")
        local script_category=$(extract_manage_metadata "$script" "SCRIPT_CATEGORY")
        local check_command=$(extract_manage_metadata "$script" "SCRIPT_CHECK_COMMAND")

        # Skip if no SCRIPT_ID or SCRIPT_NAME found (invalid script)
        if [[ -z "$script_id" || -z "$script_name" ]]; then
            continue
        fi

        # Default category if not specified
        if [[ -z "$script_category" ]]; then
            script_category="UNCATEGORIZED"
        fi

        # Default description if not specified
        if [[ -z "$script_description" ]]; then
            script_description="No description available"
        fi

        # Output tab-separated values
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$script_basename" \
            "$script_id" \
            "$script_name" \
            "$script_description" \
            "$script_category" \
            "$check_command"
    done

    return 0
}

# Get the full path to a manage script from its basename
#
# Usage: get_manage_script_path <manage_dir> <script_basename>
#
# Arguments:
#   manage_dir      - Directory containing dev-*.sh scripts
#   script_basename - The basename of the script (e.g., "dev-help.sh")
#
# Returns: Full path to the script via stdout
# Exit code: 0 on success, 1 if script not found
#
# Example:
#   script_path=$(get_manage_script_path "/workspace/.devcontainer/manage" "dev-help.sh")
#   # Returns: "/workspace/.devcontainer/manage/dev-help.sh"
#
get_manage_script_path() {
    local manage_dir="$1"
    local script_basename="$2"

    # Validate inputs
    if [[ -z "$manage_dir" || -z "$script_basename" ]]; then
        echo "" >&2
        return 1
    fi

    local script_path="$manage_dir/$script_basename"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        echo "" >&2
        return 1
    fi

    echo "$script_path"
    return 0
}

#------------------------------------------------------------------------------
# LIBRARY INITIALIZATION
#------------------------------------------------------------------------------

# Mark library as loaded
COMPONENT_SCANNER_LOADED=1
