#!/bin/bash
# paths.sh - Centralized path detection for UIS
#
# This is the SINGLE SOURCE OF TRUTH for all UIS paths.
# All other libraries should use these functions instead of implementing their own.
#
# Path detection logic:
# 1. If global variable already set, use it
# 2. If container path exists (/mnt/urbalurbadisk/...), use it
# 3. Fall back to host path using get_base_path()

# Guard against multiple sourcing
[[ -n "${_UIS_PATHS_LOADED:-}" ]] && return 0
_UIS_PATHS_LOADED=1

# Determine script directory for sourcing siblings
_PATHS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utilities for get_base_path()
[[ -z "${_UIS_UTILITIES_LOADED:-}" ]] && source "$_PATHS_SCRIPT_DIR/utilities.sh"

# ============================================================
# Core Path Detection Functions
# ============================================================

# Get UIS templates directory (container or host)
# Output: Path to provision-host/uis/templates/
get_templates_dir() {
    # If already set, use it
    [[ -n "${TEMPLATES_DIR:-}" ]] && echo "$TEMPLATES_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/provision-host/uis/templates" ]]; then
        echo "/mnt/urbalurbadisk/provision-host/uis/templates"
        return 0
    fi

    # Host path: derive from this script's location
    local templates_dir
    templates_dir="$(dirname "$_PATHS_SCRIPT_DIR")/templates"
    if [[ -d "$templates_dir" ]]; then
        echo "$templates_dir"
        return 0
    fi

    # Fallback to container path
    echo "/mnt/urbalurbadisk/provision-host/uis/templates"
}

# Get user's extend directory (.uis.extend/)
# Output: Path to .uis.extend/ directory
get_extend_dir() {
    # If already set, use it
    [[ -n "${EXTEND_DIR:-}" ]] && echo "$EXTEND_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/.uis.extend" ]]; then
        echo "/mnt/urbalurbadisk/.uis.extend"
        return 0
    fi

    # Host path: use get_base_path
    echo "$(get_base_path)/.uis.extend"
}

# Get user's secrets directory (.uis.secrets/)
# Output: Path to .uis.secrets/ directory
get_secrets_dir() {
    # If already set, use it
    [[ -n "${SECRETS_DIR:-}" ]] && echo "$SECRETS_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/.uis.secrets" ]]; then
        echo "/mnt/urbalurbadisk/.uis.secrets"
        return 0
    fi

    # Host path: use get_base_path
    echo "$(get_base_path)/.uis.secrets"
}

# Get services directory (service scripts)
# Output: Path to provision-host/uis/services/
get_services_dir() {
    # If already set, use it
    [[ -n "${SERVICES_DIR:-}" ]] && echo "$SERVICES_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/provision-host/uis/services" ]]; then
        echo "/mnt/urbalurbadisk/provision-host/uis/services"
        return 0
    fi

    # Host path: derive from this script's location
    local services_dir
    services_dir="$(dirname "$_PATHS_SCRIPT_DIR")/services"
    if [[ -d "$services_dir" ]]; then
        echo "$services_dir"
        return 0
    fi

    # Fallback to container path
    echo "/mnt/urbalurbadisk/provision-host/uis/services"
}

# Get tools directory (tool install scripts)
# Output: Path to provision-host/uis/tools/
get_tools_dir() {
    # If already set, use it
    [[ -n "${TOOLS_DIR:-}" ]] && echo "$TOOLS_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/provision-host/uis/tools" ]]; then
        echo "/mnt/urbalurbadisk/provision-host/uis/tools"
        return 0
    fi

    # Host path: derive from this script's location
    local tools_dir
    tools_dir="$(dirname "$_PATHS_SCRIPT_DIR")/tools"
    if [[ -d "$tools_dir" ]]; then
        echo "$tools_dir"
        return 0
    fi

    # Fallback to container path
    echo "/mnt/urbalurbadisk/provision-host/uis/tools"
}

# ============================================================
# Derived Path Functions
# ============================================================

# Get host templates directory (for host configurations)
# Output: Path to templates/uis.extend/hosts/
get_hosts_templates_dir() {
    echo "$(get_templates_dir)/uis.extend/hosts"
}

# Get secrets templates directory (for secrets templates)
# Output: Path to templates/uis.secrets/
get_secrets_templates_dir() {
    echo "$(get_templates_dir)/uis.secrets"
}

# Get cloud-init templates directory
# Output: Path to templates/ubuntu-cloud-init/
get_cloud_init_templates_dir() {
    echo "$(get_templates_dir)/ubuntu-cloud-init"
}

# ============================================================
# Global Variables (for backward compatibility)
# ============================================================
# These are set once when paths.sh is sourced, for libraries that
# use global variables instead of function calls.

