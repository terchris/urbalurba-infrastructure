#!/bin/bash
# file: .devcontainer/additions/tests/static/test-categories.sh
#
# DESCRIPTION: Validates that all scripts use valid categories from lib/categories.sh
# PURPOSE: Ensures category consistency across all scripts
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Source production library for category validation
source_libs "categories.sh"

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

test_install_scripts_categories() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)

        if [[ -n "$script_cat" ]]; then
            if ! is_valid_category "$script_cat"; then
                echo "  ✗ $name - invalid category '$script_cat'"
                echo "    Valid: $(get_all_category_ids | tr '\n' ' ')"
                ((failed++))
            else
                echo "  ✓ $name"
            fi
        else
            echo "  ✓ $name (no category set)"
        fi
    done

    return $failed
}

test_config_scripts_categories() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)

        if [[ -n "$script_cat" ]]; then
            if ! is_valid_category "$script_cat"; then
                echo "  ✗ $name - invalid category '$script_cat'"
                echo "    Valid: $(get_all_category_ids | tr '\n' ' ')"
                ((failed++))
            else
                echo "  ✓ $name"
            fi
        else
            echo "  ✓ $name (no category set)"
        fi
    done

    return $failed
}

test_service_scripts_categories() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "service-*.sh" "$filter"); do
        local name=$(basename "$script")
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)

        if [[ -n "$script_cat" ]]; then
            if ! is_valid_category "$script_cat"; then
                echo "  ✗ $name - invalid category '$script_cat'"
                echo "    Valid: $(get_all_category_ids | tr '\n' ' ')"
                ((failed++))
            else
                echo "  ✓ $name"
            fi
        else
            echo "  ✓ $name (no category set)"
        fi
    done

    return $failed
}

test_cmd_scripts_categories() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "cmd-*.sh" "$filter"); do
        local name=$(basename "$script")
        local script_cat=$(grep -m 1 "^SCRIPT_CATEGORY=" "$script" 2>/dev/null | cut -d'"' -f2)

        if [[ -n "$script_cat" ]]; then
            if ! is_valid_category "$script_cat"; then
                echo "  ✗ $name - invalid category '$script_cat'"
                echo "    Valid: $(get_all_category_ids | tr '\n' ' ')"
                ((failed++))
            else
                echo "  ✓ $name"
            fi
        else
            echo "  ✓ $name (no category set)"
        fi
    done

    return $failed
}

#------------------------------------------------------------------------------
# CATEGORY METADATA TESTS
#------------------------------------------------------------------------------

# Test that all categories have required metadata fields
test_category_metadata() {
    local failed=0

    for category_id in $(get_all_category_ids); do
        local issues=""

        # Check CATEGORY_NAME
        local name=$(get_category_name "$category_id")
        if [[ -z "$name" ]] || [[ "$name" == "$category_id" ]]; then
            issues+="missing CATEGORY_NAME; "
        fi

        # Check CATEGORY_ABSTRACT
        local abstract=$(get_category_abstract "$category_id")
        if [[ -z "$abstract" ]]; then
            issues+="missing CATEGORY_ABSTRACT; "
        fi

        # Check CATEGORY_SUMMARY
        local summary=$(get_category_summary "$category_id")
        if [[ -z "$summary" ]]; then
            issues+="missing CATEGORY_SUMMARY; "
        fi

        # Check CATEGORY_TAGS (required for search)
        local tags=$(get_category_tags "$category_id")
        if [[ -z "$tags" ]]; then
            issues+="missing CATEGORY_TAGS; "
        fi

        # Check CATEGORY_ORDER
        local order=$(get_category_order "$category_id")
        if [[ -z "$order" ]] || ! [[ "$order" =~ ^[0-9]+$ ]]; then
            issues+="invalid CATEGORY_ORDER; "
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $category_id - $issues"
            ((failed++))
        else
            echo "  ✓ $category_id"
        fi
    done

    return $failed
}

# Test backward compatibility aliases
test_category_backward_compat() {
    local failed=0

    for category_id in $(get_all_category_ids); do
        local issues=""

        # Test get_category_display_name (alias for get_category_name)
        local name=$(get_category_name "$category_id")
        local display_name=$(get_category_display_name "$category_id")
        if [[ "$name" != "$display_name" ]]; then
            issues+="get_category_display_name mismatch; "
        fi

        # Test get_category_short_description (alias for get_category_abstract)
        local abstract=$(get_category_abstract "$category_id")
        local short_desc=$(get_category_short_description "$category_id")
        if [[ "$abstract" != "$short_desc" ]]; then
            issues+="get_category_short_description mismatch; "
        fi

        # Test get_category_description (alias for get_category_summary)
        local summary=$(get_category_summary "$category_id")
        local desc=$(get_category_description "$category_id")
        if [[ "$summary" != "$desc" ]]; then
            issues+="get_category_description mismatch; "
        fi

        # Test get_category_sort_order (alias for get_category_order)
        local order=$(get_category_order "$category_id")
        local sort_order=$(get_category_sort_order "$category_id")
        if [[ "$order" != "$sort_order" ]]; then
            issues+="get_category_sort_order mismatch; "
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $category_id - $issues"
            ((failed++))
        else
            echo "  ✓ $category_id"
        fi
    done

    return $failed
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local filter="${1:-}"

    run_test "Install scripts use valid categories" test_install_scripts_categories "$filter"
    run_test "Config scripts use valid categories" test_config_scripts_categories "$filter"
    run_test "Service scripts use valid categories" test_service_scripts_categories "$filter"
    run_test "Cmd scripts use valid categories" test_cmd_scripts_categories "$filter"
    run_test "Categories have required metadata" test_category_metadata
    run_test "Category backward compat aliases work" test_category_backward_compat
}

main "$@"
