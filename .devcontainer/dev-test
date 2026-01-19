#!/bin/bash
# file: .devcontainer/manage/dev-test.sh
#
# Run devcontainer-toolbox tests
# Wrapper for run-all-tests.sh test orchestrator
#
# Usage:
#   dev-test                      # Run all tests
#   dev-test static               # Run static tests only
#   dev-test unit                 # Run unit tests only
#   dev-test install              # Run install cycle tests only
#   dev-test lint                 # Run ShellCheck linting only
#   dev-test static script.sh     # Run static tests for specific script
#   dev-test --help               # Show this help

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-test"
SCRIPT_NAME="Run Tests"
SCRIPT_DESCRIPTION="Run static, unit, and install tests"
SCRIPT_CATEGORY="CONTRIBUTOR_TOOLS"
SCRIPT_CHECK_COMMAND="true"

#------------------------------------------------------------------------------
# Script Setup
#------------------------------------------------------------------------------
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
DEVCONTAINER_DIR="$SCRIPT_DIR/.."

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
dev-test - Run devcontainer-toolbox tests

Usage:
  dev-test                      # Run all tests
  dev-test static               # Run static tests only
  dev-test unit                 # Run unit tests only
  dev-test install              # Run install cycle tests only
  dev-test lint                 # Run ShellCheck linting only
  dev-test static script.sh     # Run static tests for specific script
  dev-test --help               # Show this help

Test Levels:
  lint     - ShellCheck linting (warnings, not blocking)
  static   - Level 1: Syntax, metadata, categories, flags
  unit     - Level 2: --help, --verify, library functions
  install  - Level 3: Full install/uninstall cycles

Examples:
  # Run all tests
  dev-test

  # Run only static analysis
  dev-test static

  # Run ShellCheck linting
  dev-test lint

  # Run static tests for a specific script
  dev-test static install-python.sh

EOF
}

#------------------------------------------------------------------------------
# ShellCheck Linting
#------------------------------------------------------------------------------
run_shellcheck() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ShellCheck Linting"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ! command -v shellcheck &> /dev/null; then
        echo "⚠️  ShellCheck not installed."
        echo "   Install with: .devcontainer/additions/install-dev-bash.sh"
        echo "   Or via menu:  dev-setup → Development Tools → Bash Development Tools"
        return 1
    fi

    local issues=0
    local files_checked=0

    # Find all shell scripts
    while IFS= read -r -d '' script; do
        files_checked=$((files_checked + 1))
        if ! shellcheck --severity=warning "$script" 2>/dev/null; then
            issues=$((issues + 1))
        fi
    done < <(find "$DEVCONTAINER_DIR" -name "*.sh" -print0 2>/dev/null)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $issues -eq 0 ]]; then
        echo "✅ ShellCheck: No warnings ($files_checked files checked)"
    else
        echo "⚠️  ShellCheck: $issues file(s) with warnings ($files_checked files checked)"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Return 0 even with warnings (non-blocking, like CI)
    return 0
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

# Handle --help locally
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Handle lint command locally
if [[ "${1:-}" == "lint" ]]; then
    run_shellcheck
    exit $?
fi

# For "all tests" (no args), run shellcheck first, then other tests
if [[ -z "${1:-}" ]]; then
    run_shellcheck
    echo ""
fi

# Pass all arguments to run-all-tests.sh
exec "$SCRIPT_DIR/../additions/tests/run-all-tests.sh" "$@"
