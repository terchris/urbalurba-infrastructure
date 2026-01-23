#!/bin/bash
# tool-installation.sh - Tool installation management for UIS
#
# Manages optional tools that can be installed in the UIS container.
# Pattern based on DCT tool-installation.sh

# Guard against multiple sourcing
[[ -n "${_UIS_TOOL_INSTALLATION_LOADED:-}" ]] && return 0
_UIS_TOOL_INSTALLATION_LOADED=1

# Determine script directory for sourcing siblings
_TOOL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$_TOOL_SCRIPT_DIR/logging.sh"
source "$_TOOL_SCRIPT_DIR/utilities.sh"
source "$_TOOL_SCRIPT_DIR/paths.sh"

# Note: TOOLS_DIR is set by paths.sh

# Built-in tools that are always available
BUILTIN_TOOLS="kubectl k9s helm ansible"

# Get all available tool IDs
# Output: Tool IDs, one per line
get_all_tool_ids() {
    local dir="${TOOLS_DIR}"

    # First list built-in tools
    for tool in $BUILTIN_TOOLS; do
        echo "$tool"
    done

    # Then list installable tools from tool scripts
    while IFS= read -r -d '' script; do
        [[ -f "$script" ]] || continue
        local basename
        basename=$(basename "$script")
        [[ "$basename" == install-*.sh ]] || continue

        local id=""
        while IFS= read -r line; do
            case "$line" in
                TOOL_ID=*)
                    id="${line#TOOL_ID=}"
                    id="${id//\"/}"
                    id="${id//\'/}"
                    break
                    ;;
            esac
        done < "$script"

        [[ -n "$id" ]] && echo "$id"
    done < <(find "$dir" -name "install-*.sh" -type f -print0 2>/dev/null)
}

# Find tool script by tool ID
# Usage: find_tool_script <tool_id>
# Output: Full path to script, or empty if not found
find_tool_script() {
    local tool_id="$1"
    local dir="${TOOLS_DIR}"

    # Check for install-<tool_id>.sh
    local script="$dir/install-${tool_id}.sh"
    if [[ -f "$script" ]]; then
        echo "$script"
        return 0
    fi

    # Search all scripts for matching TOOL_ID
    while IFS= read -r -d '' script; do
        [[ -f "$script" ]] || continue

        local id=""
        while IFS= read -r line; do
            case "$line" in
                TOOL_ID=*)
                    id="${line#TOOL_ID=}"
                    id="${id//\"/}"
                    id="${id//\'/}"
                    break
                    ;;
            esac
        done < "$script"

        if [[ "$id" == "$tool_id" ]]; then
            echo "$script"
            return 0
        fi
    done < <(find "$dir" -name "install-*.sh" -type f -print0 2>/dev/null)

    return 1
}

# Get tool metadata
# Usage: get_tool_value <tool_id> <field_name>
get_tool_value() {
    local tool_id="$1"
    local field_name="$2"

    # Built-in tools have predefined metadata
    case "$tool_id" in
        kubectl)
            case "$field_name" in
                TOOL_NAME) echo "kubectl" ;;
                TOOL_DESCRIPTION) echo "Kubernetes command-line interface" ;;
                TOOL_CATEGORY) echo "BUILTIN" ;;
                TOOL_CHECK_COMMAND) echo "command -v kubectl" ;;
            esac
            return 0
            ;;
        k9s)
            case "$field_name" in
                TOOL_NAME) echo "k9s" ;;
                TOOL_DESCRIPTION) echo "Kubernetes TUI manager" ;;
                TOOL_CATEGORY) echo "BUILTIN" ;;
                TOOL_CHECK_COMMAND) echo "command -v k9s" ;;
            esac
            return 0
            ;;
        helm)
            case "$field_name" in
                TOOL_NAME) echo "Helm" ;;
                TOOL_DESCRIPTION) echo "Kubernetes package manager" ;;
                TOOL_CATEGORY) echo "BUILTIN" ;;
                TOOL_CHECK_COMMAND) echo "command -v helm" ;;
            esac
            return 0
            ;;
        ansible)
            case "$field_name" in
                TOOL_NAME) echo "Ansible" ;;
                TOOL_DESCRIPTION) echo "Infrastructure automation" ;;
                TOOL_CATEGORY) echo "BUILTIN" ;;
                TOOL_CHECK_COMMAND) echo "command -v ansible-playbook" ;;
            esac
            return 0
            ;;
    esac

    # For installable tools, read from script
    local script
    script=$(find_tool_script "$tool_id")
    [[ -z "$script" ]] && return 1

    local value=""
    while IFS= read -r line; do
        case "$line" in
            "${field_name}"=*)
                value="${line#${field_name}=}"
                value="${value//\"/}"
                value="${value//\'/}"
                break
                ;;
        esac
    done < "$script"

    echo "$value"
}

