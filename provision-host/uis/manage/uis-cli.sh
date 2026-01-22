#!/bin/bash
# uis-cli.sh - UIS Command Line Interface
#
# This is the main CLI entry point called from inside the container.
# The ./uis wrapper script on the host routes commands here.
#
# Usage: uis-cli.sh <command> [args...]

set -e

# Get script directory and UIS root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UIS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$UIS_DIR/lib"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/categories.sh"
source "$LIB_DIR/service-scanner.sh"
source "$LIB_DIR/first-run.sh"
source "$LIB_DIR/service-deployment.sh"
source "$LIB_DIR/service-auto-enable.sh" 2>/dev/null || true

# Version
UIS_VERSION="0.1.0"

# ============================================================
# Command Functions
# ============================================================

cmd_version() {
    echo "UIS (Urbalurba Infrastructure Stack) v$UIS_VERSION"
}

cmd_help() {
    cat <<EOF
UIS (Urbalurba Infrastructure Stack) v$UIS_VERSION

Usage: uis <command> [options]

Service Discovery:
  list                    List available services with status
  status                  Show deployed services health
  categories              List service categories

Service Deployment:
  deploy [service]        Deploy all enabled services, or specific service
  remove <service>        Remove a specific service

Configuration:
  enable <service>        Add service to enabled-services.conf
  disable <service>       Remove service from enabled-services.conf
  list-enabled            Show currently enabled services

Information:
  version                 Show UIS version
  help                    Show this help message

Examples:
  uis list                # Show all available services
  uis enable prometheus   # Enable prometheus
  uis deploy              # Deploy all enabled services
  uis deploy grafana      # Deploy grafana (auto-enables)
  uis status              # Check health of deployed services

EOF
}

cmd_list() {
    local show_all=false
    local filter_category=""

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a) show_all=true; shift ;;
            --category|-c) filter_category="$2"; shift 2 ;;
            *) break ;;
        esac
    done

    print_section "Available Services"

    # Print header
    printf "%-15s %-20s %-12s %s\n" "ID" "NAME" "CATEGORY" "STATUS"
    echo "─────────────────────────────────────────────────────────────────────"

    # Get services grouped by category
    local current_category=""
    local service_id script

    # First, collect all services
    for cat_id in "${CATEGORY_ORDER[@]}"; do
        [[ -n "$filter_category" && "$filter_category" != "$cat_id" ]] && continue

        while IFS= read -r service_id; do
            [[ -z "$service_id" ]] && continue
            script=$(find_service_script "$service_id")
            [[ -z "$script" ]] && continue

            # Load metadata
            unset SCRIPT_ID SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_CATEGORY SCRIPT_CHECK_COMMAND
            # shellcheck source=/dev/null
            source "$script" 2>/dev/null

            # Check deployment status
            local status_icon status_text
            if [[ -z "$SCRIPT_CHECK_COMMAND" ]]; then
                status_icon="○"
                status_text="No check"
            elif check_service_deployed "$service_id" 2>/dev/null; then
                status_icon="✅"
                status_text="Deployed"
            else
                status_icon="❌"
                status_text="Not deployed"
            fi

            # Print row
            printf "%-15s %-20s %-12s %s %s\n" \
                "$SCRIPT_ID" \
                "${SCRIPT_NAME:0:20}" \
                "${SCRIPT_CATEGORY:0:12}" \
                "$status_icon" \
                "$status_text"

        done < <(get_services_by_category "$cat_id")
    done

    echo ""
    echo "Use 'uis enable <service>' to enable a service"
    echo "Use 'uis deploy' to deploy all enabled services"
}

cmd_status() {
    print_section "Deployed Services Status"

    local has_deployed=false
    local service_id script

    printf "%-15s %-20s %-12s %s\n" "ID" "NAME" "CATEGORY" "HEALTH"
    echo "─────────────────────────────────────────────────────────────────────"

    for service_id in $(get_all_service_ids); do
        script=$(find_service_script "$service_id")
        [[ -z "$script" ]] && continue

        # Load metadata
        unset SCRIPT_ID SCRIPT_NAME SCRIPT_CATEGORY SCRIPT_CHECK_COMMAND
        # shellcheck source=/dev/null
        source "$script" 2>/dev/null

        # Only show if has check command and is deployed
        if [[ -n "$SCRIPT_CHECK_COMMAND" ]]; then
            if check_service_deployed "$service_id" 2>/dev/null; then
                has_deployed=true
                printf "%-15s %-20s %-12s %s\n" \
                    "$SCRIPT_ID" \
                    "${SCRIPT_NAME:0:20}" \
                    "${SCRIPT_CATEGORY:0:12}" \
                    "✅ Healthy"
            fi
        fi
    done

    if [[ "$has_deployed" != "true" ]]; then
        echo "No deployed services found."
        echo ""
        echo "Use 'uis deploy' to deploy enabled services."
    fi
}

