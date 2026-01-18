#!/bin/bash
# publish-social-card.sh - Publish generated social card to website
#
# Takes the generated social card from the brand folder and copies it to
# the location used by Docusaurus (static/img/social-card.png).
#
# Also creates an optimized JPG version for faster loading.
#
# IMPORTANT: Run this script inside the devcontainer where ImageMagick is available.
#
# Usage:
#   ./publish-social-card.sh [source.png]
#
# Arguments:
#   source.png - Optional. Source image (default: social-card-generated.png)
#
# Output files (in ../):
#   social-card.png - PNG version (used by Docusaurus)
#   social-card.jpg - Optimized JPG version (smaller file size)

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

# Copy PNG (Docusaurus default)
cp "$SOURCE" "$DEST_DIR/social-card.png"
echo "  Created: social-card.png ($(du -h "$DEST_DIR/social-card.png" | cut -f1))"

# Create optimized JPG version (quality 85 is good balance)
convert "$SOURCE" -quality 85 "$DEST_DIR/social-card.jpg"
echo "  Created: social-card.jpg ($(du -h "$DEST_DIR/social-card.jpg" | cut -f1))"

echo ""
echo "Done! Social card published to $DEST_DIR/"
echo ""
echo "Docusaurus is configured to use: img/social-card.jpg"
echo "To use PNG instead, update docusaurus.config.ts:"
echo "  image: 'img/social-card.png'"
