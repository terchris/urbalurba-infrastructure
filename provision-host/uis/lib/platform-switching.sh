#!/bin/bash
# platform-switching.sh — Shared helpers for `./uis platform list / use` + Layer 1 banner.
#
# Spec: website/docs/ai-developer/plans/active/PLAN-platform-list-use-and-banner.md
# Investigation: website/docs/ai-developer/plans/backlog/INVESTIGATE-active-cluster-visibility-ux.md
#
# Functions:
#   pf_active_platform           Echo kubectl current-context from kubeconf-all.
#   pf_probe_reachable <ctx>     Return 0 if API reachable (3s timeout), else non-zero.
#   pf_lockstep_flip <platform>  Atomic write: kubectl context + cluster-config.sh.
#   pf_list_platforms            Echo platform names (rancher-desktop + platforms/*).
#   pf_platform_summary <plat>   Invoke <plat>/scripts/status.sh --summary, validate, echo.
#   pf_banner [opts]             Layer 1 banner to stderr; honors UIS_BANNER_PRINTED.
#
# Sourced by: provision-host/uis/manage/uis-cli.sh (cmd_platform_list / cmd_platform_use
# and every cluster-touching cmd_<verb> for the banner), platforms/azure-aks/scripts/
# 02-post-apply.sh + 03-destroy.sh (lockstep writer for auto-flip/auto-reset).
#
# Container-fixed paths. The kubeconf-all sits at the in-container location (NOT
# bind-mounted) to keep kubectl's flock working on Rancher Desktop's lima VM —
# the bind-mounted path under .uis.secrets/generated/kubeconfig/ breaks flock.
PF_KUBECONFIG="${PF_KUBECONFIG:-/mnt/urbalurbadisk/kubeconfig/kubeconf-all}"
PF_CLUSTER_CONFIG="${PF_CLUSTER_CONFIG:-/mnt/urbalurbadisk/.uis.extend/cluster-config.sh}"
PF_PLATFORMS_DIR="${PF_PLATFORMS_DIR:-/mnt/urbalurbadisk/platforms}"
PF_PROBE_TIMEOUT="${PF_PROBE_TIMEOUT:-3s}"

# C-1 enum — the only valid <state> values status.sh --summary may emit.
PF_VALID_STATES_REGEX='^(not-initialized|configured-not-running|running|unreachable)$'


# ----- pf_ensure_kubeconf_seeded ----------------------------------------------
# Bootstrap `kubeconf-all` on a fresh container. The merged kubeconfig is only
# *built* by 02-post-apply.sh during AKS provisioning, but `platform list` is
# the discovery command novices use *before* any cluster work. Without a seed
# step, a fresh container reports rancher-desktop as `not-initialized` even
# when it's running on the host. F15 from talk48.
#
# Strategy: when kubeconf-all is missing, extract the rancher-desktop context
# from the bind-mounted host kubeconfig at /home/ansible/.kube/config and write
# it BOTH to:
#   - rancher-desktop-kubeconf — the per-platform seed file the existing
#     04-merge-kubeconf.yml playbook picks up. Ensures rancher-desktop survives
#     the AKS merge that runs at the end of 02-post-apply.sh.
#   - kubeconf-all directly — so `platform list` / `platform use` work right
#     now, before any merge has run.
#
# Idempotent: returns 0 immediately if kubeconf-all already exists, or if the
# host kubeconfig is missing / has no rancher-desktop context (clean CI env).
# Safe to call from any pf_* entry point.
pf_ensure_kubeconf_seeded() {
    [[ -f "$PF_KUBECONFIG" ]] && return 0

    local host_kc="/home/ansible/.kube/config"
    [[ -f "$host_kc" ]] || return 0

    # Does the host have a rancher-desktop context to seed from?
    KUBECONFIG="$host_kc" kubectl config get-contexts rancher-desktop \
        >/dev/null 2>&1 || return 0

    local kc_dir
    kc_dir="$(dirname "$PF_KUBECONFIG")"
    mkdir -p "$kc_dir" 2>/dev/null || return 0

    # Extract just the rancher-desktop context (--minify drops other contexts
    # the user might have on their host; --flatten inlines cert/key data so
    # the file is self-contained).
    local seed_file="$kc_dir/rancher-desktop-kubeconf"
    KUBECONFIG="$host_kc" kubectl config view \
        --minify --context=rancher-desktop --flatten \
        > "$seed_file" 2>/dev/null || { rm -f "$seed_file"; return 0; }

    cp "$seed_file" "$PF_KUBECONFIG"
    chmod 600 "$seed_file" "$PF_KUBECONFIG" 2>/dev/null || true
}


