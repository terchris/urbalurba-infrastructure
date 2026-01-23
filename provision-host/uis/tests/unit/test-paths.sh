#!/bin/bash
# test-paths.sh - Unit tests for paths.sh library
#
# Tests the centralized path detection functions

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../lib/test-framework.sh"

# Get UIS root
UIS_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB_DIR="$UIS_ROOT/lib"

# Source the library
source "$LIB_DIR/paths.sh"

echo ""
echo "=== Paths Library Tests ==="

# ============================================================
# Library Loading Tests
# ============================================================

start_test "paths.sh exists"
assert_file_exists "$LIB_DIR/paths.sh" && pass_test

start_test "paths.sh loads without error"
(source "$LIB_DIR/paths.sh" 2>/dev/null) && pass_test

start_test "_UIS_PATHS_LOADED is set"
[[ -n "$_UIS_PATHS_LOADED" ]] && pass_test

# ============================================================
# Core Function Definition Tests
# ============================================================

start_test "get_templates_dir is defined"
type get_templates_dir &>/dev/null && pass_test

start_test "get_extend_dir is defined"
type get_extend_dir &>/dev/null && pass_test

start_test "get_secrets_dir is defined"
type get_secrets_dir &>/dev/null && pass_test

start_test "get_services_dir is defined"
type get_services_dir &>/dev/null && pass_test

start_test "get_tools_dir is defined"
type get_tools_dir &>/dev/null && pass_test

# ============================================================
# Derived Function Definition Tests
# ============================================================

start_test "get_hosts_templates_dir is defined"
type get_hosts_templates_dir &>/dev/null && pass_test

start_test "get_secrets_templates_dir is defined"
type get_secrets_templates_dir &>/dev/null && pass_test

start_test "get_cloud_init_templates_dir is defined"
type get_cloud_init_templates_dir &>/dev/null && pass_test

# ============================================================
# Global Variable Tests
# ============================================================

start_test "TEMPLATES_DIR is set"
[[ -n "$TEMPLATES_DIR" ]] && pass_test

start_test "EXTEND_DIR is set"
[[ -n "$EXTEND_DIR" ]] && pass_test

start_test "SECRETS_DIR is set"
[[ -n "$SECRETS_DIR" ]] && pass_test

start_test "SERVICES_DIR is set"
[[ -n "$SERVICES_DIR" ]] && pass_test

start_test "TOOLS_DIR is set"
[[ -n "$TOOLS_DIR" ]] && pass_test

# ============================================================
# Path Value Tests
# ============================================================

start_test "get_templates_dir returns valid path"
result=$(get_templates_dir)
[[ -d "$result" ]] && pass_test

start_test "get_services_dir returns valid path"
result=$(get_services_dir)
[[ -d "$result" ]] && pass_test

start_test "get_tools_dir returns valid path"
result=$(get_tools_dir)
[[ -d "$result" ]] && pass_test

start_test "get_hosts_templates_dir returns path containing uis.extend/hosts"
result=$(get_hosts_templates_dir)
[[ "$result" == *"uis.extend/hosts"* ]] && pass_test

start_test "get_secrets_templates_dir returns path containing uis.secrets"
result=$(get_secrets_templates_dir)
[[ "$result" == *"uis.secrets"* ]] && pass_test

start_test "get_cloud_init_templates_dir returns path containing ubuntu-cloud-init"
result=$(get_cloud_init_templates_dir)
[[ "$result" == *"ubuntu-cloud-init"* ]] && pass_test

# ============================================================
# Consistency Tests
# ============================================================

start_test "TEMPLATES_DIR matches get_templates_dir"
[[ "$TEMPLATES_DIR" == "$(get_templates_dir)" ]] && pass_test

start_test "EXTEND_DIR matches get_extend_dir"
[[ "$EXTEND_DIR" == "$(get_extend_dir)" ]] && pass_test

start_test "SECRETS_DIR matches get_secrets_dir"
[[ "$SECRETS_DIR" == "$(get_secrets_dir)" ]] && pass_test

start_test "SERVICES_DIR matches get_services_dir"
[[ "$SERVICES_DIR" == "$(get_services_dir)" ]] && pass_test

start_test "TOOLS_DIR matches get_tools_dir"
[[ "$TOOLS_DIR" == "$(get_tools_dir)" ]] && pass_test

# ============================================================
# Path Format Tests
# ============================================================

start_test "EXTEND_DIR ends with .uis.extend"
[[ "$EXTEND_DIR" == *".uis.extend" ]] && pass_test

start_test "SECRETS_DIR ends with .uis.secrets"
[[ "$SECRETS_DIR" == *".uis.secrets" ]] && pass_test

start_test "TEMPLATES_DIR ends with templates"
[[ "$TEMPLATES_DIR" == *"templates" ]] && pass_test

start_test "SERVICES_DIR ends with services"
[[ "$SERVICES_DIR" == *"services" ]] && pass_test

start_test "TOOLS_DIR ends with tools"
[[ "$TOOLS_DIR" == *"tools" ]] && pass_test

# Print summary
print_summary
