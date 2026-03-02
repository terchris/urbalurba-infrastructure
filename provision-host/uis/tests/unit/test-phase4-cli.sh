#!/bin/bash
# test-phase4-cli.sh - Phase 4 CLI command tests
#
# Tests for the UIS CLI entry point and service-auto-enable library.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    UIS_CLI="/mnt/urbalurbadisk/provision-host/uis/manage/uis-cli.sh"
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
else
    UIS_CLI="$(cd "$SCRIPT_DIR/../../manage" && pwd)/uis-cli.sh"
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
fi

print_test_section "Phase 4: CLI Command Tests"

# ============================================================
# Test uis-cli.sh exists and is executable
# ============================================================

start_test "uis-cli.sh exists"
if [[ -f "$UIS_CLI" ]]; then
    pass_test
else
    fail_test "File not found: $UIS_CLI"
fi

start_test "uis-cli.sh is executable"
if [[ -x "$UIS_CLI" ]]; then
    pass_test
else
    fail_test "File is not executable: $UIS_CLI"
fi

start_test "uis-cli.sh has valid bash syntax"
if bash -n "$UIS_CLI" 2>/dev/null; then
    pass_test
else
    fail_test "Syntax error in uis-cli.sh"
fi

# ============================================================
# Test CLI help command
# ============================================================

start_test "uis help runs without error"
if "$UIS_CLI" help >/dev/null 2>&1; then
    pass_test
else
    fail_test "uis help failed"
fi

start_test "uis help shows Usage"
if "$UIS_CLI" help 2>&1 | grep -q "Usage"; then
    pass_test
else
    fail_test "No 'Usage' in help output"
fi

start_test "uis help shows list command"
if "$UIS_CLI" help 2>&1 | grep -q "list"; then
    pass_test
else
    fail_test "No 'list' command in help output"
fi

start_test "uis help shows deploy command"
if "$UIS_CLI" help 2>&1 | grep -q "deploy"; then
    pass_test
else
    fail_test "No 'deploy' command in help output"
fi

start_test "uis help shows enable command"
if "$UIS_CLI" help 2>&1 | grep -q "enable"; then
    pass_test
else
    fail_test "No 'enable' command in help output"
fi

# ============================================================
# Test CLI version command
# ============================================================

start_test "uis version runs without error"
if "$UIS_CLI" version >/dev/null 2>&1; then
    pass_test
else
    fail_test "uis version failed"
fi

start_test "uis version shows UIS"
if "$UIS_CLI" version 2>&1 | grep -q "UIS"; then
    pass_test
else
    fail_test "No 'UIS' in version output"
fi

# ============================================================
# Test CLI list command (doesn't require cluster)
# ============================================================

start_test "uis list runs without error"
if "$UIS_CLI" list >/dev/null 2>&1; then
    pass_test
else
    fail_test "uis list failed"
fi

start_test "uis list shows services"
if "$UIS_CLI" list 2>&1 | grep -q "nginx\|prometheus\|grafana"; then
    pass_test
else
    fail_test "No services shown in list output"
fi

# ============================================================
# Test CLI categories command
# ============================================================

start_test "uis categories runs without error"
if "$UIS_CLI" categories >/dev/null 2>&1; then
    pass_test
else
    fail_test "uis categories failed"
fi

start_test "uis categories shows OBSERVABILITY"
if "$UIS_CLI" categories 2>&1 | grep -q "OBSERVABILITY"; then
    pass_test
else
    fail_test "No 'OBSERVABILITY' in categories output"
fi

# ============================================================
# Test unknown command returns error
# ============================================================

start_test "uis unknown-cmd returns error"
if ! "$UIS_CLI" unknown-cmd >/dev/null 2>&1; then
    pass_test
else
    fail_test "Unknown command should return non-zero exit code"
fi

# ============================================================
# Test service-auto-enable.sh
# ============================================================

start_test "service-auto-enable.sh exists"
if [[ -f "$LIB_DIR/service-auto-enable.sh" ]]; then
    pass_test
else
    fail_test "File not found: $LIB_DIR/service-auto-enable.sh"
fi

start_test "service-auto-enable.sh has valid bash syntax"
if bash -n "$LIB_DIR/service-auto-enable.sh" 2>/dev/null; then
    pass_test
else
    fail_test "Syntax error in service-auto-enable.sh"
fi

# Source for function tests
source "$LIB_DIR/service-auto-enable.sh" 2>/dev/null

ENABLE_FUNCTIONS=(
    is_service_enabled
    enable_service
    disable_service
    list_enabled_services
    count_enabled_services
    toggle_service
    get_enabled_services_file
)

for fn in "${ENABLE_FUNCTIONS[@]}"; do
    start_test "service-auto-enable.sh defines $fn"
    if type "$fn" &>/dev/null; then
        pass_test
    else
        fail_test "Function not defined: $fn"
    fi
done

print_summary
