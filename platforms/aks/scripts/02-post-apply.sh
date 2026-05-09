#!/bin/bash
# File: platforms/aks/scripts/02-post-apply.sh
#
# Description:
#   Post-apply cluster configuration:
#     1. Merge AKS kubeconfig into the unified kubeconf-all
#     2. Apply storage class aliases (Azure Disk → local-path / microk8s-hostpath)
#     3. Install Traefik ingress controller
#     4. Validate and report external IP
#
# Prerequisites:
#   - scripts/01-apply.sh completed successfully
#   - Kubeconfig written to $KUBECONFIG_FILE
#
# Usage:
#   ./scripts/02-post-apply.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_section() { echo; echo -e "${GREEN}========================================${NC}"; echo -e "${GREEN}$1${NC}"; echo -e "${GREEN}========================================${NC}"; echo; }

# ─── Environment check ────────────────────────────────────────────────────────
if [[ ! -f /.dockerenv ]] || [[ ! -d /mnt/urbalurbadisk ]]; then
    print_error "This script must run inside the provision-host container"
    exit 1
fi

# ─── Load config from .uis.secrets/cloud-accounts/azure-default.env ───────────
source "/mnt/urbalurbadisk/provision-host/uis/lib/paths.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/.."
CONFIG_FILE="$(get_cloud_credentials_path azure)"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Azure cloud-account config not found: $CONFIG_FILE"
    echo "  Have you run 00-bootstrap-state.sh and 01-apply.sh first?"
    exit 1
fi

source "$CONFIG_FILE"

# Inline defaults (only the ones referenced in this script)
AZURE_AKS_CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:-azure-aks}"

# Derived. Both the per-cluster file and the merged file live under
# $(get_kubeconfig_path) — the canonical UIS kubeconfig directory.
KUBECONFIG_DIR="$(get_kubeconfig_path)"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/${AZURE_AKS_CLUSTER_NAME}-kubeconf"
MERGED_KUBECONFIG="${KUBECONFIG_DIR}/kubeconf-all"

print_section "AKS PLATFORM — POST-APPLY SETUP"

# ─── Step 1: Merge kubeconfig ─────────────────────────────────────────────────
# 01-apply.sh wrote $KUBECONFIG_FILE into $KUBECONFIG_DIR (the canonical UIS
# location). 04-merge-kubeconf.yml reads the same directory and writes the
# merged kubeconf-all there. So we point KUBECONFIG straight at $MERGED_KUBECONFIG
# without any cross-directory copying.
print_section "Step 1: Merge kubeconfig"

ANSIBLE_PLAYBOOK="/mnt/urbalurbadisk/ansible/playbooks/04-merge-kubeconf.yml"
if [[ -f "$ANSIBLE_PLAYBOOK" ]]; then
    cd /mnt/urbalurbadisk
    ansible-playbook "$ANSIBLE_PLAYBOOK"
    print_success "Kubeconfig merged via Ansible"
else
    print_warning "Ansible playbook not found — using AKS kubeconfig directly"
    export KUBECONFIG="$KUBECONFIG_FILE"
fi

export KUBECONFIG="$MERGED_KUBECONFIG"

# ─── Step 2: Switch context ───────────────────────────────────────────────────
print_status "Switching to $AZURE_AKS_CLUSTER_NAME context..."
kubectl config use-context "$AZURE_AKS_CLUSTER_NAME"

NODE_COUNT_ACTUAL=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [[ "$NODE_COUNT_ACTUAL" -eq 0 ]]; then
    print_error "No nodes found — check cluster status"
    exit 1
fi
print_success "Connected — $NODE_COUNT_ACTUAL node(s) ready"

# ─── Step 3: Storage class aliases ────────────────────────────────────────────
print_section "Step 2: Storage class aliases"

STORAGE_MANIFEST="$PLATFORM_DIR/manifests/000-storage-class-azure-alias.yaml"
if [[ ! -f "$STORAGE_MANIFEST" ]]; then
    print_error "Manifest not found: $STORAGE_MANIFEST"
    exit 1