# Check if a tool is installed
# Usage: is_tool_installed <tool_id>
# Returns: 0 if installed, 1 if not
is_tool_installed() {
    local tool_id="$1"
    local check_cmd
    check_cmd=$(get_tool_value "$tool_id" "TOOL_CHECK_COMMAND")

    [[ -z "$check_cmd" ]] && return 1

    eval "$check_cmd" >/dev/null 2>&1
}

# Check if a tool is built-in (always available)
# Usage: is_builtin_tool <tool_id>
is_builtin_tool() {
    local tool_id="$1"
    [[ " $BUILTIN_TOOLS " == *" $tool_id "* ]]
}

# Install a tool
# Usage: install_tool <tool_id>
install_tool() {
    local tool_id="$1"

    # Can't install built-in tools
    if is_builtin_tool "$tool_id"; then
        log_info "$tool_id is a built-in tool (always available)"
        return 0
    fi

    # Check if already installed
    if is_tool_installed "$tool_id"; then
        log_warn "$tool_id is already installed"
        return 0
    fi

    local script
    script=$(find_tool_script "$tool_id")
    if [[ -z "$script" ]]; then
        log_error "Tool '$tool_id' not found"
        return 1
    fi

    local tool_name
    tool_name=$(get_tool_value "$tool_id" "TOOL_NAME")
    tool_name="${tool_name:-$tool_id}"

    log_info "Installing $tool_name..."

    # Source the script and call install_tool function
    (
        source "$script"
        if type do_install &>/dev/null; then
            do_install
        else
            log_error "Script $script does not define do_install function"
            exit 1
        fi
    )

    local status=$?
    if [[ $status -eq 0 ]]; then
        # Verify installation
        if is_tool_installed "$tool_id"; then
            log_success "$tool_name installed successfully"
            return 0
        else
            log_error "$tool_name installation completed but verification failed"
            return 1
        fi
    else
        log_error "Failed to install $tool_name"
        return 1
    fi
}

# List all tools with status
# Output: Formatted table of tools
list_tools() {
    printf "%-15s %-25s %-10s %s\n" "ID" "NAME" "STATUS" "DESCRIPTION"
    echo "───────────────────────────────────────────────────────────────────────"

    local tool_id
    for tool_id in $(get_all_tool_ids | sort -u); do
        local name desc status_icon
        name=$(get_tool_value "$tool_id" "TOOL_NAME")
        name="${name:-$tool_id}"
        desc=$(get_tool_value "$tool_id" "TOOL_DESCRIPTION")

        if is_tool_installed "$tool_id"; then
            status_icon="✅ Installed"
        else
            status_icon="❌ Not installed"
        fi

        # Add (built-in) marker
        if is_builtin_tool "$tool_id"; then
            status_icon="✅ Built-in"
        fi

        printf "%-15s %-25s %-10s %s\n" "$tool_id" "${name:0:25}" "$status_icon" "${desc:0:30}"
    done
}
