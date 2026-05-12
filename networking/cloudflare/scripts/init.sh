#!/bin/bash
# init.sh — Interactive wizard for Cloudflare tunnel onboarding.
#
# Entry point: ./uis network init cloudflare
#
# Writes .uis.secrets/service-keys/cloudflare.env with the tunnel token the
# user copies from the Cloudflare Zero Trust dashboard. The token is the ONLY
# required field — checked against ansible/playbooks/820-deploy + 822-verify;
# they don't consume any other Cloudflare credential.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# networking/cloudflare/scripts/init.sh → repo root is three levels up.
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/cloudflare.env"
ENV_FILE_REL=".uis.secrets/service-keys/cloudflare.env"
# The master config that envsubst reads when 'uis secrets generate' runs.
# We patch the CLOUDFLARE_* lines in this file so the token actually lands in
# the urbalurba-secrets k8s Secret that 820-deploy + 822-verify consume.
COMMON_VALUES="$REPO_ROOT/.uis.secrets/secrets-config/00-common-values.env.template"
COMMON_VALUES_REL=".uis.secrets/secrets-config/00-common-values.env.template"

# ----- Colors / printers -----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Cloudflare tunnel setup wizard"
echo " (uis network init cloudflare)"
echo " Writes the tunnel token. No tunnel is deployed yet."
echo "═══════════════════════════════════════════════════════════"
echo

# ----- TTY guard -----
if [[ ! -t 0 ]]; then
    print_error "uis network init cloudflare requires an interactive terminal."
    echo "  Run it from your terminal (not piped, not inside a non-tty container exec)."
    exit 1
fi

# ----- Pre-conditions reminder -----
echo "Before continuing you need:"
echo "  - A Cloudflare account with a domain you own (DNS managed by Cloudflare)."
echo "  - A tunnel created at: Zero Trust → Networks → Tunnels → Create a tunnel."
echo "  - The tunnel token from the install instructions (long string starting 'ey...')."
echo

# ----- Overwrite gate -----
if [[ -f "$ENV_FILE" ]]; then
    echo "An existing config file was found:"
    echo "  $ENV_FILE_REL"
    echo
    echo "What would you like to do?"
    echo "  [1] Skip — keep the existing values, exit the wizard."
    echo "  [2] Re-prompt — overwrite with new values."
    echo "  [3] Show — print the current values + path, then exit."
    echo
    read -rp "Choice [1-3]: " choice
    case "$choice" in
        1|"")
            print_status "Keeping existing config. To deploy: ./uis network up cloudflare"
            exit 0
            ;;
        2)
            # fall through to prompt
            ;;
        3)
            echo
            echo "Path: $ENV_FILE_REL"
            echo
            grep -E '^[A-Z_]+=' "$ENV_FILE" || true
            exit 0
            ;;
        *)
            print_error "Unknown choice: $choice"
            exit 1
            ;;
    esac
fi

# ----- Prompt for tunnel token -----
echo
echo "Paste the Cloudflare tunnel token (long string from the dashboard):"
read -rsp "  CLOUDFLARE_TUNNEL_TOKEN: " token
echo
echo

if [[ -z "$token" ]]; then
    print_error "Token is required. Aborting."
    exit 1
fi

# Quick sanity on shape — Cloudflare tunnel tokens are long JWT-shaped strings.
# Don't hard-fail (it might change), just warn if it doesn't look right.
if [[ ${#token} -lt 100 ]]; then
    print_warning "Token looks short (${#token} chars). Cloudflare tunnel tokens are usually 200+ chars."
    read -rp "Continue anyway? [y/N]: " confirm
    case "$confirm" in
        y|Y|yes|Yes) ;;
        *) print_error "Aborted."; exit 1 ;;
    esac
fi

# ----- Optional: base domain (used by verify's e2e HTTP probe) -----
echo "Base domain (optional — enables 'uis network verify cloudflare' end-to-end check)."
echo "  Example: skryter.no (the apex you've routed through the tunnel)"
read -rp "  BASE_DOMAIN_CLOUDFLARE [skip]: " domain
echo

# ----- Persist (file 1/2): per-provider record under service-keys/ -----
mkdir -p "$(dirname "$ENV_FILE")"
tmp_file="$(dirname "$ENV_FILE")/.cloudflare.env.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

cat > "$tmp_file" <<EOF
# Cloudflare tunnel configuration
# Written by 'uis network init cloudflare' on $(date -u +%Y-%m-%dT%H:%M:%SZ).
# Used by: networking/cloudflare/scripts/status.sh (configured/running detection).
#
# The real load-bearing copy lives in:
#   $COMMON_VALUES_REL
# Both files are updated together; 'uis secrets generate' reads the latter.
#
# Update / regenerate with: ./uis network init cloudflare

CLOUDFLARE_TUNNEL_TOKEN="$token"
BASE_DOMAIN_CLOUDFLARE="$domain"
EOF

chmod 600 "$tmp_file"
mv "$tmp_file" "$ENV_FILE"

# ----- Persist (file 2/2): patch the master common-values template -----
# 'uis secrets generate' sources this file before envsubst, so unless the
# CLOUDFLARE_* lines here are real values, the urbalurba-secrets k8s Secret
# ends up with placeholders and 820-deploy refuses.
if [[ ! -f "$COMMON_VALUES" ]]; then
    print_warning "Common values template not found: $COMMON_VALUES_REL"
    print_warning "Token saved to service-keys but secrets pipeline can't pick it up."
    print_warning "Run 'uis secrets init' first, then re-run 'uis network init cloudflare'."
    exit 1
fi

# In-place sed update for the two CLOUDFLARE_* lines. Use a delimiter (|) that
# doesn't appear in JWT tokens. Escape any | that *do* appear, defensively.
token_esc=${token//|/\\|}
domain_esc=${domain//|/\\|}
cv_tmp="$COMMON_VALUES.tmp.$$"
trap 'rm -f "$tmp_file" "$cv_tmp"' EXIT
cp "$COMMON_VALUES" "$cv_tmp"
sed -i.bak "s|^CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=$token_esc|" "$cv_tmp"
if [[ -n "$domain" ]]; then
    sed -i.bak "s|^BASE_DOMAIN_CLOUDFLARE=.*|BASE_DOMAIN_CLOUDFLARE=$domain_esc|" "$cv_tmp"
fi
rm -f "$cv_tmp.bak"
chmod 600 "$cv_tmp"
mv "$cv_tmp" "$COMMON_VALUES"

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Cloudflare config ready"
echo "═══════════════════════════════════════════════════════════"
echo "  Token:   set (${#token} chars)"
echo "  Domain:  ${domain:-not set (verify e2e probe will be skipped)}"
echo "  Files:"
echo "    $ENV_FILE_REL"
echo "    $COMMON_VALUES_REL  (CLOUDFLARE_* patched)"
echo
echo "Next: ./uis network up cloudflare"
