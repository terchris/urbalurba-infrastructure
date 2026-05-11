#!/bin/bash
# status.sh — Show AKS cluster status, cost, and quick actions.
#
# Spec: F8 from talk45 — "is the meter running, and how much will this cost
# me overnight?" is the headline novice question after `uis platform up`.
# This script answers it in one command.
#
# Entry point: uis platform status azure-aks

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/cloud-accounts/azure-default.env"

# ----- Refuse with pointer if env missing (consistent with up/down) -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No config file found at $ENV_FILE" >&2
    echo "  Run 'uis platform init azure-aks' first to set one up." >&2
    exit 1
fi

# ----- Preflight: az is required (kubectl is best-effort below) -----
if ! command -v az >/dev/null 2>&1; then
    echo "✗ Azure CLI (az) is required for 'uis platform status azure-aks'." >&2
    echo "  Run 'uis tools install azure-aks' to install it." >&2
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# Defensive fallbacks (mirror 00-bootstrap-state.sh / 01-apply.sh / 03-destroy.sh)
if [[ -z "${AZURE_STATE_STORAGE_ACCOUNT:-}" ]]; then
    _stripped_sub="${AZURE_SUBSCRIPTION_ID//-/}"
    AZURE_STATE_STORAGE_ACCOUNT="sa${_stripped_sub:0:16}tf"
    unset _stripped_sub
fi
AZURE_AKS_LOCATION="${AZURE_AKS_LOCATION:-${AZURE_REGION:-westeurope}}"
CLUSTER_NAME="${AZURE_AKS_CLUSTER_NAME:-azure-aks}"
RG="${AZURE_AKS_RESOURCE_GROUP:-rg-urbalurba-aks-weu}"

# F10 — Preflight: must be logged in. The R0 testing protocol (./uis pull &&
# docker rm && ./uis start) wipes ~/.azure, so this is the first thing the
# user hits after every image refresh. Without it, `az account set` errors
# with a misleading "subscription doesn't exist in cloud 'AzureCloud'".
if ! az account show >/dev/null 2>&1; then
    echo "✗ Not signed in to Azure." >&2
    echo "  Run 'az login' (or re-run 'uis platform init azure-aks') first." >&2
    exit 1
fi

# Make subsequent az calls target the right subscription
az account set --subscription "$AZURE_SUBSCRIPTION_ID" >/dev/null


# ----- Cost helpers ------------------------------------------------------------
# Daily EUR estimate for AKS-eligible VM sizes in westeurope (rough on-demand
# rounding; update if Azure pricing shifts materially). Unknown sizes → "?".
_node_daily_eur() {
    case "$1" in
        Standard_B2s_v2)   echo "0.85" ;;
        Standard_B2ms)     echo "0.95" ;;
        Standard_B4ms)     echo "1.90" ;;
        Standard_D2s_v3)   echo "1.20" ;;
        Standard_D2s_v5)   echo "1.10" ;;
        Standard_D4s_v5)   echo "2.20" ;;
        *)                 echo "?"    ;;
    esac
}

# Per-day fixed overhead (rough): public IP + LB rule 1 + managed disks
_FIXED_DAILY_EUR="0.15"

# Convert ISO8601 (e.g. 2026-05-11T07:12:00Z) → seconds-since-epoch in a way
# that works on both GNU date (Linux container) and BSD date (macOS host, in
# case anyone ever sources this on the host).
_iso_to_epoch() {
    local iso="${1%.*}"     # strip fractional seconds if present
    iso="${iso%Z}Z"          # ensure trailing Z
    local epoch
    epoch=$(date -u -d "$iso" +%s 2>/dev/null) \
        || epoch=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null) \
        || epoch=0
    echo "$epoch"
}

_format_age() {
    local then_ts now_ts diff
    then_ts=$(_iso_to_epoch "$1")
    [[ "$then_ts" -eq 0 ]] && { echo "unknown"; return; }
    now_ts=$(date -u +%s)
    diff=$((now_ts - then_ts))
    if   (( diff < 60 ));    then echo "${diff}s ago"
    elif (( diff < 3600 ));  then echo "$((diff / 60)) min ago"
    elif (( diff < 86400 )); then printf "%dh %dm ago\n" $((diff / 3600)) $(((diff % 3600) / 60))
    else                          printf "%dd %dh ago\n" $((diff / 86400)) $(((diff % 86400) / 3600))
    fi
}

_estimate_spent() {
    # $1: daily EUR (or "?"); $2: ISO timestamp
    [[ "$1" == "?" ]] && { echo "?"; return; }
    local then_ts now_ts seconds
    then_ts=$(_iso_to_epoch "$2")
    [[ "$then_ts" -eq 0 ]] && { echo "?"; return; }
    now_ts=$(date -u +%s)
    seconds=$((now_ts - then_ts))
    awk -v daily="$1" -v secs="$seconds" 'BEGIN { printf "%.2f", daily * secs / 86400 }'
}


