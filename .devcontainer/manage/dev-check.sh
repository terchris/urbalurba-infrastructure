#!/bin/bash
# File: .devcontainer/manage/dev-check.sh
# Purpose: Check and configure all required prerequisites
# Usage: dev-check
#
# This script:
# - Checks status of all required configurations
# - Shows what's configured and what's missing
# - Optionally runs missing configuration scripts
# - Can be run repeatedly until all prerequisites are met

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-check"
SCRIPT_NAME="Check Configuration"
SCRIPT_DESCRIPTION="Configure and validate Git identity and credentials"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Get script directory and calculate paths
# Resolve symlinks to get actual script location
SCRIPT_SOURCE="$0"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

# Handle both cases:
# 1. Running from .devcontainer/manage/ (symlink resolved or direct execution)
# 2. Running from .devcontainer/ root (when script is a copy, not symlink - e.g., from zip extraction)
if [[ "$(basename "$SCRIPT_DIR")" == "manage" ]]; then
    DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
else
    # Script is in .devcontainer/ root (copy from zip extraction)
    DEVCONTAINER_DIR="$SCRIPT_DIR"
fi
ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"

# Source component scanner library
# shellcheck source=/dev/null
source "${ADDITIONS_DIR}/lib/component-scanner.sh"

#------------------------------------------------------------------------------
# Configuration Discovery
#------------------------------------------------------------------------------

# Arrays to store configuration information
declare -a CONFIG_NAMES=()
declare -a CONFIG_SCRIPTS=()
declare -a CONFIG_DESCRIPTIONS=()
declare -a CONFIG_CHECK_COMMANDS=()
declare -a CONFIG_STATUSES=()

discover_configs() {
    log_info "Discovering available configurations..."
    echo ""

    local found=0

    # Use library to scan config scripts
    while IFS=$'\t' read -r script_basename config_name config_description config_category check_command; do
        # Add to arrays
        CONFIG_NAMES+=("$config_name")
        CONFIG_SCRIPTS+=("$script_basename")
        CONFIG_DESCRIPTIONS+=("$config_description")
        CONFIG_CHECK_COMMANDS+=("$check_command")

        # Check status
        local status="NOT_CONFIGURED"
        if [ -n "$check_command" ] && eval "$check_command" 2>/dev/null; then
            status="CONFIGURED"
        fi
        CONFIG_STATUSES+=("$status")

        ((found++))
    done < <(scan_config_scripts "$ADDITIONS_DIR")

    if [ $found -eq 0 ]; then
        log_warn "No configuration scripts found"
        return 1
    fi

    log_success "Found $found configuration(s)"
    return 0
}

#------------------------------------------------------------------------------
# Status Display
#------------------------------------------------------------------------------

show_status() {
    local configured_count=0
    local missing_count=0

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Configuration Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    for i in "${!CONFIG_NAMES[@]}"; do
        local name="${CONFIG_NAMES[$i]}"
        local status="${CONFIG_STATUSES[$i]}"
        local description="${CONFIG_DESCRIPTIONS[$i]}"

        if [ "$status" = "CONFIGURED" ]; then
            log_success "$name"
            echo "   $description"
            ((configured_count++))
        else
            log_error "$name"
            echo "   $description"
            ((missing_count++))
        fi
        echo ""
    done

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Summary: $configured_count configured, $missing_count missing"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Return 0 if all configured, 1 if any missing
    [ $missing_count -eq 0 ]
}

#------------------------------------------------------------------------------
# Interactive Configuration
#------------------------------------------------------------------------------

run_missing_configs() {
    local missing_indices=()

    # Find missing configurations
    for i in "${!CONFIG_STATUSES[@]}"; do
        if [ "${CONFIG_STATUSES[$i]}" = "NOT_CONFIGURED" ]; then
            missing_indices+=("$i")
        fi
    done

    if [ ${#missing_indices[@]} -eq 0 ]; then
        log_success "All configurations are complete!"
        echo ""
        echo "You can now install tools that require these configurations."
        return 0
    fi

    echo ""
    log_info "Found ${#missing_indices[@]} missing configuration(s)"
    echo ""

    # Ask if user wants to configure them
    read -p "Would you like to configure missing items now? (y/n) " -r response
    echo ""

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Skipping configuration. Run this script again when ready."
        echo ""
        echo "To configure manually:"
        for idx in "${missing_indices[@]}"; do
            local script="${CONFIG_SCRIPTS[$idx]}"
            echo "  bash $ADDITIONS_DIR/$script"
        done
        echo ""
        return 1
    fi

    # Run each missing configuration script
    local success_count=0
    local fail_count=0

    for idx in "${missing_indices[@]}"; do
        local name="${CONFIG_NAMES[$idx]}"
        local script="${CONFIG_SCRIPTS[$idx]}"
        local script_path="$ADDITIONS_DIR/$script"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Configuring: $name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        if [ ! -f "$script_path" ]; then
            log_error "Configuration script not found: $script_path"
            ((fail_count++))
            continue
        fi

        # Make executable and run
        chmod +x "$script_path"
        if bash "$script_path"; then
            echo ""
            log_success "Completed: $name"
            ((success_count++))
            # Update status
            CONFIG_STATUSES[$idx]="CONFIGURED"
        else
            echo ""
            log_error "Failed: $name"
            ((fail_count++))
        fi

        # Add separator between configs
        echo ""
    done

    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Configuration Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Successful: $success_count"
    if [ $fail_count -gt 0 ]; then
        log_error "Failed: $fail_count"
    fi
    echo ""

    if [ $fail_count -gt 0 ]; then
        log_warn "Some configurations failed. Run this script again to retry."
        echo ""
        return 1
    else
        log_success "All configurations complete!"
        echo ""
        return 0
    fi
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Required Configurations Checker"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This script checks and configures all required prerequisites"
    echo "for tools and services in this devcontainer."
    echo ""

    # Discover available configurations
    if ! discover_configs; then
        log_error "No configurations found to check"
        exit 1
    fi

    # Show current status
    if show_status; then
        # All configured
        log_success "✨ All required configurations are complete!"
        echo ""
        echo "You're ready to install and use all tools."
        echo ""
        exit 0
    fi

    # Some missing - offer to configure them
    run_missing_configs
    local result=$?

    # Show final status
    echo ""
    show_status

    if [ $result -eq 0 ]; then
        echo ""
        log_success "🎉 Setup complete!"
        echo ""
        echo "Next steps:"
        echo "  - Install tools: dev-setup → Browse & Install Tools"
        echo "  - Or rebuild container to auto-install enabled tools"
        echo ""
    else
        echo ""
        log_warn "Setup incomplete. Run this script again to continue:"
        echo "  bash $0"
        echo ""
        echo "Or configure individually via:"
        echo "  dev-setup → Setup & Configuration"
        echo ""
    fi

    exit $result
}

# Run main
main "$@"
