#!/bin/bash
# file: .devcontainer/additions/_template-cmd-script.sh
#
# TEMPLATE: Copy this file when creating new command scripts
# Rename to: cmd-[purpose].sh
# Example: cmd-database.sh, cmd-docker.sh, cmd-metrics.sh
#
# Usage:
#   bash .devcontainer/additions/cmd-[name].sh --help        # Show all commands
#   bash .devcontainer/additions/cmd-[name].sh --command1    # Execute command
#   bash .devcontainer/additions/cmd-[name].sh --command2 <arg>  # Command with argument
#
# Command scripts should:
#   - Provide multiple related commands via flags
#   - Use SCRIPT_COMMANDS array as single source of truth
#   - Be non-interactive (use flags, not menus)
#   - Provide clear, actionable output
#   - Support both direct execution and menu integration
#
#------------------------------------------------------------------------------
# METADATA PATTERN - Required for automatic script discovery
#------------------------------------------------------------------------------
#
# The dev-setup.sh menu system uses the component-scanner library to automatically
# discover and display all cmd scripts. To make your script visible in the menu,
# you must define these four metadata fields below:
#
# SCRIPT_NAME - Human-readable name displayed in the menu (2-4 words)
#   Example: "Database Management"
#
# SCRIPT_DESCRIPTION - Brief description of what this script does (one sentence)
#   Example: "Query, backup, and analyze database operations"
#
# SCRIPT_CATEGORY - Category for menu organization
#   Common options: AI_TOOLS, DATABASE, MONITORING, INFRA_CONFIG, DATA_ANALYTICS
#   Example: "DATABASE"
#
# SCRIPT_PREREQUISITES - Space-separated list of required config-*.sh scripts
#   - Script checks prerequisites before showing commands in menu
#   - Leave empty ("") if no prerequisites
#   - Multiple: "config-database.sh config-credentials.sh"
#   Example: "config-database.sh"
#
# For more details, see: .devcontainer/additions/README-additions.md
#
#------------------------------------------------------------------------------
# SCRIPT_COMMANDS ARRAY PATTERN - Single source of truth for all commands
#------------------------------------------------------------------------------
#
# The SCRIPT_COMMANDS array defines all available commands. Each entry has 6 fields:
#
# Format: "category|flag|description|function|requires_arg|param_prompt"
#
# Field 1: category - Menu grouping (e.g., "Management", "Analysis", "Testing")
# Field 2: flag - Command line flag (must start with --)
# Field 3: description - User-friendly description (shown in menu)
# Field 4: function - Function name to call
# Field 5: requires_arg - "true" if needs parameter, "false" otherwise
# Field 6: param_prompt - Prompt text for parameter (empty if no parameter)
#
# Examples:
#   "Management|--list|List all items|cmd_list|false|"
#   "Management|--delete|Delete an item|cmd_delete|true|Enter item ID"
#   "Analysis|--stats|Show statistics|cmd_stats|false|"
#
# Benefits of SCRIPT_COMMANDS array:
#   - Add new command = just 1 line + implement function
#   - Help text auto-generated
#   - Menu integration automatic
#   - Parameter validation automatic
#   - No need to modify parse_args()
#
#------------------------------------------------------------------------------

# --- Core Metadata (required for dev-setup.sh) ---
SCRIPT_ID="cmd-example"  # Unique identifier (must match filename without .sh)
SCRIPT_VER="0.0.1"  # Script version - displayed in --help
SCRIPT_NAME="Example Management"
SCRIPT_DESCRIPTION="Manage and analyze example resources"
SCRIPT_CATEGORY="INFRA_CONFIG"  # Options: LANGUAGE_DEV, AI_TOOLS, CLOUD_TOOLS, DATA_ANALYTICS, BACKGROUND_SERVICES, INFRA_CONFIG
SCRIPT_PREREQUISITES=""  # Example: "config-example.sh" or "" if none

# --- Extended Metadata (for website documentation) ---
# These fields are for the documentation website only, NOT used by dev-setup.sh
SCRIPT_TAGS="[keyword1] [keyword2] [keyword3]"  # Space-separated search keywords
SCRIPT_ABSTRACT="[Brief 1-2 sentence description, 50-150 characters]"  # For tool cards
# Optional fields (uncomment if applicable):
# SCRIPT_LOGO="[script-id]-logo.webp"  # Logo file in website/static/img/tools/src/
# SCRIPT_WEBSITE="https://[official-website]"  # Official tool URL
# SCRIPT_SUMMARY="[Detailed 3-5 sentence description, 150-500 characters]"  # For tool detail pages
# SCRIPT_RELATED="[related-id-1] [related-id-2]"  # Space-separated related tool IDs

