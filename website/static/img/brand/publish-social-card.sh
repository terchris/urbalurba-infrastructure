#!/bin/bash
# publish-social-card.sh - Publish generated social card to website
#
# Takes the generated social card from the brand folder and creates an
# optimized JPG version for use by Docusaurus (static/img/social-card.jpg).
#
# IMPORTANT: Run this script inside the devcontainer where ImageMagick is available.
#
# Usage:
#   ./publish-social-card.sh [source.png]
#
# Arguments:
#   source.png - Optional. Source image (default: social-card-generated.png)
#
# Output file (in ../):
#   social-card.jpg - Optimized JPG version for social media

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${1:-$SCRIPT_DIR/social-card-generated.png}"
DEST_DIR="$(dirname "$SCRIPT_DIR")"  # Parent dir (static/img/)

# Check source exists
if [[ ! -f "$SOURCE" ]]; then
    echo "Error: Source file not found: $SOURCE"
    echo ""
    echo "Generate a social card first with:"
    echo "  ./create-social-card.sh \$'Title' \$'Tagline'"
    exit 1
fi

# Check ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is required. Run this inside the devcontainer."
    exit 1
fi

echo "Publishing social card..."
echo "  Source: $SOURCE"
echo "  Destination: $DEST_DIR/"

# Create optimized JPG version (quality 85 is good balance)
convert "$SOURCE" -quality 85 "$DEST_DIR/social-card.jpg"
echo "  Created: social-card.jpg ($(du -h "$DEST_DIR/social-card.jpg" | cut -f1))"

echo ""
echo "Done! Social card published to $DEST_DIR/social-card.jpg"
