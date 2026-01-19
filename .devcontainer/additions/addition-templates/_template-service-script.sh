#!/bin/bash
# file: .devcontainer/additions/_template-service-script.sh
#
# TEMPLATE: Copy this file when creating new service scripts
# Rename to: service-[name].sh
# Example: service-nginx.sh, service-database.sh, service-redis.sh
#
# Usage:
#   bash .devcontainer/additions/service-[name].sh --help        # Show all commands
#   bash .devcontainer/additions/service-[name].sh --start       # Start service (for supervisord)
#   bash .devcontainer/additions/service-[name].sh --stop        # Stop service
#   bash .devcontainer/additions/service-[name].sh --status      # Check status
#   bash .devcontainer/additions/service-[name].sh --logs        # View logs
#
# Service scripts should:
#   - Manage long-running background services
#   - Provide multiple operations via flags (start, stop, restart, status, logs, validate)
#   - Use SCRIPT_COMMANDS array as single source of truth
#   - Be non-interactive (use flags, not menus)
#   - Integrate with supervisord for auto-start
#   - Support both manual and supervisord execution
#
# Difference from cmd-*.sh:
#   - service-*.sh: Manage long-running services (nginx, postgres, redis)
#   - cmd-*.sh: Execute short commands that exit (queries, operations, tools)
#
#------------------------------------------------------------------------------
# METADATA PATTERN - Required for automatic script discovery
#------------------------------------------------------------------------------
#
# The dev-setup.sh menu system uses the component-scanner library to automatically
# discover and display all service scripts. To make your script visible in the menu,
# you must define these four metadata fields below:
#
# SCRIPT_NAME - Human-readable name displayed in the menu (2-4 words)
#   Example: "Example Service"
#
# SCRIPT_DESCRIPTION - Brief description of what this service does (one sentence)
#   Example: "Example background service for demonstration"
#
# SCRIPT_CATEGORY - Category for menu organization
#   Common options: INFRA_CONFIG, DATABASE, MONITORING, CACHE
#   Example: "INFRA_CONFIG"
#
# SCRIPT_PREREQUISITES - Space-separated list of required config-*.sh scripts
#   - Script checks prerequisites before showing commands in menu
#   - Leave empty ("") if no prerequisites
#   - Multiple: "config-example.sh config-database.sh"
#   Example: "config-example.sh"
#
# For more details, see: .devcontainer/additions/README-additions.md
#
#------------------------------------------------------------------------------
# SCRIPT_COMMANDS ARRAY PATTERN - Single source of truth for all operations
#------------------------------------------------------------------------------
#
# The SCRIPT_COMMANDS array defines all available service operations. Each entry has 6 fields:
#
# Format: "category|flag|description|function|requires_arg|param_prompt"
#
# Field 1: category - Menu grouping (e.g., "Control", "Status", "Config")
# Field 2: flag - Command line flag (must start with --)
# Field 3: description - User-friendly description (shown in menu)
# Field 4: function - Function name to call
# Field 5: requires_arg - "true" if needs parameter, "false" otherwise
# Field 6: param_prompt - Prompt text for parameter (empty if no parameter)
#
# Common service operations:
#   Control: --start, --stop, --restart
#   Status: --status, --logs, --logs-follow
#   Config: --validate, --reload, --show-config
#   Debug: --test, --troubleshoot, --health
#
# Examples:
#   "Control|--start|Start service in foreground|service_start|false|"
#   "Control|--stop|Stop service gracefully|service_stop|false|"
#   "Status|--logs|Show recent logs|service_logs|true|Number of lines (default 50)"
#
# Benefits of SCRIPT_COMMANDS array:
#   - Add new operation = just 1 line + implement function
#   - Help text auto-generated
#   - Menu integration automatic
#   - Parameter validation automatic
#   - No need to modify parse_args()
#
#------------------------------------------------------------------------------

# --- Core Metadata (required for dev-setup.sh) ---
SCRIPT_ID="service-example"  # Unique identifier (must match filename without .sh)
SCRIPT_VER="0.0.1"  # Script version - displayed in --help
SCRIPT_NAME="Example Service"
SCRIPT_DESCRIPTION="Example background service for demonstration"
SCRIPT_CATEGORY="BACKGROUND_SERVICES"  # Use: BACKGROUND_SERVICES, INFRA_CONFIG
SCRIPT_CHECK_COMMAND="pgrep -f 'example-service' >/dev/null 2>&1"  # Check if service is running
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

# Supervisor integration - controls startup order and dependencies
SERVICE_PRIORITY="50"  # Lower numbers start first (10=first, 99=last). nginx=20, otel=30
SERVICE_DEPENDS=""     # Comma-separated service IDs this depends on. Example: "service-nginx"

