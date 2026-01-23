#!/bin/bash
# first-run.sh - First-run helpers (runs INSIDE container)
#
# NOTE: Folder creation (.uis.extend/, .uis.secrets/) happens on HOST in wrapper script.
# This library manages CONTENTS of those folders once mounted.

# Guard against multiple sourcing
[[ -n "${_UIS_FIRST_RUN_LOADED:-}" ]] && return 0
_UIS_FIRST_RUN_LOADED=1

# shellcheck disable=SC2034  # Variables are used by callers

# Determine script directory for sourcing siblings
_FIRSTRUN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$_FIRSTRUN_SCRIPT_DIR/logging.sh"
source "$_FIRSTRUN_SCRIPT_DIR/utilities.sh"

# Auto-detect templates directory
_detect_templates_dir() {
    # If already set, use it
    [[ -n "${TEMPLATES_DIR:-}" ]] && echo "$TEMPLATES_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/provision-host/uis/templates" ]]; then
        echo "/mnt/urbalurbadisk/provision-host/uis/templates"
        return 0
    fi

    # Host path: derive from this script's location
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local templates_dir="$(dirname "$script_dir")/templates"
    if [[ -d "$templates_dir" ]]; then
        echo "$templates_dir"
        return 0
    fi

    # Fallback to container path
    echo "/mnt/urbalurbadisk/provision-host/uis/templates"
}

# Auto-detect extend directory
_detect_extend_dir() {
    # If already set, use it
    [[ -n "${EXTEND_DIR:-}" ]] && echo "$EXTEND_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/.uis.extend" ]]; then
        echo "/mnt/urbalurbadisk/.uis.extend"
        return 0
    fi

    # Host path: use get_base_path
    local base_path
    base_path=$(get_base_path)
    echo "$base_path/.uis.extend"
}

# Auto-detect secrets directory
_detect_secrets_dir() {
    # If already set, use it
    [[ -n "${SECRETS_DIR:-}" ]] && echo "$SECRETS_DIR" && return 0

    # Container path
    if [[ -d "/mnt/urbalurbadisk/.uis.secrets" ]]; then
        echo "/mnt/urbalurbadisk/.uis.secrets"
        return 0
    fi

    # Host path: use get_base_path
    local base_path
    base_path=$(get_base_path)
    echo "$base_path/.uis.secrets"
}

# Default paths (auto-detected)
TEMPLATES_DIR="${TEMPLATES_DIR:-$(_detect_templates_dir)}"
EXTEND_DIR="${EXTEND_DIR:-$(_detect_extend_dir)}"
SECRETS_DIR="${SECRETS_DIR:-$(_detect_secrets_dir)}"

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

    # Create secrets subdirectories if missing (original structure)
    local subdirs=("secrets-config" "kubernetes" "api-keys")
    for subdir in "${subdirs[@]}"; do
        if [[ ! -d "$SECRETS_DIR/$subdir" ]]; then
            mkdir -p "$SECRETS_DIR/$subdir"
            log_info "Created $SECRETS_DIR/$subdir/"
        fi
    done

    # Create new secrets subdirectories (for secrets consolidation)
    local new_subdirs=("ssh" "cloud-accounts" "service-keys" "network" "generated/kubernetes" "generated/ubuntu-cloud-init" "generated/kubeconfig")
    for subdir in "${new_subdirs[@]}"; do
        if [[ ! -d "$SECRETS_DIR/$subdir" ]]; then
            mkdir -p "$SECRETS_DIR/$subdir"
            log_info "Created $SECRETS_DIR/$subdir/"
        fi
    done

    # Create hosts subdirectories in .uis.extend/
    local host_subdirs=("hosts/managed" "hosts/cloud-vm" "hosts/physical" "hosts/local")
    for subdir in "${host_subdirs[@]}"; do
        if [[ ! -d "$EXTEND_DIR/$subdir" ]]; then
            mkdir -p "$EXTEND_DIR/$subdir"
            log_info "Created $EXTEND_DIR/$subdir/"
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

# Generate SSH keys for ansible user (used for VM provisioning)
# Keys are created in .uis.secrets/ssh/
# Returns: 0 if keys exist or created successfully, 1 on error
generate_ssh_keys() {
    local ssh_dir="$SECRETS_DIR/ssh"
    local private_key="$ssh_dir/id_rsa_ansible"
    local public_key="$ssh_dir/id_rsa_ansible.pub"

    # Ensure directory exists
    mkdir -p "$ssh_dir"

    # Check if keys already exist
    if [[ -f "$private_key" && -f "$public_key" ]]; then
        log_info "SSH keys already exist"
        return 0
    fi

    # Generate new key pair
    log_info "Generating SSH keys for ansible user..."
    if ssh-keygen -t rsa -b 4096 -f "$private_key" -N "" -C "ansible@uis" >/dev/null 2>&1; then
        chmod 600 "$private_key"
        chmod 644 "$public_key"
        log_success "SSH keys generated: $ssh_dir/"
        return 0
    else
        log_error "Failed to generate SSH keys"
        return 1
    fi
}

# Check if SSH keys exist
# Returns: 0 if keys exist, 1 if not
ssh_keys_exist() {
    local ssh_dir="$SECRETS_DIR/ssh"
    [[ -f "$ssh_dir/id_rsa_ansible" && -f "$ssh_dir/id_rsa_ansible.pub" ]]
}
