#!/bin/bash
# File: .devcontainer/additions/service-otel-monitoring.sh
#
# PURPOSE: Manage OpenTelemetry monitoring services with extensible operations
# DESCRIPTION: Consolidated service management for OTel (lifecycle, metrics, script_exporter)
#
# Author: Terje Christensen
# Created: November 2024 (migrated from start-otel-monitoring.sh + stop-otel-monitoring.sh)
#
# This script manages 3 separate processes:
#   1. Lifecycle Collector (port 4318) - Devcontainer lifecycle events
#   2. Metrics Collector - System and container metrics
#   3. Script Exporter (port 9469) - Container metrics provider
#
# Usage:
#   bash service-otel-monitoring.sh --help           # Show all operations
#------------------------------------------------------------------------------
# SERVICE METADATA - For supervisord and dev-setup integration
#------------------------------------------------------------------------------

SCRIPT_ID="service-otel"
SCRIPT_NAME="OTel Monitoring"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="OpenTelemetry monitoring stack (lifecycle, metrics, script exporter)"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="pgrep -f 'otelcol.*--config' >/dev/null 2>&1"
SCRIPT_PREREQUISITES="config-devcontainer-identity.sh"
SCRIPT_PREREQUISITE_TOOLS="install-srv-otel-monitoring.sh"  # Must be installed first

# Supervisord metadata
SERVICE_PRIORITY="30"
SERVICE_DEPENDS="service-nginx"  # Sends data through nginx reverse proxy
SERVICE_AUTO_RESTART="true"

#------------------------------------------------------------------------------
# SCRIPT_COMMANDS ARRAY - Single source of truth for all operations
#------------------------------------------------------------------------------

SCRIPT_COMMANDS=(
    "Control|--start|Start all OTel services (for supervisord)|service_start|false|"
    "Control|--stop|Stop all OTel services|service_stop|false|"
    "Control|--restart|Restart all OTel services|service_restart|false|"
    "Control|--start-lifecycle|Start only lifecycle collector|service_start_lifecycle|false|"
    "Control|--start-metrics|Start only metrics collector|service_start_metrics|false|"
    "Control|--start-exporter|Start only script exporter|service_start_exporter|false|"
    "Status|--status|Check status of all services|service_status|false|"
    "Status|--is-running|Silent check if running (exit 0=running, 1=stopped)|service_is_running|false|"
    "Status|--logs|Show recent logs from all services|service_logs|false|"
    "Status|--logs-lifecycle|Show lifecycle collector logs|service_logs_lifecycle|false|"
    "Status|--logs-metrics|Show metrics collector logs|service_logs_metrics|false|"
    "Status|--logs-exporter|Show script exporter logs|service_logs_exporter|false|"
    "Config|--validate|Validate identity configuration|service_validate|false|"
    "Config|--show-config|Display identity and configurations|service_show_config|false|"
    "Debug|--test|Test connectivity to all endpoints|service_test|false|"
    "Debug|--health|Check health of all services|service_health|false|"
)

#------------------------------------------------------------------------------
# Configuration Variables
#------------------------------------------------------------------------------

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/service-auto-enable.sh"

# Paths
OTEL_BINARY="otelcol-contrib"
CONFIG_FILE_LIFECYCLE="/workspace/.devcontainer/additions/otel/otelcol-lifecycle-config.yaml"
CONFIG_FILE_METRICS="/workspace/.devcontainer/additions/otel/otelcol-metrics-config.yaml"
SCRIPT_EXPORTER_CONFIG="/workspace/.devcontainer/additions/otel/script-exporter-config.yaml"

LOG_FILE_LIFECYCLE="/var/log/otelcol-lifecycle.log"
LOG_FILE_METRICS="/var/log/otelcol-metrics.log"
LOG_FILE_EXPORTER="/var/log/script-exporter.log"

# Identity files
# New location: .git-identity (auto-detected from git)
# Legacy location: .devcontainer-identity (manually configured)
GIT_IDENTITY_FILE="/workspace/.devcontainer.secrets/env-vars/.git-identity"
LEGACY_IDENTITY_FILE="/home/vscode/.devcontainer-identity"

