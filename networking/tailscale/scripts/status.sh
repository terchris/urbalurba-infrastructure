#!/bin/bash
# status.sh — Show Tailscale operator + exposure status.
#
# Entry point: uis network status tailscale
#
# --summary flag: emits one tab-separated line "<state>\t<hint>" for the
# `uis network list` table (C-1 contract). State machine:
#   1. env file missing                                  → not-initialized
#   2. env present, operator not running in cluster      → configured-not-running
#   3. operator running, at least one pod Running        → running
#   4. operator namespace exists, no Running pods        → unreachable

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
ENV_FILE_REL=".uis.secrets/service-keys/tailscale.env"
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

# Count Tailscale operator pods. Echoes "<running>/<total>". On failure echoes "0/0".
_operator_pod_counts() {
    local pods total running
    pods=$(_kubectl -n tailscale get pods -l app=operator \
            -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null || echo "")
    if [[ -z "$pods" ]]; then
        echo "0/0"; return
    fi
    total=$(printf '%s\n' "$pods" | grep -c . || true)
    running=$(printf '%s\n' "$pods" | grep -c '^Running$' || true)
    echo "${running}/${total}"
}

# List Tailscale-class Ingresses across ALL namespaces (per-service exposes).
# Emits one line per match in the form '<namespace>/<ingress_name>' so the
# caller can derive both the namespace and the service URL.
_exposed_services() {
    _kubectl get ingress -A -o json 2>/dev/null \
        | python3 -c "import sys, json; data=json.load(sys.stdin); print('\n'.join(i['metadata']['namespace'] + '/' + i['metadata']['name'] for i in data.get('items', []) if i.get('spec', {}).get('ingressClassName') == 'tailscale' and i['metadata'].get('namespace') != 'kube-system'))" 2>/dev/null || true
}

# Cluster Funnel Ingress present?
_cluster_funnel_present() {
    _kubectl -n kube-system get ingress traefik-ingress >/dev/null 2>&1
}

_namespace_exists() {
    _kubectl get namespace tailscale >/dev/null 2>&1
}

# ----- Summary path (C-1 contract for `uis network list`) -----
if (( SUMMARY )); then
    if [[ ! -f "$ENV_FILE" ]]; then
        printf 'not-initialized\trun '\''./uis network init tailscale'\'' to set up\n'
        exit 0
    fi
    if ! _namespace_exists; then
        printf 'configured-not-running\trun '\''./uis network up tailscale'\'' to deploy\n'
        exit 0
    fi
    counts=$(_operator_pod_counts)
    running="${counts%/*}"
    total="${counts#*/}"
    if [[ "$running" -gt 0 ]]; then
        # Optionally count exposed services for the hint.
        exposed=$(_exposed_services | grep -c . 2>/dev/null || echo 0)
        if (( exposed > 0 )); then
            printf 'running\t%s/%s operator pod up, %s service(s) exposed\n' "$running" "$total" "$exposed"
        else
            printf 'running\t%s/%s operator pod up, no services exposed yet\n' "$running" "$total"
        fi
    else
        printf 'unreachable\toperator namespace exists but no Running pods; check '\''kubectl -n tailscale logs -l app=operator'\''\n'
    fi
    exit 0
fi

# ----- Full status -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale tunnel status"
echo " (uis network status tailscale)"
echo "═══════════════════════════════════════════════════════════"
echo

if [[ ! -f "$ENV_FILE" ]]; then
    echo "  Config:     not initialized"
    echo "  Setup:      ./uis network init tailscale"
    exit 0
fi

# shellcheck source=/dev/null
source "$ENV_FILE"
echo "  Config:     $ENV_FILE_REL"
echo "  Tailnet:    ${TAILSCALE_TAILNET:-not set}"
echo "  Owner ID:   ${TAILSCALE_OWNER_ID:-not set}"
echo "  OAuth:      $([[ -n "${TAILSCALE_CLIENTID:-}" ]] && echo set || echo "not set")"

if ! _namespace_exists; then
    echo "  Operator:   not deployed"
    echo
    echo "  Deploy:     ./uis network up tailscale"
    exit 0
fi

counts=$(_operator_pod_counts)
running="${counts%/*}"
total="${counts#*/}"
echo "  Operator:   ${running}/${total} pod(s) running in 'tailscale' namespace"

if [[ "$running" -eq 0 ]]; then
    echo
    echo "  Pods exist but none are Running. Recent logs:"
    _kubectl -n tailscale logs -l app=operator --tail=20 2>&1 | sed 's/^/    /' || true
    echo
    echo "  Verify:     ./uis network verify tailscale"
    exit 0
fi

# Cluster Funnel state
if _cluster_funnel_present; then
    echo "  Cluster Funnel: https://${TAILSCALE_OWNER_ID:-?}.${TAILSCALE_TAILNET:-?}"
else
    echo "  Cluster Funnel: not deployed (opt-in via 'uis network up tailscale --with-cluster-funnel')"
fi

# Exposed services (format from _exposed_services: '<ns>/<ingress_name>')
exposed=$(_exposed_services)
if [[ -n "$exposed" ]]; then
    echo
    echo "  Exposed services:"
    while IFS= read -r entry; do
        ns="${entry%%/*}"
        ingress="${entry#*/}"
        # Tailscale ingresses are named <svc>-tailscale in addhost.yml's convention.
        host="${ingress%-tailscale}"
        echo "    https://${host}.${TAILSCALE_TAILNET:-?}    (svc: $ns/$host)"
    done <<< "$exposed"
else
    echo "  Exposed services: none"
    echo "  Expose one with:  ./uis network expose tailscale <service> [-n <namespace>]"
fi

echo
echo "  Verify:     ./uis network verify tailscale"
echo "  Remove:     ./uis network down tailscale"
