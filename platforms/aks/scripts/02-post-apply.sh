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

# ─── Load config ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$SCRIPT_DIR/.."
CONFIG_FILE="$PLATFORM_DIR/azure-aks-config.sh"

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

print_section "AKS PLATFORM — POST-APPLY SETUP"

# ─── Step 1: Merge kubeconfig ─────────────────────────────────────────────────
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

export KUBECONFIG="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"

# ─── Step 2: Switch context ───────────────────────────────────────────────────
print_status "Switching to $CLUSTER_NAME context..."
kubectl config use-context "$CLUSTER_NAME"

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

# ─── Step 4: Install Traefik ──────────────────────────────────────────────────
print_section "Step 3: Install Traefik"

helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

TRAEFIK_VALUES="/mnt/urbalurbadisk/manifests/003-traefik-config.yaml"

if helm list -n kube-system | grep -q "^traefik"; then
    print_warning "Traefik already installed"
    read -p "Upgrade it? (y/N): " upgrade
    if [[ "${upgrade,,}" == "y" ]]; then
        helm upgrade traefik traefik/traefik \
            -f "$TRAEFIK_VALUES" \
            --namespace kube-system
        print_success "Traefik upgraded"
    fi
else
    if [[ -f "$TRAEFIK_VALUES" ]]; then
        helm install traefik traefik/traefik \
            -f "$TRAEFIK_VALUES" \
            --namespace kube-system
    else
        print_warning "No Traefik values file at $TRAEFIK_VALUES — installing with defaults"
        helm install traefik traefik/traefik --namespace kube-system
    fi
    print_success "Traefik installed"
fi

# Wait for Traefik pod
print_status "Waiting for Traefik pod..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=traefik \
    -n kube-system \
    --timeout=300s >/dev/null && print_success "Traefik pod ready"

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

# ─── Summary ──────────────────────────────────────────────────────────────────
print_section "POST-APPLY COMPLETE — CLUSTER READY"

echo "Cluster:        $CLUSTER_NAME"
echo "Nodes:          $(kubectl get nodes --no-headers | wc -l)"
echo "Storage:        $(kubectl get sc --no-headers | awk '{print $1}' | tr '\n' '  ')"
[[ -n "$EXTERNAL_IP" ]] && echo "External IP:    $EXTERNAL_IP"
echo
echo "Context switching:"
echo "  kubectl config use-context rancher-desktop  # local"
echo "  kubectl config use-context $CLUSTER_NAME   # AKS"
echo
echo "Deploy services:"
echo "  ./uis deploy <service>"
echo "  ./uis stack install <stack>"
echo
echo "Manage cluster:"
echo "  ./platforms/aks/scripts/03-destroy.sh       # tear down"
