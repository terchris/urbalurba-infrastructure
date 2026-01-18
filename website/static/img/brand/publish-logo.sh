#!/bin/bash
# publish-logo.sh - Publish logo to website
#
# Takes the uis-logo-green.svg and copies it as the site logo used by Docusaurus.
#
# Usage:
#   ./publish-logo.sh [source.svg]
#
# Arguments:
#   source.svg - Optional. Source SVG file (default: uis-logo-green.svg)
#
# Output:
#   ../logo.svg - Logo used by Docusaurus navbar

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${1:-$SCRIPT_DIR/uis-logo-green.svg}"
DEST_DIR="$(dirname "$SCRIPT_DIR")"  # Parent dir (static/img/)

# Check source exists
if [[ ! -f "$SOURCE" ]]; then
    echo "Error: Source file not found: $SOURCE"
    exit 1
fi

echo "Publishing logo..."
echo "  Source: $SOURCE"
echo "  Destination: $DEST_DIR/logo.svg"

# Copy SVG
cp "$SOURCE" "$DEST_DIR/logo.svg"

echo "Done! Logo published to $DEST_DIR/logo.svg"
