#!/bin/bash
# file: .devcontainer/additions/tests/static/test-metadata.sh
#
# DESCRIPTION: Validates that all scripts have required metadata fields
# PURPOSE: Ensures scripts follow the template contracts for automatic discovery
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_scripts_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")
        local missing=""

        # Check required fields (all scripts use SCRIPT_* prefix)
        local script_id=$(grep -m 1 "^SCRIPT_ID=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_ver=$(grep -m 1 "^SCRIPT_VER=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_name=$(grep -m 1 "^SCRIPT_NAME=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_desc=$(grep -m 1 "^SCRIPT_DESCRIPTION=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)
        local check_cmd=$(grep -m 1 "^SCRIPT_CHECK_COMMAND=" "$script" 2>/dev/null | cut -d'"' -f2)

        [[ -z "$script_id" ]] && missing+="SCRIPT_ID "
        [[ -z "$script_ver" ]] && missing+="SCRIPT_VER "
        [[ -z "$script_name" ]] && missing+="SCRIPT_NAME "
        [[ -z "$script_desc" ]] && missing+="SCRIPT_DESCRIPTION "
        [[ -z "$script_cat" ]] && missing+="SCRIPT_CATEGORY "
        [[ -z "$check_cmd" ]] && missing+="SCRIPT_CHECK_COMMAND "

        # Check SCRIPT_COMMANDS array exists (for menu integration)
        if ! grep -q "^SCRIPT_COMMANDS=(" "$script" 2>/dev/null; then
            missing+="SCRIPT_COMMANDS "
        fi

        if [[ -n "$missing" ]]; then
            echo "  ✗ $name - missing: $missing"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

test_config_scripts_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")
        local missing=""

        # Check required fields (all scripts use SCRIPT_* prefix)
        local script_id=$(grep -m 1 "^SCRIPT_ID=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_name=$(grep -m 1 "^SCRIPT_NAME=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_ver=$(grep -m 1 "^SCRIPT_VER=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_desc=$(grep -m 1 "^SCRIPT_DESCRIPTION=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)
        local check_cmd=$(grep -m 1 "^SCRIPT_CHECK_COMMAND=" "$script" 2>/dev/null | cut -d'"' -f2)

        [[ -z "$script_id" ]] && missing+="SCRIPT_ID "
        [[ -z "$script_name" ]] && missing+="SCRIPT_NAME "
        [[ -z "$script_ver" ]] && missing+="SCRIPT_VER "
        [[ -z "$script_desc" ]] && missing+="SCRIPT_DESCRIPTION "
        [[ -z "$script_cat" ]] && missing+="SCRIPT_CATEGORY "
        [[ -z "$check_cmd" ]] && missing+="SCRIPT_CHECK_COMMAND "

        # Check SCRIPT_COMMANDS array exists (for menu integration)
        if ! grep -q "^SCRIPT_COMMANDS=(" "$script" 2>/dev/null; then
            missing+="SCRIPT_COMMANDS "
        fi

        if [[ -n "$missing" ]]; then
            echo "  ✗ $name - missing: $missing"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

test_service_scripts_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "service-*.sh" "$filter"); do
        local name=$(basename "$script")
        local missing=""

        # Check required fields (all scripts use SCRIPT_* prefix)
        local script_id=$(grep -m 1 "^SCRIPT_ID=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_name=$(grep -m 1 "^SCRIPT_NAME=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_ver=$(grep -m 1 "^SCRIPT_VER=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_desc=$(grep -m 1 "^SCRIPT_DESCRIPTION=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)
        local check_cmd=$(grep -m 1 "^SCRIPT_CHECK_COMMAND=" "$script" 2>/dev/null | cut -d'"' -f2)

        [[ -z "$script_id" ]] && missing+="SCRIPT_ID "
        [[ -z "$script_name" ]] && missing+="SCRIPT_NAME "
        [[ -z "$script_ver" ]] && missing+="SCRIPT_VER "
        [[ -z "$script_desc" ]] && missing+="SCRIPT_DESCRIPTION "
        [[ -z "$script_cat" ]] && missing+="SCRIPT_CATEGORY "
        [[ -z "$check_cmd" ]] && missing+="SCRIPT_CHECK_COMMAND "

        # Check SCRIPT_COMMANDS array exists
        if ! grep -q "^SCRIPT_COMMANDS=(" "$script" 2>/dev/null; then
            missing+="SCRIPT_COMMANDS "
        fi

        if [[ -n "$missing" ]]; then
            echo "  ✗ $name - missing: $missing"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

test_cmd_scripts_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "cmd-*.sh" "$filter"); do
        local name=$(basename "$script")
        local missing=""

        # Check required fields (all scripts use SCRIPT_* prefix)
        local script_id=$(grep -m 1 "^SCRIPT_ID=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_name=$(grep -m 1 "^SCRIPT_NAME=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_ver=$(grep -m 1 "^SCRIPT_VER=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_desc=$(grep -m 1 "^SCRIPT_DESCRIPTION=" "$script" 2>/dev/null | cut -d'"' -f2)
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)

        [[ -z "$script_id" ]] && missing+="SCRIPT_ID "
        [[ -z "$script_name" ]] && missing+="SCRIPT_NAME "
        [[ -z "$script_ver" ]] && missing+="SCRIPT_VER "
        [[ -z "$script_desc" ]] && missing+="SCRIPT_DESCRIPTION "
        [[ -z "$script_cat" ]] && missing+="SCRIPT_CATEGORY "

        # Check SCRIPT_COMMANDS array exists
        if ! grep -q "^SCRIPT_COMMANDS=(" "$script" 2>/dev/null; then
            missing+="SCRIPT_COMMANDS "
        fi

        if [[ -n "$missing" ]]; then
            echo "  ✗ $name - missing: $missing"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local filter="${1:-}"

    run_test "Install scripts have required metadata" test_install_scripts_metadata "$filter"
    run_test "Config scripts have required metadata" test_config_scripts_metadata "$filter"
    run_test "Service scripts have required metadata" test_service_scripts_metadata "$filter"
    run_test "Cmd scripts have required metadata" test_cmd_scripts_metadata "$filter"
}

main "$@"