TEMPLATES_DIR="${TEMPLATES_DIR:-$(get_templates_dir)}"
EXTEND_DIR="${EXTEND_DIR:-$(get_extend_dir)}"
SECRETS_DIR="${SECRETS_DIR:-$(get_secrets_dir)}"
SERVICES_DIR="${SERVICES_DIR:-$(get_services_dir)}"
TOOLS_DIR="${TOOLS_DIR:-$(get_tools_dir)}"

# Export for subprocesses
export TEMPLATES_DIR EXTEND_DIR SECRETS_DIR SERVICES_DIR TOOLS_DIR

# ============================================================
# Legacy Path Constants (for backwards compatibility)
# ============================================================

# New paths (preferred)
NEW_SECRETS_BASE="/mnt/urbalurbadisk/.uis.secrets"
NEW_EXTEND_BASE="/mnt/urbalurbadisk/.uis.extend"

# Old paths (deprecated, for backwards compatibility)
OLD_SECRETS_BASE="/mnt/urbalurbadisk/topsecret"
OLD_SSH_BASE="/mnt/urbalurbadisk/secrets"

# Track if deprecation warning has been shown (show once per session)
_DEPRECATION_WARNING_SHOWN=""

# ============================================================
# Deprecation Warning Function
# ============================================================

# Warn user about deprecated path usage (shows once per session)
# Usage: warn_deprecated_path <old_path> <new_path>
warn_deprecated_path() {
    local old_path="$1"
    local new_path="$2"

    # Only show warning once per session
    [[ -n "$_DEPRECATION_WARNING_SHOWN" ]] && return 0
    _DEPRECATION_WARNING_SHOWN=1

    echo "⚠️  WARNING: Using deprecated path: $old_path" >&2
    echo "   Please migrate to: $new_path" >&2
    echo "   Run './uis' to set up the new structure" >&2
    echo "" >&2
}

# ============================================================
# Backwards-Compatible Path Resolution Functions
# ============================================================
# These functions prefer new paths but fall back to old paths
# with a deprecation warning.

# Get secrets base path (prefers new, falls back to old)
# Output: Path to secrets directory
get_secrets_base_path() {
    if [[ -d "$NEW_SECRETS_BASE" ]]; then
        echo "$NEW_SECRETS_BASE"
    elif [[ -d "$OLD_SECRETS_BASE" ]]; then
        warn_deprecated_path "$OLD_SECRETS_BASE" "$NEW_SECRETS_BASE"
        echo "$OLD_SECRETS_BASE"
    else
        echo "$NEW_SECRETS_BASE"  # Default to new
    fi
}

# Get SSH key directory path
# New: .uis.secrets/ssh/
# Old: secrets/ or topsecret/ssh/
get_ssh_key_path() {
    # New location
    if [[ -d "$NEW_SECRETS_BASE/ssh" ]]; then
        echo "$NEW_SECRETS_BASE/ssh"
        return 0
    fi

    # Old location: secrets/ folder
    if [[ -d "$OLD_SSH_BASE" ]]; then
        warn_deprecated_path "$OLD_SSH_BASE" "$NEW_SECRETS_BASE/ssh"
        echo "$OLD_SSH_BASE"
        return 0
    fi

    # Old location: topsecret/ssh/
    if [[ -d "$OLD_SECRETS_BASE/ssh" ]]; then
        warn_deprecated_path "$OLD_SECRETS_BASE/ssh" "$NEW_SECRETS_BASE/ssh"
        echo "$OLD_SECRETS_BASE/ssh"
        return 0
    fi

    # Default to new
    echo "$NEW_SECRETS_BASE/ssh"
}

# Get Kubernetes secrets output path
# New: .uis.secrets/generated/kubernetes/
# Old: topsecret/kubernetes/
get_kubernetes_secrets_path() {
    # New location
    if [[ -d "$NEW_SECRETS_BASE/generated/kubernetes" ]]; then
        echo "$NEW_SECRETS_BASE/generated/kubernetes"
        return 0
    fi

    # New location (but generated/ doesn't exist yet)
    if [[ -d "$NEW_SECRETS_BASE" ]]; then
        echo "$NEW_SECRETS_BASE/generated/kubernetes"
        return 0
    fi

    # Old location
    if [[ -d "$OLD_SECRETS_BASE/kubernetes" ]]; then
        warn_deprecated_path "$OLD_SECRETS_BASE/kubernetes" "$NEW_SECRETS_BASE/generated/kubernetes"
        echo "$OLD_SECRETS_BASE/kubernetes"
        return 0
    fi

    # Default to new
    echo "$NEW_SECRETS_BASE/generated/kubernetes"
}

