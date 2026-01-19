#!/bin/bash
# File: .devcontainer/additions/config-supervisor.sh
# Purpose: Auto-generate supervisor config from service metadata
# Usage: bash config-supervisor.sh
#        bash config-supervisor.sh --verify   # Non-interactive validation

#------------------------------------------------------------------------------
# CONFIG METADATA - For dev-setup.sh integration
#------------------------------------------------------------------------------

SCRIPT_ID="config-supervisor"
SCRIPT_NAME="Supervisor configuration"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Regenerate supervisor configuration from enabled services"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="test -f /etc/supervisor/supervisord.conf"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="supervisor services process management daemon"
SCRIPT_ABSTRACT="Auto-generate supervisor configuration from enabled service metadata."
SCRIPT_LOGO="config-supervisor-logo.webp"
SCRIPT_WEBSITE="https://supervisord.org"
SCRIPT_SUMMARY="Configuration script that auto-generates supervisor process management configuration from enabled services. Reads service metadata (commands, priorities, dependencies, auto-restart settings) and creates the appropriate supervisor conf.d files."
SCRIPT_RELATED="srv-nginx srv-otel"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Regenerate supervisor configuration||false|"
    "Action|--show|Display enabled services and status||false|"
    "Action|--verify|Verify supervisor configuration||false|"
    "Info|--help|Show help information||false|"
)

#------------------------------------------------------------------------------

set -e

# Source logging library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# Paths
ADDITIONS_DIR="/workspace/.devcontainer/additions"
SUPERVISOR_CONF_D="/etc/supervisor/conf.d"
TEMP_CONF_DIR="/tmp/supervisor-configs"
ENABLED_SERVICES_CONF="/workspace/.devcontainer.extend/enabled-services.conf"

# Service metadata arrays
declare -a SERVICE_NAMES=()
declare -a SERVICE_COMMANDS=()
declare -a SERVICE_PRIORITIES=()
declare -a SERVICE_DEPENDENCIES=()
declare -a SERVICE_AUTO_RESTART=()

# Enabled services list
declare -a ENABLED_SERVICES=()

#------------------------------------------------------------------------------
# Enabled Services Management
#------------------------------------------------------------------------------

load_enabled_services() {
    log_info "Loading enabled services from $ENABLED_SERVICES_CONF..."

    # Create file if it doesn't exist
    if [[ ! -f "$ENABLED_SERVICES_CONF" ]]; then
        log_warn "No enabled-services.conf found - creating empty list"
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
#
# Note: Services auto-enable themselves when first started successfully

EOF
        return
    fi

    # Read enabled services (skip comments and empty lines)
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        ENABLED_SERVICES+=("$line")
    done < "$ENABLED_SERVICES_CONF"

    log_info "  Loaded ${#ENABLED_SERVICES[@]} enabled services"
}

is_service_enabled() {
    local script_id="$1"

    # Check if SCRIPT_ID is in enabled list (direct match, no conversion)
    for enabled in "${ENABLED_SERVICES[@]}"; do
        if [[ "$enabled" == "$script_id" ]]; then
            return 0
        fi
    done

    return 1
}

#------------------------------------------------------------------------------
# Service Discovery
#------------------------------------------------------------------------------

