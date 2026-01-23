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

# ============================================================
# Legacy Path Constants Tests
# ============================================================

start_test "NEW_SECRETS_BASE is defined"
[[ -n "$NEW_SECRETS_BASE" ]] && pass_test

start_test "OLD_SECRETS_BASE is defined"
[[ -n "$OLD_SECRETS_BASE" ]] && pass_test

start_test "OLD_SSH_BASE is defined"
[[ -n "$OLD_SSH_BASE" ]] && pass_test

start_test "NEW_SECRETS_BASE contains .uis.secrets"
[[ "$NEW_SECRETS_BASE" == *".uis.secrets"* ]] && pass_test

start_test "OLD_SECRETS_BASE contains topsecret"
[[ "$OLD_SECRETS_BASE" == *"topsecret"* ]] && pass_test

# ============================================================
# Backwards-Compatible Function Definition Tests
# ============================================================

start_test "warn_deprecated_path is defined"
type warn_deprecated_path &>/dev/null && pass_test

start_test "get_secrets_base_path is defined"
type get_secrets_base_path &>/dev/null && pass_test

start_test "get_ssh_key_path is defined"
type get_ssh_key_path &>/dev/null && pass_test

start_test "get_kubernetes_secrets_path is defined"
type get_kubernetes_secrets_path &>/dev/null && pass_test

start_test "get_cloud_init_output_path is defined"
type get_cloud_init_output_path &>/dev/null && pass_test

start_test "get_kubeconfig_path is defined"
type get_kubeconfig_path &>/dev/null && pass_test

start_test "get_tailscale_key_path is defined"
type get_tailscale_key_path &>/dev/null && pass_test

start_test "get_cloudflare_token_path is defined"
type get_cloudflare_token_path &>/dev/null && pass_test

start_test "get_cloud_credentials_path is defined"
type get_cloud_credentials_path &>/dev/null && pass_test

start_test "is_using_new_paths is defined"
type is_using_new_paths &>/dev/null && pass_test

start_test "is_using_legacy_paths is defined"
type is_using_legacy_paths &>/dev/null && pass_test

start_test "ensure_path_exists is defined"
type ensure_path_exists &>/dev/null && pass_test

# ============================================================
# Backwards-Compatible Function Output Tests
# ============================================================

start_test "get_secrets_base_path returns a path"
result=$(get_secrets_base_path 2>/dev/null)
[[ -n "$result" ]] && pass_test

start_test "get_ssh_key_path returns path containing ssh"
result=$(get_ssh_key_path 2>/dev/null)
[[ "$result" == *"ssh"* ]] && pass_test

start_test "get_kubernetes_secrets_path returns path containing kubernetes"
result=$(get_kubernetes_secrets_path 2>/dev/null)
[[ "$result" == *"kubernetes"* ]] && pass_test

start_test "get_cloud_init_output_path returns path containing cloud-init"
result=$(get_cloud_init_output_path 2>/dev/null)
[[ "$result" == *"cloud-init"* ]] && pass_test

start_test "get_kubeconfig_path returns path containing kubeconfig"
result=$(get_kubeconfig_path 2>/dev/null)
[[ "$result" == *"kubeconfig"* ]] && pass_test

start_test "get_tailscale_key_path returns path containing tailscale"
result=$(get_tailscale_key_path 2>/dev/null)
[[ "$result" == *"tailscale"* ]] && pass_test

start_test "get_cloudflare_token_path returns path containing cloudflare"
result=$(get_cloudflare_token_path 2>/dev/null)
[[ "$result" == *"cloudflare"* ]] && pass_test

start_test "get_cloud_credentials_path returns path for azure"
result=$(get_cloud_credentials_path "azure" 2>/dev/null)
[[ "$result" == *"azure"* ]] && pass_test

start_test "get_cloud_credentials_path returns path for gcp"
result=$(get_cloud_credentials_path "gcp" 2>/dev/null)
[[ "$result" == *"gcp"* ]] && pass_test

# ============================================================
# New Path Preference Tests
# ============================================================

start_test "get_secrets_base_path prefers new path when available"
# On test system, new path should be preferred
result=$(get_secrets_base_path 2>/dev/null)
[[ "$result" == *".uis.secrets"* ]] && pass_test

start_test "get_ssh_key_path prefers new path structure"
result=$(get_ssh_key_path 2>/dev/null)
[[ "$result" == *".uis.secrets/ssh"* ]] && pass_test

start_test "get_kubernetes_secrets_path uses new generated path"
result=$(get_kubernetes_secrets_path 2>/dev/null)
[[ "$result" == *".uis.secrets/generated/kubernetes"* ]] && pass_test

start_test "get_cloud_init_output_path uses new generated path"
result=$(get_cloud_init_output_path 2>/dev/null)
[[ "$result" == *".uis.secrets/generated/ubuntu-cloud-init"* ]] && pass_test

start_test "get_kubeconfig_path uses new generated path"
result=$(get_kubeconfig_path 2>/dev/null)
[[ "$result" == *".uis.secrets/generated/kubeconfig"* ]] && pass_test

# Print summary
print_summary
