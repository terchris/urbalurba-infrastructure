#!/bin/bash
# create-social-card.sh - Generate social card images with text and logo
#
# Combines a background image with title text, tagline, and logo to create
# social media card images (Open Graph, Twitter cards, etc.)
#
# IMPORTANT: Run this script inside the devcontainer where ImageMagick
# and rsvg-convert are available.
#
# Usage:
#   ./create-social-card.sh "Title" "Tagline" [logo.svg] [output.png]
#
# Arguments:
#   Title    - Main heading text. Use \n for line breaks (e.g., "Urbalurba\nInfrastructure")
#   Tagline  - Secondary text below title. Use \n for line breaks
#   logo.svg - Optional. Path to SVG logo (default: uis-text-green.svg)
#   output   - Optional. Output filename (default: social-card-generated.png)
#
# Examples:
#   # Generate with defaults
#   ./create-social-card.sh $'Urbalurba\nInfrastructure' $'Complete datacenter\non your laptop.'
#
#   # Custom output file
#   ./create-social-card.sh $'My Project' $'A cool tagline.' uis-text-green.svg my-card.png
#
# Requirements:
#   - ImageMagick (convert command)
#   - rsvg-convert (for SVG with text - librsvg2-bin package)
#   - social-card-background.png in same directory
#
# Layout:
#   - Title: Right side, green (#3a8f5e), 72pt Helvetica Bold
#   - Tagline: Below title, green, 42pt Helvetica
#   - Logo: Bottom right corner, 270px wide

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKGROUND="$SCRIPT_DIR/social-card-background.png"

# Default values
TITLE="${1:-Urbalurba\nInfrastructure}"
TAGLINE="${2:-Complete datacenter\non your laptop.}"
LOGO="${3:-$SCRIPT_DIR/uis-text-green.svg}"
OUTPUT="${4:-$SCRIPT_DIR/social-card-generated.png}"

# Colors (matching SovereignSky branding)
TEXT_COLOR="#3a8f5e"  # Green
TITLE_SIZE=72
TAGLINE_SIZE=42

# Positions (based on original social-card.png layout - 1424x752)
# Text is on the RIGHT side of the image
TITLE_X=700
TITLE_Y=180
TAGLINE_X=700
TAGLINE_Y=420   # More space between title and tagline
LOGO_X=50    # From right edge
LOGO_Y=40    # From bottom edge
LOGO_WIDTH=270  # 50% bigger (was 180)

# Check dependencies
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is required. Run this inside the devcontainer."
    exit 1
fi

# Check background exists
if [[ ! -f "$BACKGROUND" ]]; then
    echo "Error: Background image not found: $BACKGROUND"
    exit 1
fi

# Check logo exists (handle relative paths)
if [[ ! -f "$LOGO" ]]; then
    if [[ -f "$SCRIPT_DIR/$LOGO" ]]; then
        LOGO="$SCRIPT_DIR/$LOGO"
    else
        echo "Error: Logo not found: $LOGO"
        exit 1
    fi
fi

echo "Creating social card..."
echo "  Title: $TITLE"
echo "  Tagline: $TAGLINE"
echo "  Logo: $LOGO"
echo "  Output: $OUTPUT"

# Create temporary files
TEMP_LOGO=$(mktemp /tmp/logo.XXXXXX.png)
trap "rm -f $TEMP_LOGO" EXIT

# Convert SVG logo to PNG using rsvg-convert (better font support)
if command -v rsvg-convert &> /dev/null; then
    rsvg-convert -w ${LOGO_WIDTH} "$LOGO" -o "$TEMP_LOGO"
else
    convert -background none -density 300 "$LOGO" -resize ${LOGO_WIDTH}x "$TEMP_LOGO"
fi

# Create the social card:
# - Text on the right side (using NorthWest gravity with x offset)
# - Logo in bottom right corner
convert "$BACKGROUND" \
    -font "Helvetica-Bold" -pointsize $TITLE_SIZE -fill "$TEXT_COLOR" \
    -gravity NorthWest -annotate +${TITLE_X}+${TITLE_Y} "$TITLE" \
    -font "Helvetica" -pointsize $TAGLINE_SIZE -fill "$TEXT_COLOR" \
    -gravity NorthWest -annotate +${TAGLINE_X}+${TAGLINE_Y} "$TAGLINE" \
    "$TEMP_LOGO" -gravity SouthEast -geometry +${LOGO_X}+${LOGO_Y} -composite \
    "$OUTPUT"

echo "Done! Created: $OUTPUT"