discover_services() {
    log_info "Discovering services in $ADDITIONS_DIR..."

    # Find all service-*.sh scripts (extensible pattern)
    while IFS= read -r -d '' service_script; do
        # Extract metadata from service-*.sh files
        local script_id
        local service_name
        local service_command
        local service_priority
        local service_depends
        local service_auto_restart

        # Extract SCRIPT_ID and SCRIPT_NAME
        script_id=$(grep '^SCRIPT_ID=' "$service_script" 2>/dev/null | cut -d'"' -f2 || echo "")
        service_name=$(grep '^SCRIPT_NAME=' "$service_script" 2>/dev/null | cut -d'"' -f2 || echo "")
        # Command is the script path with --start flag
        service_command="bash $service_script --start"
        service_priority=$(grep '^SERVICE_PRIORITY=' "$service_script" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "50")
        service_depends=$(grep '^SERVICE_DEPENDS=' "$service_script" 2>/dev/null | cut -d'"' -f2 || echo "")
        service_auto_restart=$(grep '^SERVICE_AUTO_RESTART=' "$service_script" 2>/dev/null | cut -d'"' -f2 || echo "true")

        # Only include if has SCRIPT_ID and is enabled
        if [[ -n "$script_id" && -n "$service_name" ]]; then
            if is_service_enabled "$script_id"; then
                SERVICE_NAMES+=("$service_name")
                SERVICE_COMMANDS+=("$service_command")
                SERVICE_PRIORITIES+=("$service_priority")
                SERVICE_DEPENDENCIES+=("$service_depends")
                SERVICE_AUTO_RESTART+=("$service_auto_restart")

                log_info "  Found: $service_name (priority: $service_priority) ✅ ENABLED"
            else
                log_info "  Found: $service_name (priority: $service_priority) ⏸️  disabled"
            fi
        fi
    done < <(find "$ADDITIONS_DIR" -name "service-*.sh" -type f -print0)

    # Add built-in log cleanup scheduler (always enabled, runs last)
    SERVICE_NAMES+=("Log Cleanup")
    SERVICE_COMMANDS+=("bash $ADDITIONS_DIR/cmd-logs.sh --scheduled")
    SERVICE_PRIORITIES+=("999")
    SERVICE_DEPENDENCIES+=("")
    SERVICE_AUTO_RESTART+=("true")
    log_info "  Added: Log Cleanup (priority: 999) ✅ BUILT-IN"

    log_success "Discovered ${#SERVICE_NAMES[@]} enabled services"
}

#------------------------------------------------------------------------------
# Config Generation
#------------------------------------------------------------------------------

generate_config_for_service() {
    local index=$1
    local name="${SERVICE_NAMES[$index]}"
    local command="${SERVICE_COMMANDS[$index]}"
    local priority="${SERVICE_PRIORITIES[$index]}"
    local depends="${SERVICE_DEPENDENCIES[$index]}"
    local auto_restart="${SERVICE_AUTO_RESTART[$index]}"

    # Convert service name to program name (lowercase, no spaces)
    local program_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Generate config file
    local config_file="$TEMP_CONF_DIR/${program_name}.conf"

    cat > "$config_file" << EOF
[program:${program_name}]
command=${command}
autostart=true
autorestart=${auto_restart}
priority=${priority}
user=vscode
stdout_logfile=/var/log/supervisor/${program_name}.log
stderr_logfile=/var/log/supervisor/${program_name}-error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
startsecs=5
stopwaitsecs=10
EOF

    # Add dependencies if specified
    if [[ -n "$depends" ]]; then
        echo "depends_on=${depends}" >> "$config_file"
    fi

    log_info "  Generated config: ${program_name}.conf"
}

