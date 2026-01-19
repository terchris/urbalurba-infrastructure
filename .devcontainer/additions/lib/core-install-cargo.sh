#!/bin/bash
# file: .devcontainer/additions/lib/core-install-cargo.sh
#
# Core functionality for managing Rust packages via cargo install
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

# Function to check if a Cargo package is installed
is_cargo_package_installed() {
    local package=$1
    # Extract package name without version
    local pkg_name="${package%%@*}"

    debug "Checking if Cargo package '$pkg_name' is installed..."
    command -v "$pkg_name" >/dev/null 2>&1
}

# Function to install Cargo packages
process_cargo_packages_install() {
    debug "=== Starting Cargo package installation ==="

    # Get array reference
    declare -n arr=$1

    log "Installing ${#arr[@]} Cargo packages..."
    echo
    printf "%-50s %-20s\n" "Package" "Status"
    printf "%s\n" "----------------------------------------------------------------------"

    local installed=0
    local failed=0

    for package in "${arr[@]}"; do
        printf "%-50s " "$package"

        if cargo install "$package" 2>/dev/null; then
            printf "%-20s\n" "Installed"
            installed=$((installed + 1))
        else
            printf "%-20s\n" "Failed"
            failed=$((failed + 1))
        fi
    done

    echo
    echo "----------------------------------------"
    log "Cargo Package Installation Summary"
    echo "  Total packages:         ${#arr[@]}"
    echo "  Successfully installed: $installed"
    echo "  Failed:                 $failed"
    echo
}

# Function to uninstall Cargo packages
process_cargo_packages_uninstall() {
    debug "=== Starting Cargo package uninstallation ==="

    # Get array reference
    declare -n arr=$1

    log "Uninstalling ${#arr[@]} Cargo packages..."
    echo
    printf "%-50s %-20s\n" "Package" "Status"
    printf "%s\n" "----------------------------------------------------------------------"

    local uninstalled=0
    local failed=0

    for package in "${arr[@]}"; do
        # Extract package name without version
        local pkg_name="${package%%@*}"
        printf "%-50s " "$package"

        if cargo uninstall "$pkg_name" 2>/dev/null; then
            printf "%-20s\n" "Uninstalled"
            uninstalled=$((uninstalled + 1))
        else
            printf "%-20s\n" "Failed"
            failed=$((failed + 1))
        fi
    done

    echo
    echo "----------------------------------------"
    log "Cargo Package Uninstallation Summary"
    echo "  Total packages:           ${#arr[@]}"
    echo "  Successfully uninstalled: $uninstalled"
    echo "  Failed:                   $failed"
    echo
}

# Function to process packages (install or uninstall)
process_cargo_packages() {
    if [ "${UNINSTALL_MODE:-0}" -eq 1 ]; then
        process_cargo_packages_uninstall "$@"
    else
        process_cargo_packages_install "$@"
    fi
}
