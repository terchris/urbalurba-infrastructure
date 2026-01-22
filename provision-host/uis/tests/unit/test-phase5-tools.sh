#!/bin/bash
# test-phase5-tools.sh - Tests for Phase 5 tool installation
#
# Tests the tool-installation.sh library

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine library and tools paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis/lib" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
    UIS_ROOT="/mnt/urbalurbadisk/provision-host/uis"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
    UIS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

print_test_section "Phase 5: Tool Installation Tests"

# ============================================================
# Test: tool-installation.sh loading
# ============================================================

start_test "tool-installation.sh exists"
assert_file_exists "$LIB_DIR/tool-installation.sh" && pass_test

# Source dependencies first
source "$LIB_DIR/logging.sh" 2>/dev/null
source "$LIB_DIR/utilities.sh" 2>/dev/null

start_test "tool-installation.sh loads without error"
if source "$LIB_DIR/tool-installation.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Failed to source tool-installation.sh"
fi

# ============================================================
# Test: tool-installation.sh functions exist
# ============================================================

for fn in get_all_tool_ids find_tool_script get_tool_value is_tool_installed is_builtin_tool install_tool list_tools; do
    start_test "tool-installation.sh defines $fn"
    assert_function_exists "$fn" && pass_test
done

# ============================================================
# Test: Built-in tools
# ============================================================

for tool in kubectl k9s helm ansible; do
    start_test "$tool is a built-in tool"
    if is_builtin_tool "$tool"; then
        pass_test
    else
        fail_test
    fi
done

start_test "azure-cli is NOT a built-in tool"
if ! is_builtin_tool "azure-cli"; then
    pass_test
else
    fail_test
fi

# ============================================================
# Test: Tool metadata retrieval
# ============================================================

start_test "get_tool_value returns kubectl name"
name=$(get_tool_value kubectl TOOL_NAME)
assert_equals "kubectl" "$name" && pass_test

start_test "get_tool_value returns k9s description"
desc=$(get_tool_value k9s TOOL_DESCRIPTION)
assert_equals "Kubernetes TUI manager" "$desc" && pass_test

start_test "get_tool_value returns helm check command"
check=$(get_tool_value helm TOOL_CHECK_COMMAND)
assert_equals "command -v helm" "$check" && pass_test

# ============================================================
# Test: Tool discovery
# ============================================================

start_test "get_all_tool_ids returns kubectl"
if get_all_tool_ids | grep -q 'kubectl'; then
    pass_test
else
    fail_test
fi

start_test "get_all_tool_ids returns k9s"
if get_all_tool_ids | grep -q 'k9s'; then
    pass_test
else
    fail_test
fi

start_test "get_all_tool_ids returns helm"
if get_all_tool_ids | grep -q 'helm'; then
    pass_test
else
    fail_test
fi

start_test "get_all_tool_ids returns ansible"
if get_all_tool_ids | grep -q 'ansible'; then
    pass_test
else
    fail_test
fi

# ============================================================
# Test: Installable tools (if tools directory exists)
# ============================================================

if [[ -d "$UIS_ROOT/tools" ]]; then
    # Check for azure-cli
    if [[ -f "$UIS_ROOT/tools/install-azure-cli.sh" ]]; then
        start_test "get_all_tool_ids returns azure-cli"
        if get_all_tool_ids | grep -q 'azure-cli'; then
            pass_test
        else
            fail_test
        fi

        start_test "find_tool_script finds azure-cli"
        script=$(find_tool_script azure-cli)
        if [[ -n "$script" ]]; then
            pass_test
        else
            fail_test
        fi

        start_test "get_tool_value returns azure-cli name"
        name=$(get_tool_value azure-cli TOOL_NAME)
        assert_equals "Azure CLI" "$name" && pass_test
    fi

    # Check for aws-cli
    if [[ -f "$UIS_ROOT/tools/install-aws-cli.sh" ]]; then
        start_test "get_all_tool_ids returns aws-cli"
        if get_all_tool_ids | grep -q 'aws-cli'; then
            pass_test
        else
            fail_test
        fi
    fi

    # Check for gcp-cli
    if [[ -f "$UIS_ROOT/tools/install-gcp-cli.sh" ]]; then
        start_test "get_all_tool_ids returns gcp-cli"
        if get_all_tool_ids | grep -q 'gcp-cli'; then
            pass_test
        else
            fail_test
        fi
    fi
fi

# ============================================================
# Test: Tool script validation
# ============================================================

if [[ -d "$UIS_ROOT/tools" ]]; then
    for script in "$UIS_ROOT/tools"/install-*.sh; do
        [[ -f "$script" ]] || continue
        basename=$(basename "$script")

        start_test "$basename has TOOL_ID"
        if grep -q '^TOOL_ID=' "$script"; then
            pass_test
        else
            fail_test
        fi

        start_test "$basename has TOOL_NAME"
        if grep -q '^TOOL_NAME=' "$script"; then
            pass_test
        else
            fail_test
        fi

        start_test "$basename has TOOL_DESCRIPTION"
        if grep -q '^TOOL_DESCRIPTION=' "$script"; then
            pass_test
        else
            fail_test
        fi

        start_test "$basename has TOOL_CHECK_COMMAND"
        if grep -q '^TOOL_CHECK_COMMAND=' "$script"; then
            pass_test
        else
            fail_test
        fi

        start_test "$basename has do_install function"
        if grep -q 'do_install()' "$script"; then
            pass_test
        else
            fail_test
        fi
    done
fi

# ============================================================
# Summary
# ============================================================

print_summary