install_configs() {
    log_info "Installing supervisor configs..."

    # Clear existing auto-generated configs
    sudo rm -f "$SUPERVISOR_CONF_D"/auto-*.conf

    # Install new configs
    for conf_file in "$TEMP_CONF_DIR"/*.conf; do
        if [ -f "$conf_file" ]; then
            local filename=$(basename "$conf_file")
            sudo cp "$conf_file" "$SUPERVISOR_CONF_D/auto-${filename}"
        fi
    done

    log_success "Installed ${#SERVICE_NAMES[@]} service configs"
}

reload_supervisor() {
    log_info "Reloading supervisor..."

    if pgrep supervisord > /dev/null; then
        sudo supervisorctl reread
        sudo supervisorctl update
        log_success "Supervisor reloaded"
    else
        log_info "Supervisor not running - starting it now..."
        # Start supervisord in background with output redirected
        sudo supervisord -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &
        sleep 3
        if pgrep supervisord > /dev/null; then
            log_success "Supervisor started and services are now running"
        else
            log_warn "Failed to start supervisor - check supervisord.conf"
        fi
    fi
}

#------------------------------------------------------------------------------
# SHOW CONFIG - Display current configuration
#------------------------------------------------------------------------------

show_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Current Configuration: $SCRIPT_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Show enabled services
    echo "Enabled Services (from $ENABLED_SERVICES_CONF):"
    if [ -f "$ENABLED_SERVICES_CONF" ]; then
        local count=0
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            echo "  • $line"
            count=$((count + 1))
        done < "$ENABLED_SERVICES_CONF"
        if [ $count -eq 0 ]; then
            echo "  (none)"
        fi
    else
        echo "  (config file not found)"
    fi
    echo ""

    # Show auto-generated configs
    echo "Auto-generated Supervisor Configs:"
    local auto_configs=$(ls "$SUPERVISOR_CONF_D"/auto-*.conf 2>/dev/null || true)
    if [ -n "$auto_configs" ]; then
        for conf in $auto_configs; do
            echo "  • $(basename "$conf")"
        done
    else
        echo "  (none)"
    fi
    echo ""

    # Show supervisor status
    echo "Supervisor Status:"
    if pgrep supervisord > /dev/null; then
        echo "  Running: ✅ Yes"
        echo ""
        echo "  Service Status:"
        sudo supervisorctl status 2>/dev/null | sed 's/^/    /' || echo "    (unable to get status)"
    else
        echo "  Running: ❌ No"
    fi
    echo ""

    return 0
}

#------------------------------------------------------------------------------
# Verify Function (for --verify flag)
#------------------------------------------------------------------------------

verify_supervisor() {
    local errors=0

    # Check if supervisord.conf exists
    if [[ ! -f /etc/supervisor/supervisord.conf ]]; then
        log_warn "Supervisor config not found: /etc/supervisor/supervisord.conf"
        ((errors++))
    fi

    # Check if supervisor conf.d directory exists
    if [[ ! -d "$SUPERVISOR_CONF_D" ]]; then
        log_warn "Supervisor conf.d directory not found: $SUPERVISOR_CONF_D"
        ((errors++))
    fi

    # Check if supervisord is running
    if pgrep supervisord > /dev/null; then
        log_info "Supervisor is running"
    else
        log_info "Supervisor is not running (will start when services are enabled)"
    fi

    # List auto-generated configs
    local auto_configs
    auto_configs=$(ls "$SUPERVISOR_CONF_D"/auto-*.conf 2>/dev/null | wc -l)
    log_info "Auto-generated service configs: $auto_configs"

    if [[ $errors -eq 0 ]]; then
        log_success "Supervisor configuration verified"
        return 0
    else
        log_warn "Supervisor configuration has issues"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Handle flags
    case "${1:-}" in
        --show)
            show_config
            exit $?
            ;;
        --verify)
            verify_supervisor
            exit $?
            ;;
        --help)
            echo "Usage: $0 [--show|--verify|--help]"
            echo ""
            echo "  (no args)  Regenerate supervisor configuration"
            echo "  --show     Display enabled services and status"
            echo "  --verify   Verify supervisor configuration"
            echo "  --help     Show this help"
            exit 0
            ;;
    esac

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Generating Supervisor Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Create temp directory
    mkdir -p "$TEMP_CONF_DIR"

    # Load enabled services list
    load_enabled_services

    echo ""

    # Discover services
    discover_services

    if [ ${#SERVICE_NAMES[@]} -eq 0 ]; then
        log_warn "No services found with SERVICE_NAME metadata"
        exit 0
    fi

    echo ""
    log_info "Generating configurations..."

    # Generate config for each service
    for i in "${!SERVICE_NAMES[@]}"; do
        generate_config_for_service "$i"
    done

    echo ""

    # Install configs
    install_configs

    # Reload supervisor
    reload_supervisor

    # Cleanup
    rm -rf "$TEMP_CONF_DIR"

    echo ""
    log_success "Supervisor configuration complete"
    echo ""
}

main "$@"
