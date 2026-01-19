#!/bin/bash
# dev-update.sh - Update devcontainer-toolbox from inside the container
# Usage: dev-update [--force]

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-update"
SCRIPT_NAME="Update"
SCRIPT_DESCRIPTION="Update devcontainer-toolbox to latest version"
SCRIPT_CATEGORY="SYSTEM_COMMANDS"
SCRIPT_CHECK_COMMAND="true"

set -e

REPO="terchris/devcontainer-toolbox"

# Self-copy pattern: copy to temp and exec from there for safe self-update
# We must capture WORKSPACE_ROOT before copying, as $0 changes when running from temp
if [ -z "$DEV_UPDATE_RUNNING_FROM_TEMP" ]; then
    # Calculate workspace root from original script location
    # Script is at .devcontainer/dev-update, so go up one level
    ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    export DEV_UPDATE_WORKSPACE_ROOT="$(cd "$ORIGINAL_SCRIPT_DIR/.." && pwd)"

    TEMP_SCRIPT=$(mktemp)
    cp "$0" "$TEMP_SCRIPT"
    chmod +x "$TEMP_SCRIPT"
    DEV_UPDATE_RUNNING_FROM_TEMP=1 exec "$TEMP_SCRIPT" "$@"
fi

# Parse arguments
FORCE=false
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE=true
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: dev-update [OPTIONS]"
    echo ""
    echo "Update devcontainer-toolbox to the latest version."
    echo ""
    echo "Options:"
    echo "  -f, --force    Force update even if already on latest version"
    echo "  -h, --help     Show this help message"
    exit 0
fi

# Use workspace root captured before self-copy
WORKSPACE_ROOT="$DEV_UPDATE_WORKSPACE_ROOT"
cd "$WORKSPACE_ROOT"

echo "Checking for updates from $REPO..."

# Read current installed version
CURRENT_VERSION=""
if [ -f ".devcontainer/.version" ]; then
    CURRENT_VERSION=$(grep "^VERSION=" .devcontainer/.version 2>/dev/null | cut -d= -f2)
fi

# Fetch remote version
REMOTE_VERSION=$(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/version.txt" 2>/dev/null || echo "")

if [ -z "$REMOTE_VERSION" ]; then
    echo "Error: Could not fetch remote version from $REPO"
    exit 1
fi

# Compare versions
if [ "$FORCE" = false ] && [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
    echo "Already up to date (version $CURRENT_VERSION)"
    exit 0
fi

if [ -n "$CURRENT_VERSION" ]; then
    echo "Updating from $CURRENT_VERSION to $REMOTE_VERSION..."
else
    echo "Installing version $REMOTE_VERSION..."
fi

# Download and extract
TEMP_DIR=$(mktemp -d)
URL="https://github.com/$REPO/releases/download/latest/dev_containers.zip"

echo "Downloading from $URL..."
curl -fsSL "$URL" -o "$TEMP_DIR/dev_containers.zip"

echo "Extracting..."
unzip -q "$TEMP_DIR/dev_containers.zip" -d "$TEMP_DIR/extract"

# Check if devcontainer.json changed
REBUILD_NEEDED=false
if [ -f ".devcontainer/devcontainer.json" ] && [ -f "$TEMP_DIR/extract/.devcontainer/devcontainer.json" ]; then
    if ! diff -q "$TEMP_DIR/extract/.devcontainer/devcontainer.json" ".devcontainer/devcontainer.json" > /dev/null 2>&1; then
        REBUILD_NEEDED=true
    fi
fi

# Replace .devcontainer (use sudo for mounted volume permissions)
echo "Updating .devcontainer..."
sudo rm -rf .devcontainer
sudo cp -r "$TEMP_DIR/extract/.devcontainer" .
sudo chown -R "$(id -u):$(id -g)" .devcontainer

# Handle .devcontainer.extend based on format
EXTEND_BACKED_UP=false
if [ -d ".devcontainer.extend" ]; then
    # Check if it's new format (has *.conf files) or old format (no *.conf files)
    if ls .devcontainer.extend/*.conf 1>/dev/null 2>&1; then
        # New format with *.conf files - preserve user config
        echo "Preserving existing .devcontainer.extend configuration..."
    else
        # Old format without *.conf files - back it up and install fresh
        echo "Detected old .devcontainer.extend format (no *.conf files)..."
        echo "Backing up to .devcontainer.extend.backup..."
        sudo rm -rf .devcontainer.extend.backup
        sudo mv .devcontainer.extend .devcontainer.extend.backup
        EXTEND_BACKED_UP=true

        echo "Installing new .devcontainer.extend..."
        sudo cp -r "$TEMP_DIR/extract/.devcontainer.extend" .
        sudo chown -R "$(id -u):$(id -g)" .devcontainer.extend
    fi
else
    # No .devcontainer.extend exists - install fresh
    echo "Installing default .devcontainer.extend..."
    sudo cp -r "$TEMP_DIR/extract/.devcontainer.extend" .
    sudo chown -R "$(id -u):$(id -g)" .devcontainer.extend
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "Updated to version $REMOTE_VERSION"

if [ "$EXTEND_BACKED_UP" = true ]; then
    echo ""
    echo "⚠️  Your old .devcontainer.extend was backed up to .devcontainer.extend.backup"
    echo "   The old format is no longer supported. Please reconfigure:"
    echo "   - Edit .devcontainer.extend/enabled-tools.conf"
    echo "   - Run: dev-setup"
fi

echo ""
echo "🔄 Rebuild the container to apply all changes:"
echo "   VS Code: Cmd/Ctrl+Shift+P > 'Dev Containers: Rebuild Container'"
if [ "$REBUILD_NEEDED" = true ]; then
    echo ""
    echo "   ⚠️  devcontainer.json has changed - rebuild is required!"
fi

echo ""
echo "Done!"
