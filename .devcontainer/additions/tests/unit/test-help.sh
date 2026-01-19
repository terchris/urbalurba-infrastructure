#!/bin/bash
# file: .devcontainer/additions/tests/unit/test-help.sh
#
# DESCRIPTION: Tests that --help flag works on all scripts
# PURPOSE: Ensures scripts can display help without errors
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_scripts_help_execution() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")

        if bash "$script" --help >/dev/null 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - --help returned non-zero exit code"
            ((failed++))
        fi
    done

    return $failed
}

test_config_scripts_help_execution() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Config scripts may not have --help, skip if not present
        if grep -q '"\-\-help"\|= "--help"' "$script" 2>/dev/null; then
            if bash "$script" --help >/dev/null 2>&1; then
                echo "  ✓ $name"
            else
                echo "  ✗ $name - --help returned non-zero exit code"
                ((failed++))
            fi
        else
            echo "  ✓ $name (no --help handler)"
        fi
    done

    return $failed
}

test_cmd_scripts_help_execution() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "cmd-*.sh" "$filter"); do
        local name=$(basename "$script")

        if bash "$script" --help >/dev/null 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - --help returned non-zero exit code"
            ((failed++))
        fi
    done

    return $failed
}

test_service_scripts_help_execution() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "service-*.sh" "$filter"); do
        local name=$(basename "$script")

        if bash "$script" --help >/dev/null 2>&1; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - --help returned non-zero exit code"
            ((failed++))
        fi
    done

    return $failed
}

test_help_output_not_empty() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")
        local help_output

        help_output=$(bash "$script" --help 2>&1 || true)

        if [[ -n "$help_output" ]]; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - --help output is empty"
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

    run_test "Install scripts --help executes" test_install_scripts_help_execution "$filter"
    run_test "Config scripts --help executes" test_config_scripts_help_execution "$filter"
    run_test "Cmd scripts --help executes" test_cmd_scripts_help_execution "$filter"
    run_test "Service scripts --help executes" test_service_scripts_help_execution "$filter"
    run_test "Install scripts --help produces output" test_help_output_not_empty "$filter"
}

main "$@"
