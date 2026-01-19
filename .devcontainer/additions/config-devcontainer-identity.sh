#!/bin/bash
# file: .devcontainer/additions/config-devcontainer-identity.sh
#
# DESCRIPTION: Developer onboarding script - sets up identity for devcontainer monitoring
# PURPOSE: Decodes admin-provided identity string and configures environment
#
# Usage:
#   bash config-devcontainer-identity.sh        # Run normally (need to source afterward)
#   source config-devcontainer-identity.sh      # Run and load vars in current shell
#
# Interactive script - will prompt for identity string from admin
#
#------------------------------------------------------------------------------
# CONFIGURATION - Metadata for dev-setup.sh discovery
#------------------------------------------------------------------------------

SCRIPT_ID="config-devcontainer-identity"
SCRIPT_NAME="Developer Identity"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Configure your identity for devcontainer monitoring (required for tracking your activity in Grafana dashboards)"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_CHECK_COMMAND="[ -f ~/.devcontainer-identity ] && grep -q '^export DEVELOPER_ID=' ~/.devcontainer-identity"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="identity monitoring telemetry onboarding developer"
SCRIPT_ABSTRACT="Configure developer identity for devcontainer monitoring and Grafana dashboards."
SCRIPT_LOGO="config-devcontainer-identity-logo.webp"
SCRIPT_SUMMARY="Developer onboarding script that decodes an admin-provided identity string and configures environment variables for devcontainer monitoring. Required for tracking activity in Grafana dashboards and telemetry collection."
SCRIPT_RELATED="srv-otel config-host-info"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Configure developer identity||false|"
    "Action|--show|Display current identity||false|"
    "Action|--verify|Restore from .devcontainer.secrets||false|"
    "Info|--help|Show help information||false|"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source logging library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Files
IDENTITY_FILE="$HOME/.devcontainer-identity"
BASHRC_FILE="$HOME/.bashrc"

# Persistent storage paths
PERSISTENT_DIR="/workspace/.devcontainer.secrets/env-vars"
PERSISTENT_FILE="$PERSISTENT_DIR/.devcontainer-identity"

#------------------------------------------------------------------------------
# FUNCTIONS
#------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_if_already_configured() {
    if [ -f "$IDENTITY_FILE" ]; then
        echo ""
        log_warn "Identity already configured!"
        echo ""
        echo "Current configuration:"
        if [ -r "$IDENTITY_FILE" ]; then
            # Source it temporarily to show values
            (
                source "$IDENTITY_FILE" 2>/dev/null
                echo "   Developer ID:    ${DEVELOPER_ID:-<not set>}"
                echo "   Email:           ${DEVELOPER_EMAIL:-<not set>}"
                echo "   Project:         ${PROJECT_NAME:-<not set>}"
            )
        fi
        echo ""
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            log_info "Keeping existing configuration"
            exit 0
        fi
        echo ""
        log_info "Reconfiguring identity..."
    fi
}

prompt_for_identity_string() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Enter Identity String"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Paste the base64 string provided by your administrator:"
    echo "(It will be a long string of letters and numbers)"
    echo ""
    read -r IDENTITY_STRING

    # Trim whitespace
    IDENTITY_STRING=$(echo "$IDENTITY_STRING" | tr -d '[:space:]')

    if [ -z "$IDENTITY_STRING" ]; then
        log_error "No identity string provided"
        exit 1
    fi
}

