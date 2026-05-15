#!/bin/bash
# up.sh — Deploy the Cloudflare tunnel into the active Kubernetes cluster.
#
# Entry point: uis network up cloudflare
#
# Pipeline:
#   1. Refuse if .uis.secrets/service-keys/cloudflare.env is missing (run init).
#   2. 'uis secrets generate' + 'uis secrets apply' — pushes the token into the
#      urbalurba-secrets k8s Secret that 820-deploy reads.
#   3. ansible-playbook 820-deploy-network-cloudflare-tunnel.yml — applies the
#      static manifest and waits for cloudflared pods to register.
#
# Targets whichever cluster the kubeconf-all current-context points at. This
# round is rancher-desktop-focused (see PLAN-network-cloudflare-port-and-docs-lift-up.md).
# The playbooks themselves are cluster-agnostic.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/cloudflare.env"
ENV_FILE_REL=".uis.secrets/service-keys/cloudflare.env"
# Resolve the uis CLI: inside the container the binary lives at /usr/local/bin/uis
# (on PATH); on a developer host the repo-root './uis' is what works. Try the
# repo-relative path first to keep developer-host workflows honest, then fall
# back to PATH for the container.
if [[ -x "$REPO_ROOT/uis" ]]; then
    UIS_CLI="$REPO_ROOT/uis"
else
    UIS_CLI="$(command -v uis 2>/dev/null || true)"
fi
PLAYBOOK="$REPO_ROOT/ansible/playbooks/820-deploy-network-cloudflare-tunnel.yml"

# ----- Refuse with pointer if init has not been run -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No Cloudflare config found at $ENV_FILE_REL" >&2
    echo "  Run './uis network init cloudflare' first to set the tunnel token." >&2
    exit 1
fi

# Load the env file so the banner can show what's about to be deployed.
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Cloudflare tunnel deployment"
echo " (uis network up cloudflare)"
echo " Token:   set (${#CLOUDFLARE_TUNNEL_TOKEN} chars)"
echo " Domain:  ${BASE_DOMAIN_CLOUDFLARE:-not set}"
echo "═══════════════════════════════════════════════════════════"
echo
echo "This deploys cloudflared pods into the active cluster."
echo "No Cloudflare-side cost. Inbound traffic routes through Cloudflare's edge."
echo

# ----- 1/2 Push token into urbalurba-secrets via the standard pipeline -----
echo "▶ 1/2 Pushing token into urbalurba-secrets (uis secrets generate + apply)..."
if [[ -z "$UIS_CLI" || ! -x "$UIS_CLI" ]]; then
    echo "✗ uis CLI not found — checked $REPO_ROOT/uis and \$PATH." >&2
    echo "  Run inside the UIS container (./uis network up cloudflare) or from a repo with ./uis." >&2
    exit 1
fi
"$UIS_CLI" secrets generate
"$UIS_CLI" secrets apply
echo

# ----- 2/2 Apply manifest + wait for cloudflared to register -----
echo "▶ 2/2 Deploying cloudflared (ansible-playbook 820-deploy-network-cloudflare-tunnel.yml)..."
ansible-playbook "$PLAYBOOK"

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Cloudflare tunnel is up"
echo "═══════════════════════════════════════════════════════════"
echo "  Pods:    kubectl -n default get pods -l app=cloudflared"
echo "  Logs:    kubectl -n default logs -l app=cloudflared --tail=50"
echo
echo "  Verify:  ./uis network verify cloudflare"
echo "  Status:  ./uis network status cloudflare"
echo "  Remove:  ./uis network down cloudflare"
