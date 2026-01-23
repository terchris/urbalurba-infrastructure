#!/bin/bash
# service-auto-enable.sh - Service enable/disable management
#
# Manages the enabled-services.conf file, allowing services to be
# enabled or disabled without manual file editing.

# Guard against multiple sourcing
[[ -n "${_UIS_SERVICE_AUTO_ENABLE_LOADED:-}" ]] && return 0
_UIS_SERVICE_AUTO_ENABLE_LOADED=1

# shellcheck disable=SC2034  # Variables are used by callers

# Determine script directory for sourcing siblings
_ENABLE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$_ENABLE_SCRIPT_DIR/logging.sh"
source "$_ENABLE_SCRIPT_DIR/utilities.sh"
source "$_ENABLE_SCRIPT_DIR/service-scanner.sh"

# Default paths
CONFIG_DIR="${CONFIG_DIR:-/mnt/urbalurbadisk/.uis.extend}"

# Get the enabled services config file path
get_enabled_services_file() {
    echo "$CONFIG_DIR/enabled-services.conf"
}

# Check if a service is enabled in the config
# Usage: is_service_enabled <service_id>
# Returns: 0 if enabled, 1 if not
is_service_enabled() {
    local service_id="$1"
    local config_file
    config_file=$(get_enabled_services_file)

    [[ ! -f "$config_file" ]] && return 1

    # Look for the service ID as a whole word (not commented)
    grep -q "^[[:space:]]*${service_id}[[:space:]]*$" "$config_file" 2>/dev/null
}

# Enable a service by adding it to enabled-services.conf
# Usage: enable_service <service_id>
enable_service() {
    local service_id="$1"
    local config_file
    config_file=$(get_enabled_services_file)

    # Validate service exists
    local script
    script=$(find_service_script "$service_id")
    if [[ -z "$script" ]]; then
        log_error "Service '$service_id' not found"
        return 1
    fi

    # Check if already enabled
    if is_service_enabled "$service_id"; then
        log_warn "Service '$service_id' is already enabled"
        return 0
    fi

    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        log_info "Run 'uis deploy' first to initialize configuration"
        return 1
    fi

    # Get service metadata for category
    unset SCRIPT_NAME SCRIPT_CATEGORY
    # shellcheck source=/dev/null
    source "$script" 2>/dev/null

    # Add to config file with category comment if possible
    local category_comment=""
    if [[ -n "$SCRIPT_CATEGORY" ]]; then
        # Check if category section exists
        if grep -q "^# === $SCRIPT_CATEGORY" "$config_file" 2>/dev/null; then
            # Find the category section and add after it
            local temp_file
            temp_file=$(mktemp)

            local in_category=false
            local added=false
            while IFS= read -r line; do
                echo "$line" >> "$temp_file"

                # Check if we're entering the right category
                if [[ "$line" =~ ^#.*===.*$SCRIPT_CATEGORY ]]; then
                    in_category=true
                elif [[ "$line" =~ ^#.*=== && "$in_category" == "true" ]]; then
                    # Reached next category, insert before this line
                    if [[ "$added" != "true" ]]; then
                        # Insert before the line we just wrote
                        sed -i '' '$d' "$temp_file" 2>/dev/null || sed -i '$d' "$temp_file"
                        echo "$service_id" >> "$temp_file"
                        echo "" >> "$temp_file"
                        echo "$line" >> "$temp_file"
                        added=true
                    fi
                    in_category=false
                fi
            done < "$config_file"

            # If we were in category but reached end of file
            if [[ "$in_category" == "true" && "$added" != "true" ]]; then
                echo "$service_id" >> "$temp_file"
                added=true
            fi

            # If we found the category section, use the modified file
            if [[ "$added" == "true" ]]; then
                mv "$temp_file" "$config_file"
                log_success "Enabled service '$service_id'"
                return 0
            fi
            rm -f "$temp_file"
        fi
    fi

    # Fallback: append to end of file
    echo "$service_id" >> "$config_file"
    log_success "Enabled service '$service_id'"
}

# Disable a service by removing it from enabled-services.conf
# Usage: disable_service <service_id>
disable_service() {
    local service_id="$1"
    local config_file
    config_file=$(get_enabled_services_file)

    # Check if enabled
    if ! is_service_enabled "$service_id"; then
        log_warn "Service '$service_id' is not enabled"
        return 0
    fi

    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    # Remove the service line (keeping any comments before it)
    local temp_file
    temp_file=$(mktemp)

    while IFS= read -r line; do
        # Skip the line if it matches the service ID (not commented)
        if [[ "$line" =~ ^[[:space:]]*${service_id}[[:space:]]*$ ]]; then
            continue
        fi
        echo "$line" >> "$temp_file"
    done < "$config_file"

    mv "$temp_file" "$config_file"
    log_success "Disabled service '$service_id'"
}

# List all enabled services
# Usage: list_enabled_services
# Output: One service ID per line
list_enabled_services() {
    local config_file
    config_file=$(get_enabled_services_file)

    [[ ! -f "$config_file" ]] && return 0

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Trim and output
        echo "${line// /}"
    done < "$config_file"
}

# Count enabled services
# Usage: count_enabled_services
# Output: Number of enabled services
count_enabled_services() {
    list_enabled_services | wc -l | tr -d ' '
}

# Toggle a service (enable if disabled, disable if enabled)
# Usage: toggle_service <service_id>
toggle_service() {
    local service_id="$1"

    if is_service_enabled "$service_id"; then
        disable_service "$service_id"
    else
        enable_service "$service_id"
    fi
}
