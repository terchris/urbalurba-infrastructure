#!/bin/bash
# File: .devcontainer/additions/service-nginx.sh
#
# PURPOSE: Manage nginx reverse proxy service with extensible operations
# DESCRIPTION: Consolidated service management for nginx with start, stop, restart,
#              status, logs, validate, reload, and other operations
#
# Author: Terje Christensen
# Created: November 2024 (migrated from start-nginx.sh + stop-nginx.sh)
#
# Usage:
#   bash service-nginx.sh --help           # Show all available operations
#------------------------------------------------------------------------------
# SERVICE METADATA - For supervisord and dev-setup integration
#------------------------------------------------------------------------------

SCRIPT_ID="service-nginx"
SCRIPT_NAME="Nginx Reverse Proxy"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Nginx reverse proxy for LiteLLM (adds Host header)"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="pgrep -x nginx >/dev/null 2>&1"
SCRIPT_PREREQUISITES=""  # Optional: "config-nginx.sh" if required
SCRIPT_PREREQUISITE_TOOLS="install-srv-nginx.sh"  # Must be installed first

# Supervisord metadata
SERVICE_PRIORITY="20"
SERVICE_DEPENDS=""
SERVICE_AUTO_RESTART="true"

#------------------------------------------------------------------------------
# SCRIPT_COMMANDS ARRAY - Single source of truth for all operations
#------------------------------------------------------------------------------

