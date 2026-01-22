#!/bin/bash
# first-run.sh - First-run helpers (runs INSIDE container)
#
# NOTE: Folder creation (.uis.extend/, .uis.secrets/) happens on HOST in wrapper script.
# This library manages CONTENTS of those folders once mounted.

# shellcheck disable=SC2034  # Variables are used by callers

# Determine script directory for sourcing siblings
_FIRSTRUN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$_FIRSTRUN_SCRIPT_DIR/logging.sh"
source "$_FIRSTRUN_SCRIPT_DIR/utilities.sh"

# Default paths (can be overridden)
EXTEND_DIR="${EXTEND_DIR:-/mnt/urbalurbadisk/.uis.extend}"
SECRETS_DIR="${SECRETS_DIR:-/mnt/urbalurbadisk/.uis.secrets}"
TEMPLATES_DIR="${TEMPLATES_DIR:-/mnt/urbalurbadisk/provision-host/uis/templates}"

# Check if first-run setup has been completed
# Returns: 0 if configured, 1 if needs setup
check_first_run() {
    [[ -f "$EXTEND_DIR/enabled-services.conf" ]]
}

# Copy default config files if they don't exist
# Called when container starts with empty mounted volumes
copy_defaults_if_missing() {
    local templates_extend="$TEMPLATES_DIR/uis.extend"
    local templates_secrets="$TEMPLATES_DIR/uis.secrets"

    # Copy enabled-services.conf
    if [[ ! -f "$EXTEND_DIR/enabled-services.conf" ]]; then
        if [[ -f "$templates_extend/enabled-services.conf.default" ]]; then
            cp "$templates_extend/enabled-services.conf.default" "$EXTEND_DIR/enabled-services.conf"
            log_info "Created enabled-services.conf with defaults"
        else
            log_warn "Template enabled-services.conf.default not found"
        fi
    fi

    # Copy cluster-config.sh
    if [[ ! -f "$EXTEND_DIR/cluster-config.sh" ]]; then
        if [[ -f "$templates_extend/cluster-config.sh.default" ]]; then
            cp "$templates_extend/cluster-config.sh.default" "$EXTEND_DIR/cluster-config.sh"
            log_info "Created cluster-config.sh with defaults"
        else
            log_warn "Template cluster-config.sh.default not found"
        fi
    fi

    # Copy enabled-tools.conf
    if [[ ! -f "$EXTEND_DIR/enabled-tools.conf" ]]; then
        if [[ -f "$templates_extend/enabled-tools.conf.default" ]]; then
            cp "$templates_extend/enabled-tools.conf.default" "$EXTEND_DIR/enabled-tools.conf"
            log_info "Created enabled-tools.conf with defaults"
        else
            log_warn "Template enabled-tools.conf.default not found"
        fi
    fi

    # Copy secrets README if missing
    if [[ ! -f "$SECRETS_DIR/README.md" ]]; then
        if [[ -f "$templates_secrets/README.md" ]]; then
            cp "$templates_secrets/README.md" "$SECRETS_DIR/README.md"
            log_info "Created secrets README.md"
        fi
    fi

    # Create secrets subdirectories if missing
    local subdirs=("secrets-config" "kubernetes" "api-keys")
    for subdir in "${subdirs[@]}"; do
        if [[ ! -d "$SECRETS_DIR/$subdir" ]]; then
            mkdir -p "$SECRETS_DIR/$subdir"
            log_info "Created $SECRETS_DIR/$subdir/"
        fi
    done
}

# Validate that config structure is correct
# Returns: 0 if valid, dies with error if invalid
validate_config_structure() {
    if [[ ! -d "$EXTEND_DIR" ]]; then
        die_config ".uis.extend/ not mounted at $EXTEND_DIR"
    fi

    if [[ ! -d "$SECRETS_DIR" ]]; then
        die_config ".uis.secrets/ not mounted at $SECRETS_DIR"
    fi

    if [[ ! -f "$EXTEND_DIR/enabled-services.conf" ]]; then
        die_config "enabled-services.conf missing from $EXTEND_DIR"
    fi

    return 0
}

# Initialize UIS configuration (copy defaults and validate)
# This should be called once at startup
initialize_uis_config() {
    log_info "Initializing UIS configuration..."

    # Copy defaults if missing
    copy_defaults_if_missing

    # Validate structure
    validate_config_structure

    log_success "UIS configuration initialized"
}

# Load cluster configuration
# Exports: CLUSTER_TYPE, PROJECT_NAME, BASE_DOMAIN, TARGET_HOST
load_cluster_config() {
    local config_file="$EXTEND_DIR/cluster-config.sh"

    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
        log_info "Loaded cluster config: $CLUSTER_TYPE"
    else
        # Use defaults
        CLUSTER_TYPE="${CLUSTER_TYPE:-rancher-desktop}"
        PROJECT_NAME="${PROJECT_NAME:-uis}"
        BASE_DOMAIN="${BASE_DOMAIN:-localhost}"
        TARGET_HOST="${TARGET_HOST:-rancher-desktop}"
        log_warn "No cluster-config.sh found, using defaults"
    fi

    export CLUSTER_TYPE PROJECT_NAME BASE_DOMAIN TARGET_HOST
}

# Get default secrets value (for development)
# Usage: get_default_secret <key>
# Returns: the default value or empty string
get_default_secret() {
    local key="$1"
    local defaults_file="$TEMPLATES_DIR/default-secrets.env"

    if [[ ! -f "$defaults_file" ]]; then
        return 1
    fi

    # Source the file and get the value
    (
        # shellcheck source=/dev/null
        source "$defaults_file" 2>/dev/null
        echo "${!key}"
    )
}

# Check if using default secrets (development mode)
# Returns: 0 if using defaults, 1 if custom secrets configured
is_using_default_secrets() {
    # If any custom secret files exist, not using defaults
    if [[ -n "$(ls -A "$SECRETS_DIR/secrets-config" 2>/dev/null)" ]]; then
        return 1
    fi
    if [[ -n "$(ls -A "$SECRETS_DIR/api-keys" 2>/dev/null)" ]]; then
        return 1
    fi
    return 0
}
