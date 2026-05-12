#!/bin/bash
# verify.sh — Run the full Cloudflare tunnel verification suite.
#
# Entry point: uis network verify cloudflare
#
# Delegates to 822-verify-cloudflare.yml, which checks:
#   - urbalurba-secrets has a real (non-placeholder) tunnel token
#   - DNS + TCP/7844 connectivity to argotunnel.com
#   - cloudflared pod count and Running status
#   - Pod log markers ("Registered tunnel connection")
#   - End-to-end HTTPS probe to BASE_DOMAIN_CLOUDFLARE (if set)

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PLAYBOOK="$REPO_ROOT/ansible/playbooks/822-verify-cloudflare.yml"

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Cloudflare tunnel verification"
echo " (uis network verify cloudflare)"
echo "═══════════════════════════════════════════════════════════"
echo

# ----- Delegate -----
exec ansible-playbook "$PLAYBOOK"
