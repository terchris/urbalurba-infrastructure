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
source "$LIB_DIR/menu-helpers.sh" 2>/dev/null || true
source "$LIB_DIR/tool-installation.sh" 2>/dev/null || true
source "$LIB_DIR/secrets-management.sh" 2>/dev/null || true

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

Interactive:
  setup                   Interactive TUI menu for service management
  init                    Initialize configuration (first-time setup wizard)

Service Discovery:
  list                    List available services with status
  status                  Show deployed services health
  categories              List service categories
  cluster types           List available cluster types

Service Deployment:
  deploy [service]        Deploy all enabled services, or specific service
  remove <service>        Remove a specific service

Configuration:
  enable <service>        Add service to enabled-services.conf
  disable <service>       Remove service from enabled-services.conf
  list-enabled            Show currently enabled services

Secrets Management:
  secrets init            Create .uis.secrets/ structure with templates
  secrets status          Show secrets configuration status
  secrets edit            Open secrets config in editor
  secrets generate        Generate Kubernetes secrets from templates
  secrets apply           Apply generated secrets to cluster
  secrets validate        Validate secrets configuration

Tools:
  tools list              List all available tools with status
  tools install <tool>    Install an optional tool

Documentation:
  docs generate           Generate JSON files for website

Information:
  version                 Show UIS version
  help                    Show this help message

Examples:
  uis setup               # Open interactive menu
  uis init                # Run first-time setup wizard
  uis list                # Show all available services
  uis enable prometheus   # Enable prometheus
  uis deploy              # Deploy all enabled services
  uis secrets init        # Initialize secrets configuration
  uis secrets status      # Show what's configured
  uis tools list          # Show available tools
  uis tools install azure-cli  # Install Azure CLI

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
# Tools Commands
# ============================================================

cmd_tools() {
    local subcmd="${1:-list}"
    shift || true

    case "$subcmd" in
        list|ls)
            cmd_tools_list
            ;;
        install)
            cmd_tools_install "$@"
            ;;
        *)
            log_error "Unknown tools subcommand: $subcmd"
            echo "Usage: uis tools [list|install <tool>]"
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

cmd_tools_list() {
    print_section "Available Tools"

    if ! type list_tools &>/dev/null; then
        log_error "tool-installation.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    list_tools
}

cmd_tools_install() {
    local tool_id="${1:-}"

    if [[ -z "$tool_id" ]]; then
        log_error "Usage: uis tools install <tool>"
        exit "$EXIT_GENERAL_ERROR"
    fi

    if ! type install_tool &>/dev/null; then
        log_error "tool-installation.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    install_tool "$tool_id"
}

# ============================================================
# Interactive Setup Menu
# ============================================================

cmd_setup() {
    if ! type show_menu &>/dev/null; then
        log_error "menu-helpers.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    while true; do
        local choice
        choice=$(show_menu "UIS Setup Menu v$UIS_VERSION" "Select an option:" \
            "services" "Browse & Deploy Services" \
            "tools" "Install Optional Tools" \
            "status" "System Status" \
            "exit" "Exit")

        case "$choice" in
            services)
                setup_services_menu
                ;;
            tools)
                setup_tools_menu
                ;;
            status)
                clear_screen
                cmd_status
                echo ""
                read -p "Press Enter to continue..."
                ;;
            exit|"")
                break
                ;;
        esac
    done
}

setup_services_menu() {
    while true; do
        # Build category menu
        local -a menu_args=()
        for cat_id in "${CATEGORY_ORDER[@]}"; do
            local cat_name
            cat_name=$(get_category_name "$cat_id")
            menu_args+=("$cat_id" "$cat_name")
        done
        menu_args+=("back" "Back to Main Menu")

        local choice
        choice=$(show_menu "Service Categories" "Select a category:" "${menu_args[@]}")

        if [[ "$choice" == "back" || -z "$choice" ]]; then
            break
        fi

        setup_category_services "$choice"
    done
}