SCRIPT_COMMANDS=(
    "Control|--start|Start nginx in foreground (for supervisord)|service_start|false|"
    "Control|--stop|Stop nginx gracefully|service_stop|false|"
    "Control|--restart|Restart nginx service|service_restart|false|"
    "Status|--status|Check if nginx is running|service_status|false|"
    "Status|--is-running|Silent check if running (exit 0=running, 1=stopped)|service_is_running|false|"
    "Status|--logs|Show recent nginx logs|service_logs|false|"
    "Status|--logs-follow|Follow nginx logs in real-time|service_logs_follow|false|"
    "Config|--validate|Validate nginx configuration|service_validate|false|"
    "Config|--reload|Reload nginx configuration without restart|service_reload|false|"
    "Config|--show-config|Display current nginx configuration|service_show_config|false|"
    "Debug|--test|Test nginx connectivity|service_test|false|"
    "Debug|--health|Check nginx health|service_health|false|"
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

# Config file locations
# Try multiple locations for config file (handle different environments)
if [ -f "$HOME/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="$HOME/.nginx-backend-config"
elif [ -f "/home/vscode/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="/home/vscode/.nginx-backend-config"
elif [ -f "/workspace/.devcontainer.secrets/nginx-config/.nginx-backend-config" ]; then
    NGINX_CONFIG_FILE="/workspace/.devcontainer.secrets/nginx-config/.nginx-backend-config"
else
    NGINX_CONFIG_FILE=""
fi

NGINX_LITELLM_TEMPLATE="${SCRIPT_DIR}/nginx/litellm-proxy.conf.template"
NGINX_LITELLM_CONFIG="/etc/nginx/sites-available/litellm-proxy.conf"

# Default values (used if not configured)
DEFAULT_BACKEND_URL="http://host.docker.internal"
DEFAULT_LITELLM_PORT="8080"

# Log files
NGINX_ACCESS_LOG="/var/log/nginx/access.log"
NGINX_ERROR_LOG="/var/log/nginx/error.log"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

check_prerequisites() {
    local missing=0

    # Check if nginx is installed
    if ! command -v nginx >/dev/null 2>&1; then
        log_error "Nginx is not installed"
        log_info "Run: bash ${SCRIPT_DIR}/install-srv-nginx.sh"
        ((missing++))
    fi

    if [ $missing -gt 0 ]; then
        log_error "Prerequisites not met"
        return 1
    fi

    return 0
}

load_configuration() {
    # Check if config file exists and is not empty
    if [ -n "$NGINX_CONFIG_FILE" ] && [ -f "$NGINX_CONFIG_FILE" ]; then
        log_info "Loading backend configuration from $NGINX_CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$NGINX_CONFIG_FILE"
        log_success "Backend configured: ${BACKEND_TYPE:-unknown} (${BACKEND_URL:-unknown})"
        log_info "LiteLLM port: ${NGINX_LITELLM_PORT:-8080}, OTEL port: ${NGINX_OTEL_PORT:-not set}"
    else
        log_warning "No backend configuration found, using defaults"
        log_info "Run 'bash ${SCRIPT_DIR}/config-nginx.sh' to configure backend"
        BACKEND_URL="$DEFAULT_BACKEND_URL"
        BACKEND_TYPE="docker-internal-default"
        NGINX_LITELLM_PORT="$DEFAULT_LITELLM_PORT"
    fi
}

generate_nginx_config() {
    log_info "Generating nginx configurations from templates..."

    # Generate LiteLLM proxy config
    if [ ! -f "$NGINX_LITELLM_TEMPLATE" ]; then
        log_error "LiteLLM template not found: $NGINX_LITELLM_TEMPLATE"
        return 1
    fi

    sudo sed -e "s|BACKEND_URL|${BACKEND_URL}|g" \
             -e "s|NGINX_LITELLM_PORT|${NGINX_LITELLM_PORT}|g" \
             "$NGINX_LITELLM_TEMPLATE" | \
        sudo tee "$NGINX_LITELLM_CONFIG" >/dev/null

    # Enable LiteLLM site
    sudo ln -sf "$NGINX_LITELLM_CONFIG" /etc/nginx/sites-enabled/litellm-proxy.conf 2>/dev/null || true

    log_success "LiteLLM proxy config generated (port: $NGINX_LITELLM_PORT)"

    # Generate OTEL proxy config (if NGINX_OTEL_PORT is set)
    if [ -n "${NGINX_OTEL_PORT:-}" ]; then
        local NGINX_OTEL_TEMPLATE="${SCRIPT_DIR}/nginx/otel-proxy.conf.template"
        local NGINX_OTEL_CONFIG="/etc/nginx/sites-available/otel-proxy.conf"

        if [ -f "$NGINX_OTEL_TEMPLATE" ]; then
            sudo sed -e "s|BACKEND_URL|${BACKEND_URL}|g" \
                     -e "s|NGINX_OTEL_PORT|${NGINX_OTEL_PORT}|g" \
                     "$NGINX_OTEL_TEMPLATE" | \
                sudo tee "$NGINX_OTEL_CONFIG" >/dev/null

            # Enable OTEL site
            sudo ln -sf "$NGINX_OTEL_CONFIG" /etc/nginx/sites-enabled/otel-proxy.conf 2>/dev/null || true

            log_success "OTEL proxy config generated (port: $NGINX_OTEL_PORT)"
        else
            log_warning "OTEL template not found: $NGINX_OTEL_TEMPLATE (skipping)"
        fi
    fi

    # Generate Open WebUI proxy config (if NGINX_OPENWEBUI_PORT is set)
    if [ -n "${NGINX_OPENWEBUI_PORT:-}" ]; then
        local NGINX_OPENWEBUI_TEMPLATE="${SCRIPT_DIR}/nginx/openwebui-proxy.conf.template"
        local NGINX_OPENWEBUI_CONFIG="/etc/nginx/sites-available/openwebui-proxy.conf"

        if [ -f "$NGINX_OPENWEBUI_TEMPLATE" ]; then
            sudo sed -e "s|{{BACKEND_URL}}|${BACKEND_URL}|g" \
                     -e "s|8082|${NGINX_OPENWEBUI_PORT}|g" \
                     "$NGINX_OPENWEBUI_TEMPLATE" | \
                sudo tee "$NGINX_OPENWEBUI_CONFIG" >/dev/null

            # Enable Open WebUI site
            sudo ln -sf "$NGINX_OPENWEBUI_CONFIG" /etc/nginx/sites-enabled/openwebui-proxy.conf 2>/dev/null || true

            log_success "Open WebUI proxy config generated (port: $NGINX_OPENWEBUI_PORT)"
        else
            log_warning "Open WebUI template not found: $NGINX_OPENWEBUI_TEMPLATE (skipping)"
        fi
    fi

    log_success "Backend: ${BACKEND_URL:-unknown}"
    return 0
}

is_service_running() {
    if pgrep -x nginx >/dev/null 2>&1; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

get_service_pid() {
    # Get master nginx process PID
    pgrep -x nginx 2>/dev/null | head -1
}

wait_for_service_ready() {
    local max_wait=10
    local waited=0

    log_info "Waiting for nginx to be ready..."

    while [ $waited -lt $max_wait ]; do
        if is_service_running; then
            log_success "Nginx is ready"
            return 0
        fi
        sleep 1
        ((waited++))
    done

    log_error "Nginx failed to start within ${max_wait}s"
    return 1
}

#------------------------------------------------------------------------------
# Service Operations - Control
#------------------------------------------------------------------------------

service_start() {
    echo ""
    log_info "=========================================="
    log_info "Starting Nginx Reverse Proxy"
    log_info "=========================================="
    echo ""

    # Check prerequisites
    check_prerequisites || exit 1

    # Load configuration
    load_configuration

    # Generate nginx config from template with configured backend
    if ! generate_nginx_config; then
        exit 1
    fi

    # Validate configuration
    if ! service_validate; then
        exit 1
    fi

    # Check if already running
    if is_service_running; then
        log_warning "Nginx is already running"
        exit 0
    fi

    # Stop any existing nginx process (cleanup)
    log_info "Stopping any existing nginx processes..."
    sudo nginx -s quit 2>/dev/null || sudo pkill -9 nginx 2>/dev/null || true
    sleep 1

    # Auto-enable for container restart (BEFORE exec)
    auto_enable_service

    # Start nginx in foreground mode (CRITICAL: Use exec for supervisord)
    log_info "Starting nginx in foreground mode..."
    exec sudo nginx -g "daemon off;"

    # IMPORTANT: Code after exec will NEVER run
    # The shell process is replaced by nginx
}

service_stop() {
    echo ""
    log_info "=========================================="
    log_info "Stopping Nginx Reverse Proxy"
    log_info "=========================================="
    echo ""

    # Check if not running
    if ! is_service_running; then
        log_info "Nginx is not running"
        # Still disable from auto-start
        auto_disable_service
        return 0
    fi

    # Get PID for logging
    local pid=$(get_service_pid)
    log_info "Nginx PID: $pid"

    # Try graceful shutdown first
    log_info "Attempting graceful shutdown (nginx -s quit)..."
    if sudo nginx -s quit 2>/dev/null; then
        # Wait for graceful shutdown (max 10 seconds)
        local waited=0
        while [ $waited -lt 10 ]; do
            if ! is_service_running; then
                log_success "Nginx stopped gracefully"
                auto_disable_service
                return 0
            fi
            sleep 1
            ((waited++))
        done
    fi

    # Force kill if graceful shutdown fails
    log_warning "Graceful shutdown failed, forcing stop..."
    if sudo pkill -9 nginx 2>/dev/null; then
        sleep 1
        log_success "Nginx stopped (forced)"
        auto_disable_service
        return 0
    fi

    log_error "Failed to stop nginx"
    return 1
}

service_restart() {
    echo ""
    log_info "=========================================="
    log_info "Restarting Nginx Reverse Proxy"
    log_info "=========================================="
    echo ""

    # Stop the service
    service_stop
    sleep 2

    # Check prerequisites
    check_prerequisites || exit 1

    # Load configuration
    load_configuration

    # Generate nginx config
    if ! generate_nginx_config; then
        exit 1
    fi

    # Validate configuration
    if ! service_validate; then
        exit 1
    fi

    # Start nginx in background (NO EXEC - this is for manual restart)
    log_info "Starting nginx..."
    sudo nginx

    # Wait for service to be ready
    wait_for_service_ready

    echo ""
    log_success "Nginx restarted successfully"
    echo ""
}

#------------------------------------------------------------------------------
# Service Operations - Status
#------------------------------------------------------------------------------

service_is_running() {
    # Silent check - returns 0 if running, 1 if not
    # No output, just exit code for scripting
    if is_service_running; then
        return 0
    else
        return 1
    fi
}

service_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Nginx Reverse Proxy Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Load configuration to display config values
    load_configuration

    if is_service_running; then
        local pid=$(get_service_pid)
        echo "✅ Status: Running"
        echo "   PID: $pid"

        # Show uptime
        local uptime=$(ps -p "$pid" -o etime= 2>/dev/null | tr -d ' ')
        echo "   Uptime: ${uptime:-unknown}"

        # Show listening ports
        echo ""
        echo "📡 Listening ports:"
        sudo netstat -tlnp 2>/dev/null | grep nginx || echo "   (Unable to get port info)"

        # Show config info
        echo ""
        echo "⚙️  Configuration:"
        echo "   Backend: ${BACKEND_URL:-not loaded}"
        echo "   LiteLLM port: ${NGINX_LITELLM_PORT:-not loaded}"
        if [ -n "${NGINX_OTEL_PORT:-}" ]; then
            echo "   OTEL port: $NGINX_OTEL_PORT"
        fi
        if [ -n "${NGINX_OPENWEBUI_PORT:-}" ]; then
            echo "   Open WebUI port: $NGINX_OPENWEBUI_PORT"
        fi

        echo ""
        return 0
    else
        echo "❌ Status: Not running"
        echo ""

        # Show last error if available
        if [ -f "$NGINX_ERROR_LOG" ]; then
            echo "📋 Recent errors (last 5 lines):"
            sudo tail -5 "$NGINX_ERROR_LOG" 2>/dev/null || echo "   (Unable to read error log)"
            echo ""
        fi

        return 1
    fi
}

service_logs() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Recent Nginx Logs"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local log_dir="/var/log/nginx"
    local lines_per_log=15

    # Show LiteLLM logs (main proxy)
    if [ -f "$log_dir/litellm-access.log" ]; then
        local litellm_lines=$(wc -l < "$log_dir/litellm-access.log" 2>/dev/null || echo "0")
        echo "🤖 LiteLLM Access Log ($litellm_lines total lines):"
        sudo tail -n $lines_per_log "$log_dir/litellm-access.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    if [ -f "$log_dir/litellm-error.log" ] && [ -s "$log_dir/litellm-error.log" ]; then
        echo "🔴 LiteLLM Error Log:"
        sudo tail -n $lines_per_log "$log_dir/litellm-error.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    # Show OTEL logs
    if [ -f "$log_dir/otel-access.log" ]; then
        local otel_lines=$(wc -l < "$log_dir/otel-access.log" 2>/dev/null || echo "0")
        echo "📊 OTEL Access Log ($otel_lines total lines, showing last $lines_per_log):"
        sudo tail -n $lines_per_log "$log_dir/otel-access.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    if [ -f "$log_dir/otel-error.log" ] && [ -s "$log_dir/otel-error.log" ]; then
        echo "🔴 OTEL Error Log:"
        sudo tail -n $lines_per_log "$log_dir/otel-error.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    # Show Open WebUI logs
    if [ -f "$log_dir/openwebui-access.log" ]; then
        local webui_lines=$(wc -l < "$log_dir/openwebui-access.log" 2>/dev/null || echo "0")
        echo "🌐 Open WebUI Access Log ($webui_lines total lines):"
        sudo tail -n $lines_per_log "$log_dir/openwebui-access.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    if [ -f "$log_dir/openwebui-error.log" ] && [ -s "$log_dir/openwebui-error.log" ]; then
        echo "🔴 Open WebUI Error Log:"
        sudo tail -n $lines_per_log "$log_dir/openwebui-error.log" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    # Show default nginx logs only if they have content
    if [ -f "$NGINX_ERROR_LOG" ] && [ -s "$NGINX_ERROR_LOG" ]; then
        echo "🔴 Default Error Log:"
        sudo tail -n $lines_per_log "$NGINX_ERROR_LOG" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    if [ -f "$NGINX_ACCESS_LOG" ] && [ -s "$NGINX_ACCESS_LOG" ]; then
        echo "🟢 Default Access Log:"
        sudo tail -n $lines_per_log "$NGINX_ACCESS_LOG" 2>/dev/null | sed 's/^/   /' || echo "   (empty)"
        echo ""
    fi

    echo "📁 Log directory: $log_dir"
    echo ""
}

service_logs_follow() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Following Nginx Logs (Ctrl+C to stop)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ -f "$NGINX_ERROR_LOG" ] && [ -f "$NGINX_ACCESS_LOG" ]; then
        sudo tail -f "$NGINX_ERROR_LOG" "$NGINX_ACCESS_LOG" 2>/dev/null
    elif [ -f "$NGINX_ERROR_LOG" ]; then
        sudo tail -f "$NGINX_ERROR_LOG" 2>/dev/null
    elif [ -f "$NGINX_ACCESS_LOG" ]; then
        sudo tail -f "$NGINX_ACCESS_LOG" 2>/dev/null
    else
        log_error "No log files found"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Service Operations - Config
#------------------------------------------------------------------------------

service_validate() {
    log_info "Validating nginx configuration..."

    local nginx_test_output
    nginx_test_output=$(sudo nginx -t 2>&1)
    local nginx_exit_code=$?

    if [ $nginx_exit_code -eq 0 ]; then
        log_success "Nginx configuration is valid"
        return 0
    else
        log_error "Nginx configuration has errors:"
        echo "$nginx_test_output"
        return 1
    fi
}

service_reload() {
    echo ""
    log_info "Reloading nginx configuration..."
    echo ""

    # Check if nginx is running
    if ! is_service_running; then
        log_error "Nginx is not running, cannot reload"
        log_info "Use --start or --restart to start nginx"
        exit 1
    fi

    # Regenerate config from templates
    load_configuration
    if ! generate_nginx_config; then
        log_error "Failed to generate configuration"
        exit 1
    fi

    # Validate new configuration before reloading
    if ! service_validate; then
        log_error "Configuration validation failed, not reloading"
        exit 1
    fi

    # Reload nginx configuration
    if sudo nginx -s reload 2>/dev/null; then
        log_success "Nginx configuration reloaded successfully"
        return 0
    else
        log_error "Failed to reload nginx configuration"
        return 1
    fi
}

service_show_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  Nginx Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Show backend configuration
    echo "🔧 Backend Configuration:"
    if [ -n "$NGINX_CONFIG_FILE" ] && [ -f "$NGINX_CONFIG_FILE" ]; then
        echo "   Config file: $NGINX_CONFIG_FILE"
        cat "$NGINX_CONFIG_FILE"
    else
        echo "   No backend configuration file found"
        echo "   Run: bash ${SCRIPT_DIR}/config-nginx.sh"
    fi

    echo ""

    # Show enabled sites
    echo "🌐 Enabled Sites:"
    if [ -d /etc/nginx/sites-enabled ]; then
        ls -la /etc/nginx/sites-enabled/ | grep -v "^total" | grep -v "default" || echo "   No custom sites enabled"
    else
        echo "   sites-enabled directory not found"
    fi

    echo ""

    # Show main nginx config (last 20 lines)
    echo "📄 Main Nginx Config (/etc/nginx/nginx.conf - last 20 lines):"
    sudo tail -20 /etc/nginx/nginx.conf 2>/dev/null || echo "   (Unable to read main config)"

    echo ""
}

