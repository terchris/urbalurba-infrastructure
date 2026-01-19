#!/bin/bash
# file: .devcontainer/additions/install-dev-imagetools.sh
#
# Installs ImageMagick and related tools for image processing.
# For usage information, run: ./install-dev-imagetools.sh --help
#
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="dev-imagetools"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="Image Processing Tools"
SCRIPT_DESCRIPTION="Installs ImageMagick for image processing, resizing, and format conversion"
SCRIPT_CATEGORY="CONTRIBUTOR_TOOLS"
SCRIPT_CHECK_COMMAND="command -v convert >/dev/null 2>&1"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="imagemagick image processing resize convert webp svg png logo"
SCRIPT_ABSTRACT="Image processing tools with ImageMagick for resizing, converting, and optimizing images."
SCRIPT_LOGO="dev-imagetools-logo.webp"
SCRIPT_WEBSITE="https://imagemagick.org"
SCRIPT_SUMMARY="ImageMagick toolkit for image manipulation including resizing, format conversion (SVG to WebP/PNG), optimization, and batch processing. Used by dev-logos to process logo assets for the website."
SCRIPT_RELATED="tool-dataanalytics"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install image processing tools||false|"
    "Action|--uninstall|Uninstall image processing tools||false|"
    "Info|--help|Show help and usage information||false|"
)

# System packages
# SYNC NOTE: If you change these packages, also update:
# .github/workflows/deploy-docs.yml (Install image processing tools step)
PACKAGES_SYSTEM=(
    "imagemagick"      # Image manipulation tool
    "librsvg2-bin"     # SVG rendering library (for rsvg-convert)
    "webp"             # WebP image format tools
)

# VS Code extensions (none needed for image tools)
EXTENSIONS=()

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# --- Pre-installation/Uninstallation Setup ---
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."
        echo "✅ Pre-installation setup complete"
    fi
}

# --- Post-installation/Uninstallation Messages ---
post_installation_message() {
    local convert_version
    convert_version=$(convert --version 2>/dev/null | head -1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   ImageMagick: $convert_version"
    echo
    echo "Quick start: convert input.svg -resize 512x512 output.webp"
    echo "             dev-logos  # Process all logo assets"
    echo "Docs: https://imagemagick.org/script/command-line-processing.php"
    echo
}

post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    echo "   ✅ Image processing tools removed"
    echo
}

#------------------------------------------------------------------------------
# MAIN SCRIPT EXECUTION - Do not modify below this line
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags for core scripts
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

# Source all core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-node.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"
source "${SCRIPT_DIR}/lib/core-install-pwsh.sh"
source "${SCRIPT_DIR}/lib/core-install-python.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

# Function to process installations
process_installations() {
    # Process standard installations (packages and extensions)
    process_standard_installations
}



#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
