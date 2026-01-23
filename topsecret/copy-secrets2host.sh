#!/bin/bash
# filename: topsecret/copy-secrets2host.sh
#
# ============================================================================
# DEPRECATED - This script is deprecated and will be removed in a future release
# ============================================================================
#
# REPLACEMENT:
#   The new UIS secrets system uses direct volume mounts - no copying needed!
#
#   Your secrets directory (.uis.secrets/) is mounted directly into the container.
#   Any changes made inside the container are immediately saved to your host.
#
#   Secrets are stored in:
#     .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
#
# MIGRATION:
#   1. Run './uis' to set up the new secrets structure
#   2. Your secrets will be in .uis.secrets/ (mounted directly)
#   3. No manual copying is ever needed
#   4. Changes persist automatically
#
# For more information, see: topsecret/DEPRECATED.md
# ============================================================================
#
# ORIGINAL DESCRIPTION:
# description: Copy updated kubernetes-secrets.yml from provision-host to Mac host
# usage: ./topsecret/copy-secrets2host.sh
#
# This script copies the updated kubernetes-secrets.yml file from the provision-host
# container to the host Mac, preserving any new credentials (like Cloudflare tunnel
# credentials) that were added during infrastructure operations.
#
# Run this after:
# - Setting up new Cloudflare tunnels
# - Any operation that modifies secrets in the provision-host
# - Before tearing down provision-host to preserve credentials

# Show deprecation warning
echo ""
echo "============================================================================"
echo "WARNING: This script is DEPRECATED"
echo "============================================================================"
echo ""
echo "The new UIS secrets system uses direct volume mounts - no copying needed!"
echo ""
echo "Your secrets directory (.uis.secrets/) is mounted directly into the container."
echo "Any changes made inside the container are immediately saved to your host."
echo ""
echo "Secrets location: .uis.secrets/generated/kubernetes/kubernetes-secrets.yml"
echo ""
echo "Run './uis' to set up the new secrets structure."
echo "See topsecret/DEPRECATED.md for migration details."
echo ""
echo "============================================================================"
echo ""
echo "Continuing with legacy behavior for backwards compatibility..."
echo ""

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
PROVISION_HOST="provision-host"
SOURCE_FILE="/mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml"
DEST_FILE="./topsecret/kubernetes/kubernetes-secrets.yml"

echo "📁 Copying secrets file from provision-host to Mac host..."
echo "Source: provision-host:$SOURCE_FILE"  
echo "Destination: $DEST_FILE"
echo ""

# Check if provision-host container exists and is running
if ! docker ps --format "table {{.Names}}" | grep -q "^${PROVISION_HOST}$"; then
    echo "❌ Error: provision-host container is not running"
    echo "💡 Start provision-host first: docker start provision-host"
    exit 1
fi

# Check if source file exists in container
if ! docker exec $PROVISION_HOST test -f "$SOURCE_FILE"; then
    echo "❌ Error: Source file not found in provision-host: $SOURCE_FILE"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$(dirname "$DEST_FILE")"

# Copy the file from container to host
if docker cp "${PROVISION_HOST}:${SOURCE_FILE}" "$DEST_FILE"; then
    echo "✅ Successfully copied secrets file to Mac host"
    echo "📍 File saved to: $DEST_FILE"
    
    # Show what changed (if git is available)
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        echo ""
        echo "📝 Changes detected:"
        git diff --no-index --color=always "$DEST_FILE" "$DEST_FILE" 2>/dev/null || echo "Unable to show diff"
    fi
    
    echo ""
    echo "💾 Your credentials are now safely stored on the Mac host"
    echo "🔄 They will be restored when provision-host is rebuilt"
    
else
    echo "❌ Error: Failed to copy secrets file"
    exit 1
fi