#------------------------------------------------------------------------------
# LOGGING NOTE
#------------------------------------------------------------------------------
# If your command script creates persistent log files, add them to cmd-logs.sh
# configuration so they can be managed (viewed, cleaned) centrally. Edit the
# arrays at the top of cmd-logs.sh:
#
#   TRUNCATE_LOGS - For log files that should be truncated when over size limit
#     Example: "/var/log/mycommand.log:10"  (truncate at 10MB)
#
#   CLEAN_DIRS - For directories with timestamped log files to delete when old
#     Example: "/tmp/mycommand-logs:7"  (delete files older than 7 days)
#
# This ensures logs don't fill up disk space during long-running sessions.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# SCRIPT_COMMANDS DEFINITIONS - Single source of truth
#------------------------------------------------------------------------------

# Format: category|flag|description|function|requires_arg|param_prompt
SCRIPT_COMMANDS=(
    "Management|--list|List all items|cmd_list|false|"
    "Management|--show|Show details for specific item|cmd_show|true|Enter item ID"
    "Management|--create|Create new item|cmd_create|true|Enter item name"
    "Management|--delete|Delete an item|cmd_delete|true|Enter item ID"
    "Analysis|--stats|Show usage statistics|cmd_stats|false|"
    "Analysis|--summary|Show summary report|cmd_summary|false|"
    "Testing|--test|Test connectivity|cmd_test|false|"
    "Testing|--validate|Validate specific item|cmd_validate|true|Enter item ID"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/utilities.sh"

# Configuration - Customize for your script
EXAMPLE_API_URL="${EXAMPLE_API_URL:-http://localhost:8080}"
EXAMPLE_TIMEOUT="${EXAMPLE_TIMEOUT:-30}"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

check_prerequisites() {
    local errors=0

    log_info "Checking prerequisites..."

    # Example: Check for required command-line tools
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq not installed (required for JSON parsing)"
        log_info "Fix: sudo apt-get install jq"
        errors=1
    fi

    # Example: Check for required environment variables
    # if [ -z "${EXAMPLE_API_KEY:-}" ]; then
    #     log_error "EXAMPLE_API_KEY not set"
    #     log_info "Fix: bash ${SCRIPT_DIR}/config-example.sh"
    #     errors=1
    # fi

    # Example: Check service connectivity
    # if ! curl -s --connect-timeout 5 "${EXAMPLE_API_URL}/health" >/dev/null 2>&1; then
    #     log_warning "Cannot reach API at ${EXAMPLE_API_URL}"
    #     errors=1
    # fi

    if [ $errors -eq 1 ]; then
        echo ""
        log_error "Prerequisites not met. Please fix the issues above."
        return 1
    fi

    log_success "Prerequisites OK"
    echo ""
    return 0
}

call_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    local url="${EXAMPLE_API_URL}${endpoint}"

    if [ "$method" = "GET" ]; then
        curl -s --connect-timeout 10 --max-time "$EXAMPLE_TIMEOUT" \
            -H "Accept: application/json" \
            "$url"
    elif [ "$method" = "POST" ]; then
        curl -s --connect-timeout 10 --max-time "$EXAMPLE_TIMEOUT" \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
}

#------------------------------------------------------------------------------
# Command Functions - Management
#------------------------------------------------------------------------------

cmd_list() {
    echo "════════════════════════════════════════════════════════"
    echo "📋 List of Items"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Implementation example
    # local response
    # response=$(call_api "/items" "GET")
    #
    # if [ -z "$response" ]; then
    #     log_error "Failed to fetch items"
    #     return 1
    # fi
    #
    # # Parse and display
    # echo "$response" | jq -r '.items[] | "\(.id)\t\(.name)"' | column -t -s $'\t'

    # Placeholder
    echo "1    Example Item 1"
    echo "2    Example Item 2"
    echo "3    Example Item 3"

    echo ""
    echo "════════════════════════════════════════════════════════"
}

cmd_show() {
    local item_id="$1"

    echo "════════════════════════════════════════════════════════"
    echo "📄 Item Details: $item_id"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Implementation example
    # local response
    # response=$(call_api "/items/${item_id}" "GET")
    #
    # if [ -z "$response" ]; then
    #     log_error "Item not found: $item_id"
    #     return 1
    # fi
    #
    # # Parse and display
    # echo "ID:          $(echo "$response" | jq -r '.id')"
    # echo "Name:        $(echo "$response" | jq -r '.name')"
    # echo "Created:     $(echo "$response" | jq -r '.created_at')"

    # Placeholder
    echo "ID:          $item_id"
    echo "Name:        Example Item"
    echo "Status:      Active"

    echo ""
    echo "════════════════════════════════════════════════════════"
}