decode_and_validate() {
    log_info "Decoding identity string..."

    # Decode base64
    if ! DECODED=$(echo "$IDENTITY_STRING" | base64 -d 2>/dev/null); then
        log_error "Failed to decode identity string"
        echo ""
        echo "The string may be corrupted or incomplete."
        echo "Please check with your administrator."
        exit 1
    fi

    # Validate it contains expected exports
    if ! echo "$DECODED" | grep -q "DEVELOPER_ID"; then
        log_error "Invalid identity string format"
        echo ""
        echo "The string does not contain valid identity information."
        echo "Please check with your administrator."
        exit 1
    fi

    log_success "Identity string decoded successfully"

    # Extract and display values for confirmation
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Your Identity Configuration:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Source in subshell to extract values for display
    (
        eval "$DECODED"
        echo "   Developer ID:    ${DEVELOPER_ID:-<not set>}"
        echo "   Email:           ${DEVELOPER_EMAIL:-<not set>}"
        echo "   Project:         ${PROJECT_NAME:-<not set>}"
        echo "   Hostname:        ${TS_HOSTNAME:-<not set>}"
    )

    echo ""
    read -p "Does this look correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_warn "Setup cancelled"
        echo "Please contact your administrator for a new identity string."
        exit 1
    fi
}

write_identity_file() {
    log_info "Writing identity configuration..."

    # Write decoded identity to file
    echo "$DECODED" > "$IDENTITY_FILE"

    # Set permissions (readable only by user)
    chmod 600 "$IDENTITY_FILE"

    log_success "Identity file created: $IDENTITY_FILE"
}

update_bashrc() {
    log_info "Configuring shell environment..."

    # Check if already configured in .bashrc
    if grep -q "devcontainer-identity" "$BASHRC_FILE" 2>/dev/null; then
        log_info ".bashrc already configured (skipping)"
        return 0
    fi

    # Add source line to .bashrc
    cat >> "$BASHRC_FILE" <<'EOF'

# Devcontainer identity - managed by config-devcontainer-identity.sh
[ -f ~/.devcontainer-identity ] && source ~/.devcontainer-identity
EOF

    log_success ".bashrc updated"
}

load_identity_now() {
    log_info "Loading identity in current session..."

    # Source the identity file
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE"

    log_success "Identity loaded"
}

show_completion() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Setup Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Your identity is configured"
    log_success "New terminals will automatically load your identity"
    echo ""
    echo "📝 Important - Load Identity in Current Terminal:"
    echo ""
    echo "   Run this command now:"
    echo "   source ~/.devcontainer-identity"
    echo ""
    echo "   Or open a new terminal (identity loads automatically)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Additional Info:"
    echo ""
    echo "• Your identity is stored in: ~/.devcontainer-identity"
    echo "  (Symlink to: /workspace/.devcontainer.secrets/env-vars/.devcontainer-identity)"
    echo "  Persists across container rebuilds"
    echo ""
    echo "• To verify your identity anytime:"
    echo "  echo \$DEVELOPER_ID"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$SOURCED" = true ]; then
        # Script was sourced - load identity in current shell
        source "$IDENTITY_FILE"
        log_success "Identity loaded in current terminal!"
        echo ""
        echo "Test it now:"
        echo "  echo \$DEVELOPER_ID"
    else
        # Script was executed - need manual sourcing
        log_success "You can now start working!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚡ To load identity in THIS terminal, run:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "source ~/.devcontainer-identity && echo \"DEVELOPER_ID: \$DEVELOPER_ID\""
    fi
    echo ""
}

#------------------------------------------------------------------------------
# PERSISTENT STORAGE SETUP - Use .devcontainer.secrets folder for persistence across rebuilds
#------------------------------------------------------------------------------

setup_persistent_storage() {
    # Ensure persistent directory exists
    mkdir -p "$PERSISTENT_DIR"

    # Create symlink (force overwrite if exists)
    ln -sf "$PERSISTENT_FILE" "$IDENTITY_FILE"
}

#------------------------------------------------------------------------------
# SHOW CONFIG - Display current configuration
#------------------------------------------------------------------------------

