#!/bin/bash
# File: .devcontainer/manage/dev-setup.sh
# Description: Simple development environment setup and tool selection
# Purpose: Central setup script for devcontainer development tools and templates
#
# Usage: dev-setup [--help] [--version]
#
# Exit Codes:
#   0 - Success or user exit
#   1 - Error in script execution
#   2 - Required directory not found
#   3 - User cancelled operation
#
#------------------------------------------------------------------------------

set -e

# Script metadata (for component scanner)
SCRIPT_ID="dev-setup"
SCRIPT_NAME="Setup Menu"
SCRIPT_DESCRIPTION="Interactive menu for installing tools and managing services"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"
SCRIPT_VERSION="3.4.0"

# Get script directory and calculate absolute paths
# Resolve symlinks to get actual script location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Handle both cases:
# 1. Running from .devcontainer/manage/ (symlink resolved or direct execution)
# 2. Running from .devcontainer/ root (when script is a copy, not symlink)
if [[ "$(basename "$SCRIPT_DIR")" == "manage" ]]; then
    DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
    MANAGE_DIR="$SCRIPT_DIR"
else
    # Script is in .devcontainer/ root (copy from zip extraction)
    DEVCONTAINER_DIR="$SCRIPT_DIR"
    MANAGE_DIR="$SCRIPT_DIR/manage"
fi
ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"
DEV_TEMPLATE_SCRIPT="$MANAGE_DIR/dev-template.sh"

# Source component scanner library
LIB_DIR="$ADDITIONS_DIR/lib"
if [[ -f "$LIB_DIR/component-scanner.sh" ]]; then
    source "$LIB_DIR/component-scanner.sh"
else
    echo "Error: component-scanner.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Source service auto-enable library for managing enabled-services.conf
if [[ -f "$LIB_DIR/service-auto-enable.sh" ]]; then
    source "$LIB_DIR/service-auto-enable.sh"
else
    echo "Error: service-auto-enable.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Source tool auto-enable library for managing enabled-tools.conf
if [[ -f "$LIB_DIR/tool-auto-enable.sh" ]]; then
    source "$LIB_DIR/tool-auto-enable.sh"
else
    echo "Error: tool-auto-enable.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Source categories library
if [[ -f "$LIB_DIR/categories.sh" ]]; then
    source "$LIB_DIR/categories.sh"
else
    echo "Error: categories.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Source prerequisite-check library
if [[ -f "$LIB_DIR/prerequisite-check.sh" ]]; then
    source "$LIB_DIR/prerequisite-check.sh"
else
    echo "Error: prerequisite-check.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Source tool-installation library for interactive tool installation
if [[ -f "$LIB_DIR/tool-installation.sh" ]]; then
    source "$LIB_DIR/tool-installation.sh"
else
    echo "Error: tool-installation.sh library not found at $LIB_DIR" >&2
    exit 1
fi

# Setup structured logging
# Create log directory and file for this session
LOG_DIR="${DEVCONTAINER_LOG_DIR:-/tmp/devcontainer-setup}"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/dev-setup-${TIMESTAMP}.log"
export CURRENT_LOG_FILE="$LOG_FILE"

# Logging functions for audit trail
log_action() {
    echo "[$(date +%H:%M:%S)] ACTION: $*" >> "$LOG_FILE"
}

log_user_choice() {
    local menu="$1"
    local choice="$2"
    echo "[$(date +%H:%M:%S)] USER: $menu -> $choice" >> "$LOG_FILE"
}

log_installation() {
    local tool="$1"
    local result="$2"
    echo "[$(date +%H:%M:%S)] INSTALL: $tool -> $result" >> "$LOG_FILE"
}

log_error_msg() {
    echo "[$(date +%H:%M:%S)] ERROR: $*" >> "$LOG_FILE"
}

log_info_msg() {
    echo "[$(date +%H:%M:%S)] INFO: $*" >> "$LOG_FILE"
}

# Error handling helpers
show_error() {
    local title="$1"
    local message="$2"

    log_error_msg "$title: $message"
    dialog --title "$title" --msgbox "$message" 12 70
    clear
}

show_warning() {
    local title="$1"
    local message="$2"

    log_info_msg "WARNING - $title: $message"
    dialog --title "$title" --msgbox "$message" 12 70
    clear
}

show_info() {
    local title="$1"
    local message="$2"

    log_info_msg "$title: $message"
    dialog --title "$title" --msgbox "$message" 12 70
    clear
}

# Log session start
log_action "dev-setup session started by $(whoami)"
log_info_msg "Log file: $LOG_FILE"

# Build category display name mapping from library
declare -A CATEGORIES
while IFS= read -r category_key; do
    CATEGORIES[$category_key]=$(get_category_display_name "$category_key")
done < <(get_all_category_ids)
# Add UNCATEGORIZED
CATEGORIES["UNCATEGORIZED"]="Other Tools"

# Global arrays for tools
declare -a AVAILABLE_TOOLS=()
declare -a TOOL_SCRIPTS=()
declare -a TOOL_DESCRIPTIONS=()
declare -a TOOL_CATEGORIES=()

# Category organization
declare -A TOOLS_BY_CATEGORY  # Maps category to comma-separated tool indices
declare -A CATEGORY_COUNTS     # Maps category to tool count

# Global arrays for services
declare -a AVAILABLE_SERVICES=()
declare -a SERVICE_SCRIPTS=()
declare -a SERVICE_IDS=()
declare -a SERVICE_DESCRIPTIONS=()
declare -a SERVICE_CATEGORIES=()
declare -a SERVICE_PRIORITIES=()
declare -a SERVICE_DEPENDS=()
declare -a SERVICE_PREREQUISITE_CONFIGS=()
declare -a SERVICE_PREREQUISITE_TOOLS=()

# Service category organization
declare -A SERVICES_BY_CATEGORY  # Maps category to comma-separated service indices
declare -A SERVICE_CATEGORY_COUNTS  # Maps category to service count

# Global arrays for configs
declare -a AVAILABLE_CONFIGS=()
declare -a CONFIG_SCRIPTS=()
declare -a CONFIG_DESCRIPTIONS=()
declare -a CONFIG_CATEGORIES=()
declare -a CONFIG_CHECK_COMMANDS=()

# Config category organization
declare -A CONFIGS_BY_CATEGORY  # Maps category to comma-separated config indices
declare -A CONFIG_CATEGORY_COUNTS  # Maps category to config count

# Global arrays for manage scripts (dev-*.sh in manage directory)
declare -a AVAILABLE_MANAGE_SCRIPTS=()
declare -a MANAGE_SCRIPT_BASENAMES=()
declare -a MANAGE_SCRIPT_IDS=()
declare -a MANAGE_SCRIPT_NAMES=()
declare -a MANAGE_SCRIPT_DESCRIPTIONS=()
declare -a MANAGE_SCRIPT_CATEGORIES=()

# Manage script category organization
declare -A MANAGE_BY_CATEGORY  # Maps category to comma-separated script indices
declare -A MANAGE_CATEGORY_COUNTS  # Maps category to script count

# Whiptail dimensions
DIALOG_HEIGHT=20
DIALOG_WIDTH=80
MENU_HEIGHT=12

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    dev-setup [OPTIONS]

OPTIONS:
    --help          Show this help message
    --version       Show version information

DESCRIPTION:
    Simple setup script for development environment tools and project templates.
    Uses dialog for a clean, user-friendly interface with live descriptions.

EOF
}

show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

# Check if dialog is available
check_dialog() {
    if ! command -v dialog >/dev/null 2>&1; then
        echo "❌ Error: dialog is not installed"
        echo ""
        echo "Please install dialog first:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install dialog"
        echo ""
        exit 2
    fi
}

