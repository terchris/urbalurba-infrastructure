#!/bin/bash
# File: .devcontainer/additions/lib/tool-auto-enable.sh
# Purpose: Shared library for tool auto-enablement in project-installs.sh
# Usage: Source this file from install-*.sh scripts
#
# Main API Functions (auto-detect SCRIPT_ID from metadata):
#   auto_enable_tool    - Enable tool for auto-install (reads SCRIPT_ID)
#   auto_disable_tool   - Disable tool from auto-install (reads SCRIPT_ID)
#
# Low-level Functions (manual ID passing):
#   enable_tool_autoinstall TOOL_ID [NAME]
#   disable_tool_autoinstall TOOL_ID [NAME]

# Paths
readonly AUTO_ENABLE_TOOLS_CONF="/workspace/.devcontainer.extend/enabled-tools.conf"
readonly EVENT_NOTIFICATION_SCRIPT="/workspace/.devcontainer/additions/otel/scripts/send-event-notification.sh"

# Colors for logging
readonly TOOL_AUTO_ENABLE_GREEN='\033[0;32m'
readonly TOOL_AUTO_ENABLE_BLUE='\033[0;34m'
readonly TOOL_AUTO_ENABLE_YELLOW='\033[1;33m'
readonly TOOL_AUTO_ENABLE_NC='\033[0m'

#------------------------------------------------------------------------------
# Event Notification Functions
#------------------------------------------------------------------------------

