#!/bin/bash
# test-phase5-menu.sh - Tests for Phase 5 menu helpers
#
# Tests the menu-helpers.sh library

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine library path (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis/lib" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
fi

print_test_section "Phase 5: Menu Helpers Tests"

# ============================================================
# Test: menu-helpers.sh loading
# ============================================================

start_test "menu-helpers.sh exists"
assert_file_exists "$LIB_DIR/menu-helpers.sh" && pass_test

# Source dependencies first
source "$LIB_DIR/logging.sh" 2>/dev/null
source "$LIB_DIR/utilities.sh" 2>/dev/null

start_test "menu-helpers.sh loads without error"
if source "$LIB_DIR/menu-helpers.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source menu-helpers.sh"
fi

# ============================================================
# Test: menu-helpers.sh functions exist
# ============================================================

for fn in has_dialog show_menu show_checklist show_msgbox show_yesno show_inputbox clear_screen; do
    start_test "menu-helpers.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

# ============================================================
# Test: has_dialog returns correct values
# ============================================================

start_test "has_dialog returns 0 or 1"
has_dialog
result=$?
if [[ $result -eq 0 || $result -eq 1 ]]; then
    pass_test
else
    fail_test "has_dialog returned $result instead of 0 or 1"
fi

# ============================================================
# Summary
# ============================================================

print_summary
