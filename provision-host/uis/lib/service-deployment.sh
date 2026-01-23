#!/bin/bash
# service-deployment.sh - Service deployment logic
#
# Provides functions for deploying, removing, and checking services
# based on enabled-services.conf configuration.

# Guard against multiple sourcing
[[ -n "${_UIS_SERVICE_DEPLOYMENT_LOADED:-}" ]] && return 0
_UIS_SERVICE_DEPLOYMENT_LOADED=1

# shellcheck disable=SC2034  # Variables are used by callers

# Determine script directory for sourcing siblings
_DEPLOY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
source "$_DEPLOY_SCRIPT_DIR/service-scanner.sh"
source "$_DEPLOY_SCRIPT_DIR/logging.sh"
source "$_DEPLOY_SCRIPT_DIR/utilities.sh"

# Default paths
CONFIG_DIR="${CONFIG_DIR:-/mnt/urbalurbadisk/.uis.extend}"
ANSIBLE_DIR="${ANSIBLE_DIR:-/mnt/urbalurbadisk/ansible/playbooks}"
MANIFESTS_DIR="${MANIFESTS_DIR:-/mnt/urbalurbadisk/manifests}"

# Read enabled services from config file
# Usage: read_enabled_services
# Output: One service ID per line (comments and blanks removed)
read_enabled_services() {
    local config_file="$CONFIG_DIR/enabled-services.conf"

    if [[ ! -f "$config_file" ]]; then
        die_config "enabled-services.conf not found at $config_file"
    fi

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        # Trim whitespace and output
        echo "${line// /}"
    done < "$config_file"
}

