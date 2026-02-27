#!/bin/bash
# test-phase1-libraries.sh - Tests for Phase 1 UIS Libraries
#
# Tests that all Phase 1 libraries load correctly and define expected functions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine library path (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis/lib" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
fi

print_test_section "Phase 1: Library Tests"
echo "Library directory: $LIB_DIR"

# ============================================================================
# Test logging.sh
# ============================================================================
print_test_section "logging.sh"

start_test "logging.sh exists"
assert_file_exists "$LIB_DIR/logging.sh" && pass_test

start_test "logging.sh loads without error"
if source "$LIB_DIR/logging.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source logging.sh"
fi

for fn in log_info log_warn log_error log_success log_debug print_section print_subsection log_progress; do
    start_test "logging.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

# ============================================================================
# Test utilities.sh
# ============================================================================
print_test_section "utilities.sh"

start_test "utilities.sh exists"
assert_file_exists "$LIB_DIR/utilities.sh" && pass_test

start_test "utilities.sh loads without error"
if source "$LIB_DIR/utilities.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source utilities.sh"
fi

for fn in get_uis_root get_base_path die die_config die_k8s die_dependency check_kubernetes_connection require_file require_directory read_config_lines config_contains config_add config_remove is_empty to_lower to_upper; do
    start_test "utilities.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

# Test exit code constants
start_test "EXIT_SUCCESS is defined"
assert_var_defined "EXIT_SUCCESS" && pass_test

start_test "EXIT_CONFIG_ERROR is defined"
assert_var_defined "EXIT_CONFIG_ERROR" && pass_test

# ============================================================================
# Test categories.sh
# ============================================================================
print_test_section "categories.sh"

start_test "categories.sh exists"
assert_file_exists "$LIB_DIR/categories.sh" && pass_test

start_test "categories.sh loads without error"
if source "$LIB_DIR/categories.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source categories.sh"
fi

for fn in get_category_name get_category_description get_category_tags get_category_icon is_valid_category list_categories generate_categories_json_internal print_categories_table; do
    start_test "categories.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

start_test "_CATEGORY_DATA array is defined"
assert_var_defined "_CATEGORY_DATA" && pass_test

start_test "CATEGORY_ORDER array is defined"
assert_var_defined "CATEGORY_ORDER" && pass_test

# Test category functionality
start_test "MANAGEMENT is a valid category"
if is_valid_category "MANAGEMENT"; then
    pass_test
else
    fail_test
fi

start_test "get_category_name returns non-empty for MANAGEMENT"
name=$(get_category_name "MANAGEMENT")
assert_not_empty "$name" "Category name is empty" && pass_test

start_test "get_category_name OBSERVABILITY returns 'Observability'"
name=$(get_category_name "OBSERVABILITY")
assert_equals "Observability" "$name" && pass_test

start_test "INVALID_CAT is not a valid category"
if ! is_valid_category "INVALID_CAT"; then
    pass_test
else
    fail_test "INVALID_CAT should not be valid"
fi

# ============================================================================
# Test service-scanner.sh
# ============================================================================
print_test_section "service-scanner.sh"

start_test "service-scanner.sh exists"
assert_file_exists "$LIB_DIR/service-scanner.sh" && pass_test

start_test "service-scanner.sh loads without error"
if source "$LIB_DIR/service-scanner.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source service-scanner.sh"
fi

for fn in scan_setup_scripts extract_script_metadata check_service_deployed get_service_value find_service_script get_all_service_ids get_services_by_category clear_service_cache; do
    start_test "service-scanner.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

start_test "SERVICES_DIR is defined"
assert_var_defined "SERVICES_DIR" && pass_test

# ============================================================================
# Summary
# ============================================================================
print_summary