# ----- pf_active_platform -----------------------------------------------------
# Echo the kubectl current-context name (the active platform per Q1). Empty
# string if unset (e.g. fresh kubeconfig).
pf_active_platform() {
    pf_ensure_kubeconf_seeded
    KUBECONFIG="$PF_KUBECONFIG" kubectl config current-context 2>/dev/null || echo ""
}


# ----- pf_probe_reachable -----------------------------------------------------
# The shared primitive for "is this cluster reachable right now?". Used by
# Layer 1's banner (C-9) and by per-platform status.sh --summary (C-1 state
# machine). Targets the named context explicitly — never the bare current
# context (which would give wrong-cluster answers when probing a non-active
# platform; see F12 from talk46).
pf_probe_reachable() {
    local ctx="${1:-}"
    [[ -z "$ctx" ]] && return 2
    KUBECONFIG="$PF_KUBECONFIG" kubectl --context "$ctx" \
        --request-timeout="$PF_PROBE_TIMEOUT" \
        get --raw /version >/dev/null 2>&1
}


# ----- pf_lockstep_flip -------------------------------------------------------
# Atomic write of both halves of "the active platform":
#   1. kubectl current-context in kubeconf-all (truth for reads, Q1)
#   2. cluster-config.sh's CLUSTER_TYPE + TARGET_HOST fields (cached projection
#      that ansible playbooks read for inventory; written here in lockstep so
#      it always agrees with kubectl by construction)
#
# Three call sites converge on this function:
#   - 02-post-apply.sh's auto-flip-on-up
#   - 03-destroy.sh's auto-reset-on-down
#   - cmd_platform_use's manual flip
# Single writer means cluster-config.sh can never silently diverge from the
# kubectl context — Q4 of the investigation.
pf_lockstep_flip() {
    local platform="${1:?pf_lockstep_flip: missing platform argument}"

    # Truth for reads.
    KUBECONFIG="$PF_KUBECONFIG" kubectl config use-context "$platform" >/dev/null

    # Cached projection. By convention CLUSTER_TYPE == TARGET_HOST == platform
    # directory name (per the investigation's edge case #10). Write both for
    # backward compat with existing ansible readers; future work can collapse.
    if [[ -f "$PF_CLUSTER_CONFIG" ]]; then
        sed -i.bak \
            -e "s|^CLUSTER_TYPE=.*|CLUSTER_TYPE=\"$platform\"|" \
            -e "s|^TARGET_HOST=.*|TARGET_HOST=\"$platform\"|" \
            "$PF_CLUSTER_CONFIG"
        rm -f "${PF_CLUSTER_CONFIG}.bak"
    fi
}


