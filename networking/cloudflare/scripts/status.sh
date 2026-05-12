#!/bin/bash
# status.sh — Show Cloudflare tunnel status (config + pods + connectivity).
#
# Entry point: uis network status cloudflare
#
# --summary flag: emits one tab-separated line "<state>\t<hint>" for the
# `uis network list` table (C-1 contract). State machine:
#   1. env file missing                                  → not-initialized
#   2. env present, no cloudflared Deployment in cluster → configured-not-running
#   3. deployment present, at least one pod Running     → running
#   4. deployment present, no pods Running              → unreachable

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/cloudflare.env"
ENV_FILE_REL=".uis.secrets/service-keys/cloudflare.env"
KUBECONFIG_PATH="${UIS_KUBECONFIG:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"

# ----- Flag parsing -----
SUMMARY=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary) SUMMARY=1; shift ;;
        *) shift ;;
    esac
done

# ----- Helpers -----
_kubectl() {
    if [[ -f "$KUBECONFIG_PATH" ]]; then
        KUBECONFIG="$KUBECONFIG_PATH" kubectl "$@"
    else
        kubectl "$@"
    fi
}

# Count running cloudflared pods. Echoes "<running>/<total>". On failure (e.g.
# no cluster reachable) echoes "0/0" so the caller treats it as not-running.
_pod_counts() {
    local pods total running
    pods=$(_kubectl -n default get pods -l app=cloudflared \
            -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
    if [[ -z "$pods" ]]; then
        echo "0/0"; return
    fi
    total=$(printf '%s\n' "$pods" | grep -c . || true)
    running=$(printf '%s\n' "$pods" | grep -c '^Running$' || true)
    echo "${running}/${total}"
}

# Cluster touch — true iff cloudflared Deployment exists in default namespace.
_deployment_present() {
    _kubectl -n default get deployment cloudflare-tunnel >/dev/null 2>&1
}

# ----- Summary path (C-1 contract for `uis network list`) -----
if (( SUMMARY )); then
    if [[ ! -f "$ENV_FILE" ]]; then
        printf 'not-initialized\trun '\''./uis network init cloudflare'\'' to set up\n'
        exit 0
    fi
    if ! _deployment_present; then
        printf 'configured-not-running\trun '\''./uis network up cloudflare'\'' to deploy\n'
        exit 0
    fi
    counts=$(_pod_counts)
    running="${counts%/*}"
    total="${counts#*/}"
    if [[ "$running" -gt 0 ]]; then
        printf 'running\t%s/%s cloudflared pods up\n' "$running" "$total"
    else
        printf 'unreachable\tdeployment exists but no Running pods; check '\''kubectl -n default logs -l app=cloudflared'\''\n'
    fi
    exit 0
fi

# ----- Full status -----
echo "═══════════════════════════════════════════════════════════"
echo " Cloudflare tunnel status"
echo " (uis network status cloudflare)"
echo "═══════════════════════════════════════════════════════════"
echo

if [[ ! -f "$ENV_FILE" ]]; then
    echo "  Config:    not initialized"
    echo "  Setup:     ./uis network init cloudflare"
    exit 0
fi

# shellcheck source=/dev/null
source "$ENV_FILE"
echo "  Config:    $ENV_FILE_REL"
echo "  Token:     set (${CLOUDFLARE_TUNNEL_TOKEN:+${#CLOUDFLARE_TUNNEL_TOKEN} chars})"
echo "  Domain:    ${BASE_DOMAIN_CLOUDFLARE:-not set}"

if ! _deployment_present; then
    echo "  Pods:      not deployed"
    echo
    echo "  Deploy:    ./uis network up cloudflare"
    exit 0
fi

counts=$(_pod_counts)
running="${counts%/*}"
total="${counts#*/}"
echo "  Pods:      ${running}/${total} cloudflared running"

if [[ "$running" -eq 0 ]]; then
    echo
    echo "  Pods exist but none are Running. Recent logs:"
    _kubectl -n default logs -l app=cloudflared --tail=20 2>&1 | sed 's/^/    /' || true
    echo
    echo "  Verify:    ./uis network verify cloudflare"
    exit 0
fi

echo
echo "  Verify e2e: ./uis network verify cloudflare"
echo "  Remove:     ./uis network down cloudflare"
