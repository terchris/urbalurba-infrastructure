#!/bin/bash
# file: .devcontainer/additions/tests/static/test-generated-json.sh
#
# DESCRIPTION: Validates generated JSON files (tools.json, categories.json)
# PURPOSE: Ensures dev-docs.sh generates valid JSON with all required fields
#
# NOTE: This test requires dev-docs.sh to have been run first.
#       Run with --generate flag to regenerate JSON before testing.
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Paths to JSON files
WORKSPACE_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"
TOOLS_JSON="$WORKSPACE_ROOT/website/src/data/tools.json"
CATEGORIES_JSON="$WORKSPACE_ROOT/website/src/data/categories.json"
DEV_DOCS="$WORKSPACE_ROOT/.devcontainer/manage/dev-docs.sh"

# Flag to regenerate JSON before testing
REGENERATE=0

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Check if jq is available
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo "jq not installed - skipping JSON validation"
        return 1
    fi
    return 0
}

# Validate JSON syntax
is_valid_json() {
    local file="$1"
    jq empty "$file" 2>/dev/null
}

# Count items in JSON array
json_array_count() {
    local file="$1"
    local path="$2"
    jq -r "$path | length" "$file" 2>/dev/null
}

# Check if JSON field exists and is not null/empty
json_field_exists() {
    local file="$1"
    local query="$2"
    local result=$(jq -r "$query" "$file" 2>/dev/null)
    [[ -n "$result" && "$result" != "null" ]]
}

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

# Test tools.json exists and is valid
test_tools_json_exists() {
    local failed=0

    if [[ ! -f "$TOOLS_JSON" ]]; then
        echo "  ✗ tools.json not found at $TOOLS_JSON"
        echo "    Run 'dev-docs' to generate it"
        return 1
    fi
    echo "  ✓ tools.json exists"

    if ! check_jq; then
        echo "  ✓ Skipping JSON validation (jq not available)"
        return 0
    fi

    if ! is_valid_json "$TOOLS_JSON"; then
        echo "  ✗ tools.json is not valid JSON"
        ((failed++))
    else
        echo "  ✓ tools.json is valid JSON"
    fi

    local count=$(json_array_count "$TOOLS_JSON" ".tools")
    if [[ "$count" -gt 0 ]]; then
        echo "  ✓ tools.json contains $count tools"
    else
        echo "  ✗ tools.json contains no tools"
        ((failed++))
    fi

    return $failed
}

# Test tools.json has required fields for each tool
test_tools_json_fields() {
    local failed=0

    if ! check_jq; then
        skip_test "jq not available"
    fi

    if [[ ! -f "$TOOLS_JSON" ]]; then
        skip_test "tools.json not found"
    fi

    # Required fields for each tool
    local required_fields=("id" "type" "name" "description" "category" "tags" "abstract")

    local count=$(json_array_count "$TOOLS_JSON" ".tools")
    for i in $(seq 0 $((count - 1))); do
        local tool_id=$(jq -r ".tools[$i].id" "$TOOLS_JSON")
        local issues=""

        for field in "${required_fields[@]}"; do
            if ! json_field_exists "$TOOLS_JSON" ".tools[$i].$field"; then
                issues+="missing $field; "
            fi
        done

        # Validate type is one of: install, config, service
        local type=$(jq -r ".tools[$i].type" "$TOOLS_JSON")
        if [[ "$type" != "install" && "$type" != "config" && "$type" != "service" ]]; then
            issues+="invalid type '$type'; "
        fi

        # Validate tags is an array
        local tags_type=$(jq -r ".tools[$i].tags | type" "$TOOLS_JSON")
        if [[ "$tags_type" != "array" ]]; then
            issues+="tags should be array; "
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $tool_id - $issues"
            ((failed++))
        else
            echo "  ✓ $tool_id"
        fi
    done

    return $failed
}

# Test categories.json exists and is valid
test_categories_json_exists() {
    local failed=0

    if [[ ! -f "$CATEGORIES_JSON" ]]; then
        echo "  ✗ categories.json not found at $CATEGORIES_JSON"
        echo "    Run 'dev-docs' to generate it"
        return 1
    fi
    echo "  ✓ categories.json exists"

    if ! check_jq; then
        echo "  ✓ Skipping JSON validation (jq not available)"
        return 0
    fi

    if ! is_valid_json "$CATEGORIES_JSON"; then
        echo "  ✗ categories.json is not valid JSON"
        ((failed++))
    else
        echo "  ✓ categories.json is valid JSON"
    fi

    local count=$(json_array_count "$CATEGORIES_JSON" ".categories")
    if [[ "$count" -gt 0 ]]; then
        echo "  ✓ categories.json contains $count categories"
    else
        echo "  ✗ categories.json contains no categories"
        ((failed++))
    fi

    return $failed
}

# Test categories.json has required fields for each category
test_categories_json_fields() {
    local failed=0

    if ! check_jq; then
        skip_test "jq not available"
    fi

    if [[ ! -f "$CATEGORIES_JSON" ]]; then
        skip_test "categories.json not found"
    fi

    # Required fields for each category
    local required_fields=("id" "name" "order" "tags" "abstract" "summary")

    local count=$(json_array_count "$CATEGORIES_JSON" ".categories")
    for i in $(seq 0 $((count - 1))); do
        local cat_id=$(jq -r ".categories[$i].id" "$CATEGORIES_JSON")
        local issues=""

        for field in "${required_fields[@]}"; do
            if ! json_field_exists "$CATEGORIES_JSON" ".categories[$i].$field"; then
                issues+="missing $field; "
            fi
        done

        # Validate order is a number
        local order=$(jq -r ".categories[$i].order" "$CATEGORIES_JSON")
        if ! [[ "$order" =~ ^[0-9]+$ ]]; then
            issues+="order should be number; "
        fi

        # Validate tags is an array
        local tags_type=$(jq -r ".categories[$i].tags | type" "$CATEGORIES_JSON")
        if [[ "$tags_type" != "array" ]]; then
            issues+="tags should be array; "
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $cat_id - $issues"
            ((failed++))
        else
            echo "  ✓ $cat_id"
        fi
    done

    return $failed
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    # Check for --generate flag
    if [[ "${1:-}" == "--generate" ]]; then
        echo "Regenerating JSON files..."
        if [[ -f "$DEV_DOCS" ]]; then
            bash "$DEV_DOCS" >/dev/null 2>&1
            echo "Done."
        else
            echo "Warning: dev-docs.sh not found"
        fi
        shift
    fi

    run_test "tools.json exists and is valid" test_tools_json_exists
    run_test "tools.json has required fields" test_tools_json_fields
    run_test "categories.json exists and is valid" test_categories_json_exists
    run_test "categories.json has required fields" test_categories_json_fields
}

main "$@"
