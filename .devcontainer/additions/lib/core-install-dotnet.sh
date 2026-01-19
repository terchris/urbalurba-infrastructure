#!/bin/bash
# file: .devcontainer/additions/lib/core-install-dotnet.sh
#
# Core functionality for managing .NET global tools via dotnet tool install
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

# Function to check if a .NET tool is installed
is_dotnet_tool_installed() {
    local package=$1
    # Extract package name (handle versions like package@1.0.0)
    local pkg_name="${package%%@*}"

    debug "Checking if .NET tool '$pkg_name' is installed..."
    dotnet tool list --global 2>/dev/null | grep -q "^${pkg_name}\s"
}

# Function to get installed .NET tool version
get_dotnet_tool_version() {
    local package=$1
    local pkg_name="${package%%@*}"

    if dotnet tool list --global 2>/dev/null | grep -q "^${pkg_name}\s"; then
        dotnet tool list --global 2>/dev/null | grep "^${pkg_name}\s" | awk '{print $2}'
    else
        echo ""
    fi
}

# Function to install .NET tools
process_dotnet_tools_install() {
    debug "=== Starting .NET tool installation ==="

    # Get array reference
    declare -n arr=$1

    log "Installing ${#arr[@]} .NET tools..."
    echo
    printf "%-30s %-20s %-20s\n" "Package" "Status" "Version"
    printf "%s\n" "--------------------------------------------------------------------"

    local installed=0
    local already_installed=0
    local failed=0

    for package in "${arr[@]}"; do
        # Extract package name and version if specified
        local pkg_name="${package%%@*}"
        local pkg_version=""
        if [[ "$package" == *"@"* ]]; then
            pkg_version="${package##*@}"
        fi

        printf "%-30s " "$pkg_name"

        # Check if already installed
        if is_dotnet_tool_installed "$pkg_name"; then
            local current_version=$(get_dotnet_tool_version "$pkg_name")
            printf "%-20s %-20s\n" "Already installed" "v${current_version}"
            already_installed=$((already_installed + 1))
            continue
        fi

        # Install the tool
        if [ -n "$pkg_version" ]; then
            if dotnet tool install --global "$pkg_name" --version "$pkg_version" >/dev/null 2>&1; then
                local new_version=$(get_dotnet_tool_version "$pkg_name")
                printf "%-20s %-20s\n" "Installed" "v${new_version}"
                installed=$((installed + 1))
            else
                printf "%-20s %-20s\n" "Failed" ""
                failed=$((failed + 1))
            fi
        else
            if dotnet tool install --global "$pkg_name" >/dev/null 2>&1; then
                local new_version=$(get_dotnet_tool_version "$pkg_name")
                printf "%-20s %-20s\n" "Installed" "v${new_version}"
                installed=$((installed + 1))
            else
                printf "%-20s %-20s\n" "Failed" ""
                failed=$((failed + 1))
            fi
        fi
    done

    # Show current status
    echo
    echo "Current Status:"
    for package in "${arr[@]}"; do
        local pkg_name="${package%%@*}"
        if is_dotnet_tool_installed "$pkg_name"; then
            local version=$(get_dotnet_tool_version "$pkg_name")
            echo "* ✅ $pkg_name (v${version})"
        else
            echo "* ❌ $pkg_name (not installed)"
        fi
    done

    echo
    echo "----------------------------------------"
    log ".NET Tool Installation Summary"
    echo "Total tools: ${#arr[@]}"
    echo "  Already installed: $already_installed"
    echo "  Newly installed: $installed"
    echo "  Failed: $failed"
    echo
}

# Function to uninstall .NET tools
process_dotnet_tools_uninstall() {
    debug "=== Starting .NET tool uninstallation ==="

    # Get array reference
    declare -n arr=$1

    log "Uninstalling ${#arr[@]} .NET tools..."
    echo
    printf "%-30s %-20s\n" "Package" "Status"
    printf "%s\n" "--------------------------------------------------------------------"

    local uninstalled=0
    local not_installed=0
    local failed=0

    for package in "${arr[@]}"; do
        # Extract package name without version
        local pkg_name="${package%%@*}"
        printf "%-30s " "$pkg_name"

        # Check if installed
        if ! is_dotnet_tool_installed "$pkg_name"; then
            printf "%-20s\n" "Not installed"
            not_installed=$((not_installed + 1))
            continue
        fi

        # Uninstall the tool
        if dotnet tool uninstall --global "$pkg_name" >/dev/null 2>&1; then
            printf "%-20s\n" "Uninstalled"
            uninstalled=$((uninstalled + 1))
        else
            printf "%-20s\n" "Failed"
            failed=$((failed + 1))
        fi
    done

    echo
    echo "----------------------------------------"
    log ".NET Tool Uninstallation Summary"
    echo "Total tools: ${#arr[@]}"
    echo "  Successfully uninstalled: $uninstalled"
    echo "  Not installed: $not_installed"
    echo "  Failed: $failed"
    echo
}

# Function to process tools (install or uninstall)
process_dotnet_tools() {
    if [ "${UNINSTALL_MODE:-0}" -eq 1 ]; then
        process_dotnet_tools_uninstall "$@"
    else
        process_dotnet_tools_install "$@"
    fi
}
