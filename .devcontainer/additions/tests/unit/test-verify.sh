#!/bin/bash
# file: .devcontainer/additions/tests/unit/test-verify.sh
#
# DESCRIPTION: Tests that --verify flag works on config scripts
# PURPOSE: Ensures config scripts can restore from .devcontainer.secrets non-interactively
#
# NOTE: --verify is expected to return 1 if no backup exists in .devcontainer.secrets
#       This is normal behavior, not an error
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_config_scripts_verify_execution() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Run --verify and capture exit code
        # Exit 0 = restored successfully
        # Exit 1 = no backup found (normal, not an error)
        # Exit 2+ = actual error

        local exit_code=0
        bash "$script" --verify >/dev/null 2>&1 || exit_code=$?

        if [[ $exit_code -gt 1 ]]; then
            echo "  ✗ $name - --verify returned exit code $exit_code (expected 0 or 1)"
            ((failed++))
        else
            echo "  ✓ $name (exit code: $exit_code)"
        fi
    done

    return $failed
}

test_config_scripts_verify_no_prompt() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Run --verify with stdin closed (no input possible)
        # Should complete without hanging
        local exit_code=0
        timeout 5s bash "$script" --verify </dev/null >/dev/null 2>&1 || exit_code=$?

        if [[ $exit_code -eq 124 ]]; then
            echo "  ✗ $name - --verify timed out (prompts for input?)"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

test_config_scripts_verify_idempotent() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Run --verify twice - should give same result
        local exit1=0 exit2=0
        bash "$script" --verify >/dev/null 2>&1 || exit1=$?
        bash "$script" --verify >/dev/null 2>&1 || exit2=$?

        if [[ $exit1 -ne $exit2 ]]; then
            echo "  ✗ $name - --verify not idempotent (first: $exit1, second: $exit2)"
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

    run_test "Config scripts --verify executes" test_config_scripts_verify_execution "$filter"
    run_test "Config scripts --verify is non-interactive" test_config_scripts_verify_no_prompt "$filter"
    run_test "Config scripts --verify is idempotent" test_config_scripts_verify_idempotent "$filter"
}

main "$@"