show_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Current Configuration: $SCRIPT_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ ! -f "$IDENTITY_FILE" ]; then
        echo "❌ Not configured"
        echo ""
        echo "Run: bash $0"
        return 1
    fi

    # Source and display
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE" 2>/dev/null

    echo "Config file: $IDENTITY_FILE"
    if [ -L "$IDENTITY_FILE" ]; then
        echo "Symlink to:  $(readlink -f "$IDENTITY_FILE")"
    fi
    echo ""
    echo "Variables:"
    echo "  DEVELOPER_ID:     ${DEVELOPER_ID:-<not set>}"
    echo "  DEVELOPER_EMAIL:  ${DEVELOPER_EMAIL:-<not set>}"
    echo "  PROJECT_NAME:     ${PROJECT_NAME:-<not set>}"
    echo "  TS_HOSTNAME:      ${TS_HOSTNAME:-<not set>}"
    echo ""

    # Show persistent storage status
    if [ -f "$PERSISTENT_FILE" ]; then
        echo "Persistent Storage: ✅ Survives container rebuild"
        echo "  Location: $PERSISTENT_FILE"
    else
        echo "Persistent Storage: ❌ Will be lost on rebuild"
    fi
    echo ""

    return 0
}

#------------------------------------------------------------------------------
# VERIFY MODE - Non-interactive validation for container rebuild
#------------------------------------------------------------------------------

verify_identity() {
    # Silent mode - no prompts, just validate

    # Always set up symlink first (in case container was rebuilt)
    setup_persistent_storage

    # Ensure bashrc is configured to load identity (in case container was rebuilt)
    if [ -f "$BASHRC_FILE" ] && ! grep -q "devcontainer-identity" "$BASHRC_FILE" 2>/dev/null; then
        cat >> "$BASHRC_FILE" <<'EOF'

# Devcontainer identity - managed by config-devcontainer-identity.sh
[ -f ~/.devcontainer-identity ] && source ~/.devcontainer-identity
EOF
    fi

    # Check if identity file exists
    if [ ! -f "$IDENTITY_FILE" ]; then
        # File doesn't exist - this is expected on first container creation
        # Exit silently without error
        return 0
    fi

    # File exists - validate it has required variables
    # shellcheck source=/dev/null
    source "$IDENTITY_FILE" 2>/dev/null || return 1

    local missing_vars=()
    [ -z "${DEVELOPER_ID:-}" ] && missing_vars+=("DEVELOPER_ID")
    [ -z "${DEVELOPER_EMAIL:-}" ] && missing_vars+=("DEVELOPER_EMAIL")
    [ -z "${PROJECT_NAME:-}" ] && missing_vars+=("PROJECT_NAME")
    [ -z "${TS_HOSTNAME:-}" ] && missing_vars+=("TS_HOSTNAME")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "⚠️  Identity file exists but is incomplete. Missing: ${missing_vars[*]}"
        echo "   Run: bash .devcontainer/additions/config-devcontainer-identity.sh"
        return 1
    fi

    # Identity is valid
    echo "✅ Developer identity verified: ${DEVELOPER_ID}"
    return 0
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

# Detect if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SOURCED=true
else
    SOURCED=false
fi

main() {
    # Handle flags
    case "${1:-}" in
        --show)
            show_config
            exit $?
            ;;
        --verify)
            verify_identity
            exit $?
            ;;
        --help)
            echo "Usage: $0 [--show|--verify|--help]"
            echo ""
            echo "  (no args)  Configure developer identity interactively"
            echo "  --show     Display current identity configuration"
            echo "  --verify   Restore from .devcontainer.secrets (non-interactive)"
            echo "  --help     Show this help"
            exit 0
            ;;
    esac

    # Setup persistent storage (symlink)
    setup_persistent_storage

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔐 Developer Identity Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This script will configure your identity for devcontainer monitoring."
    echo ""

    # Check if already configured
    check_if_already_configured

    # Prompt for identity string
    prompt_for_identity_string

    # Decode and validate
    decode_and_validate

    # Write identity file
    write_identity_file

    # Update .bashrc
    update_bashrc

    # Load in current session
    load_identity_now

    # Show completion
    show_completion
}

# Run main
main "$@"