# Source git identity file first (new auto-detected identity)
if [ -f "$GIT_IDENTITY_FILE" ]; then
    # shellcheck source=/dev/null
    source "$GIT_IDENTITY_FILE"
fi

# Source legacy identity file if exists (for backward compatibility)
# This may override some values if both exist
if [ -f "$LEGACY_IDENTITY_FILE" ]; then
    # shellcheck source=/dev/null
    source "$LEGACY_IDENTITY_FILE"
fi

# Host information file (for OTEL resource attributes)
HOST_INFO_FILE="/workspace/.devcontainer.secrets/env-vars/.host-info"

# Source host info file automatically if it exists
if [ -f "$HOST_INFO_FILE" ]; then
    # shellcheck source=/dev/null
    source "$HOST_INFO_FILE"
fi

# Nginx backend configuration (for NGINX_OTEL_PORT)
NGINX_CONFIG_FILE="/home/vscode/.nginx-backend-config"

# Source nginx config file automatically if it exists
if [ -f "$NGINX_CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$NGINX_CONFIG_FILE"
fi

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

check_prerequisites() {
    local missing=0

    # Check if OTel binary is installed
    if ! command -v otelcol-contrib >/dev/null 2>&1; then
        log_error "OTel Collector binary not found"
        log_info "Run: bash ${SCRIPT_DIR}/install-srv-otel-monitoring.sh"
        ((missing++))
    fi

    # Check if script_exporter is installed
    if ! command -v script_exporter >/dev/null 2>&1; then
        log_error "script_exporter binary not found"
        log_info "Run: bash ${SCRIPT_DIR}/install-srv-otel-monitoring.sh"
        ((missing++))
    fi

    # Check config files exist
    if [ ! -f "$CONFIG_FILE_LIFECYCLE" ]; then
        log_error "Lifecycle config not found: $CONFIG_FILE_LIFECYCLE"
        ((missing++))
    fi

    if [ ! -f "$CONFIG_FILE_METRICS" ]; then
        log_error "Metrics config not found: $CONFIG_FILE_METRICS"
        ((missing++))
    fi

    if [ ! -f "$SCRIPT_EXPORTER_CONFIG" ]; then
        log_error "Script exporter config not found: $SCRIPT_EXPORTER_CONFIG"
        ((missing++))
    fi

    if [ $missing -gt 0 ]; then
        log_error "Prerequisites not met"
        return 1
    fi

    return 0
}

load_configuration() {
    # Load identity from git-identity file (new auto-detected format)
    if [ -f "$GIT_IDENTITY_FILE" ]; then
        # shellcheck source=/dev/null
        source "$GIT_IDENTITY_FILE"
        log_info "Identity loaded from $GIT_IDENTITY_FILE"
    elif [ -f "$LEGACY_IDENTITY_FILE" ]; then
        # Fallback to legacy file
        # shellcheck source=/dev/null
        source "$LEGACY_IDENTITY_FILE"
        log_info "Identity loaded from $LEGACY_IDENTITY_FILE (legacy)"
    else
        log_warning "No identity file found"
        log_info "Run: bash ${SCRIPT_DIR}/config-git.sh --verify"
    fi
}

validate_required_variables() {
    local missing=()

    if [ -z "${DEVELOPER_ID:-}" ]; then
        missing+=("DEVELOPER_ID")
    fi

    if [ -z "${DEVELOPER_EMAIL:-}" ]; then
        missing+=("DEVELOPER_EMAIL")
    fi

    if [ -z "${PROJECT_NAME:-}" ]; then
        missing+=("PROJECT_NAME")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required environment variables: ${missing[*]}"
        echo ""
        echo "Please run the identity setup script:"
        echo "  bash ${SCRIPT_DIR}/config-devcontainer-identity.sh"
        echo ""
        return 1
    fi

    # Generate TS_HOSTNAME if not provided
    if [ -z "${TS_HOSTNAME:-}" ]; then
        TS_HOSTNAME="dev-${DEVELOPER_ID}-${PROJECT_NAME}"
        export TS_HOSTNAME
        log_info "Generated TS_HOSTNAME: $TS_HOSTNAME"
    fi

    # Set default values for optional variables that OTel configs expect
    # These are used by both lifecycle and metrics collectors
    # NOTE: OTel resource processor does not allow empty values, so we use "undefined"
    # (avoid "n/a" because "/" can cause problems in queries)

    # Windows extended host attributes (using OTel semantic conventions)
    export HOST_ARCH="${HOST_ARCH:-undefined}"
    export HOST_CPU_MODEL_NAME="${HOST_CPU_MODEL_NAME:-undefined}"
    export HOST_CPU_LOGICAL_COUNT="${HOST_CPU_LOGICAL_COUNT:-undefined}"

    # Organization detection (from Windows OneDrive/LOGONSERVER)
    export ORGANIZATION_NAME="${ORGANIZATION_NAME:-undefined}"
    export ORGANIZATION_PREFIX="${ORGANIZATION_PREFIX:-undefined}"
    export ORGANIZATION_MACHINE_OWNERSHIP="${ORGANIZATION_MACHINE_OWNERSHIP:-undefined}"

    # Git repository info (for project/organization filtering in reports)
    export GIT_PROVIDER="${GIT_PROVIDER:-unknown}"
    export GIT_ORG="${GIT_ORG:-undefined}"
    export GIT_REPO="${GIT_REPO:-unknown}"

    log_success "All required variables present"
    return 0
}

#------------------------------------------------------------------------------
# Process Status Functions
#------------------------------------------------------------------------------

is_lifecycle_running() {
    pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' >/dev/null 2>&1
}

is_metrics_running() {
    pgrep -f 'otelcol-contrib.*otelcol-metrics-config.yaml' >/dev/null 2>&1
}

is_exporter_running() {
    pgrep -f 'script_exporter' >/dev/null 2>&1
}

get_lifecycle_pid() {
    pgrep -f 'otelcol-contrib.*otelcol-lifecycle-config.yaml' 2>/dev/null | head -1
}

get_metrics_pid() {
    pgrep -f 'otelcol-contrib.*otelcol-metrics-config.yaml' 2>/dev/null | head -1
}

get_exporter_pid() {
    pgrep -f 'script_exporter' 2>/dev/null | head -1
}

#------------------------------------------------------------------------------
# Individual Service Start Functions
#------------------------------------------------------------------------------

start_lifecycle_collector() {
    log_info "Starting Lifecycle Collector (port 4318)..."

    if is_lifecycle_running; then
        log_warning "Lifecycle collector is already running"
        return 0
    fi

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE_LIFECYCLE")"
    sudo touch "$LOG_FILE_LIFECYCLE"
    sudo chmod 666 "$LOG_FILE_LIFECYCLE" 2>/dev/null || true

    # Export env vars for OTel Collector
    export DEVELOPER_ID
    export DEVELOPER_EMAIL
    export PROJECT_NAME
    export TS_HOSTNAME

    # Start collector in background
    nohup "$OTEL_BINARY" --config="$CONFIG_FILE_LIFECYCLE" >> "$LOG_FILE_LIFECYCLE" 2>&1 &
    local pid=$!

    # Wait for startup
    sleep 2

    # Check if still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Lifecycle collector failed to start"
        echo "Check logs: bash $0 --logs-lifecycle"
        return 1
    fi

    log_success "Lifecycle collector started (PID: $pid)"
    return 0
}

start_metrics_collector() {
    log_info "Starting Metrics Collector..."

    if is_metrics_running; then
        log_warning "Metrics collector is already running"
        return 0
    fi

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE_METRICS")"
    sudo touch "$LOG_FILE_METRICS"
    sudo chmod 666 "$LOG_FILE_METRICS" 2>/dev/null || true

    # Export env vars for OTel Collector
    export DEVELOPER_ID
    export DEVELOPER_EMAIL
    export PROJECT_NAME
    export TS_HOSTNAME

    # Start collector in background
    nohup "$OTEL_BINARY" --config="$CONFIG_FILE_METRICS" >> "$LOG_FILE_METRICS" 2>&1 &
    local pid=$!

    # Wait for startup
    sleep 2

    # Check if still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Metrics collector failed to start"
        echo "Check logs: bash $0 --logs-metrics"
        return 1
    fi

    log_success "Metrics collector started (PID: $pid)"
    return 0
}

start_script_exporter() {
    log_info "Starting script_exporter (port 9469)..."

    if is_exporter_running; then
        log_warning "script_exporter is already running"
        return 0
    fi

    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE_EXPORTER")"
    sudo touch "$LOG_FILE_EXPORTER"
    sudo chmod 666 "$LOG_FILE_EXPORTER" 2>/dev/null || true

    # Start script_exporter in background
    nohup script_exporter --config.files="$SCRIPT_EXPORTER_CONFIG" >> "$LOG_FILE_EXPORTER" 2>&1 &
    local pid=$!

    # Wait for startup
    sleep 2

    # Check if still running
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "script_exporter failed to start"
        echo "Check logs: bash $0 --logs-exporter"
        return 1
    fi

    log_success "script_exporter started (PID: $pid)"
    return 0
}

#------------------------------------------------------------------------------
# Individual Service Stop Functions
#------------------------------------------------------------------------------

stop_lifecycle_collector() {
    log_info "Stopping Lifecycle Collector..."

    if ! is_lifecycle_running; then
        log_info "Lifecycle collector is not running"
        return 0
    fi

    local pid=$(get_lifecycle_pid)
    log_info "Found lifecycle collector (PID: $pid)"

    # Try graceful shutdown
    if kill -TERM "$pid" 2>/dev/null; then
        local count=0
        while [ $count -lt 5 ]; do
            if ! is_lifecycle_running; then
                log_success "Lifecycle collector stopped gracefully"
                return 0
            fi
            sleep 1
            ((count++))
        done

        # Force kill if still running
        log_warning "Graceful shutdown timed out, forcing..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
        log_success "Lifecycle collector stopped (forced)"
    fi

    return 0
}

stop_metrics_collector() {
    log_info "Stopping Metrics Collector..."

    if ! is_metrics_running; then
        log_info "Metrics collector is not running"
        return 0
    fi

    local pid=$(get_metrics_pid)
    log_info "Found metrics collector (PID: $pid)"

    # Try graceful shutdown
    if kill -TERM "$pid" 2>/dev/null; then
        sleep 2
        if ! is_metrics_running; then
            log_success "Metrics collector stopped gracefully"
        else
            kill -9 "$pid" 2>/dev/null || true
            log_success "Metrics collector stopped (forced)"
        fi
    fi

    return 0
}

stop_script_exporter() {
    log_info "Stopping script_exporter..."

    if ! is_exporter_running; then
        log_info "script_exporter is not running"
        return 0
    fi

    local pid=$(get_exporter_pid)
    log_info "Found script_exporter (PID: $pid)"

    # Try graceful shutdown
    if kill -TERM "$pid" 2>/dev/null; then
        sleep 1
        if ! is_exporter_running; then
            log_success "script_exporter stopped gracefully"
        else
            kill -9 "$pid" 2>/dev/null || true
            log_success "script_exporter stopped (forced)"
        fi
    fi

    return 0
}

#------------------------------------------------------------------------------
# Service Operations - Control (Combined)
#------------------------------------------------------------------------------

service_start() {
    echo ""
    log_info "=========================================="
    log_info "Starting OTel Monitoring Services"
    log_info "=========================================="
    echo ""

    # Check prerequisites
    check_prerequisites || exit 1

    # Load and validate configuration
    load_configuration
    validate_required_variables || exit 1

    echo ""

    # Start script_exporter first (dependency for metrics)
    start_script_exporter || exit 1

    echo ""

    # Start metrics collector
    start_metrics_collector || exit 1

    echo ""

    # Start lifecycle collector in background
    start_lifecycle_collector || exit 1

    echo ""
    log_success "All OTel services started successfully"

    # Auto-enable for container restart
    auto_enable_service
}

service_stop() {
    echo ""
    log_info "=========================================="
    log_info "Stopping OTel Monitoring Services"
    log_info "=========================================="
    echo ""

    local failed=0

    # Stop lifecycle collector
    stop_lifecycle_collector || ((failed++))

    echo ""

    # Stop metrics collector
    stop_metrics_collector || ((failed++))

    echo ""

    # Stop script_exporter
    stop_script_exporter || ((failed++))

    echo ""
    if [ $failed -eq 0 ]; then
        log_success "All OTel services stopped successfully"
        auto_disable_service
    else
        log_warning "$failed service(s) failed to stop"
    fi
    echo ""

    return 0
}

service_restart() {
    echo ""
    log_info "=========================================="
    log_info "Restarting OTel Monitoring Services"
    log_info "=========================================="
    echo ""

    # Stop all services
    service_stop
    sleep 2

    # Check prerequisites
    check_prerequisites || exit 1

    # Load and validate configuration
    load_configuration
    validate_required_variables || exit 1

    echo ""

    # Start script_exporter first
    start_script_exporter || exit 1

    echo ""

    # Start metrics collector
    start_metrics_collector || exit 1

    echo ""

    # Start lifecycle collector (NO EXEC for restart)
    start_lifecycle_collector || exit 1

    echo ""
    log_success "All OTel services restarted successfully"
    echo ""
}

# Individual start operations (for manual control)
service_start_lifecycle() {
    echo ""
    check_prerequisites || exit 1
    load_configuration
    validate_required_variables || exit 1
    start_lifecycle_collector
    echo ""
}

service_start_metrics() {
    echo ""
    check_prerequisites || exit 1
    load_configuration
    validate_required_variables || exit 1
    start_metrics_collector
    echo ""
}

service_start_exporter() {
    echo ""
    check_prerequisites || exit 1
    start_script_exporter
    echo ""
}

#------------------------------------------------------------------------------
# Service Operations - Status
#------------------------------------------------------------------------------

service_is_running() {
    # Silent check - returns 0 if at least one component is running, 1 if all stopped
    # No output, just exit code for scripting
    if is_lifecycle_running || is_metrics_running || is_exporter_running; then
        return 0  # At least one component is running
    else
        return 1  # All stopped
    fi
}

service_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 OTel Monitoring Services Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Load configuration for display
    load_configuration

    # Check each service
    local all_running=true

    echo "1️⃣  Lifecycle Collector (port 4318):"
    if is_lifecycle_running; then
        local pid=$(get_lifecycle_pid)
        local uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        echo "   ✅ Running (PID: $pid, Uptime: ${uptime:-unknown})"
        echo "   📁 Config: $CONFIG_FILE_LIFECYCLE"
        echo "   📋 Log: $LOG_FILE_LIFECYCLE"
    else
        echo "   ❌ Not running"
        all_running=false
    fi

    echo ""

    echo "2️⃣  Metrics Collector:"
    if is_metrics_running; then
        local pid=$(get_metrics_pid)
        local uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        echo "   ✅ Running (PID: $pid, Uptime: ${uptime:-unknown})"
        echo "   📁 Config: $CONFIG_FILE_METRICS"
        echo "   📋 Log: $LOG_FILE_METRICS"
    else
        echo "   ❌ Not running"
        all_running=false
    fi

    echo ""

    echo "3️⃣  Script Exporter (port 9469):"
    if is_exporter_running; then
        local pid=$(get_exporter_pid)
        local uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        echo "   ✅ Running (PID: $pid, Uptime: ${uptime:-unknown})"
        echo "   📁 Config: $SCRIPT_EXPORTER_CONFIG"
        echo "   📋 Log: $LOG_FILE_EXPORTER"
    else
        echo "   ❌ Not running"
        all_running=false
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "$all_running" = true ]; then
        echo "✅ Overall Status: ALL SERVICES RUNNING"
    else
        echo "⚠️  Overall Status: SOME SERVICES DOWN"
    fi

    # Show identity info if available
    if [ -n "${DEVELOPER_ID:-}" ]; then
        echo ""
        echo "🆔 Identity:"
        echo "   Developer: $DEVELOPER_ID (${DEVELOPER_EMAIL:-unknown})"
        echo "   Project: ${PROJECT_NAME:-unknown}"
        echo "   Hostname: ${TS_HOSTNAME:-unknown}"
    fi

    echo ""
}

