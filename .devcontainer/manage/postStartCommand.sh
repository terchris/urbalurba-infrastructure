#!/bin/bash
# File: .devcontainer/manage/postStartCommand.sh
# Purpose: Script that runs on EVERY container start (not just first creation)
# Called by: devcontainer.json postStartCommand
#
# This handles:
# - Re-detecting dynamic values (git identity may have changed)
# - Starting services that need to run every time
# - Sending startup events for monitoring

set -e

# Get script directory for library sourcing
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ADDITIONS_DIR="$SCRIPT_DIR/../additions"

# Source common installation library for helper functions
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/install-common.sh"

# Source component scanner library (required by tool-installation.sh)
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/component-scanner.sh"

# Source prerequisite check library (required by tool-installation.sh)
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

# Source tool installation library for start_supervisor_services
# shellcheck source=/dev/null
source "$ADDITIONS_DIR/lib/tool-installation.sh"

#------------------------------------------------------------------------------
# Dynamic Value Refresh
#------------------------------------------------------------------------------

# Re-detect git identity (repo may have changed, branch may have switched)
refresh_git_identity() {
    if [[ -f "$ADDITIONS_DIR/config-git.sh" ]]; then
        # Run git identity detection (non-interactive)
        bash "$ADDITIONS_DIR/config-git.sh" --verify 2>/dev/null || true
    fi
}

# Refresh host info if needed (rarely changes but good to verify)
refresh_host_info() {
    if [[ -f "$ADDITIONS_DIR/config-host-info.sh" ]]; then
        bash "$ADDITIONS_DIR/config-host-info.sh" --refresh 2>/dev/null || true
    fi
}

#------------------------------------------------------------------------------
# Service Startup
#------------------------------------------------------------------------------

# Start OTel monitoring services
start_otel_monitoring() {
    if [[ -f "$ADDITIONS_DIR/service-otel-monitoring.sh" ]]; then
        # Check if OTel is enabled in enabled-tools.conf
        local enabled_tools="$ADDITIONS_DIR/enabled-tools.conf"
        if grep -q "^service-otel-monitoring" "$enabled_tools" 2>/dev/null; then
            bash "$ADDITIONS_DIR/service-otel-monitoring.sh" --start 2>/dev/null || true
        fi
    fi
}

# Send startup event to monitoring
send_startup_event() {
    local event_script="$ADDITIONS_DIR/otel/scripts/send-event-notification.sh"
    if [[ -f "$event_script" ]]; then
        # Only send if OTel monitoring is running
        if pgrep -f "otelcol-contrib" > /dev/null 2>&1; then
            bash "$event_script" \
                --event-type "devcontainer.started" \
                --message "Devcontainer started" \
                --quiet 2>/dev/null || true
        fi
    fi
}

# Send tool inventory to Loki
send_tools_inventory() {
    local inventory_script="$ADDITIONS_DIR/otel/scripts/send-tools-inventory.sh"
    if [[ -f "$inventory_script" ]]; then
        # Only send if OTel monitoring is running
        if pgrep -f "otelcol-contrib" > /dev/null 2>&1; then
            bash "$inventory_script" --quiet 2>/dev/null || true
        fi
    fi
}

#------------------------------------------------------------------------------
# Main Execution Flow
#------------------------------------------------------------------------------

main() {
    echo "🚀 Starting devcontainer post-start setup..."

    # 1. Re-detect dynamic values (git repo may have changed)
    echo "🔍 Refreshing dynamic values..."
    refresh_git_identity
    refresh_host_info

    # 2. Start supervisor services (nginx, etc.)
    echo "📦 Starting supervisor services..."
    start_supervisor_services "$ADDITIONS_DIR"

    # 3. Start OTel monitoring
    echo "📊 Starting OTel monitoring..."
    start_otel_monitoring

    # 4. Send startup event
    echo "📤 Sending startup event..."
    send_startup_event

    # 5. Send tool inventory
    echo "📋 Sending tool inventory..."
    send_tools_inventory

    echo "✅ Post-start setup complete!"
}

# Execute main with error handling to prevent container start failure
set +e
main
exit_code=$?
set -e

if [ $exit_code -ne 0 ]; then
    echo ""
    echo "⚠️  Post-start setup completed with warnings (exit code: $exit_code)"
    echo "🔍 Check the logs above for details"
    echo ""
fi

# Always exit successfully to allow container to continue
exit 0
