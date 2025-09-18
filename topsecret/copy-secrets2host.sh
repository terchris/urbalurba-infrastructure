#!/bin/bash
# filename: topsecret/copy-secrets2host.sh
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