#------------------------------------------------------------------------------
# LOGGING NOTE
#------------------------------------------------------------------------------
# If your service creates log files, add them to cmd-logs.sh configuration so
# they can be managed (viewed, cleaned) centrally. Edit the arrays at the top
# of cmd-logs.sh:
#
#   TRUNCATE_LOGS - For log files that should be truncated when over size limit
#     Example: "/var/log/myservice.log:10"  (truncate at 10MB)
#
#   CLEAN_DIRS - For directories with timestamped log files to delete when old
#     Example: "/tmp/myservice-logs:7"  (delete files older than 7 days)
#
# This ensures logs don't fill up disk space during long-running sessions.
#------------------------------------------------------------------------------
# SCRIPT_COMMANDS DEFINITIONS - Single source of truth
#------------------------------------------------------------------------------

# Format: category|flag|description|function|requires_arg|param_prompt
SCRIPT_COMMANDS=(
    "Control|--start|Start service in foreground (for supervisord)|service_start|false|"
    "Control|--stop|Stop service gracefully|service_stop|false|"
    "Control|--restart|Restart service|service_restart|false|"
    "Status|--status|Check if service is running|service_status|false|"
    "Status|--logs|Show recent logs|service_logs|false|"
    "Status|--logs-follow|Follow logs in real-time|service_logs_follow|false|"
    "Config|--validate|Validate service configuration|service_validate|false|"
    "Config|--reload|Reload configuration without restart|service_reload|false|"
    "Config|--show-config|Display current configuration|service_show_config|false|"
    "Debug|--test|Test service connectivity|service_test|false|"
    "Debug|--health|Check service health|service_health|false|"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/utilities.sh"

# Configuration - Customize for your service
SERVICE_NAME="example-service"
SERVICE_BINARY="example-daemon"  # Change to your service binary
SERVICE_CONFIG_FILE="$HOME/.example-config"
SERVICE_PID_FILE="/var/run/example-service.pid"
SERVICE_LOG_FILE="/var/log/example-service.log"
SERVICE_PORT="${EXAMPLE_PORT:-8080}"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

check_prerequisites() {
    local errors=0

    log_info "Checking prerequisites..."

    # Example: Check for required binary
    if ! command -v "$SERVICE_BINARY" >/dev/null 2>&1; then
        log_error "$SERVICE_BINARY not installed"
        log_info "Fix: Install via install-example.sh"
        errors=1
    fi

    # Example: Check for required config file
    if [ ! -f "$SERVICE_CONFIG_FILE" ]; then
        log_warning "Config file not found: $SERVICE_CONFIG_FILE"
        log_info "Fix: Run bash ${SCRIPT_DIR}/config-example.sh"
        errors=1
    fi

    if [ $errors -eq 1 ]; then
        echo ""
        log_error "Prerequisites not met. Please fix the issues above."
        return 1
    fi

    log_success "Prerequisites OK"
    echo ""
    return 0
}

load_configuration() {
    log_info "Loading configuration..."

    if [ -f "$SERVICE_CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$SERVICE_CONFIG_FILE"
        log_success "Configuration loaded from $SERVICE_CONFIG_FILE"
    else
        log_warning "No configuration file found, using defaults"
    fi

    log_info "Service port: $SERVICE_PORT"
    echo ""
}

is_service_running() {
    # Example: Check if process is running
    if pgrep -x "$SERVICE_BINARY" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_service_pid() {
    if [ -f "$SERVICE_PID_FILE" ]; then
        cat "$SERVICE_PID_FILE"
    else
        pgrep -x "$SERVICE_BINARY" || echo ""
    fi
}

wait_for_service_ready() {
    local timeout="${1:-30}"
    local count=0

    log_info "Waiting for service to be ready (timeout: ${timeout}s)..."

    while ! is_service_running; do
        sleep 1
        count=$((count + 1))
        if [ $count -ge $timeout ]; then
            log_error "Service did not start within ${timeout} seconds"
            return 1
        fi
    done

    log_success "Service is ready"
    return 0
}

#------------------------------------------------------------------------------
# Service Operations - Control
#------------------------------------------------------------------------------

service_start() {
    echo "════════════════════════════════════════════════════════"
    echo "🚀 Starting $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Check prerequisites
    check_prerequisites || exit 1

    # Load configuration
    load_configuration

    # Check if already running
    if is_service_running; then
        log_warning "Service is already running"
        local pid=$(get_service_pid)
        log_info "PID: $pid"
        exit 0
    fi

    # Stop any existing process
    service_stop 2>/dev/null || true
    sleep 1

    log_info "Starting $SERVICE_BINARY..."

    # IMPORTANT: Use 'exec' for supervisord integration
    # This replaces the shell process with the service process
    # supervisord expects this behavior for proper process management
    #
    # Example for foreground service:
    exec "$SERVICE_BINARY" --foreground --port "$SERVICE_PORT" --config "$SERVICE_CONFIG_FILE"

    # Example for background service (without exec):
    # "$SERVICE_BINARY" --daemon --port "$SERVICE_PORT" --config "$SERVICE_CONFIG_FILE"
    # wait_for_service_ready
    # log_success "Service started successfully"

    # This line will never be reached due to exec
    exit 0
}

service_stop() {
    echo "════════════════════════════════════════════════════════"
    echo "🛑 Stopping $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if ! is_service_running; then
        log_info "Service is not running"
        return 0
    fi

    local pid=$(get_service_pid)
    log_info "Stopping service (PID: $pid)..."

    # Try graceful shutdown first
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown
        local count=0
        while is_service_running && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done

        if ! is_service_running; then
            log_success "Service stopped gracefully"
            rm -f "$SERVICE_PID_FILE"
            return 0
        fi
    fi

    # Force kill if graceful shutdown fails
    log_warning "Graceful shutdown failed, forcing stop..."
    if pkill -9 -x "$SERVICE_BINARY" 2>/dev/null; then
        log_success "Service stopped (forced)"
        rm -f "$SERVICE_PID_FILE"
        return 0
    fi

    log_error "Failed to stop service"
    return 1
}

service_restart() {
    echo "════════════════════════════════════════════════════════"
    echo "🔄 Restarting $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Stop service
    service_stop

    # Wait a moment
    sleep 2

    # Start service (cannot use exec for restart)
    # Must call the binary directly, not via service_start (which uses exec)
    check_prerequisites || exit 1
    load_configuration

    log_info "Starting $SERVICE_BINARY..."
    "$SERVICE_BINARY" --daemon --port "$SERVICE_PORT" --config "$SERVICE_CONFIG_FILE" &

    wait_for_service_ready

    echo ""
    log_success "Service restarted successfully"
}

#------------------------------------------------------------------------------
# Service Operations - Status
#------------------------------------------------------------------------------

service_status() {
    echo "════════════════════════════════════════════════════════"
    echo "📊 Status: $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if is_service_running; then
        local pid=$(get_service_pid)
        log_success "Service is running"
        echo ""
        echo "PID:        $pid"
        echo "Binary:     $SERVICE_BINARY"
        echo "Config:     $SERVICE_CONFIG_FILE"
        echo "Logs:       $SERVICE_LOG_FILE"
        echo "Port:       $SERVICE_PORT"

        # Show supervisord status if available
        if command -v supervisorctl >/dev/null 2>&1; then
            echo ""
            echo "Supervisord status:"
            sudo supervisorctl status "$SERVICE_NAME" 2>/dev/null || echo "  Not managed by supervisord"
        fi
    else
        log_error "Service is not running"
        return 1
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
}

service_logs() {
    echo "════════════════════════════════════════════════════════"
    echo "📄 Recent Logs: $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if [ -f "$SERVICE_LOG_FILE" ]; then
        tail -n 50 "$SERVICE_LOG_FILE"
    else
        log_warning "Log file not found: $SERVICE_LOG_FILE"

        # Try supervisord logs
        if command -v supervisorctl >/dev/null 2>&1; then
            echo ""
            log_info "Trying supervisord logs..."
            sudo supervisorctl tail "$SERVICE_NAME" 2>/dev/null || log_error "No logs available"
        fi
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
}

service_logs_follow() {
    echo "════════════════════════════════════════════════════════"
    echo "📄 Following Logs: $SCRIPT_NAME"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "Press Ctrl+C to stop following..."
    echo ""

    if [ -f "$SERVICE_LOG_FILE" ]; then
        tail -f "$SERVICE_LOG_FILE"
    else
        log_error "Log file not found: $SERVICE_LOG_FILE"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Service Operations - Config
#------------------------------------------------------------------------------

service_validate() {
    echo "════════════════════════════════════════════════════════"
    echo "✅ Validating Configuration"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local errors=0

    # Validate binary exists
    if ! command -v "$SERVICE_BINARY" >/dev/null 2>&1; then
        log_error "Service binary not found: $SERVICE_BINARY"
        errors=1
    else
        log_success "Service binary found: $SERVICE_BINARY"
    fi

    # Validate config file
    if [ -f "$SERVICE_CONFIG_FILE" ]; then
        log_success "Config file exists: $SERVICE_CONFIG_FILE"

        # Example: Validate config syntax
        # if "$SERVICE_BINARY" --validate-config "$SERVICE_CONFIG_FILE" 2>/dev/null; then
        #     log_success "Configuration is valid"
        # else
        #     log_error "Configuration has errors"
        #     errors=1
        # fi
    else
        log_warning "Config file not found: $SERVICE_CONFIG_FILE"
    fi

    # Validate port is not in use (if service not running)
    if ! is_service_running; then
        if netstat -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
            log_error "Port $SERVICE_PORT is already in use by another process"
            errors=1
        else
            log_success "Port $SERVICE_PORT is available"
        fi
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        log_success "All validations passed"
        echo "════════════════════════════════════════════════════════"
        return 0
    else
        log_error "Validation failed with $errors error(s)"
        echo "════════════════════════════════════════════════════════"
        return 1
    fi
}

service_reload() {
    echo "════════════════════════════════════════════════════════"
    echo "🔄 Reloading Configuration"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if ! is_service_running; then
        log_error "Service is not running. Use --start to start it."
        return 1
    fi

    local pid=$(get_service_pid)
    log_info "Sending reload signal to service (PID: $pid)..."

    # Send HUP signal for config reload (common convention)
    if kill -HUP "$pid" 2>/dev/null; then
        log_success "Reload signal sent successfully"
        sleep 1

        if is_service_running; then
            log_success "Service is still running after reload"
        else
            log_error "Service stopped after reload (unexpected)"
            return 1
        fi
    else
        log_error "Failed to send reload signal"
        return 1
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
}

service_show_config() {
    echo "════════════════════════════════════════════════════════"
    echo "⚙️  Current Configuration"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if [ -f "$SERVICE_CONFIG_FILE" ]; then
        cat "$SERVICE_CONFIG_FILE"
    else
        log_error "Config file not found: $SERVICE_CONFIG_FILE"
        return 1
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
}

#------------------------------------------------------------------------------
# Service Operations - Debug
#------------------------------------------------------------------------------

service_test() {
    echo "════════════════════════════════════════════════════════"
    echo "🧪 Testing Service Connectivity"
    echo "════════════════════════════════════════════════════════"
    echo ""

    if ! is_service_running; then
        log_error "Service is not running"
        return 1
    fi

    log_info "Testing connection to localhost:$SERVICE_PORT..."

    # Example: Test HTTP endpoint
    # if curl -s --connect-timeout 5 "http://localhost:$SERVICE_PORT/health" >/dev/null 2>&1; then
    #     log_success "Service is responding"
    # else
    #     log_error "Service is not responding"
    #     return 1
    # fi

    # Example: Test TCP connection
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/localhost/$SERVICE_PORT" 2>/dev/null; then
        log_success "Service is accepting connections on port $SERVICE_PORT"
    else
        log_error "Cannot connect to service on port $SERVICE_PORT"
        return 1
    fi

    echo ""
    echo "════════════════════════════════════════════════════════"
}

service_health() {
    echo "════════════════════════════════════════════════════════"
    echo "💚 Service Health Check"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local health_ok=0

    # Check 1: Process running
    if is_service_running; then
        log_success "✓ Process is running"
    else
        log_error "✗ Process is not running"
        health_ok=1
    fi

    # Check 2: Port listening
    if netstat -tuln 2>/dev/null | grep -q ":$SERVICE_PORT "; then
        log_success "✓ Port $SERVICE_PORT is listening"
    else
        log_warning "✗ Port $SERVICE_PORT is not listening"
        health_ok=1
    fi

    # Check 3: Recent logs show no errors (example)
    if [ -f "$SERVICE_LOG_FILE" ]; then
        local recent_errors=$(tail -n 100 "$SERVICE_LOG_FILE" | grep -ic "error" || true)
        if [ "$recent_errors" -eq 0 ]; then
            log_success "✓ No recent errors in logs"
        else
            log_warning "✗ Found $recent_errors error(s) in recent logs"
            health_ok=1
        fi
    fi

    echo ""
    if [ $health_ok -eq 0 ]; then
        log_success "Overall health: GOOD"
        echo "════════════════════════════════════════════════════════"
        return 0
    else
        log_warning "Overall health: DEGRADED"
        echo "════════════════════════════════════════════════════════"
        return 1
    fi
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
    cmd_framework_generate_help SCRIPT_COMMANDS "service-example.sh" "$SCRIPT_VER"

    # Add examples section
    echo ""
    echo "Examples:"
    echo "  service-example.sh --start                # Start service (for supervisord)"
    echo "  service-example.sh --stop                 # Stop service"
    echo "  service-example.sh --restart              # Restart service"
    echo "  service-example.sh --status               # Check status"
    echo "  service-example.sh --logs                 # View recent logs"
    echo "  service-example.sh --validate             # Validate configuration"
    echo ""
    echo "Supervisord Integration:"
    echo "  The --start command uses 'exec' for supervisord compatibility."
    echo "  For manual restarts, use --restart (which doesn't use exec)."
    echo ""
}

parse_args() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_parse_args >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Use framework to parse arguments
    cmd_framework_parse_args SCRIPT_COMMANDS "service-example.sh" "$@"
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

    # Parse and execute command
    parse_args "$@"
}

main "$@"
