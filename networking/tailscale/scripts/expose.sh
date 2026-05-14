#!/bin/bash
# expose.sh — Create a per-service Tailscale Funnel ingress.
#
# Entry point: uis network expose tailscale <service>
#
# Each invocation creates a Tailscale Ingress in 'default' for the named
# service. The operator spawns a per-service proxy pod that registers as
# '<service>.<tailnet>.ts.net' (no owner_id prefix — Decision 8). The proxy
# routes directly to the backend Service on port 80 — Traefik is bypassed
# entirely (C-8).
#
# Refuses if:
#   - operator not running in the 'tailscale' namespace (run 'up' first)
#   - the named service doesn't exist in 'default'
#
# First-use confirmation:
#   The first time a Tailscale Ingress is created in 'default', surface the
#   Traefik-bypass fact and ask for explicit confirmation. '--yes' skips it.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
ENV_FILE_REL=".uis.secrets/service-keys/tailscale.env"
ADDHOST_PLAYBOOK="$REPO_ROOT/ansible/playbooks/802-tailscale-tunnel-addhost.yml"
KUBECONFIG_PATH="${UIS_KUBECONFIG:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"

# ----- Helpers -----
_kubectl() {
    if [[ -f "$KUBECONFIG_PATH" ]]; then
        KUBECONFIG="$KUBECONFIG_PATH" kubectl "$@"
    else
        kubectl "$@"
    fi
}

# ----- Flag parsing -----
SKIP_CONFIRM=0
SERVICE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes|-y) SKIP_CONFIRM=1; shift ;;
        --help|-h)
            echo "Usage: uis network expose tailscale <service> [--yes]"
            echo "  <service>: name of a Kubernetes service in 'default' (e.g. 'whoami')"
            echo "  --yes:     skip the first-use Traefik-bypass confirmation"
            exit 0
            ;;
        --*) echo "✗ Unknown flag: $1" >&2; exit 1 ;;
        *)
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"; shift
            else
                echo "✗ Unexpected argument: $1" >&2
                echo "  Usage: uis network expose tailscale <service> [--yes]" >&2
                exit 1
            fi
            ;;
    esac
done

# ----- Argument validation -----
if [[ -z "$SERVICE" ]]; then
    echo "✗ Usage: uis network expose tailscale <service>" >&2
    echo "  Example: uis network expose tailscale whoami" >&2
    exit 1
fi

# ----- Refuse if init has not been run -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No Tailscale config found at $ENV_FILE_REL" >&2
    echo "  Run './uis network init tailscale' first to set credentials." >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${TAILSCALE_TAILNET:-}" ]]; then
    echo "✗ TAILSCALE_TAILNET is empty in $ENV_FILE_REL" >&2
    echo "  Re-run './uis network init tailscale'." >&2
    exit 1
fi

# ----- Refuse if operator not running -----
running_count=$(_kubectl -n tailscale get pods -l app=operator \
    -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null \
    | grep -c '^Running$' || true)
if [[ "$running_count" -eq 0 ]]; then
    echo "✗ Tailscale operator is not running in namespace 'tailscale'." >&2
    echo "  Run './uis network up tailscale' first to install the operator." >&2
    exit 1
fi

# ----- Refuse if the named service doesn't exist -----
if ! _kubectl -n default get svc "$SERVICE" >/dev/null 2>&1; then
    echo "✗ Service 'default/$SERVICE' not found in cluster." >&2
    echo "  Available services in 'default':" >&2
    _kubectl -n default get svc -o name 2>/dev/null | sed 's|^service/|  - |' >&2
    exit 1
fi

# ----- First-use confirmation (Traefik-bypass surfacing #3) -----
existing_ts_ingresses=$(_kubectl -n default get ingress -o json 2>/dev/null \
    | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for i in data.get('items', []) if i.get('spec', {}).get('ingressClassName') == 'tailscale'))" \
    2>/dev/null || echo 0)
if [[ "$existing_ts_ingresses" -eq 0 && "$SKIP_CONFIRM" -eq 0 ]]; then
    echo "═══════════════════════════════════════════════════════════"
    echo " First per-service Tailscale expose on this cluster"
    echo "═══════════════════════════════════════════════════════════"
    echo
    echo "⚠ Tailscale Funnel BYPASSES Traefik. The operator's per-service proxy"
    echo "  routes directly to the backend Service. Authentik forward-auth,"
    echo "  Traefik middleware, and HostRegexp rules will NOT apply on the"
    echo "  resulting URL. If '$SERVICE' needs auth, the service itself has"
    echo "  to enforce it (or expose it via Cloudflare instead)."
    echo
    echo "  The URL will be publicly reachable on the internet:"
    echo "  https://$SERVICE.$TAILSCALE_TAILNET"
    echo
    read -rp "Continue? [y/N]: " confirm
    case "$confirm" in
        y|Y|yes|Yes) ;;
        *) echo "Aborted." >&2; exit 1 ;;
    esac
    echo
fi

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale per-service expose"
echo " (uis network expose tailscale $SERVICE)"
echo " URL: https://$SERVICE.$TAILSCALE_TAILNET"
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Invoke the addhost playbook -----
ansible-playbook "$ADDHOST_PLAYBOOK" \
    -e "service_name=$SERVICE" \
    -e "tailscale_tailnet=$TAILSCALE_TAILNET"

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ $SERVICE exposed"
echo "═══════════════════════════════════════════════════════════"
echo "  URL:        https://$SERVICE.$TAILSCALE_TAILNET"
echo "  Cert:       provisioned via Let's Encrypt (5-cert-per-7-day limit per hostname)"
echo "  Unexpose:   ./uis network unexpose tailscale $SERVICE"
