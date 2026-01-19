#!/bin/bash
# file: .devcontainer/additions/tests/static/test-flags.sh
#
# DESCRIPTION: Validates that scripts have required flag handlers
# PURPOSE: Ensures install scripts have --help and --uninstall, config scripts have --verify
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_scripts_help_flag() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check for --help handler (quoted or in case statement)
        if grep -q '"\-\-help"' "$script" 2>/dev/null || \
           grep -q "'\-\-help'" "$script" 2>/dev/null || \
           grep -q '\-\-help)' "$script" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - missing --help handler"
            ((failed++))
        fi
    done

    return $failed
}

test_install_scripts_uninstall_flag() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check for --uninstall handler (quoted or in case statement)
        if grep -q '"\-\-uninstall"' "$script" 2>/dev/null || \
           grep -q "'\-\-uninstall'" "$script" 2>/dev/null || \
           grep -q '\-\-uninstall)' "$script" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - missing --uninstall handler"
            ((failed++))
        fi
    done

    return $failed
}

test_config_scripts_verify_flag() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check for --verify handler (quoted or in case statement)
        if grep -q '"\-\-verify"' "$script" 2>/dev/null || \
           grep -q "'\-\-verify'" "$script" 2>/dev/null || \
           grep -q '\-\-verify)' "$script" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - missing --verify handler"
            ((failed++))
        fi
    done

    return $failed
}

test_cmd_scripts_help_flag() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "cmd-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check for --help handler (quoted, case statement, or via framework)
        if grep -q '"\-\-help"' "$script" 2>/dev/null || \
           grep -q "'\-\-help'" "$script" 2>/dev/null || \
           grep -q '\-\-help)' "$script" 2>/dev/null || \
           grep -q 'cmd_framework_parse_args' "$script" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - missing --help handler"
            ((failed++))
        fi
    done

    return $failed
}

test_service_scripts_help_flag() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "service-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check for --help handler (quoted, case statement, or via framework)
        if grep -q '"\-\-help"' "$script" 2>/dev/null || \
           grep -q "'\-\-help'" "$script" 2>/dev/null || \
           grep -q '\-\-help)' "$script" 2>/dev/null || \
           grep -q 'cmd_framework_parse_args' "$script" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name - missing --help handler"
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

    run_test "Install scripts have --help handler" test_install_scripts_help_flag "$filter"
    run_test "Install scripts have --uninstall handler" test_install_scripts_uninstall_flag "$filter"
    run_test "Config scripts have --verify handler" test_config_scripts_verify_flag "$filter"
    run_test "Cmd scripts have --help handler" test_cmd_scripts_help_flag "$filter"
    run_test "Service scripts have --help handler" test_service_scripts_help_flag "$filter"
}

main "$@"