#------------------------------------------------------------------------------
# Service Operations - Debug
#------------------------------------------------------------------------------

service_test() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Testing Nginx Connectivity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check if running
    if ! is_service_running; then
        log_error "Nginx is not running"
        log_info "Start nginx first: bash $0 --start"
        exit 1
    fi

    # Load configuration to get ports
    load_configuration

    # Test LiteLLM proxy
    echo "🔍 Testing LiteLLM proxy (port: ${NGINX_LITELLM_PORT:-8080})..."
    local litellm_port="${NGINX_LITELLM_PORT:-8080}"
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${litellm_port}/health" 2>/dev/null | grep -q "200\|404"; then
        log_success "LiteLLM proxy is responding on port $litellm_port"
    else
        log_warning "LiteLLM proxy may not be responding correctly on port $litellm_port"
    fi

    # Test OTEL proxy if configured
    if [ -n "${NGINX_OTEL_PORT:-}" ]; then
        echo ""
        echo "🔍 Testing OTEL proxy (port: $NGINX_OTEL_PORT)..."
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_OTEL_PORT}/" 2>/dev/null | grep -q "200\|404\|302"; then
            log_success "OTEL proxy is responding on port $NGINX_OTEL_PORT"
        else
            log_warning "OTEL proxy may not be responding correctly on port $NGINX_OTEL_PORT"
        fi
    fi

    # Test Open WebUI proxy if configured
    if [ -n "${NGINX_OPENWEBUI_PORT:-}" ]; then
        echo ""
        echo "🔍 Testing Open WebUI proxy (port: $NGINX_OPENWEBUI_PORT)..."
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${NGINX_OPENWEBUI_PORT}/" 2>/dev/null | grep -q "200\|404\|302"; then
            log_success "Open WebUI proxy is responding on port $NGINX_OPENWEBUI_PORT"
        else
            log_warning "Open WebUI proxy may not be responding correctly on port $NGINX_OPENWEBUI_PORT"
        fi
    fi

    echo ""
    log_success "Connectivity test complete"
    echo ""
}