# Deploy all services listed in enabled-services.conf
# Usage: deploy_enabled_services
deploy_enabled_services() {
    local services=()
    local service

    while IFS= read -r service; do
        services+=("$service")
    done < <(read_enabled_services)

    if [[ ${#services[@]} -eq 0 ]]; then
        log_warn "No services enabled in enabled-services.conf"
        return 0
    fi

    log_info "Deploying ${#services[@]} enabled service(s)..."

    local failed=0
    for service_id in "${services[@]}"; do
        if ! deploy_single_service "$service_id"; then
            ((++failed))
            log_error "Failed to deploy $service_id"
            return 1  # Stop on first failure per design
        fi
    done

    log_success "All enabled services deployed"
    return 0
}

# Deploy a single service by ID
# Usage: deploy_single_service <service_id>
deploy_single_service() {
    local service_id="$1"
    local script

    script=$(find_service_script "$service_id")

    if [[ -z "$script" ]]; then
        die_config "Service '$service_id' not found"
    fi

    # Load service metadata
    # Clear previous values
    unset SCRIPT_ID SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_CATEGORY
    unset SCRIPT_PLAYBOOK SCRIPT_MANIFEST SCRIPT_CHECK_COMMAND
    unset SCRIPT_REMOVE SCRIPT_REQUIRES SCRIPT_PRIORITY

    # shellcheck source=/dev/null
    source "$script" 2>/dev/null

    log_info "Deploying $SCRIPT_NAME ($service_id)..."

    # Check dependencies first
    if [[ -n "$SCRIPT_REQUIRES" ]]; then
        if ! check_dependencies "$SCRIPT_REQUIRES"; then
            return $?
        fi
    fi

    # Determine deployment method
    if [[ -n "$SCRIPT_PLAYBOOK" ]]; then
        # Ansible deployment
        local playbook_path="$ANSIBLE_DIR/$SCRIPT_PLAYBOOK"
        if [[ ! -f "$playbook_path" ]]; then
            die_config "Playbook not found: $SCRIPT_PLAYBOOK"
        fi
        log_info "Running Ansible playbook: $SCRIPT_PLAYBOOK"
        if ! ansible-playbook "$playbook_path"; then
            die_k8s "Playbook failed: $SCRIPT_PLAYBOOK"
        fi

    elif [[ -n "$SCRIPT_MANIFEST" ]]; then
        # Direct manifest deployment
        local manifest_path="$MANIFESTS_DIR/$SCRIPT_MANIFEST"
        if [[ ! -f "$manifest_path" ]]; then
            die_config "Manifest not found: $SCRIPT_MANIFEST"
        fi
        log_info "Applying manifest: $SCRIPT_MANIFEST"
        if ! kubectl apply -f "$manifest_path"; then
            die_k8s "Manifest apply failed: $SCRIPT_MANIFEST"
        fi

    else
        log_warn "Service '$service_id' has no SCRIPT_PLAYBOOK or SCRIPT_MANIFEST - nothing to deploy"
        return 0
    fi

    # Verify deployment
    if [[ -n "$SCRIPT_CHECK_COMMAND" ]]; then
        log_info "Verifying deployment..."
        # Give it a moment to start
        sleep 2
        if check_service_deployed "$service_id"; then
            log_success "$SCRIPT_NAME deployed successfully"
        else
            log_warn "$SCRIPT_NAME deployed but health check failed (may need time to start)"
        fi
    else
        log_success "$SCRIPT_NAME deployment completed"
    fi

    return 0
}

# Remove a single service by ID
# Usage: remove_single_service <service_id>
remove_single_service() {
    local service_id="$1"
    local script

    script=$(find_service_script "$service_id")

    if [[ -z "$script" ]]; then
        die_config "Service '$service_id' not found"
    fi

    # Load service metadata
    unset SCRIPT_ID SCRIPT_NAME SCRIPT_REMOVE SCRIPT_MANIFEST SCRIPT_REMOVE_PLAYBOOK
    # shellcheck source=/dev/null
    source "$script" 2>/dev/null

    log_info "Removing $SCRIPT_NAME ($service_id)..."

    # Check for removal playbook first
    if [[ -n "$SCRIPT_REMOVE_PLAYBOOK" ]]; then
        local remove_playbook="$ANSIBLE_DIR/$SCRIPT_REMOVE_PLAYBOOK"
        if [[ -f "$remove_playbook" ]]; then
            log_info "Running removal playbook: $SCRIPT_REMOVE_PLAYBOOK"
            if ! ansible-playbook "$remove_playbook"; then
                die_k8s "Removal playbook failed"
            fi
            log_success "$SCRIPT_NAME removed"
            return 0
        fi
    fi

    # Fall back to manifest deletion
    if [[ -n "$SCRIPT_MANIFEST" ]]; then
        local manifest_path="$MANIFESTS_DIR/$SCRIPT_MANIFEST"
        if [[ -f "$manifest_path" ]]; then
            log_info "Deleting manifest: $SCRIPT_MANIFEST"
            if ! kubectl delete -f "$manifest_path" --ignore-not-found; then
                die_k8s "Manifest deletion failed"
            fi
            log_success "$SCRIPT_NAME removed"
            return 0
        fi
    fi

    log_warn "No removal method found for $service_id - manual cleanup may be required"
    return 0
}

# Check if required dependencies are deployed
# Usage: check_dependencies "service1 service2 service3"
check_dependencies() {
    local requires="$1"
    local dep

    for dep in $requires; do
        if ! check_service_deployed "$dep"; then
            die_dependency "Required service '$dep' is not deployed"
        fi
        log_info "Dependency '$dep' is deployed"
    done

    return 0
}

# Get list of services sorted by priority
# Usage: get_services_by_priority
# Output: service IDs sorted by SCRIPT_PRIORITY (lower first)
get_services_by_priority() {
    local -a services_with_priority=()

    while IFS= read -r service_id; do
        local priority
        priority=$(get_service_value "$service_id" "SCRIPT_PRIORITY")
        priority="${priority:-50}"  # Default priority 50
        services_with_priority+=("$priority|$service_id")
    done < <(read_enabled_services)

    # Sort by priority (numeric) and output service IDs
    printf '%s\n' "${services_with_priority[@]}" | sort -t'|' -k1 -n | cut -d'|' -f2
}

# Show deployment status for all enabled services
# Usage: show_deployment_status
show_deployment_status() {
    log_info "Checking deployment status..."

    local service_id
    while IFS= read -r service_id; do
        local script
        script=$(find_service_script "$service_id")
        [[ -z "$script" ]] && continue

        unset SCRIPT_NAME SCRIPT_CHECK_COMMAND
        # shellcheck source=/dev/null
        source "$script" 2>/dev/null

        if [[ -z "$SCRIPT_CHECK_COMMAND" ]]; then
            echo "  $service_id: ${SCRIPT_NAME:-Unknown} - No health check"
        elif check_service_deployed "$service_id"; then
            echo "  $service_id: ${SCRIPT_NAME:-Unknown} - Deployed"
        else
            echo "  $service_id: ${SCRIPT_NAME:-Unknown} - Not deployed"
        fi
    done < <(read_enabled_services)
}