service_logs() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Recent OTel Monitoring Logs (last 20 lines each)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "1️⃣  Lifecycle Collector Log:"
    if [ -f "$LOG_FILE_LIFECYCLE" ]; then
        tail -n 20 "$LOG_FILE_LIFECYCLE" 2>/dev/null || echo "   (Unable to read log)"
    else
        echo "   ⚠️  Log file not found"
    fi

    echo ""
    echo "2️⃣  Metrics Collector Log:"
    if [ -f "$LOG_FILE_METRICS" ]; then
        tail -n 20 "$LOG_FILE_METRICS" 2>/dev/null || echo "   (Unable to read log)"
    else
        echo "   ⚠️  Log file not found"
    fi

    echo ""
    echo "3️⃣  Script Exporter Log:"
    if [ -f "$LOG_FILE_EXPORTER" ]; then
        tail -n 20 "$LOG_FILE_EXPORTER" 2>/dev/null || echo "   (Unable to read log)"
    else
        echo "   ⚠️  Log file not found"
    fi

    echo ""
}

service_logs_lifecycle() {
    echo ""
    echo "📋 Lifecycle Collector Logs (last 50 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -f "$LOG_FILE_LIFECYCLE" ]; then
        tail -n 50 "$LOG_FILE_LIFECYCLE" 2>/dev/null || echo "Unable to read log"
    else
        log_error "Log file not found: $LOG_FILE_LIFECYCLE"
    fi
    echo ""
}

