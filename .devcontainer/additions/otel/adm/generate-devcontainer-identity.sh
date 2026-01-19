#!/bin/bash
# file: .devcontainer/additions/otel/adm/generate-devcontainer-identity.sh
#
# DESCRIPTION: Admin tool to generate base64-encoded identity string for developers
# PURPOSE: Creates a secure, single-string credential for developer onboarding
#
# Usage: ./generate-devcontainer-identity.sh <developer-id> <email> <project-name>
#
# Example:
#   ./generate-devcontainer-identity.sh john-doe john@developer.com client-portal
#
# Output: Base64 string to send to developer
#
#------------------------------------------------------------------------------

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

#------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------

show_usage() {
    cat <<EOF
Usage: $0 <developer-id> <email> <project-name>

Arguments:
  developer-id    Unique identifier (lowercase, use hyphens)
                  Example: john-doe, jane-smith, developer-123

  email           Developer's email address
                  Example: john.doe@developer.com

  project-name    Project identifier (lowercase, use hyphens)
                  Example: client-portal, api-backend

Examples:
  $0 john-doe john.doe@developer.com client-portal
  $0 jane-smith jane@company.com mobile-app

Output:
  Base64-encoded string containing identity configuration
  Send this string to the developer via secure channel (Slack, email, 1Password)

EOF
}

validate_input() {
    local dev_id="$1"
    local email="$2"
    local project="$3"

    # Check developer ID format (lowercase, hyphens, no spaces)
    if [[ ! "$dev_id" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${YELLOW}⚠️  Warning: Developer ID should be lowercase with hyphens${NC}"
        echo "   Got: $dev_id"
        echo "   Recommended: $(echo "$dev_id" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check email format (basic validation)
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${YELLOW}⚠️  Warning: Email format looks invalid${NC}"
        echo "   Got: $email"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check project name format
    if [[ ! "$project" =~ ^[a-z0-9-]+$ ]]; then
        echo -e "${YELLOW}⚠️  Warning: Project name should be lowercase with hyphens${NC}"
        echo "   Got: $project"
        echo "   Recommended: $(echo "$project" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

generate_identity() {
    local dev_id="$1"
    local email="$2"
    local project="$3"

    # Generate TS_HOSTNAME
    local ts_hostname="dev-${dev_id}-${project}"

    # Create identity string (shell format for easy sourcing)
    local identity=$(cat <<EOF
export DEVELOPER_ID="${dev_id}"
export DEVELOPER_EMAIL="${email}"
export PROJECT_NAME="${project}"
export TS_HOSTNAME="${ts_hostname}"
EOF
)

    # Encode to base64
    local encoded=$(echo "$identity" | base64 -w 0)

    echo "$encoded"
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    # Check arguments
    if [ $# -ne 3 ]; then
        show_usage
        exit 1
    fi

    DEVELOPER_ID="$1"
    DEVELOPER_EMAIL="$2"
    PROJECT_NAME="$3"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔐 Generating Developer Identity"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Validate inputs
    validate_input "$DEVELOPER_ID" "$DEVELOPER_EMAIL" "$PROJECT_NAME"

    echo -e "${BLUE}📋 Identity Configuration:${NC}"
    echo "   Developer ID:    $DEVELOPER_ID"
    echo "   Email:           $DEVELOPER_EMAIL"
    echo "   Project:         $PROJECT_NAME"
    echo "   Hostname:        dev-${DEVELOPER_ID}-${PROJECT_NAME}"
    echo ""

    # Generate base64 string
    IDENTITY_STRING=$(generate_identity "$DEVELOPER_ID" "$DEVELOPER_EMAIL" "$PROJECT_NAME")

    echo -e "${GREEN}✅ Identity string generated!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📤 Send this to developer (via Slack, email, or 1Password):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$IDENTITY_STRING"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${BLUE}📝 Instructions for developer:${NC}"
    echo ""
    echo "1. Open the devcontainer in VSCode"
    echo "2. Open a terminal"
    echo "3. Run: bash .devcontainer/additions/config-devcontainer-identity.sh"
    echo "4. Paste the identity string when prompted"
    echo ""
    echo -e "${GREEN}✅ Done!${NC}"
    echo ""
}

# Run main
main "$@"