# Get cloud-init output path
# New: .uis.secrets/generated/ubuntu-cloud-init/
# Old: cloud-init/
get_cloud_init_output_path() {
    # New location
    if [[ -d "$NEW_SECRETS_BASE/generated/ubuntu-cloud-init" ]]; then
        echo "$NEW_SECRETS_BASE/generated/ubuntu-cloud-init"
        return 0
    fi

    # New location (but generated/ doesn't exist yet)
    if [[ -d "$NEW_SECRETS_BASE" ]]; then
        echo "$NEW_SECRETS_BASE/generated/ubuntu-cloud-init"
        return 0
    fi

    # Old location
    if [[ -d "/mnt/urbalurbadisk/cloud-init" ]]; then
        warn_deprecated_path "/mnt/urbalurbadisk/cloud-init" "$NEW_SECRETS_BASE/generated/ubuntu-cloud-init"
        echo "/mnt/urbalurbadisk/cloud-init"
        return 0
    fi

    # Default to new
    echo "$NEW_SECRETS_BASE/generated/ubuntu-cloud-init"
}

# Get kubeconfig output path
# New: .uis.secrets/generated/kubeconfig/
# Old: various locations (topsecret/, home directory)
get_kubeconfig_path() {
    # New location
    if [[ -d "$NEW_SECRETS_BASE/generated/kubeconfig" ]]; then
        echo "$NEW_SECRETS_BASE/generated/kubeconfig"
        return 0
    fi

    # New location (but generated/ doesn't exist yet)
    if [[ -d "$NEW_SECRETS_BASE" ]]; then
        echo "$NEW_SECRETS_BASE/generated/kubeconfig"
        return 0
    fi

    # Old location: topsecret
    if [[ -d "$OLD_SECRETS_BASE" ]]; then
        warn_deprecated_path "$OLD_SECRETS_BASE" "$NEW_SECRETS_BASE/generated/kubeconfig"
        echo "$OLD_SECRETS_BASE"
        return 0
    fi

    # Default to new
    echo "$NEW_SECRETS_BASE/generated/kubeconfig"
}

# Get Tailscale auth key file path
# New: .uis.secrets/service-keys/tailscale.env
# Old: topsecret/kubernetes/kubernetes-secrets.yml (embedded)
get_tailscale_key_path() {
    local new_path="$NEW_SECRETS_BASE/service-keys/tailscale.env"
    local old_path="$OLD_SECRETS_BASE/kubernetes/kubernetes-secrets.yml"

    # New location
    if [[ -f "$new_path" ]]; then
        echo "$new_path"
        return 0
    fi

    # Old location (note: key embedded in yaml, not a direct env file)
    if [[ -f "$old_path" ]]; then
        warn_deprecated_path "$old_path" "$new_path"
        echo "$old_path"
        return 0
    fi

    # Default to new
    echo "$new_path"
}

# Get Cloudflare credentials file path
# New: .uis.secrets/service-keys/cloudflare.env
# Old: topsecret/cloudflare/ or embedded in kubernetes-secrets.yml
get_cloudflare_token_path() {
    local new_path="$NEW_SECRETS_BASE/service-keys/cloudflare.env"

    # New location
    if [[ -f "$new_path" ]]; then
        echo "$new_path"
        return 0
    fi

    # Old location: topsecret/cloudflare/
    if [[ -d "$OLD_SECRETS_BASE/cloudflare" ]]; then
        warn_deprecated_path "$OLD_SECRETS_BASE/cloudflare" "$new_path"
        echo "$OLD_SECRETS_BASE/cloudflare"
        return 0
    fi

    # Default to new
    echo "$new_path"
}

# Get cloud account credentials path
# New: .uis.secrets/cloud-accounts/<provider>.env
# Old: various locations
get_cloud_credentials_path() {
    local provider="${1:-azure}"
    local new_path="$NEW_SECRETS_BASE/cloud-accounts/${provider}-default.env"

    # New location
    if [[ -f "$new_path" ]]; then
        echo "$new_path"
        return 0
    fi

    # Default to new
    echo "$new_path"
}

# ============================================================
# Helper Functions for Scripts
# ============================================================

# Check if using new paths structure
# Returns: 0 if new structure exists, 1 if using legacy
is_using_new_paths() {
    [[ -d "$NEW_SECRETS_BASE" ]]
}

# Check if using legacy paths structure
# Returns: 0 if legacy structure exists, 1 if not
is_using_legacy_paths() {
    [[ -d "$OLD_SECRETS_BASE" ]] && [[ ! -d "$NEW_SECRETS_BASE" ]]
}

# Ensure a directory exists, creating it if needed
# Usage: ensure_path_exists <path>
ensure_path_exists() {
    local path="$1"
    [[ -d "$path" ]] || mkdir -p "$path"
}
