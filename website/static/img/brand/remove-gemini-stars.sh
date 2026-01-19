#!/bin/bash
# file: website/static/img/brand/remove-gemini-stars.sh
#
# Removes Gemini AI watermark stars from generated images.
# Gemini adds decorative 4-pointed stars in the corners of generated images.
#
# This script is optimized for social card images (~1344x768 or ~1424x752).
# It will warn if the input image doesn't match expected social card dimensions.
#
# Usage: ./remove-gemini-stars.sh [options] <input-image> [output-image]
#
# Options:
#   -l, --left, -left    Remove star from bottom-left corner (default)
#   -r, --right, -right  Remove star from bottom-right corner
#   -c, --color COLOR    Background color to use (default: rgb(25,52,78))
#   -h, --help           Show help message
#
# If output-image is not specified, overwrites the input file.
# If neither -left nor -right is specified, defaults to -left.
#
# Prerequisites:
#   - ImageMagick (convert command)
#
# Examples:
#   ./remove-gemini-stars.sh -left image.png output.png      # Remove left star only
#   ./remove-gemini-stars.sh -right image.png output.png     # Remove right star only
#   ./remove-gemini-stars.sh -left -right image.png out.png  # Remove both stars
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default background color (SovereignSky navy blue)
BG_COLOR="rgb(25,52,78)"

# Corner flags (default: left only)
REMOVE_LEFT=false
REMOVE_RIGHT=false

show_help() {
    echo "Usage: $(basename "$0") [options] <input-image> [output-image]"
    echo ""
    echo "Removes Gemini AI watermark stars from image corners."
    echo ""
    echo "Arguments:"
    echo "  input-image   Source image with Gemini stars"
    echo "  output-image  Output filename (optional, defaults to overwriting input)"
    echo ""
    echo "Options:"
    echo "  -l, --left    Remove star from bottom-left corner"
    echo "  -r, --right   Remove star from bottom-right corner"
    echo "  -c, --color   Background color to use (default: rgb(25,52,78))"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "If neither -left nor -right is specified, defaults to -left."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -left image.png                    # Remove left star"
    echo "  $(basename "$0") -right image.png output.png        # Remove right star"
    echo "  $(basename "$0") -left -right image.png output.png  # Remove both stars"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--left|-left)
            REMOVE_LEFT=true
            shift
            ;;
        -r|--right|-right)
            REMOVE_RIGHT=true
            shift
            ;;
        -c|--color)
            BG_COLOR="$2"
            shift 2
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Default to left if neither specified
if [[ "$REMOVE_LEFT" == "false" && "$REMOVE_RIGHT" == "false" ]]; then
    REMOVE_LEFT=true
fi

# Validate input
if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: Input file required"
    show_help
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Default output to input if not specified
OUTPUT_FILE="${OUTPUT_FILE:-$INPUT_FILE}"

# Check for ImageMagick
if ! command -v convert >/dev/null 2>&1; then
    echo "Error: ImageMagick (convert) not found"
    echo "Install with: bash .devcontainer/additions/install-dev-imagetools.sh"
    exit 1
fi

# Get image dimensions
DIMENSIONS=$(identify -format "%wx%h" "$INPUT_FILE")
WIDTH=$(echo "$DIMENSIONS" | cut -d'x' -f1)
HEIGHT=$(echo "$DIMENSIONS" | cut -d'x' -f2)

echo "Processing: $INPUT_FILE (${WIDTH}x${HEIGHT})"

# Validate social card dimensions
# Expected: approximately 1344x768 (Gemini) or 1424x752 (Open Graph standard)
MIN_WIDTH=1200
MAX_WIDTH=1500
MIN_HEIGHT=600
MAX_HEIGHT=850

if [[ $WIDTH -lt $MIN_WIDTH || $WIDTH -gt $MAX_WIDTH || $HEIGHT -lt $MIN_HEIGHT || $HEIGHT -gt $MAX_HEIGHT ]]; then
    echo ""
    echo "⚠️  WARNING: Image dimensions (${WIDTH}x${HEIGHT}) don't match expected social card size."
    echo "   Expected: ~1344x768 (Gemini) or ~1424x752 (Open Graph)"
    echo "   This script is optimized for social card images."
    echo "   Star removal coordinates may not be accurate for other image sizes."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Build the draw commands
DRAW_COMMANDS=""

if [[ "$REMOVE_LEFT" == "true" ]]; then
    echo "  - Removing star from bottom-left corner"
    BL_X1=0
    BL_Y1=$((HEIGHT - 90))
    BL_X2=100
    BL_Y2=$HEIGHT
    DRAW_COMMANDS="$DRAW_COMMANDS -draw \"rectangle $BL_X1,$BL_Y1 $BL_X2,$BL_Y2\""
fi

if [[ "$REMOVE_RIGHT" == "true" ]]; then
    echo "  - Removing star from bottom-right corner"
    BR_X1=$((WIDTH - 90))
    BR_Y1=$((HEIGHT - 120))
    BR_X2=$WIDTH
    BR_Y2=$((HEIGHT - 30))
    DRAW_COMMANDS="$DRAW_COMMANDS -draw \"rectangle $BR_X1,$BR_Y1 $BR_X2,$BR_Y2\""
fi

# Apply the fixes using eval to handle the dynamic draw commands
eval "convert \"$INPUT_FILE\" -fill \"$BG_COLOR\" $DRAW_COMMANDS \"$OUTPUT_FILE\""

echo "Saved: $OUTPUT_FILE"
echo "Done!"