# ----- pf_list_platforms ------------------------------------------------------
# Emit the inventory of "potential platforms UIS knows about" to stdout, one
# name per line. Sources per Q3:
#   - rancher-desktop hard-coded (always present; installed at OS level, no init.sh)
#   - Every platforms/<name>/scripts/init.sh directory listing, skipping any
#     name starting with _ or . (hidden/WIP directories — edge case #8)
#
# rancher-desktop is emitted first so it lands at the top of `list`'s table.
pf_list_platforms() {
    echo "rancher-desktop"
    local script_path name
    for script_path in "$PF_PLATFORMS_DIR"/*/scripts/init.sh; do
        [[ -f "$script_path" ]] || continue
        name="$(basename "$(dirname "$(dirname "$script_path")")")"
        case "$name" in
            _*|.*) continue ;;
            rancher-desktop) continue ;;  # already emitted above
        esac
        echo "$name"
    done
}


# ----- pf_platform_summary ----------------------------------------------------
# Invoke <platform>/scripts/status.sh --summary [--offline|--deep] and capture
# the tab-separated <state>\t<hint> output. Validates field 1 is a valid C-1
# enum state. Echoes the captured line on stdout, returns 0 on success, non-zero
# if the script is missing, errors, or emits malformed output (caller renders
# `? error` for that row).
#
# Extra args after $1 are passed through unchanged — supports both
#   pf_platform_summary azure-aks
#   pf_platform_summary azure-aks --offline
#   pf_platform_summary azure-aks --deep
pf_platform_summary() {
    local platform="${1:?pf_platform_summary: missing platform argument}"
    shift
    local script="$PF_PLATFORMS_DIR/$platform/scripts/status.sh"
    [[ -x "$script" ]] || return 1
    local line
    line="$("$script" --summary "$@" 2>/dev/null)" || return 1
    local state="${line%%	*}"
    [[ "$state" =~ $PF_VALID_STATES_REGEX ]] || return 1
    echo "$line"
}


# ----- pf_banner --------------------------------------------------------------
# Layer 1 banner (C-9). Writes to stderr per C-9's output-stream decision
# (success doesn't drown out piped stdout; failure stays visible).
#
# Flags:
#   --silent-if-set    Suppress banner when UIS_BANNER_PRINTED=1 is set (C-4
#                      child-suppression for `stack install` → child deploys).
#   --check-reachable  Run the reachability probe and surface the result —
#                      emits the four C-9 cases. Without this flag the banner
#                      just names the active platform without probing.
#
# Returns 0 on the success/warn cases (1, 3 — caller proceeds). Returns 1 on
# the abort cases (2, 4 — caller is expected to exit). The function does NOT
# call `exit` itself so it's composable in any caller (dispatcher / sourced
# helper / test harness).
pf_banner() {
    local silent_if_set=0
    local check_reachable=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --silent-if-set) silent_if_set=1; shift ;;
            --check-reachable) check_reachable=1; shift ;;
            *) shift ;;  # ignore unknown flags
        esac
    done

    # C-4 — child invocation under `stack install` etc.
    if (( silent_if_set )) && [[ "${UIS_BANNER_PRINTED:-0}" == "1" ]]; then
        return 0
    fi

    local active
    active="$(pf_active_platform)"

    # Case 4 — no active context. Abort with the rancher-desktop recovery hint.
    if [[ -z "$active" ]]; then
        {
            echo "⚠  No active kubectl context set."
            echo "   Run './uis platform use rancher-desktop' (the default) or './uis platform list' to see what you have."
            echo "   Aborting."
        } >&2
        return 1
    fi

    # Is the active context a UIS-managed platform?
    local is_uis_platform=0
    if [[ "$active" == "rancher-desktop" ]] || [[ -f "$PF_PLATFORMS_DIR/$active/scripts/init.sh" ]]; then
        is_uis_platform=1
    fi

    # Case 3 — active context is not a UIS platform (personal cluster etc.).
    # One-liner warning; caller proceeds.
    if (( ! is_uis_platform )); then
        echo "⚠  Platform: $active (not a UIS platform — proceeding with kubectl context anyway)" >&2
        # Mark printed so children don't re-banner.
        export UIS_BANNER_PRINTED=1
        return 0
    fi

    # If --check-reachable wasn't requested, name the platform and return.
    if (( ! check_reachable )); then
        echo "ℹ  Platform: $active" >&2
        export UIS_BANNER_PRINTED=1
        return 0
    fi

    # Case 1 — UIS platform AND reachable. One-liner success.
    if pf_probe_reachable "$active"; then
        echo "ℹ  Platform: $active (reachable)" >&2
        export UIS_BANNER_PRINTED=1
        return 0
    fi

    # Case 2 — UIS platform BUT unreachable. Multi-line block + abort. Pull
    # the platform-specific hint from the active platform's status.sh --summary
    # field 2 (only on this error path; common path doesn't pay this cost).
    local summary hint=""
    if summary="$(pf_platform_summary "$active" 2>/dev/null)"; then
        hint="${summary#*	}"
    fi
    {
        echo "✗  Platform: $active, but the API server is unreachable."
        [[ -n "$hint" ]] && echo "   $hint"
        echo "   Recover with: ./uis platform status $active"
        echo "   Or switch:    ./uis platform use rancher-desktop  (or another reachable platform)"
        echo "   Aborting."
    } >&2
    return 1
}


# Make the functions available to child shells if needed (sub-shell invocations
# from ansible's `shell` module, etc.). Most callers source this file directly.
export -f pf_ensure_kubeconf_seeded pf_active_platform pf_probe_reachable
export -f pf_lockstep_flip pf_list_platforms pf_platform_summary pf_banner
