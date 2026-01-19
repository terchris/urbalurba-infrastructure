#!/bin/bash
# file: .devcontainer/additions/tests/static/test-syntax.sh
#
# DESCRIPTION: Validates bash syntax for all shell scripts
# PURPOSE: Catches syntax errors before execution
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_scripts_syntax() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")
        if bash -n "$script" 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - syntax error"
            ((failed++))
        fi
    done

    return $failed
}

test_config_scripts_syntax() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")
        if bash -n "$script" 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - syntax error"
            ((failed++))
        fi
    done

    return $failed
}

test_service_scripts_syntax() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "service-*.sh" "$filter"); do
        local name=$(basename "$script")
        if bash -n "$script" 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - syntax error"
            ((failed++))
        fi
    done

    return $failed
}

test_cmd_scripts_syntax() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "cmd-*.sh" "$filter"); do
        local name=$(basename "$script")
        if bash -n "$script" 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - syntax error"
            ((failed++))
        fi
    done

    return $failed
}

test_lib_scripts_syntax() {
    local filter="${1:-}"
    local failed=0

    for script in "$ADDITIONS_DIR"/lib/*.sh; do
        [[ ! -f "$script" ]] && continue

        if [[ -n "$filter" ]] && [[ "$(basename "$script")" != "$filter" ]]; then
            continue
        fi

        local name="lib/$(basename "$script")"
        if bash -n "$script" 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - syntax error"
            ((failed++))
        fi
    done

    return $failed
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local filter="${1:-}"

    run_test "Install scripts syntax (bash -n)" test_install_scripts_syntax "$filter"
    run_test "Config scripts syntax (bash -n)" test_config_scripts_syntax "$filter"
    run_test "Service scripts syntax (bash -n)" test_service_scripts_syntax "$filter"
    run_test "Cmd scripts syntax (bash -n)" test_cmd_scripts_syntax "$filter"
    run_test "Library scripts syntax (bash -n)" test_lib_scripts_syntax "$filter"
}

main "$@"
