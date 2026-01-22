#!/bin/bash
# test-enable-disable.sh - Enable/disable integration tests
#
# Tests the enable/disable functionality using a temporary config file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine paths (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis" ]]; then
    LIB_DIR="/mnt/urbalurbadisk/provision-host/uis/lib"
    TEMPLATES_DIR="/mnt/urbalurbadisk/provision-host/uis/templates"
else
    LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
    TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../../templates" && pwd)"
fi

# Create temp directory for test
TEST_CONFIG_DIR="/tmp/test-uis-config-$$"
mkdir -p "$TEST_CONFIG_DIR"

# Export to override default paths
export CONFIG_DIR="$TEST_CONFIG_DIR"

# Source libraries with temp config dir
source "$LIB_DIR/logging.sh" 2>/dev/null
source "$LIB_DIR/utilities.sh" 2>/dev/null
source "$LIB_DIR/service-scanner.sh" 2>/dev/null
source "$LIB_DIR/service-auto-enable.sh" 2>/dev/null

print_test_section "Phase 4: Enable/Disable Integration Tests"

# ============================================================
# Setup: Create test config file
# ============================================================

# Copy default config to test directory
cp "$TEMPLATES_DIR/uis.extend/enabled-services.conf.default" "$TEST_CONFIG_DIR/enabled-services.conf"

# ============================================================
# Test initial state
# ============================================================

start_test "nginx is enabled by default"
if is_service_enabled "nginx"; then
    pass_test
else
    fail_test "nginx should be enabled in default config"
fi

start_test "prometheus is NOT enabled by default"
if ! is_service_enabled "prometheus"; then
    pass_test
else
    fail_test "prometheus should NOT be enabled in default config"
fi

start_test "list_enabled_services returns nginx"
if list_enabled_services | grep -q "nginx"; then
    pass_test
else
    fail_test "nginx should be in list of enabled services"
fi

# ============================================================
# Test enable functionality
# ============================================================

start_test "enable_service adds prometheus"
enable_service "prometheus" >/dev/null 2>&1
if is_service_enabled "prometheus"; then
    pass_test
else
    fail_test "prometheus should be enabled after enable_service"
fi

start_test "enable_service adds grafana"
enable_service "grafana" >/dev/null 2>&1
if is_service_enabled "grafana"; then
    pass_test
else
    fail_test "grafana should be enabled after enable_service"
fi

start_test "count_enabled_services returns 3"
count=$(count_enabled_services)
if [[ "$count" == "3" ]]; then
    pass_test
else
    fail_test "Expected 3 enabled services, got $count"
fi

start_test "enabling already enabled service succeeds"
if enable_service "nginx" >/dev/null 2>&1; then
    pass_test
else
    fail_test "enabling already enabled service should succeed"
fi

# ============================================================
# Test disable functionality
# ============================================================

start_test "disable_service removes prometheus"
disable_service "prometheus" >/dev/null 2>&1
if ! is_service_enabled "prometheus"; then
    pass_test
else
    fail_test "prometheus should not be enabled after disable_service"
fi

start_test "count_enabled_services returns 2 after disable"
count=$(count_enabled_services)
if [[ "$count" == "2" ]]; then
    pass_test
else
    fail_test "Expected 2 enabled services, got $count"
fi

start_test "disabling already disabled service succeeds"
if disable_service "prometheus" >/dev/null 2>&1; then
    pass_test
else
    fail_test "disabling already disabled service should succeed"
fi

# ============================================================
# Test toggle functionality
# ============================================================

start_test "toggle_service enables redis (was disabled)"
toggle_service "redis" >/dev/null 2>&1
if is_service_enabled "redis"; then
    pass_test
else
    fail_test "redis should be enabled after toggle"
fi

start_test "toggle_service disables redis (was enabled)"
toggle_service "redis" >/dev/null 2>&1
if ! is_service_enabled "redis"; then
    pass_test
else
    fail_test "redis should be disabled after toggle"
fi

# ============================================================
# Test with non-existent service
# ============================================================

start_test "enable_service fails for non-existent service"
if ! enable_service "non-existent-service-xyz" >/dev/null 2>&1; then
    pass_test
else
    fail_test "enabling non-existent service should fail"
fi

# ============================================================
# Cleanup
# ============================================================

rm -rf "$TEST_CONFIG_DIR"

print_summary