service_logs_metrics() {
    echo ""
    echo "📋 Metrics Collector Logs (last 50 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -f "$LOG_FILE_METRICS" ]; then
        tail -n 50 "$LOG_FILE_METRICS" 2>/dev/null || echo "Unable to read log"
    else
        log_error "Log file not found: $LOG_FILE_METRICS"
    fi
    echo ""
}

service_logs_exporter() {
    echo ""
    echo "📋 Script Exporter Logs (last 50 lines)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    if [ -f "$LOG_FILE_EXPORTER" ]; then
        tail -n 50 "$LOG_FILE_EXPORTER" 2>/dev/null || echo "Unable to read log"
    else
        log_error "Log file not found: $LOG_FILE_EXPORTER"
    fi
    echo ""
}

#------------------------------------------------------------------------------
# Service Operations - Config
#------------------------------------------------------------------------------

service_validate() {
    echo ""
    log_info "Validating OTel Monitoring Configuration"
    echo ""

    local issues=0

    # Check prerequisites
    echo "1️⃣  Checking prerequisites..."
    if check_prerequisites; then
        log_success "All binaries and configs found"
    else
        ((issues++))
    fi

    echo ""

    # Check identity
    echo "2️⃣  Checking identity configuration..."
    load_configuration
    if validate_required_variables 2>/dev/null; then
        log_success "Identity configuration valid"
        echo "   Developer: $DEVELOPER_ID"
        echo "   Project: $PROJECT_NAME"
    else
        log_error "Identity configuration invalid or missing"
        ((issues++))
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $issues -eq 0 ]; then
        echo "✅ Validation Result: PASSED"
        echo ""
        return 0
    else
        echo "❌ Validation Result: FAILED ($issues issues)"
        echo ""
        return 1
    fi
}

