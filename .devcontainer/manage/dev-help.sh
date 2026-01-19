#!/bin/bash
# dev-help.sh - Show available dev-* commands

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-help"
SCRIPT_NAME="Help"
SCRIPT_DESCRIPTION="Show available commands and version info"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"

# Get script directory and source utilities
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Handle both cases:
# 1. Running from .devcontainer/manage/ (symlink resolved or direct execution)
# 2. Running from .devcontainer/ root (when script is a copy, not symlink - e.g., from zip extraction)
if [[ "$(basename "$SCRIPT_DIR")" == "manage" ]]; then
    DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
    MANAGE_DIR="$SCRIPT_DIR"
else
    # Script is in .devcontainer/ root (copy from zip extraction)
    DEVCONTAINER_DIR="$SCRIPT_DIR"
    MANAGE_DIR="$SCRIPT_DIR/manage"
fi
ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"

# Source version-utils from manage/lib
if [ -f "$MANAGE_DIR/lib/version-utils.sh" ]; then
    source "$MANAGE_DIR/lib/version-utils.sh"
fi

# Source component scanner for dynamic command discovery
# shellcheck source=/dev/null
source "${ADDITIONS_DIR}/lib/component-scanner.sh"

# Show version and update status
show_version_info

echo ""
echo "Available dev-* commands:"
echo ""

# Build arrays for sorting by category
declare -a system_cmds=()
declare -a contrib_cmds=()

# Scan manage scripts and sort by category
while IFS=$'\t' read -r basename script_id name desc category check; do
    formatted=$(printf "  %-14s %s" "$script_id" "$desc")
    if [[ "$category" == "SYSTEM_COMMANDS" ]]; then
        system_cmds+=("$formatted")
    else
        contrib_cmds+=("$formatted")
    fi
done < <(scan_manage_scripts "$MANAGE_DIR")

# Add dev-setup (excluded from scanner to avoid recursion)
system_cmds+=("$(printf "  %-14s %s" "dev-setup" "Interactive menu for installing tools and managing services")")

# Output system commands first, then contributor tools
for cmd in "${system_cmds[@]}"; do
    echo "$cmd"
done
for cmd in "${contrib_cmds[@]}"; do
    echo "$cmd"
done

echo ""
echo "Run any command with --help for more details."
