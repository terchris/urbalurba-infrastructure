#!/bin/bash
# test-categories.sh - Validate service categories
#
# Tests that all SCRIPT_CATEGORY values are valid categories.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
    SERVICES_DIR="/mnt/urbalurbadisk/provision-host/uis/services"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
    SERVICES_DIR="$(cd "$SCRIPT_DIR/../../services" && pwd)"
fi

# Source categories library
source "$LIB_DIR/categories.sh"

print_test_section "Phase 2: Category Validation Tests"

for script in "$SERVICES_DIR"/*/*.sh; do
    [[ -f "$script" ]] || continue
    script_basename=$(basename "$script")

    # Clear previous values
    unset SCRIPT_ID SCRIPT_CATEGORY

    # Source script to get metadata
    source "$script" 2>/dev/null

    start_test "$script_basename has valid category '$SCRIPT_CATEGORY'"
    if is_valid_category "$SCRIPT_CATEGORY"; then
        pass_test
    else
        fail_test "Invalid category: $SCRIPT_CATEGORY"
    fi
done

print_summary
