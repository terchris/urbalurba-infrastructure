#!/bin/bash
# file: .devcontainer/additions/tests/run-all-tests.sh
# version: 1.0.0
#
# DESCRIPTION: Test orchestrator for the devcontainer-toolbox test suite
# PURPOSE: Runs test suites by level (static, unit, install) or all tests
#
# Usage:
#   ./run-all-tests.sh                    # Run all tests
#   ./run-all-tests.sh static             # Run static tests only
#   ./run-all-tests.sh unit               # Run unit tests only
#   ./run-all-tests.sh install            # Run install cycle tests only
#   ./run-all-tests.sh static script.sh   # Run static tests for specific script
#

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-framework.sh"

#------------------------------------------------------------------------------
# TEST SUITES
#------------------------------------------------------------------------------

run_static_tests() {
    local filter="${1:-}"

    print_header "Static Tests (Level 1)"
    print_info "Checking syntax, metadata, categories, and flags"
    echo ""

    # Set test level for numbering
    set_test_level "1"

    for test_script in "$SCRIPT_DIR"/static/test-*.sh; do
        [[ ! -f "$test_script" ]] && continue
        # Source instead of bash to share variables
        source "$test_script" "$filter"
    done
}

run_unit_tests() {
    local filter="${1:-}"

    print_header "Unit Tests (Level 2)"
    print_info "Testing --help, --verify, and library functions"
    echo ""

    # Set test level for numbering
    set_test_level "2"

    for test_script in "$SCRIPT_DIR"/unit/test-*.sh; do
        [[ ! -f "$test_script" ]] && continue
        # Source instead of bash to share variables
        source "$test_script" "$filter"
    done
}

run_install_tests() {
    local filter="${1:-}"

    print_header "Install Cycle Tests (Level 3)"
    print_info "Testing install → verify → uninstall → verify cycle"
    echo ""

    # Set test level for numbering
    set_test_level "3"

    for test_script in "$SCRIPT_DIR"/install/test-*.sh; do
        [[ ! -f "$test_script" ]] && continue
        # Source instead of bash to share variables
        source "$test_script" "$filter"
    done
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    local suite="${1:-all}"
    local filter="${2:-}"

    print_header "DevContainer Toolbox - Test Suite"
    echo "Run: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    case "$suite" in
        static)
            run_static_tests "$filter"
            ;;
        unit)
            run_unit_tests "$filter"
            ;;
        install)
            run_install_tests "$filter"
            ;;
        all)
            run_static_tests "$filter"
            run_unit_tests "$filter"
            # Install tests are optional, don't run by default
            print_info "Skipping install tests (run with: $0 install)"
            ;;
        *)
            echo "Usage: $0 [static|unit|install|all] [script-filter]"
            echo ""
            echo "Test Levels:"
            echo "  static   - Syntax, metadata, categories, flags (fast, no execution)"
            echo "  unit     - --help, --verify, library functions (fast, safe execution)"
            echo "  install  - Full install/uninstall cycle (slow, modifies system)"
            echo "  all      - Run static and unit tests (default)"
            echo ""
            echo "Script Filter:"
            echo "  Optional: Only test scripts matching this name"
            echo "  Example: $0 static install-dev-python.sh"
            exit 1
            ;;
    esac

    print_summary
}

main "$@"
