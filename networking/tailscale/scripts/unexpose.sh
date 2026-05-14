#!/bin/bash
# unexpose.sh — Remove a per-service Tailscale Funnel ingress.
#
# Entry point: uis network unexpose tailscale <service> [-n <namespace>]
#
# Deletes the Tailscale Ingress named '<service>-tailscale' (naming convention
# from 802-tailscale-tunnel-addhost.yml). If --namespace is not given, scans
# all namespaces and picks the matching one — most users don't remember which
# namespace they exposed from.
#
# Then invokes 803-tailscale-device-cleanup.yml to immediately remove the
# matching device from the tailnet via API. This avoids waiting for the
# operator's eventual-consistency cleanup, which can leave -N-suffixed
# stragglers visible in the admin console for several minutes.
#
# Idempotent: unexposing a service that wasn't exposed is a successful no-op.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
CLEANUP_PLAYBOOK="$REPO_ROOT/ansible/playbooks/803-tailscale-device-cleanup.yml"
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
SERVICE=""
NAMESPACE=""  # empty means "auto-detect across all namespaces"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--namespace)
            if [[ -z "${2:-}" ]]; then
                echo "✗ $1 requires a namespace argument" >&2
                exit 1
            fi
            NAMESPACE="$2"; shift 2
            ;;
        --namespace=*) NAMESPACE="${1#*=}"; shift ;;
        --help|-h)
            cat <<USAGE
Usage: uis network unexpose tailscale <service> [-n <namespace>]

  <service>           Service whose Tailscale Ingress to remove
  -n, --namespace     Namespace to look in. If omitted, scans all namespaces
                      and picks the matching <service>-tailscale Ingress.

Examples:
  uis network unexpose tailscale whoami
  uis network unexpose tailscale authentik-server -n authentik
USAGE
            exit 0
            ;;
        --*) echo "✗ Unknown flag: $1" >&2; exit 1 ;;
        *)
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"; shift
            else
                echo "✗ Unexpected argument: $1" >&2; exit 1
            fi
            ;;
    esac
done

# ----- Argument validation -----
if [[ -z "$SERVICE" ]]; then
    echo "✗ Usage: uis network unexpose tailscale <service> [-n <namespace>]" >&2
    echo "  Example: uis network unexpose tailscale whoami" >&2
    exit 1
fi

INGRESS_NAME="${SERVICE}-tailscale"

# ----- Auto-detect namespace if not specified -----
if [[ -z "$NAMESPACE" ]]; then
    # Find Ingress named <svc>-tailscale (ingressClassName=tailscale) anywhere.
    matches=$(_kubectl get ingress -A -o json 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
hits = []
for i in data.get('items', []):
    spec = i.get('spec', {})
    meta = i.get('metadata', {})
    if spec.get('ingressClassName') == 'tailscale' and meta.get('name') == '$INGRESS_NAME':
        hits.append(meta.get('namespace', '?'))
print('\n'.join(hits))
" 2>/dev/null || true)
    count=$(printf '%s\n' "$matches" | grep -c . || true)
    if [[ "$count" -eq 0 ]]; then
        NAMESPACE="default"  # nothing to delete, fall through to API cleanup
    elif [[ "$count" -eq 1 ]]; then
        NAMESPACE="$matches"
    else
        echo "✗ Multiple Tailscale ingresses named '$INGRESS_NAME' across namespaces:" >&2
        printf '%s\n' "$matches" | sed 's|^|  - |' >&2
        echo "  Specify which one: uis network unexpose tailscale $SERVICE -n <namespace>" >&2
        exit 1
    fi
fi

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale per-service unexpose"
echo " (uis network unexpose tailscale $SERVICE -n $NAMESPACE)"
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Check if there's an Ingress to delete -----
if _kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" >/dev/null 2>&1; then
    echo "▶ Deleting Ingress '$NAMESPACE/$INGRESS_NAME'..."
    _kubectl -n "$NAMESPACE" delete ingress "$INGRESS_NAME"
    echo
else
    echo "ℹ No Ingress '$NAMESPACE/$INGRESS_NAME' found — nothing to delete in-cluster."
    echo "  Proceeding to API device cleanup in case a tailnet device lingers."
    echo
fi

# ----- API device cleanup (handles operator's eventual-consistency lag) -----
if [[ -f "$ENV_FILE" ]]; then
    echo "▶ Removing matching device(s) from the tailnet via Tailscale API..."
    ansible-playbook "$CLEANUP_PLAYBOOK" -e "cleanup_hostname=$SERVICE" || true
    echo
else
    echo "⚠ No Tailscale config at .uis.secrets/service-keys/tailscale.env"
    echo "  Skipping API device cleanup. Manually delete the device from:"
    echo "  https://login.tailscale.com/admin/machines"
    echo
fi

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ $SERVICE unexposed"
echo "═══════════════════════════════════════════════════════════"
echo "  DNS may still resolve to Tailscale's Funnel edge for a few minutes."
echo "  HTTPS will fail (cert + device gone) within ~30 seconds."
echo
echo "  Re-expose: ./uis network expose tailscale $SERVICE"
