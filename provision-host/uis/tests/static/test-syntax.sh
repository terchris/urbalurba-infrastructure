#!/bin/bash
# test-syntax.sh - Validate bash syntax
#
# Tests that all scripts pass bash syntax check.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_DIR="/mnt/urbalurbadisk/provision-host/uis"
else
    UIS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

print_test_section "Phase 2: Bash Syntax Tests"

# Test all .sh files in the UIS directory
for script in "$UIS_DIR"/lib/*.sh "$UIS_DIR"/services/*/*.sh "$UIS_DIR"/tests/*/*.sh "$UIS_DIR"/tests/*.sh; do
    [[ -f "$script" ]] || continue

    # Get relative path for display
    rel_path="${script#$UIS_DIR/}"

    start_test "$rel_path syntax"
    if bash -n "$script" 2>/dev/null; then
        pass_test
    else
        fail_test "Syntax error in $rel_path"
    fi
done

print_summary
