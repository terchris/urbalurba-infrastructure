#!/bin/bash
# down.sh — Tear down the in-cluster Cloudflare tunnel deployment.
#
# Entry point: uis network down cloudflare
#
# Removes the cloudflared Deployment via 821-remove playbook. Leaves the
# Cloudflare-side tunnel intact (the dashboard config is the source of truth
# for routing — destroying it via API is out of scope for this script).
#
# Q12-style preservation: the .uis.secrets/service-keys/cloudflare.env file
# and the patched CLOUDFLARE_* lines in 00-common-values.env.template stay
# untouched. The user typically re-deploys against the same tunnel; re-running
# the wizard would force them to paste the same token again.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/cloudflare.env"
ENV_FILE_REL=".uis.secrets/service-keys/cloudflare.env"
PLAYBOOK="$REPO_ROOT/ansible/playbooks/821-remove-network-cloudflare-tunnel.yml"

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Cloudflare tunnel tear-down"
echo " (uis network down cloudflare)"
echo "═══════════════════════════════════════════════════════════"
echo
echo "This removes cloudflared pods from the cluster."
echo "The Cloudflare-side tunnel (Zero Trust dashboard) is preserved."
echo

# ----- Delegate to the remove playbook -----
if ! ansible-playbook "$PLAYBOOK"; then
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo " ✗ Tear-down failed or partial"
    echo "═══════════════════════════════════════════════════════════"
    echo "  Check pods:    kubectl -n default get pods -l app=cloudflared"
    echo "  Force delete:  kubectl -n default delete deployment cloudflare-tunnel"
    exit 1
fi

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Cloudflare tunnel removed"
echo "═══════════════════════════════════════════════════════════"
echo "  Config is preserved at:"
echo "    $ENV_FILE_REL"
echo
echo "  To redeploy:  ./uis network up cloudflare"
echo "  To reset:     rm $ENV_FILE_REL"
echo
echo "  Cloudflare dashboard cleanup (optional, if retiring the tunnel):"
echo "    https://one.dash.cloudflare.com → Networks → Tunnels → delete tunnel"
