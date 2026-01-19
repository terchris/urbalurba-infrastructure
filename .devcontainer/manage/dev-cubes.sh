#!/bin/bash
# file: .devcontainer/manage/dev-cubes.sh
#
# Generates the FloatingCubes configuration for the homepage hero section.
# Scans tool logos and creates a TypeScript config file.
#
# Usage: dev-cubes [--verbose]
#
# Options:
#   --verbose   Show detailed information about each logo
#   --help      Show this help message
#
# This script is run automatically during deployment but can also be
# run manually after adding new tool logos.
#

#------------------------------------------------------------------------------
# Script Metadata (for component scanner / dev-help)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-cubes"
SCRIPT_NAME="Cubes Generator"
SCRIPT_DESCRIPTION="Generate homepage floating cubes configuration"
SCRIPT_CATEGORY="CONTRIBUTOR_TOOLS"
SCRIPT_CHECK_COMMAND="node --version"

set -e

# Determine workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

# Paths
GENERATOR_SCRIPT="${WORKSPACE_ROOT}/website/scripts/generate-cube-config.js"
OUTPUT_FILE="${WORKSPACE_ROOT}/website/src/components/FloatingCubes/cubeConfig.ts"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

show_help() {
    echo "Usage: dev-cubes [OPTIONS]"
    echo ""
    echo "Generate FloatingCubes configuration from tool logos."
    echo ""
    echo "This script scans the tool logos in website/static/img/tools/ and"
    echo "generates a TypeScript configuration file for the homepage hero"
    echo "section's floating cubes animation."
    echo ""
    echo "Options:"
    echo "  --verbose   Show detailed information about each logo"
    echo "  --help      Show this help message"
    echo ""
    echo "Output:"
    echo "  ${OUTPUT_FILE}"
    echo ""
    echo "The script validates each logo:"
    echo "  - WebP: max 50KB, 64-512px dimensions"
    echo "  - SVG: max 100KB, min 64px dimensions"
    echo ""
    echo "Invalid logos are excluded and reported."
}

check_prerequisites() {
    if ! command -v node >/dev/null 2>&1; then
        echo "❌ Node.js not found"
        echo ""
        echo "Node.js is required to run this script."
        exit 1
    fi

    if [ ! -f "$GENERATOR_SCRIPT" ]; then
        echo "❌ Generator script not found: ${GENERATOR_SCRIPT}"
        exit 1
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
    esac

    echo "🎲 Generating FloatingCubes Configuration"
    echo "=========================================="
    echo ""

    check_prerequisites

    # Change to website directory and run the generator
    cd "${WORKSPACE_ROOT}/website"

    if [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "-v" ]; then
        node scripts/generate-cube-config.js --verbose
    else
        node scripts/generate-cube-config.js
    fi

    echo ""
    echo "✅ FloatingCubes configuration generated!"
}

main "$@"
