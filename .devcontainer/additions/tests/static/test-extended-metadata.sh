#!/bin/bash
# file: .devcontainer/additions/tests/static/test-extended-metadata.sh
#
# DESCRIPTION: Validates that all scripts have required extended metadata fields
# PURPOSE: Ensures scripts have TAGS and ABSTRACT for website documentation
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Workspace root for checking logo files
WORKSPACE_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Extract a metadata field value from a script
# Handles both quoted and unquoted values
extract_field() {
    local script="$1"
    local field="$2"
    grep -m 1 "^${field}=" "$script" 2>/dev/null | sed 's/^[^=]*=["'"'"']\{0,1\}//' | sed 's/["'"'"']\{0,1\}$//'
}

# Count characters in a string
char_count() {
    echo -n "$1" | wc -c | tr -d ' '
}

# Validate URL format (must start with https://)
is_valid_url() {
    local url="$1"
    [[ "$url" =~ ^https:// ]]
}

# Check if a script ID exists
script_id_exists() {
    local id="$1"
    for script in "$ADDITIONS_DIR"/install-*.sh "$ADDITIONS_DIR"/config-*.sh "$ADDITIONS_DIR"/service-*.sh; do
        [[ ! -f "$script" ]] && continue
        [[ "$script" =~ _template ]] && continue
        local script_id=$(extract_field "$script" "SCRIPT_ID")
        [[ "$script_id" == "$id" ]] && return 0
    done
    return 1
}

#------------------------------------------------------------------------------
# TEST FUNCTIONS
#------------------------------------------------------------------------------

# Test extended metadata for install scripts
test_install_extended_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-*.sh" "$filter"); do
        local name=$(basename "$script")
        local issues=""

        # Required: SCRIPT_TAGS
        local tags=$(extract_field "$script" "SCRIPT_TAGS")
        if [[ -z "$tags" ]]; then
            issues+="missing SCRIPT_TAGS; "
        fi

        # Required: SCRIPT_ABSTRACT (50-150 chars)
        local abstract=$(extract_field "$script" "SCRIPT_ABSTRACT")
        if [[ -z "$abstract" ]]; then
            issues+="missing SCRIPT_ABSTRACT; "
        else
            local len=$(char_count "$abstract")
            if [[ $len -lt 50 ]]; then
                issues+="SCRIPT_ABSTRACT too short ($len chars, min 50); "
            elif [[ $len -gt 150 ]]; then
                issues+="SCRIPT_ABSTRACT too long ($len chars, max 150); "
            fi
        fi

        # Optional: SCRIPT_LOGO (warn if file missing)
        local logo=$(extract_field "$script" "SCRIPT_LOGO")
        if [[ -n "$logo" ]]; then
            local logo_path="$WORKSPACE_ROOT/website/static/img/tools/src/$logo"
            if [[ ! -f "$logo_path" ]]; then
                # Just a warning, not a failure (logos added in Phase 5)
                : # issues+="SCRIPT_LOGO file not found: $logo; "
            fi
        fi

        # Optional: SCRIPT_WEBSITE (validate URL format)
        local website=$(extract_field "$script" "SCRIPT_WEBSITE")
        if [[ -n "$website" ]] && ! is_valid_url "$website"; then
            issues+="SCRIPT_WEBSITE invalid URL (must start with https://); "
        fi

        # Optional: SCRIPT_SUMMARY (150-500 chars if provided)
        local summary=$(extract_field "$script" "SCRIPT_SUMMARY")
        if [[ -n "$summary" ]]; then
            local len=$(char_count "$summary")
            if [[ $len -lt 150 ]]; then
                issues+="SCRIPT_SUMMARY too short ($len chars, min 150); "
            elif [[ $len -gt 500 ]]; then
                issues+="SCRIPT_SUMMARY too long ($len chars, max 500); "
            fi
        fi

        # Optional: SCRIPT_RELATED (validate each ID exists)
        local related=$(extract_field "$script" "SCRIPT_RELATED")
        if [[ -n "$related" ]]; then
            for rel_id in $related; do
                if ! script_id_exists "$rel_id"; then
                    issues+="SCRIPT_RELATED references unknown ID: $rel_id; "
                fi
            done
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $name - $issues"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

# Test extended metadata for config scripts
test_config_extended_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "config-*.sh" "$filter"); do
        local name=$(basename "$script")
        local issues=""

        # Required: SCRIPT_TAGS
        local tags=$(extract_field "$script" "SCRIPT_TAGS")
        if [[ -z "$tags" ]]; then
            issues+="missing SCRIPT_TAGS; "
        fi

        # Required: SCRIPT_ABSTRACT (50-150 chars)
        local abstract=$(extract_field "$script" "SCRIPT_ABSTRACT")
        if [[ -z "$abstract" ]]; then
            issues+="missing SCRIPT_ABSTRACT; "
        else
            local len=$(char_count "$abstract")
            if [[ $len -lt 50 ]]; then
                issues+="SCRIPT_ABSTRACT too short ($len chars, min 50); "
            elif [[ $len -gt 150 ]]; then
                issues+="SCRIPT_ABSTRACT too long ($len chars, max 150); "
            fi
        fi

        # Optional: SCRIPT_WEBSITE (validate URL format)
        local website=$(extract_field "$script" "SCRIPT_WEBSITE")
        if [[ -n "$website" ]] && ! is_valid_url "$website"; then
            issues+="SCRIPT_WEBSITE invalid URL (must start with https://); "
        fi

        # Optional: SCRIPT_SUMMARY (150-500 chars if provided)
        local summary=$(extract_field "$script" "SCRIPT_SUMMARY")
        if [[ -n "$summary" ]]; then
            local len=$(char_count "$summary")
            if [[ $len -lt 150 ]]; then
                issues+="SCRIPT_SUMMARY too short ($len chars, min 150); "
            elif [[ $len -gt 500 ]]; then
                issues+="SCRIPT_SUMMARY too long ($len chars, max 500); "
            fi
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $name - $issues"
            ((failed++))
        else
            echo "  ✓ $name"
        fi
    done

    return $failed
}