setup_category_services() {
    local category="$1"
    local cat_name
    cat_name=$(get_category_name "$category")

    while true; do
        # Build service checklist
        local -a checklist_args=()
        local service_id script

        while IFS= read -r service_id; do
            [[ -z "$service_id" ]] && continue
            script=$(find_service_script "$service_id")
            [[ -z "$script" ]] && continue

            unset SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_CHECK_COMMAND
            source "$script" 2>/dev/null

            local state="off"
            if is_service_enabled "$service_id" 2>/dev/null; then
                state="on"
            fi

            local status_marker=""
            if [[ -n "$SCRIPT_CHECK_COMMAND" ]]; then
                if check_service_deployed "$service_id" 2>/dev/null; then
                    status_marker="✅ "
                fi
            fi

            checklist_args+=("$service_id" "$status_marker${SCRIPT_NAME:-$service_id}" "$state")
        done < <(get_services_by_category "$category")

        if [[ ${#checklist_args[@]} -eq 0 ]]; then
            show_msgbox "No Services" "No services found in category $cat_name"
            break
        fi

        local selected
        selected=$(show_checklist "Services: $cat_name" "Toggle services to enable/disable:" "${checklist_args[@]}")

        if [[ -z "$selected" ]]; then
            break
        fi

        # Update enabled services based on selection
        for service_id in $(get_services_by_category "$category"); do
            if [[ " $selected " == *" $service_id "* ]]; then
                # Should be enabled
                if ! is_service_enabled "$service_id" 2>/dev/null; then
                    enable_service "$service_id" 2>/dev/null
                fi
            else
                # Should be disabled
                if is_service_enabled "$service_id" 2>/dev/null; then
                    disable_service "$service_id" 2>/dev/null
                fi
            fi
        done

        # Offer to deploy
        if show_yesno "Deploy Services" "Deploy the selected services now?"; then
            clear_screen
            deploy_enabled_services
            echo ""
            read -p "Press Enter to continue..."
        fi

        break
    done
}

setup_tools_menu() {
    while true; do
        # Build tool checklist
        local -a checklist_args=()
        local tool_id

        for tool_id in $(get_all_tool_ids | sort -u); do
            local name desc state
            name=$(get_tool_value "$tool_id" "TOOL_NAME")
            name="${name:-$tool_id}"
            desc=$(get_tool_value "$tool_id" "TOOL_DESCRIPTION")

            if is_tool_installed "$tool_id"; then
                state="on"
                name="✅ $name"
            else
                state="off"
            fi

            checklist_args+=("$tool_id" "$name" "$state")
        done

        local selected
        selected=$(show_checklist "Install Optional Tools" "Select tools to install:" "${checklist_args[@]}")

        if [[ -z "$selected" ]]; then
            break
        fi

        # Install selected tools that aren't already installed
        for tool_id in $selected; do
            if ! is_tool_installed "$tool_id"; then
                clear_screen
                install_tool "$tool_id"
                echo ""
                read -p "Press Enter to continue..."
            fi
        done

        break
    done
}

# ============================================================
# Init Command
# ============================================================

cmd_init() {
    print_section "UIS First-Time Setup"

    echo "Welcome to UIS (Urbalurba Infrastructure Stack)!"
    echo ""

    # Check if already initialized
    if check_first_run; then
        log_info "UIS is already initialized"
        echo ""
        echo "Current configuration:"
        load_cluster_config
        echo "  CLUSTER_TYPE: ${CLUSTER_TYPE:-rancher-desktop}"
        echo "  BASE_DOMAIN: ${BASE_DOMAIN:-localhost}"
        echo ""
        echo "To reconfigure, remove .uis.extend/ and run 'uis init' again"
        return 0
    fi

    echo "This wizard will help you configure UIS for your environment."
    echo ""

    # Project name (optional)
    local project_name
    read -p "Project name [uis]: " project_name
    project_name="${project_name:-uis}"

    # Cluster type selection
    echo ""
    echo "Select cluster type:"
    echo "  1. rancher-desktop (Local laptop - default)"
    echo "  2. azure-aks (Azure Kubernetes Service)"
    echo "  3. azure-microk8s (MicroK8s on Azure VM)"
    echo "  4. multipass-microk8s (MicroK8s on local VM)"
    echo "  5. raspberry-microk8s (MicroK8s on Raspberry Pi)"
    read -p "Choice [1]: " cluster_choice
    cluster_choice="${cluster_choice:-1}"

    local cluster_type
    case "$cluster_choice" in
        1) cluster_type="rancher-desktop" ;;
        2) cluster_type="azure-aks" ;;
        3) cluster_type="azure-microk8s" ;;
        4) cluster_type="multipass-microk8s" ;;
        5) cluster_type="raspberry-microk8s" ;;
        *) cluster_type="rancher-desktop" ;;
    esac

    # Base domain
    echo ""
    read -p "Base domain [localhost]: " base_domain
    base_domain="${base_domain:-localhost}"

    # Initialize configuration
    initialize_uis_config

    # Update cluster-config.sh with user choices
    local config_file
    config_file=$(get_base_path)/.uis.extend/cluster-config.sh

    cat > "$config_file" << EOF
