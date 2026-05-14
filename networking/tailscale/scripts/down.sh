#!/bin/bash
# down.sh — Tear down the Tailscale operator + all in-cluster Tailscale state.
#
# Entry point: uis network down tailscale
#
# Delegates to 801-remove-network-tailscale-tunnel.yml, which:
#   - deletes the cluster Funnel Ingress (if present)
#   - deletes any per-service Tailscale Ingresses still in 'default'
#   - uninstalls the Tailscale operator Helm release + namespace
#   - cleans up the operator + cluster Funnel devices on the tailnet via API
#
# Preservation: .uis.secrets/service-keys/tailscale.env and the TAILSCALE_* lines
# in 00-common-values.env.template stay untouched. Re-running 'up' reconnects
# with the same OAuth credentials. Delete the env file manually for a full reset.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
ENV_FILE_REL=".uis.secrets/service-keys/tailscale.env"
PLAYBOOK="$REPO_ROOT/ansible/playbooks/801-remove-network-tailscale-tunnel.yml"

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale tunnel tear-down"
echo " (uis network down tailscale)"
echo "═══════════════════════════════════════════════════════════"
echo
echo "This removes the operator + cluster Funnel + all per-service Ingresses."
echo "Devices on the tailnet are cleaned up via the Tailscale API."
echo "Your OAuth credentials in $ENV_FILE_REL are preserved for redeploys."
echo

# ----- Delegate to the remove playbook -----
if ! ansible-playbook "$PLAYBOOK"; then
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo " ✗ Tear-down failed or partial"
    echo "═══════════════════════════════════════════════════════════"
    echo "  Check pods:        kubectl -n tailscale get pods"
    echo "  Force ns delete:   kubectl delete namespace tailscale --grace-period=0 --force"
    echo "  Check tailnet:     https://login.tailscale.com/admin/machines"
    exit 1
fi

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Tailscale tunnel removed"
echo "═══════════════════════════════════════════════════════════"
echo "  Config preserved at:"
echo "    $ENV_FILE_REL"
echo
echo "  Redeploy:        ./uis network up tailscale"
echo "  Full reset:      rm $ENV_FILE_REL && ./uis network init tailscale"
echo
echo "  Tailscale admin cleanup (optional, if fully retiring):"
echo "    https://login.tailscale.com/admin/settings/oauth   — revoke the OAuth client"
echo "    https://login.tailscale.com/admin/machines         — confirm zero remaining devices"