service_health() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🏥 Nginx Health Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local health_ok=0

    # Check 1: Process running
    echo "1️⃣  Checking if nginx is running..."
    if is_service_running; then
        log_success "Nginx process is running"
    else
        log_error "Nginx process is not running"
        ((health_ok++))
    fi

    # Check 2: Configuration valid
    echo ""
    echo "2️⃣  Checking configuration validity..."
    if sudo nginx -t >/dev/null 2>&1; then
        log_success "Nginx configuration is valid"
    else
        log_error "Nginx configuration has errors"
        ((health_ok++))
    fi

    # Check 3: Listening on expected ports
    echo ""
    echo "3️⃣  Checking listening ports..."
    load_configuration
    local litellm_port="${NGINX_LITELLM_PORT:-8080}"
    if sudo netstat -tlnp 2>/dev/null | grep -q ":${litellm_port}.*nginx"; then
        log_success "Nginx is listening on port $litellm_port"
    else
        log_warning "Nginx may not be listening on port $litellm_port"
        ((health_ok++))
    fi

    # Check 4: Recent errors (check all error logs)
    echo ""
    echo "4️⃣  Checking for recent errors..."
    local total_errors=0
    local log_dir="/var/log/nginx"

    for error_log in "$log_dir"/*-error.log "$NGINX_ERROR_LOG"; do
        if [ -f "$error_log" ] && [ -s "$error_log" ]; then
            local count=$(sudo grep -c "emerg\|alert\|crit\|error" "$error_log" 2>/dev/null || echo "0")
            if [ "$count" -gt 0 ]; then
                total_errors=$((total_errors + count))
            fi
        fi
    done

    if [ "$total_errors" -gt 0 ]; then
        log_warning "Found $total_errors errors across nginx error logs"
        echo "   Recent errors:"
        for error_log in "$log_dir"/*-error.log "$NGINX_ERROR_LOG"; do
            if [ -f "$error_log" ] && [ -s "$error_log" ]; then
                sudo grep "emerg\|alert\|crit\|error" "$error_log" 2>/dev/null | tail -3 | sed 's/^/   /'
            fi
        done
    else
        log_success "No critical errors in recent logs"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $health_ok -eq 0 ]; then
        echo "✅ Overall Health: HEALTHY"
        echo ""
        return 0
    else
        echo "⚠️  Overall Health: DEGRADED ($health_ok issues found)"
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
    cmd_framework_generate_help SCRIPT_COMMANDS "service-nginx.sh" "$SCRIPT_VER"
}

parse_args() {
    # Use cmd-framework.sh to parse arguments and call appropriate function
    source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    cmd_framework_parse_args SCRIPT_COMMANDS "service-nginx.sh" "$@"
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
