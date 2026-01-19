#!/bin/bash
# File: .devcontainer/additions/otel/scripts/send-tools-inventory.sh
# Purpose: Send tool inventory to Loki on startup
#
# Iterates over all installed tools and sends a log entry for each one
# with event_type="devcontainer.tools.inventory"
#
# Usage:
#   send-tools-inventory.sh [--quiet]
#
# This script is called by postStartCommand.sh on every container start

set -e

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDITIONS_DIR="/workspace/.devcontainer/additions"
LIB_DIR="$ADDITIONS_DIR/lib"

# Source the component scanner library
if [[ -f "$LIB_DIR/component-scanner.sh" ]]; then
    source "$LIB_DIR/component-scanner.sh"
else
    echo "Error: component-scanner.sh library not found" >&2
    exit 1
fi

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

QUIET=false
EVENT_SCRIPT="$SCRIPT_DIR/send-event-notification.sh"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

log_info() {
    if [ "$QUIET" = false ]; then
        echo "ℹ️  $1" >&2
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo "✅ $1" >&2
    fi
}

log_error() {
    echo "❌ $1" >&2
}

#------------------------------------------------------------------------------
# Main Functions
#------------------------------------------------------------------------------

scan_and_send_inventory() {
    log_info "Scanning installed tools..."

    local installed_tools=()
    local total_count=0

    # scan_install_scripts outputs: basename, id, name, desc, category, check_command, prerequisites
    while IFS=$'\t' read -r script_basename script_id script_name script_description script_category check_command prerequisite_configs; do
        ((total_count++)) || true

        # Check if installed
        if check_component_installed "$check_command"; then
            installed_tools+=("$script_id")
        fi
    done < <(scan_install_scripts "$ADDITIONS_DIR")

    local installed_count=${#installed_tools[@]}

    # Send single inventory event with all installed tools
    if [ $installed_count -gt 0 ]; then
        local tools_list="${installed_tools[*]}"

        bash "$EVENT_SCRIPT" \
            --event-type "devcontainer.tools.inventory" \
            --message "Installed tools: $tools_list" \
            --category "devcontainer.inventory" \
            --quiet 2>/dev/null || true
    fi

    log_success "Tool inventory: $installed_count installed out of $total_count total"
}

#------------------------------------------------------------------------------
# Argument Parsing
#------------------------------------------------------------------------------

parse_arguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --quiet|-q)
                QUIET=true
                shift
                ;;
            --help|-h)
                echo "Usage: $(basename "$0") [--quiet]"
                echo ""
                echo "Send tool inventory to Loki for all installed devcontainer tools."
                echo ""
                echo "Options:"
                echo "  --quiet, -q   Suppress output messages"
                echo "  --help, -h    Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    parse_arguments "$@"

    # Check if event script exists
    if [[ ! -f "$EVENT_SCRIPT" ]]; then
        log_error "Event notification script not found: $EVENT_SCRIPT"
        exit 1
    fi

    # Scan tools and send inventory
    scan_and_send_inventory
}

main "$@"