service_show_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  OTel Monitoring Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Show identity
    echo "🆔 Identity Configuration:"
    if [ -f "$IDENTITY_FILE" ]; then
        echo "   Config file: $IDENTITY_FILE"
        echo ""
        cat "$IDENTITY_FILE"
    else
        echo "   ⚠️  No identity file found"
        echo "   Run: bash ${SCRIPT_DIR}/config-devcontainer-identity.sh"
    fi

    echo ""

    # Show config files
    echo "📁 Configuration Files:"
    echo "   Lifecycle: $CONFIG_FILE_LIFECYCLE"
    echo "   Metrics: $CONFIG_FILE_METRICS"
    echo "   Exporter: $SCRIPT_EXPORTER_CONFIG"

    echo ""

    # Show log files
    echo "📋 Log Files:"
    echo "   Lifecycle: $LOG_FILE_LIFECYCLE"
    echo "   Metrics: $LOG_FILE_METRICS"
    echo "   Exporter: $LOG_FILE_EXPORTER"

    echo ""
}

#------------------------------------------------------------------------------
# Service Operations - Debug
#------------------------------------------------------------------------------

service_test() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Testing OTel Monitoring Connectivity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if services are running
    if ! is_lifecycle_running && ! is_metrics_running && ! is_exporter_running; then
        log_error "No OTel services are running"
        log_info "Start services first: bash $0 --restart"
        exit 1
    fi

    # Test lifecycle collector (port 4318)
    echo "1️⃣  Testing Lifecycle Collector (port 4318)..."
    if is_lifecycle_running; then
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:4318/v1/logs" 2>/dev/null | grep -q "405\|200"; then
            log_success "Lifecycle collector endpoint is responding"
        else
            log_warning "Lifecycle collector may not be responding correctly"
        fi
    else
        log_warning "Lifecycle collector is not running"
    fi

    echo ""

    # Test script_exporter (port 9469)
    echo "2️⃣  Testing script_exporter (port 9469)..."
    if is_exporter_running; then
        if curl -s -f "http://localhost:9469/probe?script=cgroup_metrics" >/dev/null 2>&1; then
            log_success "script_exporter is serving metrics"
            echo "   Sample metrics:"
            curl -s "http://localhost:9469/probe?script=cgroup_metrics" 2>/dev/null | grep "^# HELP container_" | head -3 | sed 's/^# HELP /   - /'
        else
            log_warning "script_exporter may not be responding correctly"
        fi
    else
        log_warning "script_exporter is not running"
    fi

    echo ""
    log_success "Connectivity test complete"
    echo ""
}