cmd_categories() {
    print_section "Service Categories"
    print_categories_table
}

cmd_deploy() {
    local service_id="${1:-}"

    # Initialize if needed
    if ! check_first_run; then
        log_info "First run detected, initializing configuration..."
        initialize_uis_config
    fi

    if [[ -n "$service_id" ]]; then
        # Deploy specific service
        log_info "Deploying service: $service_id"

        # Check if service exists
        local script
        script=$(find_service_script "$service_id")
        if [[ -z "$script" ]]; then
            log_error "Service '$service_id' not found"
            log_info "Run 'uis list' to see available services"
            exit "$EXIT_CONFIG_ERROR"
        fi

        # Deploy and auto-enable
        deploy_single_service "$service_id"

        # Auto-enable if successful and service-auto-enable is available
        if type enable_service &>/dev/null; then
            if ! is_service_enabled "$service_id"; then
                enable_service "$service_id"
                log_info "Service '$service_id' has been auto-enabled"
            fi
        fi
    else
        # Deploy all enabled services
        if is_using_default_secrets; then
            log_warn "Using built-in defaults for localhost development"
        fi

        deploy_enabled_services
    fi
}

cmd_remove() {
    local service_id="${1:-}"

    if [[ -z "$service_id" ]]; then
        log_error "Usage: uis remove <service>"
        exit "$EXIT_GENERAL_ERROR"
    fi

    # Check if service exists
    local script
    script=$(find_service_script "$service_id")
    if [[ -z "$script" ]]; then
        log_error "Service '$service_id' not found"
        log_info "Run 'uis list' to see available services"
        exit "$EXIT_CONFIG_ERROR"
    fi

    remove_single_service "$service_id"

    # Prompt to disable if service-auto-enable is available
    if type is_service_enabled &>/dev/null && is_service_enabled "$service_id"; then
        log_warn "Service '$service_id' is still in enabled-services.conf"
        log_info "Run 'uis disable $service_id' to remove from configuration"
    fi
}

cmd_enable() {
    local service_id="${1:-}"

    if [[ -z "$service_id" ]]; then
        log_error "Usage: uis enable <service>"
        exit "$EXIT_GENERAL_ERROR"
    fi

    # Check if service exists
    local script
    script=$(find_service_script "$service_id")
    if [[ -z "$script" ]]; then
        log_error "Service '$service_id' not found"
        log_info "Run 'uis list' to see available services"
        exit "$EXIT_CONFIG_ERROR"
    fi

    if ! type enable_service &>/dev/null; then
        log_error "service-auto-enable.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    enable_service "$service_id"
}

cmd_disable() {
    local service_id="${1:-}"

    if [[ -z "$service_id" ]]; then
        log_error "Usage: uis disable <service>"
        exit "$EXIT_GENERAL_ERROR"
    fi

    if ! type disable_service &>/dev/null; then
        log_error "service-auto-enable.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    disable_service "$service_id"
}

cmd_list_enabled() {
    print_section "Enabled Services"

    local count=0
    local service_id script

    printf "%-15s %-25s %s\n" "ID" "NAME" "DEPLOYED"
    echo "──────────────────────────────────────────────────────"

    while IFS= read -r service_id; do
        [[ -z "$service_id" ]] && continue
        ((count++))

        script=$(find_service_script "$service_id")
        local name="$service_id"
        local deployed="?"

        if [[ -n "$script" ]]; then
            unset SCRIPT_NAME SCRIPT_CHECK_COMMAND
            # shellcheck source=/dev/null
            source "$script" 2>/dev/null
            name="${SCRIPT_NAME:-$service_id}"

            if [[ -n "$SCRIPT_CHECK_COMMAND" ]]; then
                if check_service_deployed "$service_id" 2>/dev/null; then
                    deployed="✅ Yes"
                else
                    deployed="❌ No"
                fi
            else
                deployed="○ No check"
            fi
        else
            deployed="⚠️  Not found"
        fi

        printf "%-15s %-25s %s\n" "$service_id" "${name:0:25}" "$deployed"
    done < <(read_enabled_services)

    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No services enabled."
        echo "Use 'uis enable <service>' to enable a service."
    else
        echo "$count service(s) enabled"
        echo "Use 'uis deploy' to deploy all enabled services"
    fi
}

# ============================================================
# Main Command Router
# ============================================================

main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        version|--version|-v)
            cmd_version
            ;;
        help|--help|-h)
            cmd_help
            ;;
        list|ls)
            cmd_list "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        categories|cats)
            cmd_categories
            ;;
        deploy)
            cmd_deploy "$@"
            ;;
        remove|rm)
            cmd_remove "$@"
            ;;
        enable)
            cmd_enable "$@"
            ;;
        disable)
            cmd_disable "$@"
            ;;
        list-enabled|enabled)
            cmd_list_enabled
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            cmd_help
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