# Send tool install/uninstall event to OTel collector
# Args: $1 - event type (devcontainer.tool.installed or devcontainer.tool.uninstalled)
#       $2 - tool identifier
#       $3 - tool display name
#       $4 - tool version (optional)
send_tool_event() {
    local event_type="$1"
    local tool_id="$2"
    local tool_name="${3:-$tool_id}"
    local tool_version="${4:-}"

    # Only send if event script exists
    if [[ ! -x "$EVENT_NOTIFICATION_SCRIPT" ]]; then
        return 0
    fi

    # Build command
    local cmd=("$EVENT_NOTIFICATION_SCRIPT"
        --event-type "$event_type"
        --message "Tool $tool_name ($tool_id) ${event_type##*.}"
        --component-name "$tool_id"
        --category "devcontainer.tools"
        --quiet
    )

    # Add version if provided
    if [[ -n "$tool_version" ]]; then
        cmd+=(--component-version "$tool_version")
    fi

    # Send event synchronously to avoid race condition with script exit
    # The --quiet flag keeps it fast, and curl has a short timeout
    "${cmd[@]}" 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Auto-Enable Functions
#------------------------------------------------------------------------------

# Check if a tool is already enabled
# Args: $1 - tool identifier (lowercase-with-dashes)
# Returns: 0 if enabled, 1 if not
is_tool_auto_enabled() {
    local tool_id="$1"

    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        return 1
    fi

    # Check if tool is in the config (skip comments)
    if grep -q "^${tool_id}$" "$AUTO_ENABLE_TOOLS_CONF" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Enable a tool for auto-install
# Args: $1 - tool identifier (lowercase-with-dashes)
#       $2 - tool display name (optional, for logging)
enable_tool_autoinstall() {
    local tool_id="$1"
    local tool_name="${2:-$tool_id}"

    # Check if already enabled
    if is_tool_auto_enabled "$tool_id"; then
        return 0
    fi

    # Ensure config file exists
    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        echo -e "${TOOL_AUTO_ENABLE_YELLOW}⚠️  Creating enabled-tools.conf${TOOL_AUTO_ENABLE_NC}"
        mkdir -p "$(dirname "$AUTO_ENABLE_TOOLS_CONF")"
        cat > "$AUTO_ENABLE_TOOLS_CONF" << 'EOF'
# Enabled Tools for Auto-Install
# Tools listed here will automatically install when the container is created/rebuilt
# Format: One tool identifier per line (matches SCRIPT_ID in install-*.sh)
#
# Management:
#   Add SCRIPT_ID to enable auto-install
#   Remove or comment out to disable
#
# Available tools are auto-discovered from .devcontainer/additions/install-*.sh
# Each install script has SCRIPT_ID metadata (e.g., SCRIPT_ID="dev-python")
#
# Note: Tools auto-enable themselves when first installed successfully

EOF
    fi

    # Add to config
    echo "$tool_id" >> "$AUTO_ENABLE_TOOLS_CONF"
    echo -e "${TOOL_AUTO_ENABLE_GREEN}✅ Auto-enabled '$tool_name' for container rebuild${TOOL_AUTO_ENABLE_NC}"
    echo -e "${TOOL_AUTO_ENABLE_BLUE}ℹ️  Remove from enabled-tools.conf to disable: $tool_id${TOOL_AUTO_ENABLE_NC}"

    # Send install event notification (non-blocking)
    send_tool_event "devcontainer.tool.installed" "$tool_id" "$tool_name" "${SCRIPT_VER:-}"

    return 0
}

#------------------------------------------------------------------------------
# Main API Functions - Auto-detect SCRIPT_ID from caller
#------------------------------------------------------------------------------

# Enable tool for auto-install (auto-detects SCRIPT_ID from metadata)
# No parameters needed - reads SCRIPT_ID and SCRIPT_NAME from caller's environment
# Usage: auto_enable_tool
auto_enable_tool() {
    if [[ -z "$SCRIPT_ID" ]]; then
        echo -e "${TOOL_AUTO_ENABLE_YELLOW}⚠️  SCRIPT_ID not defined - cannot auto-enable${TOOL_AUTO_ENABLE_NC}"
        return 1
    fi

    enable_tool_autoinstall "$SCRIPT_ID" "${SCRIPT_NAME:-$SCRIPT_ID}"
}

# Disable tool from auto-install (auto-detects SCRIPT_ID from metadata)
# No parameters needed - reads SCRIPT_ID and SCRIPT_NAME from caller's environment
# Usage: auto_disable_tool
auto_disable_tool() {
    if [[ -z "$SCRIPT_ID" ]]; then
        echo -e "${TOOL_AUTO_ENABLE_YELLOW}⚠️  SCRIPT_ID not defined - cannot auto-disable${TOOL_AUTO_ENABLE_NC}"
        return 1
    fi

    disable_tool_autoinstall "$SCRIPT_ID" "${SCRIPT_NAME:-$SCRIPT_ID}"
}

# Disable a tool from auto-install
# Args: $1 - tool identifier (kebab-case)
#       $2 - tool display name (optional, for logging)
disable_tool_autoinstall() {
    local tool_id="$1"
    local tool_name="${2:-$tool_id}"

    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        return 0  # Nothing to disable
    fi

    # Check if not enabled
    if ! is_tool_auto_enabled "$tool_id"; then
        return 0  # Already disabled
    fi

    # Remove from config (preserve comments and other entries)
    local temp_file
    temp_file=$(mktemp)
    grep -v "^${tool_id}$" "$AUTO_ENABLE_TOOLS_CONF" > "$temp_file"
    mv "$temp_file" "$AUTO_ENABLE_TOOLS_CONF"

    echo -e "${TOOL_AUTO_ENABLE_GREEN}✅ Disabled auto-install for '$tool_name'${TOOL_AUTO_ENABLE_NC}"

    # Send uninstall event notification (non-blocking)
    send_tool_event "devcontainer.tool.uninstalled" "$tool_id" "$tool_name" "${SCRIPT_VER:-}"

    return 0
}

# List all enabled tools
list_enabled_tools() {
    if [[ ! -f "$AUTO_ENABLE_TOOLS_CONF" ]]; then
        echo "No enabled tools"
        return 0
    fi

    echo "Enabled tools:"
    grep -v '^#' "$AUTO_ENABLE_TOOLS_CONF" | grep -v '^$' | while read -r tool; do
        echo "  - $tool"
    done
}