fi

kubectl apply -f "$STORAGE_MANIFEST"
print_success "Storage class aliases applied"

# ─── Step 4: Install Traefik via the shared UIS playbook ──────────────────────
# Single source of truth for Traefik across all UIS platforms (rancher-desktop
# k3s, AKS, GCP, AWS, …). Chart version + proxy image pin live in the playbook
# and the values file — not duplicated here. See:
#   ansible/playbooks/003-setup-traefik.yml
#   manifests/003-traefik-config.yaml
print_section "Step 3: Install Traefik"

ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/003-setup-traefik.yml \
    -e "target_host=$CLUSTER_NAME"
print_success "Traefik playbook complete"

# ─── Step 5: External IP ──────────────────────────────────────────────────────
print_section "Step 4: External IP"

ATTEMPTS=0
EXTERNAL_IP=""
while [[ $ATTEMPTS -lt 24 ]]; do
    EXTERNAL_IP=$(kubectl get svc traefik -n kube-system \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]] && break
    [[ $ATTEMPTS -eq 0 ]] && echo -n "Waiting for external IP"
    echo -n "."
    sleep 5
    ((ATTEMPTS++))
done
echo

if [[ -n "$EXTERNAL_IP" && "$EXTERNAL_IP" != "null" ]]; then
    print_success "External IP: $EXTERNAL_IP"
else
    print_warning "No external IP yet — check later:"
    echo "  kubectl get svc traefik -n kube-system"
fi

# ─── Step 5: Point UIS at the new AKS cluster ─────────────────────────────────
# Without this, ./uis deploy <service> would still target rancher-desktop
# (the default in cluster-config.sh). Flip CLUSTER_TYPE + TARGET_HOST so the
# next deploy hits the AKS cluster the operator just created.
print_section "Step 5: Switch UIS target to AKS"

CLUSTER_CONFIG="/mnt/urbalurbadisk/.uis.extend/cluster-config.sh"
if [[ -f "$CLUSTER_CONFIG" ]]; then
    sed -i.bak \
        -e "s|^CLUSTER_TYPE=.*|CLUSTER_TYPE=\"azure-aks\"|" \
        -e "s|^TARGET_HOST=.*|TARGET_HOST=\"${AZURE_AKS_CLUSTER_NAME}\"|" \
        "$CLUSTER_CONFIG"
    rm -f "${CLUSTER_CONFIG}.bak"
    print_success "cluster-config.sh now points at: CLUSTER_TYPE=azure-aks, TARGET_HOST=${AZURE_AKS_CLUSTER_NAME}"
    echo "  (Original is preserved in git; revert manually to switch back to rancher-desktop.)"
else
    print_warning "cluster-config.sh not found — skipping auto-flip"
    echo "  Set CLUSTER_TYPE=\"azure-aks\" and TARGET_HOST=\"${AZURE_AKS_CLUSTER_NAME}\" yourself in:"
    echo "    $CLUSTER_CONFIG"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "POST-APPLY COMPLETE — CLUSTER READY"

echo "Cluster:        $AZURE_AKS_CLUSTER_NAME"
echo "Nodes:          $(kubectl get nodes --no-headers | wc -l)"
echo "Storage:        $(kubectl get sc --no-headers | awk '{print $1}' | tr '\n' '  ')"
[[ -n "$EXTERNAL_IP" ]] && echo "External IP:    $EXTERNAL_IP"
echo
echo "Context switching:"
echo "  kubectl config use-context rancher-desktop  # local"
echo "  kubectl config use-context $AZURE_AKS_CLUSTER_NAME   # AKS"
echo
echo "Deploy services:"
echo "  ./uis deploy <service>"
echo "  ./uis stack install <stack>"
echo
echo "Manage cluster:"
echo "  ./platforms/aks/scripts/03-destroy.sh       # tear down"
