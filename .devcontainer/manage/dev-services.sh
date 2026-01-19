#!/bin/bash
# File: .devcontainer/manage/dev-services.sh
# Purpose: Manage devcontainer services via supervisord
# Usage: dev-services {status|start|stop|restart|logs|enable|disable|list-enabled} [service]

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-services"
SCRIPT_NAME="Services"
SCRIPT_DESCRIPTION="Manage background services (start, stop, status, logs)"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_error() { echo -e "${RED}❌ $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Configuration
ENABLED_SERVICES_CONF="/workspace/.devcontainer.extend/enabled-services.conf"
CONFIG_SUPERVISOR_SCRIPT="/workspace/.devcontainer/additions/config-supervisor.sh"

# Check if supervisord is running
check_supervisord() {
    if ! pgrep supervisord > /dev/null; then
        return 1
    fi
    return 0
}

# Ensure supervisord is running
ensure_supervisord() {
    if ! check_supervisord; then
        log_warn "Supervisord is not running. Starting it now..."
        echo ""

        # Try to start supervisord
        if sudo supervisord -c /etc/supervisor/supervisord.conf; then
            sleep 2
            if check_supervisord; then
                log_success "Supervisord started successfully"
                echo ""
                return 0
            fi
        fi

        log_error "Failed to start supervisord"
        echo ""
        echo "Troubleshooting steps:"
        echo "  1. Check config: sudo supervisord -c /etc/supervisor/supervisord.conf"
        echo "  2. Check logs: sudo cat /var/log/supervisor/supervisord.log"
        echo ""
        return 1
    fi
    return 0
}

# Show service status
cmd_status() {
    if ! check_supervisord; then
        log_warn "Supervisord is not running"
        echo ""
        echo "Start it with: dev-services start"
        echo ""
        return 0
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Service Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    sudo supervisorctl status
    echo ""
}

# Start a service or all services
cmd_start() {
    local service="${1:-}"

    if [ -z "$service" ]; then
        # Start supervisord if not running
        if ! check_supervisord; then
            log_info "Starting supervisord..."
            sudo supervisord -c /etc/supervisor/supervisord.conf
            sleep 2

            if check_supervisord; then
                log_success "Supervisord started with all enabled services"
                echo ""
                cmd_status
            else
                log_error "Failed to start supervisord"
                return 1
            fi
        else
            log_info "Supervisord is already running"
            cmd_status
        fi
    else
        # Start specific service
        ensure_supervisord || return 1

        log_info "Starting service: $service"
        if sudo supervisorctl start "$service"; then
            log_success "Service started: $service"
        else
            log_error "Failed to start service: $service"
            return 1
        fi
    fi
}

# Stop a service or all services
cmd_stop() {
    local service="${1:-}"

    if ! check_supervisord; then
        log_warn "Supervisord is not running"
        return 0
    fi

    if [ -z "$service" ]; then
        # Stop all services and supervisord
        log_info "Stopping all services and supervisord..."
        sudo supervisorctl stop all
        sleep 1
        sudo kill "$(pgrep supervisord)" 2>/dev/null || true
        log_success "All services stopped"
    else
        # Stop specific service
        log_info "Stopping service: $service"
        if sudo supervisorctl stop "$service"; then
            log_success "Service stopped: $service"
        else
            log_error "Failed to stop service: $service"
            return 1
        fi
    fi
}

# Restart a service or all services
cmd_restart() {
    local service="${1:-}"

    ensure_supervisord || return 1

    if [ -z "$service" ]; then
        # Restart all services
        log_info "Restarting all services..."
        sudo supervisorctl restart all
        log_success "All services restarted"
        echo ""
        cmd_status
    else
        # Restart specific service
        log_info "Restarting service: $service"
        if sudo supervisorctl restart "$service"; then
            log_success "Service restarted: $service"
        else
            log_error "Failed to restart service: $service"
            return 1
        fi
    fi
}

# View service logs
cmd_logs() {
    local service="$1"

    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        echo ""
        echo "Usage: dev-services logs <service>"
        echo ""
        echo "Available services:"
        sudo supervisorctl status 2>/dev/null | awk '{print "  - " $1}'
        return 1
    fi

    ensure_supervisord || return 1

    log_info "Viewing logs for: $service"
    echo ""
    sudo supervisorctl tail -f "$service"
}

# Enable a service for auto-start
cmd_enable() {
    local service="$1"

    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        echo ""
        echo "Usage: dev-services enable <service>"
        return 1
    fi

    # Create config file if it doesn't exist
    if [ ! -f "$ENABLED_SERVICES_CONF" ]; then
        mkdir -p "$(dirname "$ENABLED_SERVICES_CONF")"
        cat > "$ENABLED_SERVICES_CONF" << 'EOF'
# Enabled Services for Auto-Start
# Services listed here will automatically start when the container starts
# Format: One service identifier per line (matches SERVICE_NAME in lowercase-with-dashes)
#
# Management:
#   dev-services enable <service>   - Enable a service
#   dev-services disable <service>  - Disable a service
#   dev-services list-enabled       - Show enabled services

EOF
    fi

    # Check if already enabled
    if grep -q "^${service}$" "$ENABLED_SERVICES_CONF" 2>/dev/null; then
        log_warn "Service already enabled: $service"
        return 0
    fi

    # Add to enabled services
    echo "$service" >> "$ENABLED_SERVICES_CONF"
    log_success "Enabled service: $service"

    # Regenerate supervisor configs
    log_info "Regenerating supervisor configuration..."
    bash "$CONFIG_SUPERVISOR_SCRIPT"
}

# Disable a service from auto-start
cmd_disable() {
    local service="$1"

    if [ -z "$service" ]; then
        log_error "Please specify a service name"
        echo ""
        echo "Usage: dev-services disable <service>"
        return 1
    fi

    if [ ! -f "$ENABLED_SERVICES_CONF" ]; then
        log_warn "No enabled services configured"
        return 0
    fi

    # Remove from enabled services
    if grep -q "^${service}$" "$ENABLED_SERVICES_CONF"; then
        sed -i "/^${service}$/d" "$ENABLED_SERVICES_CONF"
        log_success "Disabled service: $service"

        # Regenerate supervisor configs
        log_info "Regenerating supervisor configuration..."
        bash "$CONFIG_SUPERVISOR_SCRIPT"
    else
        log_warn "Service not enabled: $service"
    fi
}

# List enabled services
cmd_list_enabled() {
    if [ ! -f "$ENABLED_SERVICES_CONF" ]; then
        log_warn "No enabled services configured"
        return 0
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Enabled Services"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local count=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        echo "  ✓ $line"
        count=$((count + 1))
    done < "$ENABLED_SERVICES_CONF"

    if [ $count -eq 0 ]; then
        echo "  (none)"
    fi

    echo ""
}

# Show help
cmd_help() {
    cat << 'EOF'
dev-services - Manage devcontainer services via supervisord

Usage:
  dev-services status                 Show status of all services
  dev-services start [service]        Start all services or specific service
  dev-services stop [service]         Stop all services or specific service
  dev-services restart [service]      Restart all services or specific service
  dev-services logs <service>         View logs for a service (follows)
  dev-services enable <service>       Enable service for auto-start
  dev-services disable <service>      Disable service from auto-start
  dev-services list-enabled           List enabled services
  dev-services help                   Show this help message

Examples:
  dev-services status                 # Show all service statuses
  dev-services start                  # Start supervisord with all enabled services
  dev-services restart otel-lifecycle # Restart specific service
  dev-services logs otel-metrics      # Follow logs for metrics collector
  dev-services enable otel-monitoring # Enable OTel monitoring for auto-start

Service Management:
  - Services are managed by supervisord
  - Configurations are auto-generated from enabled services
  - Enable/disable controls which services start automatically
  - All changes require supervisor config regeneration (done automatically)

Configuration:
  - Enabled services: /workspace/.devcontainer.extend/enabled-services.conf
  - Supervisor configs: /etc/supervisor/conf.d/
  - Service logs: /var/log/supervisor/

EOF
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    status)
        cmd_status "$@"
        ;;
    start)
        cmd_start "$@"
        ;;
    stop)
        cmd_stop "$@"
        ;;
    restart)
        cmd_restart "$@"
        ;;
    logs)
        cmd_logs "$@"
        ;;
    enable)
        cmd_enable "$@"
        ;;
    disable)
        cmd_disable "$@"
        ;;
    list-enabled)
        cmd_list_enabled "$@"
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        echo ""
        cmd_help
        exit 1
        ;;
esac
