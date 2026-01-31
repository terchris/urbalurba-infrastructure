#!/bin/bash
# test-backwards-compat-paths.sh - Test backwards-compatible path patterns in scripts
#
# Tests that scripts properly implement the backwards-compatible path pattern:
# 1. Source paths.sh if available
# 2. Fall back to hardcoded legacy paths
# 3. Accept both new and legacy environment directories

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/../lib/test-framework.sh"

print_test_section "Backwards-Compatible Path Pattern Tests"

# ============================================================================
# Test: Scripts contain paths.sh sourcing pattern
# ============================================================================

echo "Checking scripts for paths.sh sourcing pattern..."

# Scripts that should source paths.sh
PATHS_SCRIPTS=(
    "networking/cloudflare/820-cloudflare-tunnel-setup.sh"
    "networking/cloudflare/821-cloudflare-tunnel-deploy.sh"
    "networking/cloudflare/822-cloudflare-tunnel-delete.sh"
    "networking/tailscale/802-tailscale-tunnel-deploy.sh"
    "hosts/azure-aks/02-azure-aks-setup.sh"
    "hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh"
    "hosts/azure-microk8s/02-azure-ansible-inventory-v2.sh"
    "cloud-init/create-cloud-init.sh"
)

for script in "${PATHS_SCRIPTS[@]}"; do
    start_test "$script has paths.sh sourcing pattern"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        if grep -q "paths.sh" "$REPO_ROOT/$script"; then
            pass_test
        else
            fail_test "Script does not reference paths.sh"
        fi
    else
        skip_test "Script not found"
    fi
done

# ============================================================================
# Test: Scripts that USE path functions have fallback pattern
# ============================================================================

print_test_section "Fallback Pattern Tests"

echo "Checking scripts that use path functions have fallbacks..."

# Only scripts that actually call get_* functions need fallback
SCRIPTS_NEEDING_FALLBACK=(
    "networking/cloudflare/820-cloudflare-tunnel-setup.sh"
    "networking/cloudflare/821-cloudflare-tunnel-deploy.sh"
    "networking/cloudflare/822-cloudflare-tunnel-delete.sh"
    "hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh"
    "hosts/azure-microk8s/02-azure-ansible-inventory-v2.sh"
    "cloud-init/create-cloud-init.sh"
)

for script in "${SCRIPTS_NEEDING_FALLBACK[@]}"; do
    start_test "$script has fallback when paths.sh unavailable"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        # Check for the else clause in the same if-block as paths.sh source
        if grep -A20 "if.*paths.sh" "$REPO_ROOT/$script" | grep -q "else"; then
            pass_test
        else
            fail_test "No fallback pattern found"
        fi
    else
        skip_test "Script not found"
    fi
done

# Scripts that source paths.sh but don't use functions yet - just verify they source it
SCRIPTS_OPTIONAL_PATHS=(
    "networking/tailscale/802-tailscale-tunnel-deploy.sh"
    "hosts/azure-aks/02-azure-aks-setup.sh"
)

for script in "${SCRIPTS_OPTIONAL_PATHS[@]}"; do
    start_test "$script sources paths.sh (functions not yet used)"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        if grep -q "source.*paths.sh" "$REPO_ROOT/$script"; then
            pass_test
        else
            fail_test "Script does not source paths.sh"
        fi
    else
        skip_test "Script not found"
    fi
done

# ============================================================================
# Test: Environment checks accept both new and legacy paths
# ============================================================================

print_test_section "Environment Check Pattern Tests"

# Scripts that have environment checks for secrets directories
ENV_CHECK_SCRIPTS=(
    "networking/cloudflare/821-cloudflare-tunnel-deploy.sh"
    "networking/tailscale/802-tailscale-tunnel-deploy.sh"
)

for script in "${ENV_CHECK_SCRIPTS[@]}"; do
    start_test "$script accepts both .uis.secrets and topsecret"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        # Should check for both new and legacy paths
        if grep -q ".uis.secrets" "$REPO_ROOT/$script" && grep -q "topsecret" "$REPO_ROOT/$script"; then
            pass_test
        else
            fail_test "Missing dual-path check"
        fi
    else
        skip_test "Script not found"
    fi
done

# ============================================================================
# Test: Root scripts check for both paths
# ============================================================================