#!/bin/bash
# UIS Cluster Configuration
# Generated by 'uis init' on $(date)

# Project identifier
PROJECT_NAME="$project_name"

# Cluster type - determines deployment strategy
CLUSTER_TYPE="$cluster_type"

# Base domain for service URLs
BASE_DOMAIN="$base_domain"

# Additional configuration can be added here
EOF

    echo ""
    log_success "Configuration saved to .uis.extend/cluster-config.sh"
    echo ""
    echo "Next steps:"
    echo "  uis list              # See available services"
    echo "  uis enable <service>  # Enable services you want"
    echo "  uis deploy            # Deploy enabled services"
    echo ""
    echo "For custom secrets (optional):"
    echo "  uis secrets init      # Create secrets configuration"
}

cmd_cluster() {
    local subcmd="${1:-types}"
    shift || true

    case "$subcmd" in
        types)
            print_section "Available Cluster Types"
            echo ""
            printf "%-20s %s\n" "TYPE" "DESCRIPTION"
            echo "────────────────────────────────────────────────────────────"
            printf "%-20s %s\n" "rancher-desktop" "Local laptop (default)"
            printf "%-20s %s\n" "azure-aks" "Azure Kubernetes Service"
            printf "%-20s %s\n" "azure-microk8s" "MicroK8s on Azure VM"
            printf "%-20s %s\n" "multipass-microk8s" "MicroK8s on local VM"
            printf "%-20s %s\n" "raspberry-microk8s" "MicroK8s on Raspberry Pi"
            ;;
        *)
            log_error "Unknown cluster subcommand: $subcmd"
            echo "Usage: uis cluster [types]"
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# ============================================================
# Docs Commands
# ============================================================

cmd_docs() {
    local subcmd="${1:-generate}"
    shift || true

    case "$subcmd" in
        generate|gen)
            local output_dir="${1:-}"
            local docs_script="$SCRIPT_DIR/uis-docs.sh"

            if [[ ! -f "$docs_script" ]]; then
                log_error "uis-docs.sh not found"
                exit "$EXIT_GENERAL_ERROR"
            fi

            "$docs_script" "$output_dir"
            ;;
        *)
            log_error "Unknown docs subcommand: $subcmd"
            echo "Usage: uis docs [generate [output-dir]]"
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# ============================================================
# Secrets Commands
# ============================================================

cmd_secrets() {
    local subcmd="${1:-status}"
    shift || true

    if ! type init_secrets &>/dev/null; then
        log_error "secrets-management.sh not loaded"
        exit "$EXIT_GENERAL_ERROR"
    fi

    case "$subcmd" in
        init)
            init_secrets
            ;;
        status)
            show_secrets_status
            ;;
        edit)
            edit_secrets
            ;;
        generate)
            generate_secrets
            ;;
        apply)
            apply_secrets
            ;;
        validate)
            validate_secrets
            ;;
        *)
            log_error "Unknown secrets subcommand: $subcmd"
            echo "Usage: uis secrets [init|status|edit|generate|apply|validate]"
            exit "$EXIT_GENERAL_ERROR"
            ;;
    esac
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
        setup)
            cmd_setup
            ;;
        init)
            cmd_init
            ;;
        cluster)
            cmd_cluster "$@"
            ;;
        secrets)
            cmd_secrets "$@"
            ;;
        docs)
            cmd_docs "$@"
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
        tools)
            cmd_tools "$@"
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
