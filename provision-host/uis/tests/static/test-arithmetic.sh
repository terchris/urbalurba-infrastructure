#!/bin/bash
# test-arithmetic.sh - Test for problematic arithmetic patterns
#
# Detects ((var++)) which returns exit code 1 when var=0,
# causing scripts with 'set -e' to fail unexpectedly.
#
# The fix is to use ((++var)) instead, which returns the
# incremented value (always truthy when incrementing from 0).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_LIB="$SCRIPT_DIR/../lib/test-framework.sh"

# Test counters
PASS=0
FAIL=0
TOTAL=0

# Test functions
pass() {
    echo -e "  Testing: $1... \033[0;32mPASS\033[0m"
    ((++PASS))
    ((++TOTAL))
}

fail() {
    echo -e "  Testing: $1... \033[0;31mFAIL\033[0m - $2"
    ((++FAIL))
    ((++TOTAL))
}

# Find UIS root directory
UIS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo ""
echo -e "\033[1m=== Arithmetic Pattern Tests ===\033[0m"
echo "Checking for problematic ((var++)) patterns that fail with 'set -e' when var=0"
echo ""

# Files to check
check_dirs=(
    "$UIS_ROOT/lib"
    "$UIS_ROOT/manage"
    "$UIS_ROOT/services"
)

# Pattern: ((identifier++)) - post-increment that returns old value
# This is problematic when the variable starts at 0
PATTERN='\(\([a-zA-Z_][a-zA-Z0-9_]*\+\+\)\)'

problematic_files=()

for dir in "${check_dirs[@]}"; do
    [[ ! -d "$dir" ]] && continue

    while IFS= read -r file; do
        [[ ! -f "$file" ]] && continue

        # Check if file uses 'set -e'
        if grep -q "^set -e" "$file" 2>/dev/null; then
            # Check for problematic pattern
            if grep -qE "$PATTERN" "$file" 2>/dev/null; then
                # Get the specific matches
                matches=$(grep -nE "$PATTERN" "$file" 2>/dev/null)
                problematic_files+=("$file")

                # Report each match
                while IFS= read -r match; do
                    line_num="${match%%:*}"
                    line_content="${match#*:}"
                    # Extract variable name
                    var_name=$(echo "$line_content" | grep -oE '\(\([a-zA-Z_][a-zA-Z0-9_]*\+\+\)\)' | head -1 | sed 's/((\(.*\)++))/\1/')

                    fail "No post-increment with set -e: $(basename "$file"):$line_num" \
                        "(($var_name++)) should be ((++$var_name))"
                done <<< "$matches"
            fi
        fi
    done < <(find "$dir" -name "*.sh" -type f 2>/dev/null)
done

# Also check for the pattern in scripts that source files with set -e
# (they inherit the setting)

if [[ ${#problematic_files[@]} -eq 0 ]]; then
    pass "No problematic ((var++)) patterns found in scripts with 'set -e'"
fi

echo ""
echo "────────────────────────────────────"
echo "Total: $TOTAL  Passed: $PASS  Failed: $FAIL"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\033[0;32mALL TESTS PASSED\033[0m"
    exit 0
else
    echo -e "\033[0;31mSOME TESTS FAILED\033[0m"
    echo ""
    echo "Fix: Change ((var++)) to ((++var)) in files with 'set -e'"
    echo "     Post-increment returns the OLD value (0 = falsy = exit 1)"
    echo "     Pre-increment returns the NEW value (1 = truthy = exit 0)"
    exit 1
fi
