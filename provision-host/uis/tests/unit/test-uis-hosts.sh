#!/bin/bash
# test-uis-hosts.sh - Unit tests for uis-hosts.sh library
#
# Tests the host management library functions

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_DIR/../lib/test-framework.sh"

# Get UIS root
UIS_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
LIB_DIR="$UIS_ROOT/lib"
TEMPLATES_DIR="$UIS_ROOT/templates"

# Source the library
source "$LIB_DIR/uis-hosts.sh"

echo ""
echo "=== UIS Hosts Library Tests ==="

# ============================================================
# Library Loading Tests
# ============================================================

start_test "uis-hosts.sh exists"
assert_file_exists "$LIB_DIR/uis-hosts.sh" && pass_test

start_test "uis-hosts.sh loads without error"
(source "$LIB_DIR/uis-hosts.sh" 2>/dev/null) && pass_test

# ============================================================
# Function Definition Tests
# ============================================================

start_test "hosts_list_templates is defined"
type hosts_list_templates &>/dev/null && pass_test

start_test "hosts_get_all_templates is defined"
type hosts_get_all_templates &>/dev/null && pass_test

start_test "hosts_template_exists is defined"
type hosts_template_exists &>/dev/null && pass_test

start_test "hosts_get_type is defined"
type hosts_get_type &>/dev/null && pass_test

start_test "hosts_get_template_path is defined"
type hosts_get_template_path &>/dev/null && pass_test

start_test "hosts_requires_ssh is defined"
type hosts_requires_ssh &>/dev/null && pass_test

start_test "hosts_requires_tailscale is defined"
type hosts_requires_tailscale &>/dev/null && pass_test

start_test "hosts_requires_cloud_credentials is defined"
type hosts_requires_cloud_credentials &>/dev/null && pass_test

start_test "hosts_get_cloud_init_template is defined"
type hosts_get_cloud_init_template &>/dev/null && pass_test

start_test "hosts_list_configured is defined"
type hosts_list_configured &>/dev/null && pass_test

start_test "hosts_add_template is defined"
type hosts_add_template &>/dev/null && pass_test

# ============================================================
# Host Type Info Tests
# ============================================================

start_test "_get_host_type_info returns description for managed"
result=$(_get_host_type_info "managed")
[[ "$result" == *"Kubernetes"* ]] && pass_test

start_test "_get_host_type_info returns description for cloud-vm"
result=$(_get_host_type_info "cloud-vm")
[[ "$result" == *"MicroK8s"* ]] && pass_test

start_test "_get_host_type_info returns description for physical"
result=$(_get_host_type_info "physical")
[[ "$result" == *"Physical"* ]] && pass_test

start_test "_get_host_type_info returns description for local"
result=$(_get_host_type_info "local")
[[ "$result" == *"Local"* ]] && pass_test

# ============================================================
# Cloud-Init Template Tests
# ============================================================

start_test "_get_cloud_init_template returns template for azure-microk8s"
result=$(_get_cloud_init_template "azure-microk8s")
[[ "$result" == "azure-cloud-init-template.yml" ]] && pass_test

start_test "_get_cloud_init_template returns template for raspberry-pi"
result=$(_get_cloud_init_template "raspberry-pi")
[[ "$result" == "raspberry-cloud-init-template.yml" ]] && pass_test

start_test "_get_cloud_init_template returns empty for unknown template"
result=$(_get_cloud_init_template "nonexistent")
[[ -z "$result" ]] && pass_test

# ============================================================
# Host Requirements Tests
# ============================================================

start_test "hosts_requires_ssh returns 0 for physical"
hosts_requires_ssh "physical" && pass_test

start_test "hosts_requires_ssh returns 0 for cloud-vm"
hosts_requires_ssh "cloud-vm" && pass_test

start_test "hosts_requires_ssh returns 1 for managed"
! hosts_requires_ssh "managed" && pass_test

start_test "hosts_requires_ssh returns 1 for local"
! hosts_requires_ssh "local" && pass_test

start_test "hosts_requires_tailscale returns 0 for physical"
hosts_requires_tailscale "physical" && pass_test

start_test "hosts_requires_tailscale returns 0 for cloud-vm"
hosts_requires_tailscale "cloud-vm" && pass_test

start_test "hosts_requires_tailscale returns 1 for managed"
! hosts_requires_tailscale "managed" && pass_test

start_test "hosts_requires_cloud_credentials returns 0 for managed"
hosts_requires_cloud_credentials "managed" && pass_test

start_test "hosts_requires_cloud_credentials returns 0 for cloud-vm"
hosts_requires_cloud_credentials "cloud-vm" && pass_test

start_test "hosts_requires_cloud_credentials returns 1 for physical"
! hosts_requires_cloud_credentials "physical" && pass_test

start_test "hosts_requires_cloud_credentials returns 1 for local"
! hosts_requires_cloud_credentials "local" && pass_test

# ============================================================
# Template Discovery Tests
# ============================================================

start_test "hosts_template_exists returns 0 for azure-aks"
hosts_template_exists "azure-aks" && pass_test

start_test "hosts_template_exists returns 0 for raspberry-pi"
hosts_template_exists "raspberry-pi" && pass_test

start_test "hosts_template_exists returns 0 for rancher-desktop"
hosts_template_exists "rancher-desktop" && pass_test

start_test "hosts_template_exists returns 1 for nonexistent"
! hosts_template_exists "nonexistent-template" && pass_test

start_test "hosts_get_type returns managed for azure-aks"
result=$(hosts_get_type "azure-aks")
[[ "$result" == "managed" ]] && pass_test

start_test "hosts_get_type returns physical for raspberry-pi"
result=$(hosts_get_type "raspberry-pi")
[[ "$result" == "physical" ]] && pass_test

start_test "hosts_get_type returns cloud-vm for azure-microk8s"
result=$(hosts_get_type "azure-microk8s")
[[ "$result" == "cloud-vm" ]] && pass_test

start_test "hosts_get_type returns local for rancher-desktop"
result=$(hosts_get_type "rancher-desktop")
[[ "$result" == "local" ]] && pass_test

start_test "hosts_get_template_path returns valid path for azure-aks"
result=$(hosts_get_template_path "azure-aks")
[[ -f "$result" ]] && pass_test

start_test "hosts_get_all_templates includes azure-aks"
result=$(hosts_get_all_templates)
[[ "$result" == *"azure-aks"* ]] && pass_test

start_test "hosts_get_all_templates includes raspberry-pi"
result=$(hosts_get_all_templates)
[[ "$result" == *"raspberry-pi"* ]] && pass_test

# ============================================================
# Output Tests
# ============================================================

start_test "hosts_list_templates produces output"
result=$(hosts_list_templates 2>&1)
[[ -n "$result" ]] && pass_test

start_test "hosts_list_templates shows managed section"
result=$(hosts_list_templates 2>&1)
[[ "$result" == *"managed/"* ]] && pass_test

start_test "hosts_list_templates shows Usage line"
result=$(hosts_list_templates 2>&1)
[[ "$result" == *"Usage:"* ]] && pass_test

start_test "hosts_list_configured produces output"
result=$(hosts_list_configured 2>&1)
[[ -n "$result" ]] && pass_test

# Print summary
print_summary
