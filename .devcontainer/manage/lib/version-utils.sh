#!/bin/bash
# File: .devcontainer/manage/lib/version-utils.sh
# Purpose: Shared version checking utilities for dev-* commands
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/version-utils.sh"
#   show_version_info        # Shows version and update availability
#   show_version_info short  # Shows compact one-line version

# Get the .devcontainer directory (parent of manage/lib)
_get_devcontainer_dir() {
    local script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    # Go up from lib/ to manage/ to .devcontainer/
    echo "$(cd "$script_dir/../.." && pwd)"
}

# Read version info from .version file or version.txt
# Sets: TOOLBOX_VERSION, TOOLBOX_REPO
_load_version_info() {
    local devcontainer_dir="$(_get_devcontainer_dir)"
    local version_file="$devcontainer_dir/.version"
    local workspace_root="$devcontainer_dir/.."
    local version_txt="$workspace_root/version.txt"

    TOOLBOX_VERSION="unknown"
    TOOLBOX_REPO=""

    # First try .devcontainer/.version (created by dev-update for installed users)
    if [ -f "$version_file" ]; then
        TOOLBOX_VERSION=$(grep "^VERSION=" "$version_file" 2>/dev/null | cut -d= -f2)
        TOOLBOX_REPO=$(grep "^REPO=" "$version_file" 2>/dev/null | cut -d= -f2)
    # Fall back to version.txt in workspace root (for development/fresh clones)
    elif [ -f "$version_txt" ]; then
        TOOLBOX_VERSION=$(cat "$version_txt" 2>/dev/null | tr -d '[:space:]')
        TOOLBOX_REPO="terchris/devcontainer-toolbox"
    fi
}

# Check for available updates (quick, with timeout)
# Returns: TOOLBOX_REMOTE_VERSION (empty if check failed or same version)
_check_for_updates() {
    TOOLBOX_REMOTE_VERSION=""

    if [ -n "$TOOLBOX_REPO" ]; then
        local remote=$(curl -fsSL --connect-timeout 2 "https://raw.githubusercontent.com/$TOOLBOX_REPO/main/version.txt" 2>/dev/null || echo "")
        if [ -n "$remote" ] && [ "$remote" != "$TOOLBOX_VERSION" ]; then
            TOOLBOX_REMOTE_VERSION="$remote"
        fi
    fi
}

# Display version info with optional update notification
# Usage: show_version_info [short]
#   short: Single line format for welcome message
#   (default): Full format for dev-help
show_version_info() {
    local format="${1:-full}"

    _load_version_info
    _check_for_updates

    if [ "$format" = "short" ]; then
        # Compact format for welcome message
        if [ -n "$TOOLBOX_REMOTE_VERSION" ]; then
            echo "  DevContainer Toolbox v$TOOLBOX_VERSION - Update available: v$TOOLBOX_REMOTE_VERSION (run 'dev-update')"
        else
            echo "  DevContainer Toolbox v$TOOLBOX_VERSION - Type 'dev-help' for commands"
        fi
    else
        # Full format for dev-help
        echo "DevContainer Toolbox v$TOOLBOX_VERSION"
        if [ -n "$TOOLBOX_REMOTE_VERSION" ]; then
            echo "  ⬆️  Update available: v$TOOLBOX_REMOTE_VERSION (run 'dev-update')"
        fi
    fi
}
