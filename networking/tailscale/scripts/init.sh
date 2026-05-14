#!/bin/bash
# init.sh — Interactive wizard for Tailscale onboarding.
#
# Entry point: ./uis network init tailscale
#
# Writes .uis.secrets/service-keys/tailscale.env with the four values the
# cluster operator path needs:
#   - TAILSCALE_TAILNET      (MagicDNS domain, e.g. dog-pence.ts.net)
#   - TAILSCALE_CLIENTID     (OAuth client ID)
#   - TAILSCALE_CLIENTSECRET (OAuth client secret)
#   - TAILSCALE_OWNER_ID     (cluster owner identity on the shared tailnet)
#
# The auth key (TAILSCALE_VM_AUTH_KEY) is NOT prompted here — it's only used
# by the cloud-init / VM-bootstrap path, which is out of scope of the cluster
# CLI. Users who provision VMs set it manually in 00-common-values.env.template.

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# networking/tailscale/scripts/init.sh → repo root is three levels up.
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
ENV_FILE_REL=".uis.secrets/service-keys/tailscale.env"
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
echo " Tailscale Funnel setup wizard"
echo " (uis network init tailscale)"
echo " Writes credentials. No operator is installed yet."
echo "═══════════════════════════════════════════════════════════"
echo
echo "⚠ Important: Tailscale Funnel BYPASSES Traefik. The operator's per-service"
echo "  proxy routes directly to the backend Service — Authentik forward-auth,"
echo "  Traefik middleware, and HostRegexp rules do NOT apply on Tailscale URLs."
echo "  If a service needs auth, the service itself has to enforce it."
echo

# ----- TTY guard -----
if [[ ! -t 0 ]]; then
    print_error "uis network init tailscale requires an interactive terminal."
    echo "  Run it from your terminal (not piped, not inside a non-tty container exec)."
    exit 1
fi

# ----- Pre-conditions reminder -----
echo "Before continuing you need four things from the Tailscale admin console:"
echo "  1. MagicDNS enabled at https://login.tailscale.com/admin/dns"
echo "     (gives you your <words>.ts.net domain — note it for prompt 1)"
echo "  2. An OAuth client at https://login.tailscale.com/admin/settings/oauth"
echo "     with 'Devices Core (write)' + 'Keys Auth Keys (write)' scopes,"
echo "     both tagged 'tag:k8s-operator'"
echo "     (Client ID + Client Secret for prompts 2 + 3)"
echo "  3. An ACL rule at https://login.tailscale.com/admin/acls granting"
echo "     'funnel' attribute to 'tag:k8s-operator' devices."
echo "  4. Your chosen owner-id — a short name unique on the tailnet"
echo "     (e.g. 'terje', 'k8s-imac'; collides if two devs both use 'k8s')"
echo
echo "Step-by-step dashboard walk-through:"
echo "  https://uis.sovereignsky.no/docs/networking/tailscale-setup#step-2"
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
            print_status "Keeping existing config. To deploy: ./uis network up tailscale"
            exit 0
            ;;
        2)
            # fall through to prompts
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

# ----- Prompt 1: TAILSCALE_TAILNET (MagicDNS domain) -----
echo
echo "Prompt 1 of 4: TAILSCALE_TAILNET — your MagicDNS domain."
echo "  Example: dog-pence.ts.net"
read -rp "  TAILSCALE_TAILNET: " tailnet
if [[ -z "$tailnet" ]]; then
    print_error "TAILSCALE_TAILNET is required. Aborting."
    exit 1
fi

# ----- Prompt 2: TAILSCALE_CLIENTID -----
echo
echo "Prompt 2 of 4: TAILSCALE_CLIENTID — OAuth client ID from Tailscale admin."
read -rp "  TAILSCALE_CLIENTID: " clientid
if [[ -z "$clientid" ]]; then
    print_error "TAILSCALE_CLIENTID is required. Aborting."
    exit 1
fi

# ----- Prompt 3: TAILSCALE_CLIENTSECRET -----
echo
echo "Prompt 3 of 4: TAILSCALE_CLIENTSECRET — OAuth client secret (input hidden)."
read -rsp "  TAILSCALE_CLIENTSECRET: " clientsecret
echo
if [[ -z "$clientsecret" ]]; then
    print_error "TAILSCALE_CLIENTSECRET is required. Aborting."
    exit 1
fi

