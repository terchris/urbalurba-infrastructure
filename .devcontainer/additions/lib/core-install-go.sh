#!/bin/bash
# file: .devcontainer/additions/lib/core-install-go.sh
#
# Core functionality for managing Go packages via go install
# To be sourced by installation scripts, not executed directly.

set -e

# Debug function
debug() {
    if [ "${DEBUG_MODE:-0}" -eq 1 ]; then
        echo "DEBUG: $*" >&2
    fi
}

# Simple logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Error logging function
error() {
    echo "ERROR: $*" >&2
}

# Function to check if a Go package is installed
is_go_package_installed() {
    local package=$1
    # Extract package name without version
    local pkg_name="${package%%@*}"
    # Get binary name from package path
    local bin_name=$(basename "$pkg_name")

    debug "Checking if Go package '$bin_name' is installed..."
    command -v "$bin_name" >/dev/null 2>&1
}

# Function to install Go packages
process_go_packages() {
    debug "=== Starting Go package installation ==="

    # Get array reference
    declare -n arr=$1

    log "Installing ${#arr[@]} Go packages..."
    echo
    printf "%-50s %-20s\n" "Package" "Status"
    printf "%s\n" "----------------------------------------------------------------------"

    local installed=0
    local failed=0

    for package in "${arr[@]}"; do
        local pkg_name="${package%%@*}"
        local bin_name=$(basename "$pkg_name")

        printf "%-50s " "$package"

        if go install "$package" 2>/dev/null; then
            printf "%-20s\n" "Installed"
            installed=$((installed + 1))
        else
            printf "%-20s\n" "Failed"
            failed=$((failed + 1))
        fi
    done

    echo
    echo "----------------------------------------"
    log "Go Package Installation Summary"
    echo "  Total packages:         ${#arr[@]}"
    echo "  Successfully installed: $installed"
    echo "  Failed:                 $failed"
    echo
}
