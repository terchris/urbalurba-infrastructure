#!/bin/bash
# run-tests.sh - UIS Test Orchestrator
#
# Usage:
#   ./run-tests.sh static    # Run static tests (fast, no cluster needed)
#   ./run-tests.sh unit      # Run unit tests (fast, no cluster needed)
#   ./run-tests.sh deploy    # Run deploy tests (slow, needs cluster)
#   ./run-tests.sh all       # Run all tests
#
# Options:
#   --verbose     Show detailed output
#   --help        Show this help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_SCRIPTS=0
SCRIPTS_PASSED=0
SCRIPTS_FAILED=0
VERBOSE=false

show_help() {
    cat << 'EOF'
UIS Test Orchestrator

Usage: ./run-tests.sh [level...] [options]

Levels:
  static    Run static tests (metadata, syntax, categories, JSON)
  unit      Run unit tests (library functions, CLI commands)
  deploy    Run deploy tests (full deploy/remove cycle) - MODIFIES CLUSTER
  all       Run all test levels

Options:
  --verbose Show detailed output
  --help    Show this help

Examples:
  ./run-tests.sh static              # Quick validation
  ./run-tests.sh unit                # Test functions
  ./run-tests.sh static unit         # Run static and unit tests
  ./run-tests.sh all                 # Full test suite (requires cluster)
EOF
}

run_test_level() {
    local level="$1"
    local test_dir="$SCRIPT_DIR/$level"

    if [[ ! -d "$test_dir" ]]; then
        echo -e "${YELLOW}⚠${NC} Test directory not found: $test_dir"
        return 0
    fi

    local test_count=0
    for test_script in "$test_dir"/test-*.sh; do
        [[ -f "$test_script" ]] && ((test_count++))
    done

    if [[ "$test_count" -eq 0 ]]; then
        echo -e "${YELLOW}⚠${NC} No tests found in $level/"
        return 0
    fi

    echo ""
    echo -e "${BOLD}Running $level tests ($test_count scripts)...${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for test_script in "$test_dir"/test-*.sh; do
        [[ -f "$test_script" ]] || continue

        ((TOTAL_SCRIPTS++))
        local script_name
        script_name=$(basename "$test_script")

        echo ""
        echo -e "→ ${BOLD}$script_name${NC}"

        if bash "$test_script"; then
            ((SCRIPTS_PASSED++))
        else
            ((SCRIPTS_FAILED++))
            echo -e "${RED}✗ $script_name failed${NC}"
        fi
    done
}

# Parse arguments
LEVELS=()

for arg in "$@"; do
    case "$arg" in
        static|unit|deploy)
            LEVELS+=("$arg")
            ;;
        all)
            LEVELS=(static unit deploy)
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            show_help
            exit 1
            ;;
    esac
done

# Default to static if no level specified
[[ ${#LEVELS[@]} -eq 0 ]] && LEVELS=(static)

# Header
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}       UIS Test Suite${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Levels: ${LEVELS[*]}"

# Warning for deploy tests
if [[ " ${LEVELS[*]} " =~ " deploy " ]]; then
    echo ""
    echo -e "${YELLOW}⚠  WARNING: Deploy tests will modify your Kubernetes cluster!${NC}"
    echo "Press Ctrl+C to cancel or wait 3 seconds to continue..."
    sleep 3
fi

# Run tests
for level in "${LEVELS[@]}"; do
    run_test_level "$level"
done

# Final summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BOLD}Final Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test scripts run: $TOTAL_SCRIPTS"
echo "Test scripts passed: $SCRIPTS_PASSED"
echo "Test scripts failed: $SCRIPTS_FAILED"

if [[ "$SCRIPTS_FAILED" -eq 0 ]]; then
    if [[ "$TOTAL_SCRIPTS" -eq 0 ]]; then
        echo -e "${YELLOW}⚠  NO TESTS WERE RUN${NC}"
        exit 0
    fi
    echo -e "${GREEN}✅ ALL TEST LEVELS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TEST LEVELS FAILED${NC}"
    exit 1
fi
