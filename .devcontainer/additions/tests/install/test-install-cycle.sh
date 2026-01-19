#!/bin/bash
# file: .devcontainer/additions/tests/install/test-install-cycle.sh
#
# DESCRIPTION: Tests the full install → verify → uninstall → verify cycle
# PURPOSE: Ensures install scripts work correctly and clean up properly
#
# WARNING: This test actually installs and uninstalls tools!
#          It modifies the system but should return it to clean state.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

# Scripts that are known to have issues or take too long
SKIP_SCRIPTS=(
    # Add scripts to skip here if needed
    # "install-dev-example.sh"
)

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

should_skip() {
    local script_name="$1"
    for skip in "${SKIP_SCRIPTS[@]:-}"; do
        if [[ "$script_name" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

get_check_command() {
    local script="$1"
    grep -m 1 "^SCRIPT_CHECK_COMMAND=" "$script" 2>/dev/null | cut -d'"' -f2
}

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_cycle() {
    local filter="${1:-}"
    local failed=0
    local skipped=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")

        # Check if should skip
        if should_skip "$name"; then
            echo "  ⏭ $name (in skip list)"
            ((skipped++))
            continue
        fi

        # Get the SCRIPT_CHECK_COMMAND
        local check_cmd
        check_cmd=$(get_check_command "$script")

        if [[ -z "$check_cmd" ]]; then
            echo "  ⏭ $name (no SCRIPT_CHECK_COMMAND)"
            ((skipped++))
            continue
        fi

        echo "  Testing: $name"
        echo "    Check command: $check_cmd"

        # Step 1: Install
        echo "    1. Installing..."
        if ! bash "$script" >/dev/null 2>&1; then
            echo "  ✗ $name - installation failed"
            ((failed++))
            continue
        fi

        # Step 2: Verify installed (SCRIPT_CHECK_COMMAND should return 0)
        echo "    2. Verifying installation..."
        if ! eval "$check_cmd" 2>/dev/null; then
            echo "  ✗ $name - SCRIPT_CHECK_COMMAND failed after install"
            # Try to clean up
            bash "$script" --uninstall 2>/dev/null || true
            ((failed++))
            continue
        fi

        # Step 3: Uninstall
        echo "    3. Uninstalling..."
        if ! bash "$script" --uninstall >/dev/null 2>&1; then
            echo "  ✗ $name - uninstall failed"
            ((failed++))
            continue
        fi

        # Step 4: Verify uninstalled (SCRIPT_CHECK_COMMAND should return 1)
        echo "    4. Verifying uninstallation..."
        if eval "$check_cmd" 2>/dev/null; then
            echo "  ✗ $name - tool still installed after uninstall"
            ((failed++))
            continue
        fi

        echo "  ✓ $name"
    done

    if [[ $skipped -gt 0 ]]; then
        echo ""
        echo "  Skipped: $skipped scripts"
    fi

    return $failed
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local filter="${1:-}"

    print_header "Install Cycle Tests"
    print_info "This test installs and uninstalls tools"
    print_info "System should return to clean state after tests"
    echo ""

    if [[ -z "$filter" ]]; then
        echo "WARNING: Running install cycle for ALL install scripts can take a long time."
        echo "Consider testing specific scripts: $0 install-dev-python.sh"
        echo ""
    fi

    run_test "Install/Uninstall cycle" test_install_cycle "$filter"
}

main "$@"