# Check if we're in a devcontainer project
check_environment() {
    local errors=0

    # Check dialog
    if ! check_dialog; then
        ((errors++))
    fi

    # Check devcontainer directory
    if [[ ! -d "$DEVCONTAINER_DIR" ]]; then
        echo "ERROR: Devcontainer directory not found: $DEVCONTAINER_DIR" >&2
        log_error_msg "Devcontainer directory not found: $DEVCONTAINER_DIR"
        ((errors++))
    fi

    # Check additions directory
    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        echo "ERROR: Additions directory not found: $ADDITIONS_DIR" >&2
        log_error_msg "Additions directory not found: $ADDITIONS_DIR"
        ((errors++))
    fi

    # Check required libraries
    local required_libs=(
        "component-scanner.sh"
        "service-auto-enable.sh"
        "categories.sh"
        "prerequisite-check.sh"
    )

    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$LIB_DIR/$lib" ]]; then
            echo "ERROR: Required library not found: $lib" >&2
            log_error_msg "Required library not found: $lib"
            ((errors++))
        fi
    done

    # Check enabled config files (warnings only)
    if [[ ! -f "/workspace/.devcontainer.extend/enabled-tools.conf" ]]; then
        log_info_msg "enabled-tools.conf not found (will be created if needed)"
    fi

    if [[ ! -f "/workspace/.devcontainer.extend/enabled-services.conf" ]]; then
        log_info_msg "enabled-services.conf not found (will be created if needed)"
    fi

    if [[ $errors -gt 0 ]]; then
        echo ""
        echo "Environment check failed with $errors error(s)" >&2
        log_error_msg "Environment check failed with $errors error(s)"
        if command -v dialog >/dev/null 2>&1; then
            dialog --title "Environment Error" \
                --msgbox "Environment validation failed with $errors error(s).\n\nPlease check that you are running this script from a devcontainer project with all required libraries installed.\n\nSee terminal output for details." \
                15 70
            clear
        fi
        exit 2
    fi

    log_info_msg "Environment check passed"
    return 0
}

#------------------------------------------------------------------------------
# Tool discovery and management
#------------------------------------------------------------------------------

