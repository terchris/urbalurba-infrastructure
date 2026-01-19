#!/bin/bash
# file: .devcontainer/additions/tests/unit/test-libraries.sh
#
# DESCRIPTION: Tests core library functions
# PURPOSE: Ensures production libraries work correctly
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

#------------------------------------------------------------------------------
# COMPONENT SCANNER TESTS
#------------------------------------------------------------------------------

test_component_scanner_loads() {
    source_libs "component-scanner.sh"

    if [[ -n "${COMPONENT_SCANNER_VERSION:-}" ]]; then
        echo "  ✓ component-scanner.sh (v${COMPONENT_SCANNER_VERSION})"
        return 0
    else
        echo "  ✗ component-scanner.sh - COMPONENT_SCANNER_VERSION not set"
        return 1
    fi
}

test_scan_install_scripts() {
    source_libs "component-scanner.sh"

    local count=$(scan_install_scripts "$ADDITIONS_DIR" | wc -l)

    if [[ $count -ge 5 ]]; then
        echo "  ✓ scan_install_scripts found $count scripts"
        return 0
    else
        echo "  ✗ scan_install_scripts - expected at least 5, found $count"
        return 1
    fi
}

test_scan_config_scripts() {
    source_libs "component-scanner.sh"

    local count=$(scan_config_scripts "$ADDITIONS_DIR" | wc -l)

    if [[ $count -ge 3 ]]; then
        echo "  ✓ scan_config_scripts found $count scripts"
        return 0
    else
        echo "  ✗ scan_config_scripts - expected at least 3, found $count"
        return 1
    fi
}

#------------------------------------------------------------------------------
# CATEGORIES TESTS
#------------------------------------------------------------------------------

test_categories_loads() {
    source_libs "categories.sh"

    if [[ -n "${CATEGORY_TABLE:-}" ]]; then
        echo "  ✓ categories.sh loaded"
        return 0
    else
        echo "  ✗ categories.sh - CATEGORY_TABLE not set"
        return 1
    fi
}

test_is_valid_category() {
    source_libs "categories.sh"

    local failed=0

    # Test valid categories
    if is_valid_category "LANGUAGE_DEV"; then
        echo "  ✓ is_valid_category LANGUAGE_DEV"
    else
        echo "  ✗ is_valid_category - LANGUAGE_DEV should be valid"
        ((failed++))
    fi

    if is_valid_category "INFRA_CONFIG"; then
        echo "  ✓ is_valid_category INFRA_CONFIG"
    else
        echo "  ✗ is_valid_category - INFRA_CONFIG should be valid"
        ((failed++))
    fi

    # Test invalid category
    if ! is_valid_category "INVALID_CATEGORY"; then
        echo "  ✓ is_valid_category rejects INVALID_CATEGORY"
    else
        echo "  ✗ is_valid_category - INVALID_CATEGORY should not be valid"
        ((failed++))
    fi

    return $failed
}

test_get_all_category_ids() {
    source_libs "categories.sh"

    local categories
    categories=$(get_all_category_ids)

    if [[ -z "$categories" ]]; then
        echo "  ✗ get_all_category_ids returned empty"
        return 1
    fi

    # Check some expected categories exist
    if echo "$categories" | grep -q "LANGUAGE_DEV"; then
        echo "  ✓ get_all_category_ids returns categories"
        return 0
    else
        echo "  ✗ get_all_category_ids - LANGUAGE_DEV not in list"
        return 1
    fi
}

#------------------------------------------------------------------------------
# PREREQUISITE CHECK TESTS
#------------------------------------------------------------------------------

test_prerequisite_check_loads() {
    source_libs "prerequisite-check.sh"

    if [[ -n "${PREREQUISITE_CHECK_VERSION:-}" ]]; then
        echo "  ✓ prerequisite-check.sh (v${PREREQUISITE_CHECK_VERSION})"
        return 0
    else
        echo "  ✗ prerequisite-check.sh - PREREQUISITE_CHECK_VERSION not set"
        return 1
    fi
}

test_check_prerequisite_config_missing() {
    source_libs "prerequisite-check.sh"

    # Check a non-existent config - should return 1
    if check_prerequisite_config "config-nonexistent.sh" "$ADDITIONS_DIR" 2>/dev/null; then
        echo "  ✗ check_prerequisite_config - should return 1 for non-existent"
        return 1
    else
        echo "  ✓ check_prerequisite_config handles missing config"
        return 0
    fi
}

#------------------------------------------------------------------------------
# CMD FRAMEWORK TESTS
#------------------------------------------------------------------------------

test_cmd_framework_loads() {
    source_libs "cmd-framework.sh"

    # Check a function exists
    if declare -f cmd_framework_validate_commands >/dev/null; then
        echo "  ✓ cmd-framework.sh loaded"
        return 0
    else
        echo "  ✗ cmd-framework.sh - cmd_framework_validate_commands not defined"
        return 1
    fi
}

test_cmd_framework_self_test() {
    source_libs "cmd-framework.sh"

    # Run the built-in self-test
    if cmd_framework_self_test >/dev/null 2>&1; then
        echo "  ✓ cmd_framework_self_test passed"
        return 0
    else
        echo "  ✗ cmd_framework_self_test failed"
        return 1
    fi
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local filter="${1:-}"

    # Component Scanner tests
    run_test "Component scanner library loads" test_component_scanner_loads
    run_test "Scan install scripts finds scripts" test_scan_install_scripts
    run_test "Scan config scripts finds scripts" test_scan_config_scripts

    # Categories tests
    run_test "Categories library loads" test_categories_loads
    run_test "is_valid_category works" test_is_valid_category
    run_test "get_all_category_ids returns categories" test_get_all_category_ids

    # Prerequisite check tests
    run_test "Prerequisite check library loads" test_prerequisite_check_loads
    run_test "check_prerequisite_config handles missing" test_check_prerequisite_config_missing

    # Cmd framework tests
    run_test "Cmd framework library loads" test_cmd_framework_loads
    run_test "Cmd framework self-test passes" test_cmd_framework_self_test
}

main "$@"