print_test_section "Root Script Path Tests"

start_test "install-rancher.sh checks for .uis.secrets or topsecret"
if grep -q ".uis.secrets" "$REPO_ROOT/install-rancher.sh" && grep -q "topsecret" "$REPO_ROOT/install-rancher.sh"; then
    pass_test
else
    fail_test "Missing dual-path check"
fi

start_test "copy2provisionhost.sh copies both .uis.secrets and topsecret"
if grep -q ".uis.secrets" "$REPO_ROOT/copy2provisionhost.sh" && grep -q "topsecret" "$REPO_ROOT/copy2provisionhost.sh"; then
    pass_test
else
    fail_test "Missing dual-path copying"
fi

start_test "provision-host-rancher/provision-host-container-create.sh copies both paths"
if grep -q ".uis.secrets" "$REPO_ROOT/provision-host-rancher/provision-host-container-create.sh" && \
   grep -q "topsecret" "$REPO_ROOT/provision-host-rancher/provision-host-container-create.sh"; then
    pass_test
else
    fail_test "Missing dual-path copying"
fi

# ============================================================================
# Test: Bash syntax validation for all modified scripts
# ============================================================================

print_test_section "Bash Syntax Validation"

ALL_MODIFIED_SCRIPTS=(
    "copy2provisionhost.sh"
    "hosts/azure-microk8s/02-azure-ansible-inventory-v2.sh"
    "hosts/install-rancher-kubernetes.sh"
    "install-rancher.sh"
    "networking/cloudflare/820-cloudflare-tunnel-setup.sh"
    "networking/cloudflare/821-cloudflare-tunnel-deploy.sh"
    "networking/cloudflare/822-cloudflare-tunnel-delete.sh"
    "provision-host-rancher/provision-host-container-create.sh"
    "provision-host/provision-host-02-kubetools.sh"
    "provision-host/provision-host-sshconf.sh"
    "provision-host/provision-host-vm-create.sh"
)

for script in "${ALL_MODIFIED_SCRIPTS[@]}"; do
    start_test "$script has valid bash syntax"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        if bash -n "$REPO_ROOT/$script" 2>/dev/null; then
            pass_test
        else
            fail_test "Syntax error in script"
        fi
    else
        skip_test "Script not found"
    fi
done

# ============================================================================
# Test: K8S_SECRETS_PATH variable pattern
# ============================================================================

print_test_section "K8S Secrets Path Variable Tests"

# Cloudflare scripts should use K8S_SECRETS_PATH variable
for script in "networking/cloudflare/820-cloudflare-tunnel-setup.sh" \
              "networking/cloudflare/821-cloudflare-tunnel-deploy.sh" \
              "networking/cloudflare/822-cloudflare-tunnel-delete.sh"; do
    start_test "$script uses K8S_SECRETS_PATH variable"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        if grep -q "K8S_SECRETS_PATH" "$REPO_ROOT/$script"; then
            pass_test
        else
            fail_test "Missing K8S_SECRETS_PATH variable"
        fi
    else
        skip_test "Script not found"
    fi
done

# ============================================================================
# Test: SSH key path checks in provision-host scripts
# ============================================================================

print_test_section "SSH Key Path Tests"

start_test "provision-host-vm-create.sh checks both SSH key paths"
if grep -q ".uis.secrets/ssh" "$REPO_ROOT/provision-host/provision-host-vm-create.sh" && \
   grep -q "secrets/id_rsa_ansible" "$REPO_ROOT/provision-host/provision-host-vm-create.sh"; then
    pass_test
else
    fail_test "Missing dual SSH key path check"
fi

start_test "provision-host-sshconf.sh checks both SSH key paths"
if grep -q ".uis.secrets/ssh" "$REPO_ROOT/provision-host/provision-host-sshconf.sh" && \
   grep -q "secrets/id_rsa_ansible" "$REPO_ROOT/provision-host/provision-host-sshconf.sh"; then
    pass_test
else
    fail_test "Missing dual SSH key path check"
fi

start_test "provision-host-02-kubetools.sh has dynamic SSH key path"
if grep -q ".uis.secrets/ssh" "$REPO_ROOT/provision-host/provision-host-02-kubetools.sh" && \
   grep -q "SSH_KEY_PATH" "$REPO_ROOT/provision-host/provision-host-02-kubetools.sh"; then
    pass_test
