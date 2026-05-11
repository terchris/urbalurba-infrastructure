#!/bin/bash
# status.sh — Rancher Desktop status (the always-present local platform).
#
# Spec: PLAN-platform-list-use-and-banner.md Phase 2.2
# Investigation: INVESTIGATE-active-cluster-visibility-ux.md C-1 (rancher-desktop subsection)
#
# Rancher Desktop is installed at the OS level, not provisioned by UIS, so it
# has no env file and uses **3 of the 4 C-1 states**:
#
#   not-initialized: kubectl context absent in kubeconf-all → "Rancher Desktop
#                    not installed or never started"
#   running:         context present + probe succeeds
#   unreachable:     context present + probe fails ("Rancher Desktop installed
#                    but currently stopped")
#
# `configured-not-running` doesn't apply — there's nothing UIS can "configure"
# for rancher-desktop; installation is the user's OS step.

set -euo pipefail

KUBECONFIG_PATH="${UIS_KUBECONFIG:-/mnt/urbalurbadisk/kubeconfig/kubeconf-all}"
CONTEXT_NAME="rancher-desktop"

# ----- Flag parsing -----
SUMMARY=0
OFFLINE=0
DEEP=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary) SUMMARY=1; shift ;;
        --offline) OFFLINE=1; shift ;;
        --deep)    DEEP=1;    shift ;;
        *) shift ;;
    esac
done

# ----- Summary path (C-1 contract) -----
if (( SUMMARY )); then
    if ! KUBECONFIG="$KUBECONFIG_PATH" kubectl config get-contexts "$CONTEXT_NAME" >/dev/null 2>&1; then
        printf 'not-initialized\tinstall Rancher Desktop and start it, then '\''./uis start'\''\n'
        exit 0
    fi
    if (( OFFLINE )); then
        printf 'running\t(offline — reachability not probed)\n'
        exit 0
    fi
    if ! KUBECONFIG="$KUBECONFIG_PATH" kubectl --context "$CONTEXT_NAME" \
            --request-timeout=3s get --raw /version >/dev/null 2>&1; then
        printf 'unreachable\tstart Rancher Desktop\n'
        exit 0
    fi
    # Optional: --deep pulls the k3s version
    if (( DEEP )); then
        _ver="$(KUBECONFIG="$KUBECONFIG_PATH" kubectl --context "$CONTEXT_NAME" \
                version --output=jsonpath='{.serverVersion.gitVersion}' 2>/dev/null \
                | sed 's/^v//' || true)"
        if [[ -n "$_ver" ]]; then
            printf 'running\tlocal k3s, k8s %s\n' "$_ver"
        else
            printf 'running\tlocal k3s\n'
        fi
    else
        printf 'running\tlocal k3s\n'
    fi
    exit 0
fi

# ----- Human-readable path (default invocation) -----
echo "═══════════════════════════════════════════════════════════"
echo " Rancher Desktop status"
echo " (uis platform status rancher-desktop)"
echo "═══════════════════════════════════════════════════════════"
echo

if ! KUBECONFIG="$KUBECONFIG_PATH" kubectl config get-contexts "$CONTEXT_NAME" >/dev/null 2>&1; then
    echo "  Status:    not installed (or never started)"
    echo "  Cost:      €0/day  (local desktop app — no cloud resources)"
    echo
    echo "  To install: download Rancher Desktop from https://rancherdesktop.io/"
    echo "  After install + first start, run: ./uis start"
    exit 0
fi

if ! KUBECONFIG="$KUBECONFIG_PATH" kubectl --context "$CONTEXT_NAME" \
        --request-timeout=3s get --raw /version >/dev/null 2>&1; then
    echo "  Status:    installed but not running (API server unreachable)"
    echo "  Cost:      €0/day  (local desktop app — no cloud resources)"
    echo
    echo "  Recover:   start Rancher Desktop from your applications, then './uis start'"
    exit 0
fi

# Running — pull a few details
NODES=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl --context "$CONTEXT_NAME" \
        get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
K8S=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl --context "$CONTEXT_NAME" \
      version --output=jsonpath='{.serverVersion.gitVersion}' 2>/dev/null | sed 's/^v//' || echo "unknown")

echo "  Status:    ✓ running"
echo "  Nodes:     $NODES"
echo "  k8s:       $K8S"
echo "  Cost:      €0/day  (local desktop app — no cloud resources)"
echo
echo "  Switch:    ./uis platform use rancher-desktop"