cmd_create() {
    local item_name="$1"

    log_info "Creating item: $item_name"

    # Implementation example
    # local data
    # data=$(jq -n --arg name "$item_name" '{name: $name}')
    #
    # local response
    # response=$(call_api "/items" "POST" "$data")
    #
    # if [ -z "$response" ]; then
    #     log_error "Failed to create item"
    #     return 1
    # fi
    #
    # local item_id
    # item_id=$(echo "$response" | jq -r '.id')
    # log_success "Item created with ID: $item_id"

    # Placeholder
    log_success "Item created: $item_name"
}

cmd_delete() {
    local item_id="$1"

    log_warning "Deleting item: $item_id"

    # Implementation example
    # local response
    # response=$(call_api "/items/${item_id}" "DELETE")
    #
    # if [ -z "$response" ]; then
    #     log_error "Failed to delete item: $item_id"
    #     return 1
    # fi
    #
    # log_success "Item deleted: $item_id"

    # Placeholder
    log_success "Item deleted: $item_id"
}

#------------------------------------------------------------------------------
# Command Functions - Analysis
#------------------------------------------------------------------------------

cmd_stats() {
    echo "════════════════════════════════════════════════════════"
    echo "📊 Usage Statistics"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Example: Use utilities.sh date functions
    read start_date end_date <<< $(get_date_range "month")
    echo "Period:         $start_date to $end_date"

    # Example: Use utilities.sh formatting
    echo "Total Items:    $(format_number 1234567)"
    echo "Total Cost:     $(format_currency 123.45)"

    echo ""
    echo "════════════════════════════════════════════════════════"
}

cmd_summary() {
    echo "════════════════════════════════════════════════════════"
    echo "📈 Summary Report"
    echo "════════════════════════════════════════════════════════"
    echo ""

    echo "Active Items:   10"
    echo "Inactive Items: 3"
    echo "Total:          13"

    echo ""
    echo "════════════════════════════════════════════════════════"
}

#------------------------------------------------------------------------------
# Command Functions - Testing
#------------------------------------------------------------------------------

cmd_test() {
    echo "════════════════════════════════════════════════════════"
    echo "🧪 Testing Connectivity"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Implementation example
    # local start_time=$(date +%s%3N)
    # local response
    # response=$(call_api "/health" "GET")
    # local end_time=$(date +%s%3N)
    # local response_time=$((end_time - start_time))
    #
    # if [ -z "$response" ]; then
    #     log_error "API not reachable"
    #     return 1
    # fi
    #
    # log_success "API is reachable"
    # echo "URL:           $EXAMPLE_API_URL"
    # echo "Response time: ${response_time}ms"

    # Placeholder
    log_success "API is reachable"
    echo "URL:           $EXAMPLE_API_URL"
    echo "Response time: 15ms"

    echo ""
    echo "════════════════════════════════════════════════════════"
}

cmd_validate() {
    local item_id="$1"

    log_info "Validating item: $item_id"

    # Implementation example
    # local response
    # response=$(call_api "/items/${item_id}/validate" "GET")
    #
    # if [ -z "$response" ]; then
    #     log_error "Validation failed: $item_id"
    #     return 1
    # fi
    #
    # local is_valid
    # is_valid=$(echo "$response" | jq -r '.valid')
    #
    # if [ "$is_valid" = "true" ]; then
    #     log_success "Item is valid: $item_id"
    # else
    #     log_error "Item is invalid: $item_id"
    #     return 1
    # fi

    # Placeholder
    log_success "Item is valid: $item_id"
}

#------------------------------------------------------------------------------
# Help and Argument Parsing
#------------------------------------------------------------------------------

show_help() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_generate_help >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Generate help from SCRIPT_COMMANDS array (pass version as 3rd argument)
    cmd_framework_generate_help SCRIPT_COMMANDS "cmd-example.sh" "$SCRIPT_VER"

    # Add examples section
    echo ""
    echo "Examples:"
    echo "  cmd-example.sh --list                    # List all items"
    echo "  cmd-example.sh --show 123                # Show item details"
    echo "  cmd-example.sh --create MyNewItem        # Create new item"
    echo "  cmd-example.sh --stats                   # Show statistics"
    echo ""
}

parse_args() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_parse_args >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Use framework to parse arguments
    cmd_framework_parse_args SCRIPT_COMMANDS "cmd-example.sh" "$@"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Show help without checking prerequisites
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_help
        exit 0
    fi

    # Check prerequisites for all commands
    check_prerequisites || exit 1

    # Parse and execute command
    parse_args "$@"
}

main "$@"
