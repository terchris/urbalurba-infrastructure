#!/bin/bash
# file: .devcontainer/additions/tests/lib/test-framework.sh
# version: 1.0.0
#
# DESCRIPTION: Shared test utilities for the devcontainer-toolbox test suite
# PURPOSE: Provides reusable functions for running tests, assertions, and reporting
#
# Usage:
#   source "$(dirname "$0")/../lib/test-framework.sh"
#
#   test_something() {
#       assert_equals "expected" "actual" "Test description"
#   }
#
#   run_test "Test Name" test_something
#

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

# Determine paths relative to this script
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$FRAMEWORK_DIR")"
ADDITIONS_DIR="$(dirname "$TESTS_DIR")"

# Test results tracking (only initialize if not already set - allows sourcing multiple test files)
: ${TESTS_RUN:=0}
: ${TESTS_PASSED:=0}
: ${TESTS_FAILED:=0}
: ${TESTS_SKIPPED:=0}
if [[ -z "${FAILED_TESTS+x}" ]]; then
    FAILED_TESTS=()
fi
if [[ -z "${SKIPPED_TESTS+x}" ]]; then
    SKIPPED_TESTS=()
fi

# Current test level prefix (set by orchestrator, e.g., "1" for static, "2" for unit)
: ${TEST_LEVEL_PREFIX:=""}
: ${TEST_LEVEL_COUNT:=0}

# Log directory
LOG_DIR="/tmp/devcontainer-tests"
mkdir -p "$LOG_DIR"

#------------------------------------------------------------------------------
# COLORS
#------------------------------------------------------------------------------

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

#------------------------------------------------------------------------------
# OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

print_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$title${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_pass() {
    echo -e "${GREEN}PASS${NC}"
}

print_fail() {
    echo -e "${YELLOW}ISSUES${NC}"
}

print_skip() {
    echo -e "${YELLOW}SKIP${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  INFO${NC}: $1"
}

#------------------------------------------------------------------------------
# ASSERTION FUNCTIONS
#------------------------------------------------------------------------------

# Assert two values are equal
# Usage: assert_equals "expected" "actual" "description"
assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="${3:-Values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        return 1
    fi
}

# Assert a value is not empty
# Usage: assert_not_empty "$value" "description"
assert_not_empty() {
    local value="$1"
    local description="${2:-Value should not be empty}"

    if [[ -n "$value" ]]; then
        return 0
    else
        echo "  Value is empty"
        return 1
    fi
}

# Assert a command succeeds (exit code 0)
# Usage: assert_success "command" "description"
assert_success() {
    local cmd="$1"
    local description="${2:-Command should succeed}"

    if eval "$cmd" >/dev/null 2>&1; then
        return 0
    else
        echo "  Command failed: $cmd"
        return 1
    fi
}

# Assert a command fails (exit code non-zero)
# Usage: assert_failure "command" "description"
assert_failure() {
    local cmd="$1"
    local description="${2:-Command should fail}"

    if eval "$cmd" >/dev/null 2>&1; then
        echo "  Command succeeded but should have failed: $cmd"
        return 1
    else
        return 0
    fi
}

# Assert a file exists
# Usage: assert_file_exists "/path/to/file" "description"
assert_file_exists() {
    local file="$1"
    local description="${2:-File should exist}"

    if [[ -f "$file" ]]; then
        return 0
    else
        echo "  File not found: $file"
        return 1
    fi
}

# Assert a string contains a substring
# Usage: assert_contains "$haystack" "$needle" "description"
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "  String does not contain: '$needle'"
        return 1
    fi
}

# Assert a pattern exists in a file
# Usage: assert_grep "pattern" "file" "description"
assert_grep() {
    local pattern="$1"
    local file="$2"
    local description="${3:-Pattern should be found in file}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        echo "  Pattern '$pattern' not found in $file"
        return 1
    fi
}

#------------------------------------------------------------------------------
# TEST EXECUTION
#------------------------------------------------------------------------------

# Set the test level prefix for numbering (call this at start of each test file)
# Usage: set_test_level "1" for static, "2" for unit, "3" for install
set_test_level() {
    TEST_LEVEL_PREFIX="$1"
    TEST_LEVEL_COUNT=0
}

# Run a single test function
# Usage: run_test "Test Name" test_function [script_filter]
run_test() {
    local test_name="$1"
    local test_func="$2"
    local script_filter="${3:-}"

    ((TESTS_RUN++))
    ((TEST_LEVEL_COUNT++))

    # Build test ID (e.g., "1.3" for static test #3)
    local test_id="${TEST_LEVEL_PREFIX}.${TEST_LEVEL_COUNT}"
    if [[ -z "$TEST_LEVEL_PREFIX" ]]; then
        test_id="$TESTS_RUN"
    fi

    local log_file="$LOG_DIR/test-${TESTS_RUN}.log"

    echo -n "Running: ${test_id}) $test_name... "

    # Run the test and capture output
    if $test_func "$script_filter" > "$log_file" 2>&1; then
        print_pass
        ((TESTS_PASSED++))
    else
        local exit_code=$?
        if [[ $exit_code -eq 77 ]]; then
            # Special exit code for skipped tests
            print_skip
            ((TESTS_SKIPPED++))
            SKIPPED_TESTS+=("${test_id}) $test_name: $(tail -1 "$log_file")")
        else
            print_fail
            ((TESTS_FAILED++))
            FAILED_TESTS+=("${test_id}) $test_name")
            # Show only the lines with issues (✗)
            grep "✗" "$log_file" | sed 's/^/  /'
        fi
    fi
}

# Skip a test with a reason
# Usage: skip_test "reason"
skip_test() {
    local reason="$1"
    echo "$reason"
    exit 77
}

#------------------------------------------------------------------------------
# SUMMARY AND REPORTING
#------------------------------------------------------------------------------

# Print test summary
print_summary() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Test Summary${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Total Tests:  $TESTS_RUN"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Skipped:      ${YELLOW}$TESTS_SKIPPED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ ${#SKIPPED_TESTS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Skipped tests:${NC}"
        for test in "${SKIPPED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED${NC}"
        return 1
    fi
}

#------------------------------------------------------------------------------
# UTILITY FUNCTIONS
#------------------------------------------------------------------------------

# Get all scripts matching a pattern, excluding templates
# Usage: get_scripts "install-*.sh"
get_scripts() {
    local pattern="$1"
    local filter="${2:-}"

    for script in "$ADDITIONS_DIR"/$pattern; do
        [[ ! -f "$script" ]] && continue
        [[ "$script" =~ _template ]] && continue

        # If filter is specified, only include matching scripts
        if [[ -n "$filter" ]] && [[ "$(basename "$script")" != "$filter" ]]; then
            continue
        fi

        echo "$script"
    done
}

# Source production libraries
source_libs() {
    local libs=("$@")
    for lib in "${libs[@]}"; do
        if [[ -f "$ADDITIONS_DIR/lib/$lib" ]]; then
            source "$ADDITIONS_DIR/lib/$lib"
        else
            echo "Warning: Library not found: $lib" >&2
        fi
    done
}

#------------------------------------------------------------------------------
# INITIALIZATION
#------------------------------------------------------------------------------

# Disable strict mode for test framework (we handle errors ourselves)
set +e

# Mark framework as loaded
TEST_FRAMEWORK_LOADED=1