scan_available_tools() {
    AVAILABLE_TOOLS=()
    TOOL_SCRIPTS=()
    TOOL_DESCRIPTIONS=()
    TOOL_CATEGORIES=()

    # Reset category organization
    TOOLS_BY_CATEGORY=()
    CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Tools directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan install scripts
    # Output format: script_basename<TAB>SCRIPT_ID<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>SCRIPT_CHECK_COMMAND<TAB>SCRIPT_PREREQUISITES
    while IFS=$'\t' read -r script_basename script_id script_name script_description script_category check_command prerequisite_configs; do
        # Add to arrays
        AVAILABLE_TOOLS+=("$script_name")
        TOOL_SCRIPTS+=("$script_basename")
        TOOL_DESCRIPTIONS+=("$script_description")
        TOOL_CATEGORIES+=("$script_category")

        # Track tool index by category
        local tool_index=$found
        if [[ -n "${TOOLS_BY_CATEGORY[$script_category]}" ]]; then
            TOOLS_BY_CATEGORY[$script_category]="${TOOLS_BY_CATEGORY[$script_category]},$tool_index"
        else
            TOOLS_BY_CATEGORY[$script_category]="$tool_index"
        fi

        # Increment category count
        CATEGORY_COUNTS[$script_category]=$((${CATEGORY_COUNTS[$script_category]:-0} + 1))

        ((found++))
    done < <(scan_install_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Tools Found" --msgbox "No development tools found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Service discovery and management
#------------------------------------------------------------------------------

scan_available_services() {
    AVAILABLE_SERVICES=()
    SERVICE_SCRIPTS=()
    SERVICE_IDS=()
    SERVICE_DESCRIPTIONS=()
    SERVICE_CATEGORIES=()
    SERVICE_PRIORITIES=()
    SERVICE_DEPENDS=()
    SERVICE_PREREQUISITE_CONFIGS=()
    SERVICE_PREREQUISITE_TOOLS=()

    # Reset category organization
    SERVICES_BY_CATEGORY=()
    SERVICE_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Services directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Scan for service-*.sh scripts
    while IFS=$'\t' read -r script_basename service_name service_description service_category script_path prerequisite_configs; do
        # Extract additional metadata for enable/disable and ordering
        local service_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")
        local service_priority=$(extract_service_script_metadata "$script_path" "SERVICE_PRIORITY")
        local service_depends=$(extract_service_script_metadata "$script_path" "SERVICE_DEPENDS")
        local prerequisite_tools=$(extract_service_script_metadata "$script_path" "SERVICE_PREREQUISITE_TOOLS")

        # Default priority if not set
        if [[ -z "$service_priority" ]]; then
            service_priority="99"
        fi

        # Add to arrays
        AVAILABLE_SERVICES+=("$service_name")
        SERVICE_SCRIPTS+=("$script_basename")
        SERVICE_IDS+=("$service_id")
        SERVICE_DESCRIPTIONS+=("$service_description")
        SERVICE_CATEGORIES+=("$service_category")
        SERVICE_PRIORITIES+=("$service_priority")
        SERVICE_DEPENDS+=("$service_depends")
        SERVICE_PREREQUISITE_CONFIGS+=("$prerequisite_configs")
        SERVICE_PREREQUISITE_TOOLS+=("$prerequisite_tools")

        # Track service index by category
        local service_index=$found
        if [[ -n "${SERVICES_BY_CATEGORY[$service_category]}" ]]; then
            SERVICES_BY_CATEGORY[$service_category]="${SERVICES_BY_CATEGORY[$service_category]},$service_index"
        else
            SERVICES_BY_CATEGORY[$service_category]="$service_index"
        fi

        # Increment category count
        SERVICE_CATEGORY_COUNTS[$service_category]=$((${SERVICE_CATEGORY_COUNTS[$service_category]:-0} + 1))

        ((found++))
    done < <(scan_service_scripts_new "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Services Found" --msgbox "No services found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Config discovery and management
#------------------------------------------------------------------------------

scan_available_configs() {
    AVAILABLE_CONFIGS=()
    CONFIG_SCRIPTS=()
    CONFIG_DESCRIPTIONS=()
    CONFIG_CATEGORIES=()
    CONFIG_CHECK_COMMANDS=()

    # Reset category organization
    CONFIGS_BY_CATEGORY=()
    CONFIG_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Configs directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan config scripts
    while IFS=$'\t' read -r script_basename config_name config_description config_category check_command; do
        # Add to arrays
        AVAILABLE_CONFIGS+=("$config_name")
        CONFIG_SCRIPTS+=("$script_basename")
        CONFIG_DESCRIPTIONS+=("$config_description")
        CONFIG_CATEGORIES+=("$config_category")
        CONFIG_CHECK_COMMANDS+=("$check_command")

        # Track config index by category
        local config_index=$found
        if [[ -n "${CONFIGS_BY_CATEGORY[$config_category]}" ]]; then
            CONFIGS_BY_CATEGORY[$config_category]="${CONFIGS_BY_CATEGORY[$config_category]},$config_index"
        else
            CONFIGS_BY_CATEGORY[$config_category]="$config_index"
        fi

        # Increment category count
        CONFIG_CATEGORY_COUNTS[$config_category]=$((${CONFIG_CATEGORY_COUNTS[$config_category]:-0} + 1))

        ((found++))
    done < <(scan_config_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Configurations Found" --msgbox "No configuration scripts found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
}

check_config_configured() {
    local config_index=$1
    # Delegate to unified status checking function
    check_config_status "$config_index"
    return $?
}

#------------------------------------------------------------------------------
# CMD script discovery and management
#------------------------------------------------------------------------------

scan_available_cmds() {
    AVAILABLE_CMDS=()
    CMD_SCRIPTS=()
    CMD_DESCRIPTIONS=()
    CMD_CATEGORIES=()
    CMD_SCRIPT_PATHS=()
    CMD_PREREQUISITE_CONFIGS=()

    # Reset category organization
    CMDS_BY_CATEGORY=()
    CMD_CATEGORY_COUNTS=()

    if [[ ! -d "$ADDITIONS_DIR" ]]; then
        dialog --title "Error" --msgbox "Commands directory not found: $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    local found=0

    # Use library to scan cmd scripts
    while IFS=$'\t' read -r script_basename cmd_name cmd_description cmd_category script_path prerequisite_configs; do
        # Add to arrays
        AVAILABLE_CMDS+=("$cmd_name")
        CMD_SCRIPTS+=("$script_basename")
        CMD_DESCRIPTIONS+=("$cmd_description")
        CMD_CATEGORIES+=("$cmd_category")
        CMD_SCRIPT_PATHS+=("$script_path")
        CMD_PREREQUISITE_CONFIGS+=("$prerequisite_configs")

        # Track cmd index by category
        local cmd_index=$found
        if [[ -n "${CMDS_BY_CATEGORY[$cmd_category]}" ]]; then
            CMDS_BY_CATEGORY[$cmd_category]="${CMDS_BY_CATEGORY[$cmd_category]},$cmd_index"
        else
            CMDS_BY_CATEGORY[$cmd_category]="$cmd_index"
        fi

        # Increment category count
        CMD_CATEGORY_COUNTS[$cmd_category]=$((${CMD_CATEGORY_COUNTS[$cmd_category]:-0} + 1))

        ((found++))
    done < <(scan_cmd_scripts "$ADDITIONS_DIR")

    if [[ $found -eq 0 ]]; then
        dialog --title "No Command Scripts Found" --msgbox "No command scripts found in $ADDITIONS_DIR" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Manage script discovery (dev-*.sh in manage directory)
#------------------------------------------------------------------------------

scan_available_manage_scripts() {
    AVAILABLE_MANAGE_SCRIPTS=()
    MANAGE_SCRIPT_BASENAMES=()
    MANAGE_SCRIPT_IDS=()
    MANAGE_SCRIPT_NAMES=()
    MANAGE_SCRIPT_DESCRIPTIONS=()
    MANAGE_SCRIPT_CATEGORIES=()

    # Reset category organization
    MANAGE_BY_CATEGORY=()
    MANAGE_CATEGORY_COUNTS=()

    if [[ ! -d "$MANAGE_DIR" ]]; then
        return 1
    fi

    local found=0

    # Use library to scan manage scripts
    # Output format: script_basename<TAB>SCRIPT_ID<TAB>SCRIPT_NAME<TAB>SCRIPT_DESCRIPTION<TAB>SCRIPT_CATEGORY<TAB>SCRIPT_CHECK_COMMAND
    while IFS=$'\t' read -r script_basename script_id script_name script_description script_category check_command; do
        # Add to arrays
        AVAILABLE_MANAGE_SCRIPTS+=("$script_name")
        MANAGE_SCRIPT_BASENAMES+=("$script_basename")
        MANAGE_SCRIPT_IDS+=("$script_id")
        MANAGE_SCRIPT_NAMES+=("$script_name")
        MANAGE_SCRIPT_DESCRIPTIONS+=("$script_description")
        MANAGE_SCRIPT_CATEGORIES+=("$script_category")

        # Track script index by category
        local script_index=$found
        if [[ -n "${MANAGE_BY_CATEGORY[$script_category]}" ]]; then
            MANAGE_BY_CATEGORY[$script_category]="${MANAGE_BY_CATEGORY[$script_category]},$script_index"
        else
            MANAGE_BY_CATEGORY[$script_category]="$script_index"
        fi

        # Increment category count
        MANAGE_CATEGORY_COUNTS[$script_category]=$((${MANAGE_CATEGORY_COUNTS[$script_category]:-0} + 1))

        ((found++))
    done < <(scan_manage_scripts "$MANAGE_DIR")

    return 0
}

#------------------------------------------------------------------------------
# Service category menu
#------------------------------------------------------------------------------

show_service_category_menu() {
    local menu_options=()
    local option_num=1

    # Build menu with categories that have services, in order
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${SERVICE_CATEGORY_COUNTS[$category_key]:-0}

        # Skip empty categories
        if [[ $count -eq 0 ]]; then
            continue
        fi

        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count service(s) available in this category"

        menu_options+=("$option_num" "$category_name" "$help_text")
        ((option_num++))
    done

    # If no services found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Services" --msgbox "No services found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Service Management - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Map choice back to category key
    local selected_index=1
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${SERVICE_CATEGORY_COUNTS[$category_key]:-0}
        if [[ $count -eq 0 ]]; then
            continue
        fi

        if [[ $selected_index -eq $choice ]]; then
            echo "$category_key"
            return 0
        fi
        ((selected_index++))
    done

    return 1
}

#------------------------------------------------------------------------------
# Show all services in one menu with category emoji prefixes
#------------------------------------------------------------------------------

show_all_services_menu() {
    while true; do
        # Build menu with ALL services, grouped by category with emoji prefixes
        local menu_options=()
        local option_num=1
        declare -A MENU_TO_SERVICE_INDEX

        # Define category prefix mapping (using text since some emojis don't render in dialog)
        local -A CATEGORY_PREFIX=(
            ["AI_TOOLS"]="[AI]"
            ["LANGUAGE_DEV"]="[DEV]"
            ["INFRA_CONFIG"]="[INFRA]"
            ["DATA_ANALYTICS"]="[DATA]"
            ["UNCATEGORIZED"]="[OTHER]"
        )

        # Iterate through categories in order
        for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
            local service_indices="${SERVICES_BY_CATEGORY[$category_key]}"

            # Skip empty categories
            if [[ -z "$service_indices" ]]; then
                continue
            fi

            # Convert comma-separated indices to array
            IFS=',' read -ra INDICES <<< "$service_indices"

            # Add services from this category
            for service_index in "${INDICES[@]}"; do
                local service_name="${AVAILABLE_SERVICES[$service_index]}"
                local service_description="${SERVICE_DESCRIPTIONS[$service_index]}"
                local service_script="${SERVICE_SCRIPTS[$service_index]}"
                local prefix="${CATEGORY_PREFIX[$category_key]}"

                # Check if service is running
                local status_icon=""
                if bash "$ADDITIONS_DIR/$service_script" --is-running >/dev/null 2>&1; then
                    status_icon="✅ "
                else
                    status_icon="⏸️ "
                fi

                menu_options+=("$option_num" "$status_icon$prefix $service_name" "$service_description")
                MENU_TO_SERVICE_INDEX[$option_num]=$service_index
                ((option_num++))
            done
        done

        # If no services found
        if [[ ${#menu_options[@]} -eq 0 ]]; then
            dialog --title "No Services" --msgbox "No services found." $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Show service selection menu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Service Management" \
            --menu "Choose a service to manage (ESC to go back):\n\n✅=Running  ⏸️=Stopped" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Get the actual service index from the menu choice
        local selected_service_index=${MENU_TO_SERVICE_INDEX[$choice]}

        # Show service details and actions
        show_service_details_and_actions "$selected_service_index"
    done
}

#------------------------------------------------------------------------------
# Service prerequisite checking
#------------------------------------------------------------------------------

check_service_installation_prerequisites() {
    local service_index=$1
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local prerequisite_tools="${SERVICE_PREREQUISITE_TOOLS[$service_index]}"

    if [[ -z "$prerequisite_tools" ]]; then
        return 0  # No installation prerequisites
    fi

    # Check if install script exists
    local install_script="$ADDITIONS_DIR/$prerequisite_tools"
    if [[ ! -f "$install_script" ]]; then
        dialog --title "Installation Error" \
            --msgbox "ERROR: Installation script not found:\n$prerequisite_tools\n\nThis is a configuration error." \
            12 70
        clear
        return 1
    fi

    # Extract SCRIPT_CHECK_COMMAND from install script using library
    local check_command=$(extract_script_metadata "$install_script" "SCRIPT_CHECK_COMMAND")

    if [[ -z "$check_command" ]]; then
        # No check command means we can't validate installation
        return 0
    fi

    # Run the check command
    if eval "$check_command" >/dev/null 2>&1; then
        return 0  # Installed
    else
        # Not installed - offer to install
        dialog --title "Installation Required" \
            --yesno "$service_name requires installation first.\n\nThe following installation script must be run:\n  $prerequisite_tools\n\nWould you like to run the installation now?" \
            14 70
        local response=$?
        clear

        if [[ $response -eq 0 ]]; then
            # User said yes - run the install script
            clear
            echo "Running installation: $prerequisite_tools"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""

            bash "$install_script"
            local install_result=$?

            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            if [[ $install_result -eq 0 ]]; then
                echo ""
                read -p "Installation complete. Press Enter to continue..."
                return 0
            else
                echo ""
                read -p "Installation failed. Press Enter to continue..."
                return 1
            fi
        else
            # User said no
            return 1
        fi
    fi
}

#------------------------------------------------------------------------------
# Show service dependency visualization
#------------------------------------------------------------------------------

show_service_dependencies() {
    local service_index=$1
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local prerequisite_tools="${SERVICE_PREREQUISITE_TOOLS[$service_index]}"
    local prerequisite_configs="${SERVICE_PREREQUISITE_CONFIGS[$service_index]}"
    local service_depends="${SERVICE_DEPENDS[$service_index]}"
    local service_priority="${SERVICE_PRIORITIES[$service_index]}"

    local msg="Service Dependency Chain for: $service_name\n"
    msg+="Priority: $service_priority\n"
    msg+="\n"
    msg+="┌─────────────────────────────────────────────────────────┐\n"

    # Installation layer
    if [[ -n "$prerequisite_tools" ]]; then
        local install_script="$ADDITIONS_DIR/$prerequisite_tools"
        local status="✗ Not installed"

        if [[ -f "$install_script" ]]; then
            local check_command=$(extract_script_metadata "$install_script" "SCRIPT_CHECK_COMMAND")
            if [[ -n "$check_command" ]] && eval "$check_command" >/dev/null 2>&1; then
                status="✓ Installed"
            fi
        fi

        msg+="│ INSTALLATION LAYER                                      │\n"
        msg+="│   $prerequisite_tools\n"
        msg+="│   Status: $status\n"
        msg+="│                           ↓                             │\n"
    fi

    # Configuration layer
    if [[ -n "$prerequisite_configs" ]]; then
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"
        local status="✗ Not configured"

        if check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR" 2>/dev/null; then
            status="✓ Configured"
        fi

        msg+="│ CONFIGURATION LAYER                                     │\n"
        msg+="│   $prerequisite_configs\n"
        msg+="│   Status: $status\n"
        msg+="│                           ↓                             │\n"
    fi

    # Service layer (current service)
    local service_script="${SERVICE_SCRIPTS[$service_index]}"
    local service_status="⏸ Stopped"

    # Check if service is running
    if bash "$ADDITIONS_DIR/$service_script" --is-running >/dev/null 2>&1; then
        service_status="▶ Running"
    fi

    msg+="│ SERVICE LAYER (This Service)                            │\n"
    msg+="│   $service_script\n"
    msg+="│   Status: $service_status\n"

    # Runtime dependencies
    if [[ -n "$service_depends" ]]; then
        msg+="│                           ↓                             │\n"
        msg+="│ RUNTIME DEPENDENCIES                                    │\n"

        # service_depends might be comma-separated, but typically single
        local dep_status="✗ Not running"

        # Find the dependency service
        for i in "${!SERVICE_IDS[@]}"; do
            if [[ "${SERVICE_IDS[$i]}" == "$service_depends" || "${SERVICE_SCRIPTS[$i]}" == "$service_depends" ]]; then
                local dep_script="${SERVICE_SCRIPTS[$i]}"
                if bash "$ADDITIONS_DIR/$dep_script" --is-running >/dev/null 2>&1; then
                    dep_status="✓ Running"
                fi
                break
            fi
        done

        msg+="│   $service_depends\n"
        msg+="│   Status: $dep_status\n"
    fi

    msg+="└─────────────────────────────────────────────────────────┘\n"
    msg+="\n"
    msg+="Legend:\n"
    msg+="  ✓ = Ready/Running    ✗ = Not ready/Not running\n"
    msg+="  ▶ = Running          ⏸ = Stopped\n"

    dialog --title "Service Dependencies" \
        --msgbox "$msg" \
        30 65
    clear
}

#------------------------------------------------------------------------------
# Service submenu - Show commands from selected service-*.sh script
#------------------------------------------------------------------------------

show_service_submenu() {
    local service_index=$1
    local service_name="${AVAILABLE_SERVICES[$service_index]}"
    local script_name="${SERVICE_SCRIPTS[$service_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"
    local prerequisite_configs="${SERVICE_PREREQUISITE_CONFIGS[$service_index]}"

    # Check installation prerequisites first
    if ! check_service_installation_prerequisites "$service_index"; then
        return 1
    fi

    # Check configuration prerequisites
    if [[ -n "$prerequisite_configs" ]]; then
        # Source prerequisite-check library
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            # Show missing prerequisites
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot run $service_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
    fi

    while true; do
        # Extract SCRIPT_COMMANDS array from the script
        local commands=()
        while IFS= read -r cmd_def; do
            commands+=("$cmd_def")
        done < <(extract_service_commands "$script_path")

        if [[ ${#commands[@]} -eq 0 ]]; then
            dialog --title "No Commands" --msgbox "No commands found in $service_name" $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Build menu with category prefixes (like cmd-*.sh display)
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text" "$flag")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add special option to view dependencies
        local view_deps_num=$option_num
        menu_options+=("$view_deps_num" "[INFO] View Dependency Chain" "Show prerequisites and dependencies")
        ((option_num++))

        # Add back option
        menu_options+=("0" "Back to Service List" "")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "$service_name" \
            --menu "Select a command (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Handle view dependencies option
        if [[ $choice -eq $view_deps_num ]]; then
            show_service_dependencies "$service_index"
            continue
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_service_cmd_action "$script_path" "$action_def"
        fi
    done
}

#------------------------------------------------------------------------------
# Service details and actions
#------------------------------------------------------------------------------

show_service_details_and_actions() {
    local service_index=$1
    # Show service-*.sh SCRIPT_COMMANDS array menu
    show_service_submenu "$service_index"
}

execute_service_cmd_action() {
    local script_path="$1"
    local action_def="$2"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    local cmd_args=("$flag")

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Execute command
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Executing: $(basename "$script_path") ${cmd_args[*]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    bash "$script_path" "${cmd_args[@]}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Press Enter to continue..." -r
    clear
}

#------------------------------------------------------------------------------
# Manage auto-start services (enable/disable)
#------------------------------------------------------------------------------

manage_autostart_services() {
    while true; do
        # Build array of indices sorted by priority
        local -a sorted_indices=()
        for i in "${!AVAILABLE_SERVICES[@]}"; do
            sorted_indices+=("$i")
        done

        # Sort indices by priority (bubble sort for simplicity)
        local n=${#sorted_indices[@]}
        for ((i=0; i<n; i++)); do
            for ((j=0; j<n-i-1; j++)); do
                local idx1=${sorted_indices[$j]}
                local idx2=${sorted_indices[$j+1]}
                local p1=${SERVICE_PRIORITIES[$idx1]}
                local p2=${SERVICE_PRIORITIES[$idx2]}
                if [[ $p1 -gt $p2 ]]; then
                    # Swap
                    local temp=${sorted_indices[$j]}
                    sorted_indices[$j]=${sorted_indices[$j+1]}
                    sorted_indices[$j+1]=$temp
                fi
            done
        done

        # Build checklist with all services in priority order
        local checklist_options=()
        local option_num=1

        for i in "${sorted_indices[@]}"; do
            local service_name="${AVAILABLE_SERVICES[$i]}"
            local service_id="${SERVICE_IDS[$i]}"
            local service_priority="${SERVICE_PRIORITIES[$i]}"
            local prereq="${SERVICE_PREREQUISITE_CONFIGS[$i]}"

            # Build display name with priority
            local display_name="[P:$service_priority] $service_name"

            # Add prerequisite hint if any
            if [[ -n "$prereq" ]]; then
                display_name="$display_name (requires config)"
            fi

            # Check if service is auto-enabled
            local status="off"
            if is_auto_enabled "$service_id"; then
                status="on"
            fi

            checklist_options+=("$option_num" "$display_name" "$status")
            ((option_num++))
        done

        # Show checklist
        local selected
        selected=$(dialog --clear \
            --title "Manage Auto-Start Services" \
            --checklist "Select services to auto-start on container restart:\n\n[P:##] = Priority (lower numbers start first)\nSPACE=toggle  ENTER=save  ESC=cancel" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${checklist_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Process selections
        # First, disable all services
        for i in "${!AVAILABLE_SERVICES[@]}"; do
            local service_id="${SERVICE_IDS[$i]}"
            local service_name="${AVAILABLE_SERVICES[$i]}"

            if is_auto_enabled "$service_id"; then
                disable_service_autostart "$service_id" "$service_name" >/dev/null 2>&1
            fi
        done

        # Then, enable selected services
        for selection in $selected; do
            # Remove quotes from selection
            selection=$(echo "$selection" | tr -d '"')
            # Map selection back to actual service index using sorted_indices
            local sorted_index=$((selection - 1))
            local service_index=${sorted_indices[$sorted_index]}
            local service_id="${SERVICE_IDS[$service_index]}"
            local service_name="${AVAILABLE_SERVICES[$service_index]}"

            enable_service_autostart "$service_id" "$service_name" >/dev/null 2>&1
        done

        # Show success message
        dialog --title "Success" --msgbox "Auto-start services updated successfully!" 8 50
        clear

        return 0
    done
}

# Manage auto-install tools (similar to auto-start services)
manage_autoinstall_tools() {
    while true; do
        # Build checklist with all tools
        local checklist_options=()
        local option_num=1

        for i in "${!AVAILABLE_TOOLS[@]}"; do
            local tool_name="${AVAILABLE_TOOLS[$i]}"
            local tool_description="${TOOL_DESCRIPTIONS[$i]}"
            local script_name="${TOOL_SCRIPTS[$i]}"
            local script_path="$ADDITIONS_DIR/$script_name"

            # Extract tool ID
            local tool_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")

            # Build display name
            local display_name="$tool_name"

            # Check if tool is auto-enabled
            local status="off"
            if is_tool_auto_enabled "$tool_id"; then
                status="on"
            fi

            checklist_options+=("$option_num" "$display_name" "$status")
            ((option_num++))
        done

        # Show checklist
        local selected
        selected=$(dialog --clear \
            --title "Manage Auto-Install Tools" \
            --checklist "Select tools to auto-install on container build:\n\nSPACE=toggle  ENTER=save  ESC=cancel" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${checklist_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        log_user_choice "Manage Auto-Install Tools" "Updated selections: $selected"

        # Process selections
        # First, disable all tools
        for i in "${!AVAILABLE_TOOLS[@]}"; do
            local script_name="${TOOL_SCRIPTS[$i]}"
            local script_path="$ADDITIONS_DIR/$script_name"
            local tool_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")
            local tool_name="${AVAILABLE_TOOLS[$i]}"

            if is_tool_auto_enabled "$tool_id"; then
                disable_tool_autoinstall "$tool_id" "$tool_name" >/dev/null 2>&1
                log_info_msg "Disabled auto-install for: $tool_name ($tool_id)"
            fi
        done

        # Then, enable selected tools
        for selection in $selected; do
            # Remove quotes from selection
            selection=$(echo "$selection" | tr -d '"')
            # Map selection back to actual tool index
            local tool_index=$((selection - 1))
            local script_name="${TOOL_SCRIPTS[$tool_index]}"
            local script_path="$ADDITIONS_DIR/$script_name"
            local tool_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")
            local tool_name="${AVAILABLE_TOOLS[$tool_index]}"

            enable_tool_autoinstall "$tool_id" "$tool_name" >/dev/null 2>&1
            log_info_msg "Enabled auto-install for: $tool_name ($tool_id)"
        done

        # Show success message
        dialog --title "Success" --msgbox "Auto-install tools updated successfully!" 8 50
        clear
        log_action "Auto-install tools configuration updated"

        return 0
    done
}

#------------------------------------------------------------------------------
# Service management main function
#------------------------------------------------------------------------------

manage_services() {
    if ! scan_available_services; then
        return 1
    fi

    while true; do
        # Show service management menu
        local choice
        choice=$(dialog --clear \
            --title "Service Management" \
            --menu "Choose an option (ESC to return to main menu):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "1" "Start/Stop Services" \
            "2" "Manage Auto-Start Services" \
            "3" "Back to Main Menu" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        case $choice in
            1)
                # Show all services in one menu with emoji category prefixes
                show_all_services_menu
                ;;
            2)
                manage_autostart_services
                ;;
            3|"")
                return 0
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Config category menu
#------------------------------------------------------------------------------

show_config_category_menu() {
    local menu_options=()
    local option_num=1

    # Build menu with categories that have configs, in order
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CONFIG_CATEGORY_COUNTS[$category_key]:-0}

        # Skip empty categories
        if [[ $count -eq 0 ]]; then
            continue
        fi

        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count configuration(s) available in this category"

        menu_options+=("$option_num" "$category_name" "$help_text")
        ((option_num++))
    done

    # If no configs found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Configurations" --msgbox "No configurations found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Setup & Configuration - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Map choice back to category key
    local selected_index=1
    for category_key in "AI_TOOLS" "LANGUAGE_DEV" "INFRA_CONFIG" "DATA_ANALYTICS" "UNCATEGORIZED"; do
        local count=${CONFIG_CATEGORY_COUNTS[$category_key]:-0}
        if [[ $count -eq 0 ]]; then
            continue
        fi

        if [[ $selected_index -eq $choice ]]; then
            echo "$category_key"
            return 0
        fi
        ((selected_index++))
    done

    return 1
}

#------------------------------------------------------------------------------
# Configs in category menu
#------------------------------------------------------------------------------

show_configs_in_category() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"

    # Get config indices for this category
    local config_indices="${CONFIGS_BY_CATEGORY[$category_key]}"

    if [[ -z "$config_indices" ]]; then
        dialog --title "No Configurations" --msgbox "No configurations found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    while true; do
        # Build menu with configs in this category
        local menu_options=()
        local option_num=1

        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$config_indices"

        for config_index in "${INDICES[@]}"; do
            local config_name="${AVAILABLE_CONFIGS[$config_index]}"
            local config_description="${CONFIG_DESCRIPTIONS[$config_index]}"

            # Check if config is configured
            local status_icon="❌"
            if check_config_configured "$config_index"; then
                status_icon="✅"
            fi

            menu_options+=("$option_num" "$status_icon $config_name" "$config_description")
            ((option_num++))
        done

        # Show config selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Setup & Configuration - $category_name" \
            --menu "Choose a configuration to run (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC - go back to category menu)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Map choice to actual config index
        local selected_config_index=${INDICES[$((choice - 1))]}

        # Show config details and actions
        show_config_details_and_actions "$selected_config_index"
    done
}

#------------------------------------------------------------------------------
# Config details and actions
#------------------------------------------------------------------------------

show_config_details_and_actions() {
    local config_index=$1
    local config_name="${AVAILABLE_CONFIGS[$config_index]}"
    local config_description="${CONFIG_DESCRIPTIONS[$config_index]}"
    local script_name="${CONFIG_SCRIPTS[$config_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    # Try to extract SCRIPT_COMMANDS array from the script
    local commands=()
    while IFS= read -r cmd_def; do
        commands+=("$cmd_def")
    done < <(extract_script_commands "$script_path")

    # If no SCRIPT_COMMANDS array found, fall back to simple Configure/Back menu
    if [[ ${#commands[@]} -eq 0 ]]; then
        # Check if config is configured
        local is_configured=false
        if check_config_configured "$config_index"; then
            is_configured=true
        fi

        # Build menu based on current state
        local menu_options=()
        local status_text

        if [[ "$is_configured" = true ]]; then
            status_text="Status: Configured ✅"
            menu_options+=("1" "Reconfigure")
            menu_options+=("2" "Back to configuration list")
        else
            status_text="Status: Not configured ❌"
            menu_options+=("1" "Configure now")
            menu_options+=("2" "Back to configuration list")
        fi

        # Show config details with available actions
        local user_choice
        user_choice=$(dialog --clear \
            --title "Configuration: $config_name" \
            --menu "$config_description\n\n$status_text\n\nWhat would you like to do?" \
            $DIALOG_HEIGHT $DIALOG_WIDTH 6 \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Handle user choice
        if [[ $? -ne 0 ]]; then
            # User pressed ESC - go back
            return 0
        fi

        case $user_choice in
            1)
                execute_config_script "$config_index"
                ;;
            2|"")
                # Go back to config list
                ;;
        esac
        return 0
    fi

    # Show submenu with SCRIPT_COMMANDS (same pattern as show_tool_details_and_confirm)
    while true; do
        # Extract additional metadata for display
        local script_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")
        local script_ver=$(extract_script_metadata "$script_path" "SCRIPT_VER")

        # Check if configured
        local config_status="Not configured"
        if check_config_configured "$config_index"; then
            config_status="Configured"
        fi

        # Build info text for menu header
        local menu_text="ID: $script_id | Version: $script_ver | Status: $config_status\n\n$config_description"

        # Build menu with category prefixes
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to configuration list")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --title "$config_name" \
            --menu "$menu_text" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_config_action "$config_index" "$action_def"
        fi
    done
}

execute_config_script() {
    local config_index=$1
    local config_name="${AVAILABLE_CONFIGS[$config_index]}"
    local script_name="${CONFIG_SCRIPTS[$config_index]}"

    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running Configuration: $config_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local script_path="$ADDITIONS_DIR/$script_name"
    if [[ ! -f "$script_path" ]]; then
        echo "❌ Error: Configuration script not found: $script_path"
    else
        chmod +x "$script_path"
        if bash "$script_path"; then
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✅ Configuration completed: $config_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        else
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "❌ Configuration failed: $config_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..." -r
}

# Execute a config action based on the SCRIPT_COMMANDS array entry
# Similar to execute_tool_action() but for config scripts
# Handles empty flag (default action = run with no arguments)
execute_config_action() {
    local config_index=$1
    local action_def="$2"
    local config_name="${AVAILABLE_CONFIGS[$config_index]}"
    local script_name="${CONFIG_SCRIPTS[$config_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    # Build command arguments (empty flag = no arguments)
    local cmd_args=()
    if [[ -n "$flag" ]]; then
        cmd_args+=("$flag")
    fi

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Special handling for --help flag (show in dialog)
    if [[ "$flag" = "--help" ]]; then
        clear
        local help_output
        help_output=$("$script_path" --help 2>&1)
        dialog --title "$config_name - Help" \
            --msgbox "$help_output" \
            $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 0
    fi

    # Log the action
    local action_desc="${flag:-configure}"
    log_user_choice "Setup & Configuration" "Action: $config_name $action_desc"

    # Execute command
    clear
    if [[ -n "$flag" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Executing: $script_name ${cmd_args[*]}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Running Configuration: $config_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    echo ""

    # Make script executable and run
    chmod +x "$script_path"

    if "$script_path" "${cmd_args[@]}"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Command completed successfully"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Command failed"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    echo ""
    read -p "Press Enter to continue..." -r
    clear
}

#------------------------------------------------------------------------------
# CMD submenu - Show commands from selected script
#------------------------------------------------------------------------------

show_cmd_submenu() {
    local cmd_index=$1
    local cmd_name="${AVAILABLE_CMDS[$cmd_index]}"
    local script_path="${CMD_SCRIPT_PATHS[$cmd_index]}"
    local prerequisite_configs="${CMD_PREREQUISITE_CONFIGS[$cmd_index]}"

    # Check prerequisites first
    if [[ -n "$prerequisite_configs" ]]; then
        # Source prerequisite-check library
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            # Show missing prerequisites
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot run $cmd_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
    fi

    while true; do
        # Extract SCRIPT_COMMANDS array from the script
        local commands=()
        while IFS= read -r cmd_def; do
            commands+=("$cmd_def")
        done < <(extract_script_commands "$script_path")

        if [[ ${#commands[@]} -eq 0 ]]; then
            dialog --title "No Commands" --msgbox "No commands found in $cmd_name" $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Build menu with category prefixes (like services display)
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text" "$flag")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to Command Tools" "")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "$cmd_name" \
            --menu "Select a command (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_cmd_action "$script_path" "$action_def"
        fi
    done
}

execute_cmd_action() {
    local script_path="$1"
    local action_def="$2"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    local cmd_args=("$flag")

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Execute command
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Executing: $(basename "$script_path") ${cmd_args[*]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    "$script_path" "${cmd_args[@]}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Press Enter to continue..." -r
    clear
}

#------------------------------------------------------------------------------
# Config management main function
#------------------------------------------------------------------------------

manage_cmds() {
    if ! scan_available_cmds; then
        return 1
    fi

    while true; do
        # Build menu with all cmd scripts
        local menu_options=()
        local option_num=1

        for i in "${!AVAILABLE_CMDS[@]}"; do
            local cmd_name="${AVAILABLE_CMDS[$i]}"
            local cmd_description="${CMD_DESCRIPTIONS[$i]}"

            menu_options+=("$option_num" "$cmd_name" "$cmd_description")
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to Main Menu" "")

        # Show command scripts menu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Command Tools" \
            --menu "Select a command tool (ESC to return to main menu):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 ]]; then
            return 0
        fi

        # Convert choice to array index (choice 1 = index 0)
        local cmd_index=$((choice - 1))

        # Show command submenu for selected script
        show_cmd_submenu "$cmd_index"
    done
}

manage_configs() {
    if ! scan_available_configs; then
        return 1
    fi

    while true; do
        # Step 1: Show category menu
        local selected_category
        selected_category=$(show_config_category_menu)

        # If user cancelled or error, exit
        if [[ $? -ne 0 || -z "$selected_category" ]]; then
            return 0
        fi

        # Step 2: Show configs in selected category
        show_configs_in_category "$selected_category"
    done
}

#------------------------------------------------------------------------------
# Category menu
#------------------------------------------------------------------------------

show_category_menu() {
    local menu_options=()
    local option_num=1
    local -a displayed_categories=()

    # Build menu with categories that have tools, in order from library
    while IFS= read -r category_key; do
        local count=${CATEGORY_COUNTS[$category_key]:-0}

        # Skip empty categories
        if [[ $count -eq 0 ]]; then
            continue
        fi

        local category_name="${CATEGORIES[$category_key]}"
        local help_text="$count tool(s) available in this category"

        menu_options+=("$option_num" "$category_name" "$help_text")
        displayed_categories+=("$category_key")
        ((option_num++))
    done < <(get_all_category_ids)

    # Also check UNCATEGORIZED
    if [[ ${CATEGORY_COUNTS["UNCATEGORIZED"]:-0} -gt 0 ]]; then
        local count=${CATEGORY_COUNTS["UNCATEGORIZED"]}
        menu_options+=("$option_num" "${CATEGORIES["UNCATEGORIZED"]}" "$count tool(s) available in this category")
        displayed_categories+=("UNCATEGORIZED")
    fi

    # If no tools found in any category
    if [[ ${#menu_options[@]} -eq 0 ]]; then
        dialog --title "No Tools" --msgbox "No development tools found in any category." $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Show category selection menu with dynamic help
    local choice
    choice=$(dialog --clear \
        --item-help \
        --title "Tools - Select Category" \
        --menu "Choose a category (ESC to return to main menu):" \
        $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
        "${menu_options[@]}" \
        2>&1 >/dev/tty)

    # Check if user cancelled (ESC)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Map choice back to category key using our tracking array
    local selected_category="${displayed_categories[$((choice - 1))]}"
    if [[ -n "$selected_category" ]]; then
        echo "$selected_category"
        return 0
    fi

    return 1
}

#------------------------------------------------------------------------------
# Tools in category menu
#------------------------------------------------------------------------------

show_tools_in_category() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"
    
    # Get tool indices for this category
    local tool_indices="${TOOLS_BY_CATEGORY[$category_key]}"
    
    if [[ -z "$tool_indices" ]]; then
        dialog --title "No Tools" --msgbox "No tools found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi
    
    while true; do
        # Build menu with tools in this category
        local menu_options=()
        local option_num=1
        
        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$tool_indices"
        
        for tool_index in "${INDICES[@]}"; do
            local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
            local tool_description="${TOOL_DESCRIPTIONS[$tool_index]}"
            local tool_script="${TOOL_SCRIPTS[$tool_index]}"

            # Check if tool is installed
            local status_icon="❌"
            if check_tool_installed "$tool_script"; then
                status_icon="✅"
            fi

            menu_options+=("$option_num" "$status_icon $tool_name" "$tool_description")
            ((option_num++))
        done
        
        # Show tool selection menu with dynamic help
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "Tools - $category_name" \
            --menu "Choose a tool to install (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)
        
        # Check if user cancelled (ESC - go back to category menu)
        if [[ $? -ne 0 ]]; then
            return 0
        fi
        
        # Map choice to actual tool index
        local selected_tool_index=${INDICES[$((choice - 1))]}
        
        # Show tool details and confirm installation
        show_tool_details_and_confirm "$selected_tool_index"
    done
}

#------------------------------------------------------------------------------
# Tool installation
#------------------------------------------------------------------------------

install_tools() {
    if ! scan_available_tools; then
        return 1
    fi
    
    while true; do
        # Step 1: Show category menu
        local selected_category
        selected_category=$(show_category_menu)
        
        # If user cancelled or error, exit
        if [[ $? -ne 0 || -z "$selected_category" ]]; then
            return 0
        fi
        
        # Step 2: Show tools in selected category
        show_tools_in_category "$selected_category"
    done
}

# Show tool details and get user decision
# If the install script has a SCRIPT_COMMANDS array, shows a submenu with available actions
# Otherwise falls back to simple Install/Back menu
show_tool_details_and_confirm() {
    local tool_index=$1
    local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
    local tool_description="${TOOL_DESCRIPTIONS[$tool_index]}"
    local script_name="${TOOL_SCRIPTS[$tool_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    # Check prerequisites first
    local prerequisite_configs=$(extract_script_metadata "$script_path" "SCRIPT_PREREQUISITES")
    if [[ -n "$prerequisite_configs" ]]; then
        # Source prerequisite-check library
        source "$ADDITIONS_DIR/lib/prerequisite-check.sh"

        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            # Show missing prerequisites
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot run $tool_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
    fi

    # Try to extract SCRIPT_COMMANDS array from the script
    local commands=()
    while IFS= read -r cmd_def; do
        commands+=("$cmd_def")
    done < <(extract_script_commands "$script_path")

    # If no SCRIPT_COMMANDS array found, fall back to simple Install/Back menu
    if [[ ${#commands[@]} -eq 0 ]]; then
        local user_choice
        user_choice=$(dialog --clear \
            --title "Tool Details: $tool_name" \
            --menu "$tool_description\n\nWhat would you like to do?" \
            $DIALOG_HEIGHT $DIALOG_WIDTH 4 \
            "1" "Install this tool" \
            "2" "Back to tool list" \
            2>&1 >/dev/tty)

        case $user_choice in
            1)
                execute_tool_installation "$tool_index"
                ;;
            2|"")
                # Go back to tool list (do nothing, loop will continue)
                ;;
        esac
        return 0
    fi

    # Show submenu with SCRIPT_COMMANDS (same pattern as show_cmd_submenu)
    while true; do
        # Extract additional metadata for display
        local script_id=$(extract_script_metadata "$script_path" "SCRIPT_ID")
        local script_ver=$(extract_script_metadata "$script_path" "SCRIPT_VER")
        local check_command=$(extract_script_metadata "$script_path" "SCRIPT_CHECK_COMMAND")

        # Check if installed
        local install_status="Not installed"
        if [[ -n "$check_command" ]] && eval "$check_command" >/dev/null 2>&1; then
            install_status="Installed"
        fi

        # Build info text for menu header
        local menu_text="ID: $script_id | Version: $script_ver | Status: $install_status\n\n$tool_description"

        # Build menu with category prefixes
        # Note: Not using --item-help because empty flags cause dialog issues
        local menu_options=()
        local menu_actions=()
        local option_num=1

        for cmd_def in "${commands[@]}"; do
            IFS='|' read -r category flag description function requires_arg param_prompt <<< "$cmd_def"

            # Add command with category prefix
            local display_text="[$category] $description"
            menu_options+=("$option_num" "$display_text")
            menu_actions[$option_num]="$flag|$requires_arg|$param_prompt"
            ((option_num++))
        done

        # Add back option
        menu_options+=("0" "Back to tool list")

        # Show submenu
        local choice
        choice=$(dialog --clear \
            --title "$tool_name" \
            --menu "$menu_text" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Handle back option
        if [[ $choice -eq 0 || -z "$choice" ]]; then
            return 0
        fi

        # Execute selected command
        local action_def="${menu_actions[$choice]}"
        if [[ -n "$action_def" ]]; then
            execute_tool_action "$tool_index" "$action_def"
        fi
    done
}

# Execute a tool action based on the SCRIPT_COMMANDS array entry
# Similar to execute_cmd_action() but for install scripts
# Handles empty flag (default action = run with no arguments)
execute_tool_action() {
    local tool_index=$1
    local action_def="$2"
    local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
    local script_name="${TOOL_SCRIPTS[$tool_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    IFS='|' read -r flag requires_arg param_prompt <<< "$action_def"

    # Build command arguments (empty flag = no arguments)
    local cmd_args=()
    if [[ -n "$flag" ]]; then
        cmd_args+=("$flag")
    fi

    # Prompt for parameter if needed
    if [[ "$requires_arg" = "true" ]]; then
        local param_value
        param_value=$(dialog --clear \
            --title "Parameter Required" \
            --inputbox "$param_prompt:" \
            8 60 \
            2>&1 >/dev/tty)

        # Check if user cancelled
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        if [[ -n "$param_value" ]]; then
            cmd_args+=("$param_value")
        else
            dialog --msgbox "Parameter required - command cancelled" 6 40
            clear
            return 1
        fi
    fi

    # Special handling for --help flag (show in dialog)
    if [[ "$flag" = "--help" ]]; then
        clear
        local help_output
        help_output=$("$script_path" --help 2>&1)
        dialog --title "$tool_name - Help" \
            --msgbox "$help_output" \
            $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 0
    fi

    # Log the action
    local action_desc="${flag:-install}"
    log_user_choice "Browse & Install Tools" "Action: $tool_name $action_desc"

    # Execute command
    clear
    if [[ -n "$flag" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Executing: $script_name ${cmd_args[*]}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Installing: $tool_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    echo ""

    # Make script executable and run
    chmod +x "$script_path"

    if "$script_path" "${cmd_args[@]}"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Command completed successfully"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Command failed"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    echo ""
    read -p "Press Enter to continue..." -r
    clear
}

execute_tool_installation() {
    # Interactive wrapper for tool installation
    # Uses tool-installation.sh library functions for prerequisite checking
    # Keeps interactive elements (dialog, clear, read) for user experience
    local tool_index=$1
    local tool_name="${AVAILABLE_TOOLS[$tool_index]}"
    local script_name="${TOOL_SCRIPTS[$tool_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    log_user_choice "Browse & Install Tools" "Install: $tool_name ($script_name)"

    if [[ ! -f "$script_path" ]]; then
        log_error_msg "Installation script not found: $script_path"
        dialog --title "Error" --msgbox "Installation script not found: $script_path" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    # Check prerequisites before installing
    local prerequisite_configs=$(extract_script_metadata "$script_path" "SCRIPT_PREREQUISITES")
    if [[ -n "$prerequisite_configs" ]]; then
        log_info_msg "Checking prerequisites for $tool_name: $prerequisite_configs"
        if ! check_prerequisite_configs "$prerequisite_configs" "$ADDITIONS_DIR"; then
            local missing_msg=$(show_missing_prerequisites "$prerequisite_configs" "$ADDITIONS_DIR")
            log_error_msg "Prerequisites not met for $tool_name: $missing_msg"
            dialog --title "Prerequisites Not Met" \
                --msgbox "Cannot install $tool_name. Prerequisites not met:\n\n$missing_msg\n\nPlease configure required items first." \
                20 70
            clear
            return 1
        fi
        log_info_msg "Prerequisites met for $tool_name"
    fi

    # Clear screen and show installation
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Installing: $tool_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    log_installation "$script_name" "STARTING"

    # Make script executable and run it
    chmod +x "$script_path"

    if bash "$script_path"; then
        log_installation "$script_name" "SUCCESS"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Successfully installed: $tool_name"
        echo ""
        echo "ℹ️  This tool has been auto-enabled for this repo."
        echo "   It will automatically install on next container rebuild."
        echo "   To disable: Run 'dev-setup' → Manage Auto-Install Tools"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        log_installation "$script_name" "FAILED"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Failed to install: $tool_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Manage scripts menu (SYSTEM_COMMANDS and CONTRIBUTOR_TOOLS)
#------------------------------------------------------------------------------

# Show manage scripts in a category (SYSTEM_COMMANDS or CONTRIBUTOR_TOOLS)
# Scripts are executed directly (no submenu)
show_manage_scripts_menu() {
    local category_key=$1
    local category_name="${CATEGORIES[$category_key]}"

    # Scan manage scripts if not already done
    if [[ ${#AVAILABLE_MANAGE_SCRIPTS[@]} -eq 0 ]]; then
        scan_available_manage_scripts
    fi

    # Get script indices for this category
    local script_indices="${MANAGE_BY_CATEGORY[$category_key]}"

    if [[ -z "$script_indices" ]]; then
        dialog --title "No Scripts" --msgbox "No scripts found in category: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
        clear
        return 1
    fi

    while true; do
        # Build menu with scripts in this category
        local menu_options=()
        local option_num=1
        declare -A MENU_TO_SCRIPT_INDEX

        # Convert comma-separated indices to array
        IFS=',' read -ra INDICES <<< "$script_indices"

        for script_index in "${INDICES[@]}"; do
            local script_name="${MANAGE_SCRIPT_NAMES[$script_index]}"
            local script_description="${MANAGE_SCRIPT_DESCRIPTIONS[$script_index]}"
            local script_id="${MANAGE_SCRIPT_IDS[$script_index]}"

            # Skip dev-template in SYSTEM_COMMANDS menu (shown directly in main menu)
            if [[ "$category_key" == "SYSTEM_COMMANDS" && "$script_id" == "dev-template" ]]; then
                continue
            fi

            menu_options+=("$option_num" "$script_name" "$script_description")
            MENU_TO_SCRIPT_INDEX[$option_num]=$script_index
            ((option_num++))
        done

        # If no scripts to show (all filtered out)
        if [[ ${#menu_options[@]} -eq 0 ]]; then
            dialog --title "No Scripts" --msgbox "No scripts available in: $category_name" $DIALOG_HEIGHT $DIALOG_WIDTH
            clear
            return 1
        fi

        # Show script selection menu
        local choice
        choice=$(dialog --clear \
            --item-help \
            --title "$category_name" \
            --menu "Select a command to run (ESC to go back):" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "${menu_options[@]}" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC)
        if [[ $? -ne 0 ]]; then
            return 0
        fi

        # Get the actual script index from the menu choice
        local selected_script_index=${MENU_TO_SCRIPT_INDEX[$choice]}

        # Execute the manage script directly
        execute_manage_script "$selected_script_index"
    done
}

# Execute a manage script (dev-*.sh)
execute_manage_script() {
    local script_index=$1
    local script_name="${MANAGE_SCRIPT_NAMES[$script_index]}"
    local script_basename="${MANAGE_SCRIPT_BASENAMES[$script_index]}"
    local script_path="$MANAGE_DIR/$script_basename"

    log_user_choice "Manage Scripts" "Execute: $script_name ($script_basename)"

    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Running: $script_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ -f "$script_path" ]]; then
        chmod +x "$script_path"
        bash "$script_path"
    else
        echo "❌ Error: Script not found: $script_path"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "Press Enter to continue..." -r
    clear
}

#------------------------------------------------------------------------------
# Template management
#------------------------------------------------------------------------------

# Create project from template - calls dev-template.sh
create_project_from_template() {
    clear

    if [[ ! -f "$DEV_TEMPLATE_SCRIPT" ]]; then
        echo "❌ Error: dev-template.sh not found at $DEV_TEMPLATE_SCRIPT"
        echo ""
        read -p "Press Enter to return to menu..." -r
        return 1
    fi
    
    # Make script executable
    chmod +x "$DEV_TEMPLATE_SCRIPT"
    
    # Run dev-template.sh which handles everything:
    # - Clones templates from GitHub
    # - Shows categorized menu
    # - Processes selected template
    bash "$DEV_TEMPLATE_SCRIPT" --skip-update
    
    echo ""
    read -p "Press Enter to continue..." -r
}

#------------------------------------------------------------------------------
# Unified Status Checking Functions
#------------------------------------------------------------------------------

# Check if a tool is installed
# Args: tool_index (index in AVAILABLE_TOOLS array)
# Returns: 0 if installed, 1 if not
check_tool_status() {
    local tool_index=$1
    local script_name="${TOOL_SCRIPTS[$tool_index]}"
    local script_path="$ADDITIONS_DIR/$script_name"

    local check_command=$(extract_script_metadata "$script_path" "SCRIPT_CHECK_COMMAND")
    check_component_installed "$check_command"
    return $?
}

# Check if a service's installation prerequisites are met
# Args: service_index (index in AVAILABLE_SERVICES array)
# Returns: 0 if installed, 1 if not
check_service_installed() {
    local service_index=$1
    local prerequisite_tools="${SERVICE_PREREQUISITE_TOOLS[$service_index]}"

    if [[ -z "$prerequisite_tools" ]]; then
        return 0  # No prerequisites means service doesn't need installation
    fi

    local install_script="$ADDITIONS_DIR/$prerequisite_tools"
    if [[ ! -f "$install_script" ]]; then
        return 1  # Install script not found
    fi

    local check_command=$(extract_script_metadata "$install_script" "SCRIPT_CHECK_COMMAND")
    check_component_installed "$check_command"
    return $?
}

# Check if a config is configured
# Args: config_index (index in AVAILABLE_CONFIGS array)
# Returns: 0 if configured, 1 if not
check_config_status() {
    local config_index=$1
    local check_command="${CONFIG_CHECK_COMMANDS[$config_index]}"

    if [[ -z "$check_command" ]]; then
        return 1  # No check command means not configured
    fi

    eval "$check_command" 2>/dev/null
    return $?
}

# Legacy function for backwards compatibility - now calls check_tool_status
check_tool_installed() {
    local script_name="$1"

    # Find tool index by script name
    for i in "${!TOOL_SCRIPTS[@]}"; do
        if [[ "${TOOL_SCRIPTS[$i]}" == "$script_name" ]]; then
            check_tool_status "$i"
            return $?
        fi
    done

    # Fallback: extract metadata directly if not in array
    local script_path="$ADDITIONS_DIR/$script_name"
    local check_command=$(extract_script_metadata "$script_path" "SCRIPT_CHECK_COMMAND")
    check_component_installed "$check_command"
    return $?
}

#------------------------------------------------------------------------------
# Main menu and execution
#------------------------------------------------------------------------------

show_main_menu() {
    # Disable exit-on-error for interactive menus
    set +e

    # Scan manage scripts at startup for category menus
    scan_available_manage_scripts

    while true; do
        local choice
        choice=$(dialog --clear \
            --title "$SCRIPT_NAME v$SCRIPT_VERSION" \
            --menu "Choose an option:" \
            $DIALOG_HEIGHT $DIALOG_WIDTH $MENU_HEIGHT \
            "1" "Browse & Install Tools" \
            "2" "Create project from template" \
            "3" "System Commands" \
            "4" "Manage Services" \
            "5" "Setup & Configuration" \
            "6" "Command Tools" \
            "7" "Manage Auto-Install Tools" \
            "8" "Contributor Tools" \
            "9" "Exit" \
            2>&1 >/dev/tty)

        # Check if user cancelled (ESC or Cancel button)
        if [[ $? -ne 0 ]]; then
            if dialog --title "Confirm Exit" --yesno "Are you sure you want to exit?" 8 50; then
                clear
                echo ""
                echo "✅ Thanks for using $SCRIPT_NAME! 🚀"
                exit 0
            fi
            continue
        fi

        # Handle menu choice
        case $choice in
            1)
                install_tools
                ;;
            2)
                create_project_from_template
                ;;
            3)
                show_manage_scripts_menu "SYSTEM_COMMANDS"
                ;;
            4)
                manage_services
                ;;
            5)
                manage_configs
                ;;
            6)
                manage_cmds
                ;;
            7)
                log_user_choice "Main Menu" "Manage Auto-Install Tools"
                if ! scan_available_tools; then
                    dialog --title "Error" --msgbox "Failed to scan tools" 8 50
                    clear
                    continue
                fi
                manage_autoinstall_tools
                ;;
            8)
                show_manage_scripts_menu "CONTRIBUTOR_TOOLS"
                ;;
            9)
                clear
                echo ""
                echo "✅ Thanks for using $SCRIPT_NAME! 🚀"
                log_action "dev-setup session ended by user"
                exit 0
                ;;
            *)
                dialog --title "Error" --msgbox "Invalid selection: $choice" 8 50
                clear
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Main execution
#------------------------------------------------------------------------------

main() {
    # Parse command line arguments
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            show_version
            exit 0
            ;;
        "")
            # No arguments - run interactive mode
            ;;
        *)
            echo "❌ Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Check requirements and environment
    check_dialog
    check_environment
    
    # Start main menu
    show_main_menu
}

# Trap interrupts for clean exit
trap 'echo ""; echo "ℹ️  Operation cancelled by user"; exit 3' INT TERM

# Execute main function
main "$@"
