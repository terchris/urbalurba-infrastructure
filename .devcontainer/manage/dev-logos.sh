#!/bin/bash
# file: .devcontainer/manage/dev-logos.sh
#
# Processes logo images from src/ folders to production-ready formats.
# Converts SVG/PNG/JPG to 512x512 WebP for consistent display.
#
# Usage: dev-logos [--check]
#
# Options:
#   --check   Only check if logos need processing, don't process them
#   --help    Show this help message
#
# Prerequisites:
#   - ImageMagick (convert command)
#   - librsvg2-bin (rsvg-convert for SVG handling)
#   - webp tools
#
# Install prerequisites with: bash .devcontainer/additions/install-dev-imagetools.sh
#

set -e

# Determine workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

# Source directories (committed to repo)
TOOLS_SRC="${WORKSPACE_ROOT}/website/static/img/tools/src"
CATEGORIES_SRC="${WORKSPACE_ROOT}/website/static/img/categories/src"

# Output directories (gitignored, generated at build time)
TOOLS_OUT="${WORKSPACE_ROOT}/website/static/img/tools"
CATEGORIES_OUT="${WORKSPACE_ROOT}/website/static/img/categories"

# Processing parameters
SIZE="512x512"
QUALITY="90"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

show_help() {
    echo "Usage: dev-logos [OPTIONS]"
    echo ""
    echo "Process logo images from src/ folders to production-ready WebP format."
    echo ""
    echo "Options:"
    echo "  --check    Only check if logos need processing, don't process them"
    echo "  --help     Show this help message"
    echo ""
    echo "Source directories:"
    echo "  ${TOOLS_SRC}"
    echo "  ${CATEGORIES_SRC}"
    echo ""
    echo "Output directories:"
    echo "  ${TOOLS_OUT}"
    echo "  ${CATEGORIES_OUT}"
    echo ""
    echo "Prerequisites:"
    echo "  Install with: bash .devcontainer/additions/install-dev-imagetools.sh"
}

check_prerequisites() {
    local missing=0

    if ! command -v convert >/dev/null 2>&1; then
        echo "❌ ImageMagick (convert) not found"
        missing=1
    fi

    if ! command -v rsvg-convert >/dev/null 2>&1; then
        echo "⚠️  rsvg-convert not found (SVG processing may be limited)"
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo "Install prerequisites with:"
        echo "  bash .devcontainer/additions/install-dev-imagetools.sh"
        exit 1
    fi
}

process_logo() {
    local src_file="$1"
    local out_dir="$2"

    local filename
    filename=$(basename "$src_file")
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local out_file="${out_dir}/${name}.webp"

    # Skip if not a supported image format
    case "${ext,,}" in
        svg|png|jpg|jpeg|webp|gif)
            ;;
        *)
            echo "  ⏭️  Skipping ${filename} (unsupported format)"
            return
            ;;
    esac

    # Skip README and other non-image files
    if [[ "$filename" == *.md ]] || [[ "$filename" == *.txt ]]; then
        return
    fi

    # Process based on source format
    if [ "${ext,,}" = "svg" ]; then
        # For SVG, use rsvg-convert if available for better quality
        if command -v rsvg-convert >/dev/null 2>&1; then
            rsvg-convert -w 512 -h 512 "$src_file" -o "/tmp/${name}.png" 2>/dev/null || \
                convert "$src_file" -resize ${SIZE} -background transparent -gravity center -extent ${SIZE} "/tmp/${name}.png"
            convert "/tmp/${name}.png" -quality ${QUALITY} "$out_file"
            rm -f "/tmp/${name}.png"
        else
            convert "$src_file" -resize ${SIZE} -background transparent -gravity center -extent ${SIZE} -quality ${QUALITY} "$out_file"
        fi
    else
        # For raster images, resize and convert
        convert "$src_file" -resize ${SIZE} -background transparent -gravity center -extent ${SIZE} -quality ${QUALITY} "$out_file"
    fi

    echo "  ✅ ${filename} → ${name}.webp"
}

process_directory() {
    local src_dir="$1"
    local out_dir="$2"
    local label="$3"

    if [ ! -d "$src_dir" ]; then
        echo "⚠️  Source directory not found: ${src_dir}"
        return
    fi

    echo ""
    echo "📁 Processing ${label}..."

    # Create output directory
    mkdir -p "$out_dir"

    # Count files
    local count=0
    for img in "${src_dir}"/*; do
        [ -f "$img" ] || continue
        process_logo "$img" "$out_dir"
        ((count++)) || true
    done

    if [ $count -eq 0 ]; then
        echo "  ⚠️  No images found in ${src_dir}"
    else
        echo "  📊 Processed ${count} images"
    fi
}

check_logos() {
    echo "🔍 Checking logo status..."
    echo ""

    local tools_src_count=0
    local tools_out_count=0
    local cats_src_count=0
    local cats_out_count=0

    # Count tool logos
    if [ -d "$TOOLS_SRC" ]; then
        tools_src_count=$(find "$TOOLS_SRC" -type f \( -name "*.svg" -o -name "*.png" -o -name "*.jpg" -o -name "*.webp" \) 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$TOOLS_OUT" ]; then
        tools_out_count=$(find "$TOOLS_OUT" -maxdepth 1 -type f -name "*.webp" 2>/dev/null | wc -l | tr -d ' ')
    fi

    # Count category logos
    if [ -d "$CATEGORIES_SRC" ]; then
        cats_src_count=$(find "$CATEGORIES_SRC" -type f \( -name "*.svg" -o -name "*.png" -o -name "*.jpg" -o -name "*.webp" \) 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$CATEGORIES_OUT" ]; then
        cats_out_count=$(find "$CATEGORIES_OUT" -maxdepth 1 -type f -name "*.webp" 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo "Tool logos:"
    echo "  Source: ${tools_src_count} images in ${TOOLS_SRC}"
    echo "  Output: ${tools_out_count} WebP files in ${TOOLS_OUT}"

    echo ""
    echo "Category logos:"
    echo "  Source: ${cats_src_count} images in ${CATEGORIES_SRC}"
    echo "  Output: ${cats_out_count} WebP files in ${CATEGORIES_OUT}"

    echo ""
    if [ "$tools_src_count" -gt "$tools_out_count" ] || [ "$cats_src_count" -gt "$cats_out_count" ]; then
        echo "⚠️  Some logos need processing. Run: dev-logos"
        exit 1
    else
        echo "✅ All logos are up to date"
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --check)
            check_logos
            exit $?
            ;;
    esac

    echo "🖼️  Logo Processing Tool"
    echo "========================"
    echo ""
    echo "Converting source images to 512x512 WebP format..."

    check_prerequisites

    process_directory "$TOOLS_SRC" "$TOOLS_OUT" "Tool Logos"
    process_directory "$CATEGORIES_SRC" "$CATEGORIES_OUT" "Category Logos"

    echo ""
    echo "✅ Logo processing complete!"
    echo ""
    echo "Output:"
    echo "  ${TOOLS_OUT}/*.webp"
    echo "  ${CATEGORIES_OUT}/*.webp"
}

main "$@"