# Test extended metadata for service scripts (install-srv-*)
test_service_extended_metadata() {
    local filter="${1:-}"
    local failed=0

    for script in $(get_scripts "install-srv-*.sh" "$filter"); do
        local name=$(basename "$script")
        local issues=""

        # Required: SCRIPT_TAGS
        local tags=$(extract_field "$script" "SCRIPT_TAGS")
        if [[ -z "$tags" ]]; then
            issues+="missing SCRIPT_TAGS; "
        fi

        # Required: SCRIPT_ABSTRACT (50-150 chars)
        local abstract=$(extract_field "$script" "SCRIPT_ABSTRACT")
        if [[ -z "$abstract" ]]; then
            issues+="missing SCRIPT_ABSTRACT; "
        else
            local len=$(char_count "$abstract")
            if [[ $len -lt 50 ]]; then
                issues+="SCRIPT_ABSTRACT too short ($len chars, min 50); "
            elif [[ $len -gt 150 ]]; then
                issues+="SCRIPT_ABSTRACT too long ($len chars, max 150); "
            fi
        fi

        # Optional: SCRIPT_WEBSITE (validate URL format)
        local website=$(extract_field "$script" "SCRIPT_WEBSITE")
        if [[ -n "$website" ]] && ! is_valid_url "$website"; then
            issues+="SCRIPT_WEBSITE invalid URL (must start with https://); "
        fi

        if [[ -n "$issues" ]]; then
            echo "  ✗ $name - $issues"
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

    run_test "Install scripts have valid extended metadata" test_install_extended_metadata "$filter"
    run_test "Config scripts have valid extended metadata" test_config_extended_metadata "$filter"
    run_test "Service scripts have valid extended metadata" test_service_extended_metadata "$filter"
}

main "$@"