# ----- Prompt 4: TAILSCALE_OWNER_ID -----
echo
echo "Prompt 4 of 4: TAILSCALE_OWNER_ID — your cluster's identity on the tailnet."
echo "  This becomes the prefix for every Tailscale device the cluster creates:"
echo "    Operator pod:     <owner_id>-tailscale-operator.<tailnet>"
echo "    Cluster Funnel:   <owner_id>.<tailnet>          (opt-in via --with-cluster-funnel)"
echo "    Per-service:      <service>.<tailnet>           (no owner_id prefix on these)"
echo
echo "  Pick something unique on the tailnet:"
echo "    Solo:    terje, alice, bob"
echo "    Team:    terje-imac, alice-laptop, bob-mbp"
echo
echo "  Charset: lowercase a-z, digits, dashes. Max 32 chars. No leading/trailing dash."
read -rp "  TAILSCALE_OWNER_ID: " owner_id
if [[ -z "$owner_id" ]]; then
    print_error "TAILSCALE_OWNER_ID is required. Aborting."
    exit 1
fi
if [[ ${#owner_id} -gt 32 ]]; then
    print_error "TAILSCALE_OWNER_ID is ${#owner_id} chars; max is 32 so '<service>-<owner_id>' fits Tailscale's 63-char device-name limit."
    exit 1
fi
if [[ ! "$owner_id" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    print_error "TAILSCALE_OWNER_ID '$owner_id' is not a legal hostname segment."
    echo "  Must be 1-32 chars of [a-z0-9-], not starting or ending with a hyphen."
    exit 1
fi

# ----- Persist (file 1/2): service-keys/tailscale.env -----
mkdir -p "$(dirname "$ENV_FILE")"
tmp_file="$(dirname "$ENV_FILE")/.tailscale.env.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

cat > "$tmp_file" <<EOF
# Tailscale Funnel configuration
# Written by 'uis network init tailscale' on $(date -u +%Y-%m-%dT%H:%M:%SZ).
# Used by: networking/tailscale/scripts/status.sh (configured/running detection).
#
# The real load-bearing copy lives in:
#   $COMMON_VALUES_REL
# Both files are updated together; 'uis secrets generate' reads the latter.
#
# Update / regenerate with: ./uis network init tailscale

TAILSCALE_TAILNET="$tailnet"
TAILSCALE_CLIENTID="$clientid"
TAILSCALE_CLIENTSECRET="$clientsecret"
TAILSCALE_OWNER_ID="$owner_id"
EOF

chmod 600 "$tmp_file"
mv "$tmp_file" "$ENV_FILE"

# ----- Persist (file 2/2): patch the master common-values template -----
if [[ ! -f "$COMMON_VALUES" ]]; then
    print_warning "Common values template not found: $COMMON_VALUES_REL"
    print_warning "Credentials saved to service-keys but secrets pipeline can't pick them up."
    print_warning "Run 'uis secrets init' first, then re-run 'uis network init tailscale'."
    exit 1
fi

# In-place sed update. Use a delimiter (|) that doesn't appear in any of the
# four values' typical shape (alphanumeric + dots + dashes for tailnet/owner_id,
# alphanumeric + dashes + 'tskey-client-' prefix for clientid/clientsecret).
tailnet_esc=${tailnet//|/\\|}
clientid_esc=${clientid//|/\\|}
clientsecret_esc=${clientsecret//|/\\|}
owner_id_esc=${owner_id//|/\\|}

cv_tmp="$COMMON_VALUES.tmp.$$"
trap 'rm -f "$tmp_file" "$cv_tmp"' EXIT
cp "$COMMON_VALUES" "$cv_tmp"
sed -i.bak "s|^TAILSCALE_TAILNET=.*|TAILSCALE_TAILNET=$tailnet_esc|" "$cv_tmp"
sed -i.bak "s|^TAILSCALE_CLIENTID=.*|TAILSCALE_CLIENTID=$clientid_esc|" "$cv_tmp"
sed -i.bak "s|^TAILSCALE_CLIENTSECRET=.*|TAILSCALE_CLIENTSECRET=$clientsecret_esc|" "$cv_tmp"
sed -i.bak "s|^TAILSCALE_OWNER_ID=.*|TAILSCALE_OWNER_ID=$owner_id_esc|" "$cv_tmp"
rm -f "$cv_tmp.bak"
chmod 600 "$cv_tmp"
mv "$cv_tmp" "$COMMON_VALUES"

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Tailscale config ready"
echo "═══════════════════════════════════════════════════════════"
echo "  Tailnet:       $tailnet"
echo "  Owner ID:      $owner_id"
echo "  OAuth client:  $clientid (secret: set, ${#clientsecret} chars)"
echo "  Files:"
echo "    $ENV_FILE_REL"
echo "    $COMMON_VALUES_REL  (TAILSCALE_* patched)"
echo
echo "Devices that will register on first deploy:"
echo "  https://$owner_id-tailscale-operator.$tailnet     (operator pod, always)"
echo "  https://$owner_id.$tailnet                        (cluster Funnel, opt-in)"
echo "  https://<service>.$tailnet                        (per-service expose)"
echo
echo "Next:"
echo "  ./uis network up tailscale                       # install operator only"
echo "  ./uis network up tailscale --with-cluster-funnel # also create cluster Funnel device"