service_health() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏥 OTel Monitoring Health Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local health_issues=0

    # Check 1: All processes running
    echo "1️⃣  Checking process status..."
    if is_lifecycle_running && is_metrics_running && is_exporter_running; then
        log_success "All 3 processes are running"
    else
        log_error "Not all processes are running"
        if ! is_lifecycle_running; then
            echo "   ❌ Lifecycle collector is down"
        fi
        if ! is_metrics_running; then
            echo "   ❌ Metrics collector is down"
        fi
        if ! is_exporter_running; then
            echo "   ❌ script_exporter is down"
        fi
        ((health_issues++))
    fi

    echo ""

    # Check 2: Identity configured
    echo "2️⃣  Checking identity configuration..."
    load_configuration
    if validate_required_variables 2>/dev/null; then
        log_success "Identity is properly configured"
    else
        log_error "Identity configuration is missing or invalid"
        ((health_issues++))
    fi

    echo ""

    # Check 3: Recent errors in logs
    echo "3️⃣  Checking for recent errors..."
    local has_errors=false

    if [ -f "$LOG_FILE_LIFECYCLE" ]; then
        if tail -100 "$LOG_FILE_LIFECYCLE" 2>/dev/null | grep -qi "error\|failed\|panic"; then
            log_warning "Found errors in lifecycle collector log"
            has_errors=true
        fi
    fi

    if [ -f "$LOG_FILE_METRICS" ]; then
        if tail -100 "$LOG_FILE_METRICS" 2>/dev/null | grep -qi "error\|failed\|panic"; then
            log_warning "Found errors in metrics collector log"
            has_errors=true
        fi
    fi

    if [ "$has_errors" = false ]; then
        log_success "No critical errors in recent logs"
    else
        ((health_issues++))
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $health_issues -eq 0 ]; then
        echo "✅ Overall Health: HEALTHY"
        echo ""
        return 0
    else
        echo "⚠️  Overall Health: DEGRADED ($health_issues issues found)"
        echo ""
        return 1
    fi
}

#------------------------------------------------------------------------------
# Framework Integration - Help and Argument Parsing
#------------------------------------------------------------------------------

show_help() {
    # Use cmd-framework.sh to generate help text from SCRIPT_COMMANDS array (pass version as 3rd argument)
    source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    cmd_framework_generate_help SCRIPT_COMMANDS "service-otel-monitoring.sh" "$SCRIPT_VER"
}

parse_args() {
    # Use cmd-framework.sh to parse arguments and call appropriate function
    source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    cmd_framework_parse_args SCRIPT_COMMANDS "service-otel-monitoring.sh" "$@"
}

#------------------------------------------------------------------------------
# Main Entry Point
#------------------------------------------------------------------------------

main() {
    # If no arguments, show help
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # Parse arguments and execute command
    parse_args "$@"
}

# Run main function
main "$@"