else
    fail_test "Missing dynamic SSH key path"
fi

# ============================================================================
# Test: Deprecated scripts have deprecation notices
# ============================================================================

print_test_section "Deprecation Notice Tests"

DEPRECATED_SCRIPTS=(
    "topsecret/update-kubernetes-secrets-rancher.sh"
    "topsecret/kubeconf-copy2local.sh"
    "topsecret/copy-secrets2host.sh"
)

for script in "${DEPRECATED_SCRIPTS[@]}"; do
    start_test "$script has DEPRECATED header"
    if [[ -f "$REPO_ROOT/$script" ]]; then
        if grep -q "DEPRECATED" "$REPO_ROOT/$script"; then
            pass_test
        else
            fail_test "Missing DEPRECATED notice"
        fi
    else
        skip_test "Script not found"
    fi
done

start_test "topsecret/DEPRECATED.md exists"
if [[ -f "$REPO_ROOT/topsecret/DEPRECATED.md" ]]; then
    pass_test
else
    fail_test "DEPRECATED.md not found"
fi

start_test "DEPRECATED.md explains migration"
if [[ -f "$REPO_ROOT/topsecret/DEPRECATED.md" ]]; then
    if grep -q "Migration Guide" "$REPO_ROOT/topsecret/DEPRECATED.md"; then
        pass_test
    else
        fail_test "Missing migration guide"
    fi
else
    skip_test "File not found"
fi

# ============================================================================
# Test: UIS wrapper mounts (Phase 8)
# ============================================================================

print_test_section "UIS Wrapper Mount Tests"

start_test "uis wrapper mounts .uis.extend"
if grep -q '\.uis\.extend:/mnt/urbalurbadisk/\.uis\.extend' "$REPO_ROOT/uis"; then
    pass_test
else
    fail_test "Missing .uis.extend mount"
fi

start_test "uis wrapper mounts .uis.secrets"
if grep -q '\.uis\.secrets:/mnt/urbalurbadisk/\.uis\.secrets' "$REPO_ROOT/uis"; then
    pass_test
else
    fail_test "Missing .uis.secrets mount"
fi

start_test "uis wrapper mounts topsecret (backwards compat)"
if grep -q 'topsecret:/mnt/urbalurbadisk/topsecret' "$REPO_ROOT/uis"; then
    pass_test
else
    fail_test "Missing topsecret mount"
fi

start_test "uis wrapper mounts secrets directory (backwards compat)"
if grep -q 'secrets:/mnt/urbalurbadisk/secrets' "$REPO_ROOT/uis"; then
    pass_test
else
    fail_test "Missing secrets mount"
fi

start_test "uis wrapper creates kubeconfig symlinks"
if grep -q 'kubeconfig/kubeconf-all' "$REPO_ROOT/uis"; then
    pass_test
else
    fail_test "Missing kubeconfig symlink creation"
fi

# ============================================================================
# Test: Kubeconfig playbook supports both paths (Phase 8)
# ============================================================================

print_test_section "Kubeconfig Playbook Tests"

start_test "04-merge-kubeconf.yml has new path variable"
if grep -q 'new_kubernetes_files_path' "$REPO_ROOT/ansible/playbooks/04-merge-kubeconf.yml"; then
    pass_test
else
    fail_test "Missing new_kubernetes_files_path variable"
fi

start_test "04-merge-kubeconf.yml has legacy path variable"
if grep -q 'legacy_kubernetes_files_path' "$REPO_ROOT/ansible/playbooks/04-merge-kubeconf.yml"; then
    pass_test
else
    fail_test "Missing legacy_kubernetes_files_path variable"
fi

start_test "04-merge-kubeconf.yml checks which path exists"
if grep -q 'Check if new kubeconfig path exists' "$REPO_ROOT/ansible/playbooks/04-merge-kubeconf.yml"; then
    pass_test
else
    fail_test "Missing path existence check"
fi

start_test "04-merge-kubeconf.yml shows deprecation warning"
if grep -q 'Using legacy kubeconfig path' "$REPO_ROOT/ansible/playbooks/04-merge-kubeconf.yml"; then
    pass_test
else
    fail_test "Missing deprecation warning"
fi

# Print summary
print_summary