# ----- Render: cluster not provisioned -----------------------------------------
if ! az aks show -g "$RG" -n "$CLUSTER_NAME" >/dev/null 2>&1; then
    echo "═══════════════════════════════════════════════════════════"
    echo " AKS cluster status"
    echo " (uis platform status azure-aks)"
    echo "═══════════════════════════════════════════════════════════"
    echo
    echo "  Cluster:        $CLUSTER_NAME  (configured but not provisioned)"
    echo "  Region:         $AZURE_AKS_LOCATION"
    echo "  Subscription:   $AZURE_SUBSCRIPTION_ID"
    echo "  Cost:           €0/day  (no Azure resources running)"
    echo
    echo "  Bring it up:    uis platform up azure-aks"
    exit 0
fi


# ----- Pull cluster facts ------------------------------------------------------
# Single az call, multi-projection via JMESPath. `-o tsv` over an array
# projection emits one value per LINE (not tab-separated despite the name),
# so we read with mapfile and index by position.
mapfile -t _facts < <(az aks show -g "$RG" -n "$CLUSTER_NAME" \
    --query "[provisioningState, kubernetesVersion, agentPoolProfiles[0].vmSize, agentPoolProfiles[0].count, systemData.createdAt]" \
    -o tsv 2>/dev/null)
STATE="${_facts[0]:-}"
K8S="${_facts[1]:-}"
NODE_SIZE="${_facts[2]:-}"
NODE_COUNT="${_facts[3]:-}"
CREATED="${_facts[4]:-}"
# az renders JSON null as literal "None" in TSV — coerce to empty so the
# downstream `unknown` fallback fires and the `Running since:` line is
# correctly suppressed.
[[ "$CREATED" == "None" ]] && CREATED=""
CREATED="${CREATED:-unknown}"


# ----- Look up Traefik external IP (best effort) -------------------------------
# Matches the kube-system/traefik install from 02-post-apply.sh:147. Must
# explicitly target the UIS merged kubeconfig + the AKS context — otherwise
# kubectl falls through to ~/.kube/config (bind-mounted from the host, only
# contains rancher-desktop) and silently returns rancher-desktop's k3s
# Traefik IP because the service names happen to collide.
EXT_IP=""
_kubeconfig="${UIS_KUBECONFIG:-/mnt/urbalurbadisk/kubeconfig/kubeconf-all}"
if [[ -f "$_kubeconfig" ]] && \
   KUBECONFIG="$_kubeconfig" kubectl --context "$CLUSTER_NAME" \
       get svc traefik -n kube-system >/dev/null 2>&1; then
    EXT_IP=$(KUBECONFIG="$_kubeconfig" kubectl --context "$CLUSTER_NAME" \
        get svc traefik -n kube-system \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
fi
EXT_IP="${EXT_IP:-not yet provisioned}"


# ----- Cost math ---------------------------------------------------------------
NODE_DAILY=$(_node_daily_eur "$NODE_SIZE")
if [[ "$NODE_DAILY" == "?" ]]; then
    EST_DAILY="?"
    SPENT="?"
else
    EST_DAILY=$(awk -v n="$NODE_DAILY" -v c="$NODE_COUNT" -v f="$_FIXED_DAILY_EUR" \
        'BEGIN { printf "%.2f", n * c + f }')
    SPENT=$(_estimate_spent "$EST_DAILY" "$CREATED")
fi
AGE=$(_format_age "$CREATED")


# ----- Render: full status -----------------------------------------------------
echo "═══════════════════════════════════════════════════════════"
echo " AKS cluster status"
echo " (uis platform status azure-aks)"
echo "═══════════════════════════════════════════════════════════"
echo
echo "  Cluster:        $CLUSTER_NAME  ($STATE, k8s $K8S)"
echo "  Region:         $AZURE_AKS_LOCATION"
echo "  Subscription:   $AZURE_SUBSCRIPTION_ID"
echo "  Node pool:      ${NODE_COUNT}× $NODE_SIZE"
echo "  External IP:    $EXT_IP"
if [[ "$CREATED" != "unknown" ]]; then
    echo "  Running since:  $CREATED ($AGE)"
fi
echo "  Est. daily:     ~€${EST_DAILY}/day  (${NODE_COUNT}× $NODE_SIZE + IP/LB/disk overhead)"
echo "  Spent so far:   ~€${SPENT}"
echo
echo "  Tear down:      uis platform down azure-aks"
