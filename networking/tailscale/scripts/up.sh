#!/bin/bash
# up.sh — Install the Tailscale operator + optionally the cluster Funnel ingress.
#
# Entry point: uis network up tailscale [--with-cluster-funnel]
#
# Pipeline:
#   1. Refuse if .uis.secrets/service-keys/tailscale.env is missing (run init).
#   2. Refuse if TAILSCALE_OWNER_ID is empty in that file (defensive guard).
#   3. 'uis secrets generate' + 'uis secrets apply' — pushes credentials into
#      the urbalurba-secrets k8s Secret that the playbooks read.
#   4. ansible-playbook 800-tailscale-operator-install.yml — idempotent.
#   5. If --with-cluster-funnel: also ansible-playbook 802-tailscale-funnel-ingress.yml.
#
# Owner-id-change detection: if the running operator's device hostname doesn't
# match TAILSCALE_OWNER_ID in the env file, refuse with a "tear down first" hint
# (the operator Helm release will keep the old owner_id baked into its config).

set -euo pipefail

# ----- Resolve paths -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${UIS_REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
ENV_FILE="$REPO_ROOT/.uis.secrets/service-keys/tailscale.env"
ENV_FILE_REL=".uis.secrets/service-keys/tailscale.env"
PLAYBOOK_INSTALL="$REPO_ROOT/ansible/playbooks/800-tailscale-operator-install.yml"
PLAYBOOK_FUNNEL="$REPO_ROOT/ansible/playbooks/802-tailscale-funnel-ingress.yml"
KUBECONFIG_PATH="${UIS_KUBECONFIG:-/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all}"

if [[ -x "$REPO_ROOT/uis" ]]; then
    UIS_CLI="$REPO_ROOT/uis"
else
    UIS_CLI="$(command -v uis 2>/dev/null || true)"
fi

# ----- Flag parsing -----
WITH_CLUSTER_FUNNEL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-cluster-funnel) WITH_CLUSTER_FUNNEL=1; shift ;;
        --help|-h)
            echo "Usage: uis network up tailscale [--with-cluster-funnel]"
            echo "  Default: installs the Tailscale operator only."
            echo "  --with-cluster-funnel: also creates the cluster Funnel device <owner_id>.<tailnet>."
            exit 0
            ;;
        *)
            echo "✗ Unknown flag: $1" >&2
            echo "  Usage: uis network up tailscale [--with-cluster-funnel]" >&2
            exit 1
            ;;
    esac
done

# ----- Refuse with pointer if init has not been run -----
if [[ ! -f "$ENV_FILE" ]]; then
    echo "✗ No Tailscale config found at $ENV_FILE_REL" >&2
    echo "  Run './uis network init tailscale' first to set credentials." >&2
    exit 1
fi

# Load the env file.
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ----- C-9 defensive guard: empty OWNER_ID -----
if [[ -z "${TAILSCALE_OWNER_ID:-}" ]]; then
    echo "✗ TAILSCALE_OWNER_ID is empty in $ENV_FILE_REL" >&2
    echo "  Re-run './uis network init tailscale' to set it." >&2
    exit 1
fi

# ----- C-11 owner-id-change detection -----
# Check if there's an existing operator pod; if so, read its hostname annotation
# and refuse if it disagrees with the env file's TAILSCALE_OWNER_ID.
_kubectl() {
    if [[ -f "$KUBECONFIG_PATH" ]]; then
        KUBECONFIG="$KUBECONFIG_PATH" kubectl "$@"
    else
        kubectl "$@"
    fi
}

# The operator deployment carries a 'tailscale.com/hostname' label/annotation
# in the form '<owner_id>-tailscale-operator'. Pull it from the StatefulSet
# the Helm chart creates (the operator runs as a single-pod StatefulSet).
running_owner_id="$(_kubectl -n tailscale get deployment operator \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="operator")].env[?(@.name=="OPERATOR_HOSTNAME")].value}' 2>/dev/null \
    | sed 's/-tailscale-operator$//' || true)"

if [[ -n "$running_owner_id" && "$running_owner_id" != "$TAILSCALE_OWNER_ID" ]]; then
    echo "✗ Owner-id mismatch detected." >&2
    echo "  Running operator was deployed with OWNER_ID='$running_owner_id'" >&2
    echo "  But $ENV_FILE_REL now has OWNER_ID='$TAILSCALE_OWNER_ID'" >&2
    echo >&2
    echo "  Tear down first, then redeploy:" >&2
    echo "    ./uis network down tailscale" >&2
    echo "    ./uis network up tailscale" >&2
    exit 1
fi

# ----- Banner -----
echo "═══════════════════════════════════════════════════════════"
echo " Tailscale tunnel deployment"
echo " (uis network up tailscale$([[ $WITH_CLUSTER_FUNNEL -eq 1 ]] && echo ' --with-cluster-funnel'))"
echo " Tailnet:    $TAILSCALE_TAILNET"
echo " Owner ID:   $TAILSCALE_OWNER_ID"
echo " Plan:"
echo "   - Install Tailscale operator (always)"
if (( WITH_CLUSTER_FUNNEL )); then
    echo "   - Create cluster Funnel ingress at https://$TAILSCALE_OWNER_ID.$TAILSCALE_TAILNET"
else
    echo "   - Skip cluster Funnel (per-service expose is the canonical path)"
fi
echo "═══════════════════════════════════════════════════════════"
echo

# ----- 1/N Push credentials into urbalurba-secrets -----
echo "▶ Step 1: Push credentials into urbalurba-secrets (uis secrets generate + apply)..."
if [[ -z "$UIS_CLI" || ! -x "$UIS_CLI" ]]; then
    echo "✗ uis CLI not found — checked $REPO_ROOT/uis and \$PATH." >&2
    echo "  Run inside the UIS container (./uis network up tailscale) or from a repo with ./uis." >&2
    exit 1
fi
"$UIS_CLI" secrets generate
"$UIS_CLI" secrets apply
echo

# ----- 2/N Install the operator -----
echo "▶ Step 2: Install Tailscale operator (ansible-playbook 800-tailscale-operator-install.yml)..."
ansible-playbook "$PLAYBOOK_INSTALL"
echo

# ----- 3/N Optionally create the cluster Funnel ingress -----
if (( WITH_CLUSTER_FUNNEL )); then
    echo "▶ Step 3: Create cluster Funnel ingress (ansible-playbook 802-tailscale-funnel-ingress.yml)..."
    ansible-playbook "$PLAYBOOK_FUNNEL"
    echo
fi

# ----- Summary -----
echo
echo "═══════════════════════════════════════════════════════════"
echo " ✓ Tailscale operator is up"
echo "═══════════════════════════════════════════════════════════"
echo "  Operator:  https://$TAILSCALE_OWNER_ID-tailscale-operator.$TAILSCALE_TAILNET"
if (( WITH_CLUSTER_FUNNEL )); then
    echo "  Cluster:   https://$TAILSCALE_OWNER_ID.$TAILSCALE_TAILNET"
fi
echo
echo "  Expose:    ./uis network expose tailscale <service>"
echo "  Verify:    ./uis network verify tailscale"
echo "  Status:    ./uis network status tailscale"
echo "  Remove:    ./uis network down tailscale"
