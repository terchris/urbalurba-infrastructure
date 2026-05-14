#!/bin/bash
# verify.sh — Run the Tailscale verification suite.
#
# Entry point: uis network verify tailscale
#
# Delegates to 803-verify-tailscale.yml, which checks:
#   - urbalurba-secrets has real (non-placeholder) CLIENTID/CLIENTSECRET/TAILNET values
#   - OAuth client credentials authenticate against the Tailscale API
#   - Stale device report (devices with -N suffixes flagged)
#   - Operator pod is Running in the 'tailscale' namespace

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PLAYBOOK="$REPO_ROOT/ansible/playbooks/803-verify-tailscale.yml"

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale tunnel verification"
echo " (uis network verify tailscale)"
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Delegate -----
exec ansible-playbook "$PLAYBOOK"
