#!/bin/bash
# unexpose.sh — Remove a per-service Tailscale Funnel ingress.
#
# Entry point: uis network unexpose tailscale <service>
#
# Deletes the Tailscale Ingress in 'default' named '<service>-tailscale' (the
# naming convention from 802-tailscale-tunnel-addhost.yml). The operator
# tears down its per-service proxy pod when the Ingress disappears.
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

# ----- Argument validation -----
SERVICE="${1:-}"
if [[ -z "$SERVICE" ]]; then
    echo "✗ Usage: uis network unexpose tailscale <service>" >&2
    echo "  Example: uis network unexpose tailscale whoami" >&2
    exit 1
fi

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale per-service unexpose"
echo " (uis network unexpose tailscale $SERVICE)"
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Check if there's an Ingress to delete -----
INGRESS_NAME="${SERVICE}-tailscale"
if _kubectl -n default get ingress "$INGRESS_NAME" >/dev/null 2>&1; then
    echo "▶ Deleting Ingress 'default/$INGRESS_NAME'..."
    _kubectl -n default delete ingress "$INGRESS_NAME"
    echo
else
    echo "ℹ No Ingress 'default/$INGRESS_NAME' found — nothing to delete in-cluster."
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
