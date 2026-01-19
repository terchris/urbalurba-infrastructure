#!/bin/bash
# file: .devcontainer/additions/config-ai-claudecode.sh
#
# DESCRIPTION: Configure Claude Code to use LiteLLM proxy in K8s cluster
# PURPOSE: Sets up authentication and networking for Claude Code
#
# Usage:
#   bash config-ai-claudecode.sh        # Run normally (need to source afterward)
#   source config-ai-claudecode.sh      # Run and load vars in current shell
#
# Interactive script - will prompt for LiteLLM client API key
#
#------------------------------------------------------------------------------
# CONFIGURATION - Metadata for dev-setup.sh discovery
#------------------------------------------------------------------------------

SCRIPT_ID="config-ai-claudecode"
SCRIPT_NAME="Claude Code Environment"
SCRIPT_VER="0.0.1"
SCRIPT_DESCRIPTION="Configure Claude Code authentication and networking for LiteLLM proxy"
SCRIPT_CATEGORY="AI_TOOLS"
SCRIPT_CHECK_COMMAND="[ -f ~/.claude-code-env ] && grep -q '^export ANTHROPIC_AUTH_TOKEN=' ~/.claude-code-env"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="claude anthropic ai authentication litellm proxy"
SCRIPT_ABSTRACT="Configure Claude Code authentication and networking for LiteLLM proxy backend."
SCRIPT_LOGO="config-ai-claudecode-logo.webp"
SCRIPT_WEBSITE="https://claude.ai/code"
SCRIPT_SUMMARY="Interactive configuration script for Claude Code that sets up authentication tokens and networking for the LiteLLM proxy. Stores credentials securely in ~/.claude-code-env and integrates with nginx reverse proxy for API routing."
SCRIPT_RELATED="dev-ai-claudecode srv-nginx config-nginx"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Configure Claude Code environment||false|"
    "Action|--show|Display current configuration||false|"
    "Action|--verify|Restore from .devcontainer.secrets||false|"
    "Info|--help|Show help information||false|"
)

# NOTE: Claude Code depends on nginx being configured to proxy requests to LiteLLM
# Run config-nginx.sh first to set up the backend URL
SCRIPT_PREREQUISITES="config-nginx.sh"

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
ENV_FILE="$HOME/.claude-code-env"
BASHRC_FILE="$HOME/.bashrc"

# Persistent storage paths
PERSISTENT_DIR="/workspace/.devcontainer.secrets/env-vars"
PERSISTENT_FILE="$PERSISTENT_DIR/.claude-code-env"

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
    if [ -f "$ENV_FILE" ]; then
        echo ""
        log_warn "Claude Code environment already configured!"
        echo ""
        echo "Current configuration:"
        if [ -r "$ENV_FILE" ]; then
            # Source it temporarily to show values
            (
                source "$ENV_FILE" 2>/dev/null
                echo "   API Token:   ${ANTHROPIC_AUTH_TOKEN:0:20}... (truncated)"
                echo "   Base URL:    ${ANTHROPIC_BASE_URL:-<not set>}"
                echo "   Headers:     ${ANTHROPIC_CUSTOM_HEADERS:-<not set>}"
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
        log_info "Reconfiguring Claude Code environment..."
    fi
}

prompt_for_api_key() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 Enter LiteLLM Client API Key"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Paste the LiteLLM client API key provided by cluster admin:"
    echo "(It starts with 'sk-' and is used for Claude Code authentication)"
    echo ""
    read -r API_KEY

    # Trim whitespace
    API_KEY=$(echo "$API_KEY" | tr -d '[:space:]')

    if [ -z "$API_KEY" ]; then
        log_error "No API key provided"
        exit 1
    fi

    # Validate format (should start with sk-)
    if [[ ! "$API_KEY" =~ ^sk- ]]; then
        log_warn "API key doesn't start with 'sk-' - this may be incorrect"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "API key accepted"
}

create_env_file() {
    log_info "Creating Claude Code environment configuration..."

    # Create the environment file with all required variables
    cat > "$PERSISTENT_FILE" <<EOF
# Claude Code Environment Configuration
# Generated by config-claude-code.sh on $(date)
# This file is sourced by .bashrc to provide Claude Code authentication and networking

# LiteLLM Client API Key (provided by cluster admin)
export ANTHROPIC_AUTH_TOKEN="$API_KEY"

# LiteLLM Proxy Endpoint (via nginx reverse proxy on localhost:8080)
# Nginx adds Host header and forwards to host.docker.internal → Traefik → LiteLLM
# No port-forward needed - uses Traefik Host-based routing
export ANTHROPIC_BASE_URL="http://localhost:8080"

# Optional: Disable telemetry
export DISABLE_TELEMETRY="1"

# Optional: Disable auto-updater in container
export DISABLE_AUTOUPDATER="1"
EOF

    # Set permissions (readable only by user)
    chmod 600 "$PERSISTENT_FILE"

    log_success "Environment file created: $PERSISTENT_FILE"
}

setup_persistent_storage() {
    log_info "Setting up persistent storage..."

    # Ensure persistent directory exists
    mkdir -p "$PERSISTENT_DIR"

    # Create symlink (force overwrite if exists)
    ln -sf "$PERSISTENT_FILE" "$ENV_FILE"

    log_success "Symlink created: $ENV_FILE → $PERSISTENT_FILE"
}

update_bashrc() {
    log_info "Configuring shell environment..."

    # Check if already configured in .bashrc
    if grep -q "claude-code-env" "$BASHRC_FILE" 2>/dev/null; then
        log_info ".bashrc already configured (skipping)"
        return 0
    fi

    # Add source line to .bashrc
    cat >> "$BASHRC_FILE" <<'EOF'

# Claude Code environment - managed by config-claude-code.sh
[ -f ~/.claude-code-env ] && source ~/.claude-code-env
EOF

    log_success ".bashrc updated"
}

load_environment_now() {
    log_info "Loading environment in current session..."

    # Source the env file
    # shellcheck source=/dev/null
    source "$ENV_FILE"

    log_success "Environment loaded"
}

test_configuration() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Testing Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Source the env file for testing
    # shellcheck source=/dev/null
    source "$ENV_FILE"

    # Test 1: Check environment variables are set
    log_info "Test 1: Environment variables"
    if [ -n "$ANTHROPIC_AUTH_TOKEN" ] && [ -n "$ANTHROPIC_BASE_URL" ]; then
        log_success "All required environment variables are set"
    else
        log_error "Some environment variables are missing"
        return 1
    fi

    # Test 2: Check network connectivity to host.docker.internal
    log_info "Test 2: Network connectivity to host.docker.internal"
    if ping -c 1 -W 2 host.docker.internal >/dev/null 2>&1; then
        log_success "Can reach host.docker.internal"
    else
        log_warn "Cannot ping host.docker.internal (this is normal if host doesn't respond to ping)"
    fi

    # Test 3: Check LiteLLM health endpoint (via nginx)
    log_info "Test 3: LiteLLM health endpoint (via nginx)"
    if command -v curl >/dev/null 2>&1; then
        HEALTH_RESPONSE=$(curl -s -H "Authorization: Bearer ${ANTHROPIC_AUTH_TOKEN}" http://localhost:8080/health 2>&1 || echo "FAILED")
        if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
            log_success "LiteLLM is responding (health check passed)"
        else
            log_warn "Could not reach LiteLLM health endpoint"
            echo "   Response: $HEALTH_RESPONSE"
            echo "   This may be normal if nginx or LiteLLM is not running yet"
        fi
    else
        log_info "curl not available, skipping health check"
    fi

    # Test 4: Check Claude Code is installed
    log_info "Test 4: Claude Code installation"
    if command -v claude >/dev/null 2>&1; then
        CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code is installed (version: $CLAUDE_VERSION)"
    else
        log_warn "Claude Code not installed yet"
        echo "   Install it with: dev-setup"
        echo "   Or enable in: .devcontainer.extend/enabled-tools.conf"
    fi

    echo ""
}

show_completion() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Setup Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Claude Code environment is configured"
    log_success "New terminals will automatically load the environment"
    echo ""
    echo "📝 Important - Load Environment in Current Terminal:"
    echo ""
    echo "   Run this command now:"
    echo "   source ~/.claude-code-env"
    echo ""
    echo "   Or open a new terminal (environment loads automatically)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Configuration Details:"
    echo ""
    echo "• Environment file: ~/.claude-code-env"
    echo "  (Symlink to: /workspace/.devcontainer.secrets/env-vars/.claude-code-env)"
    echo "  Persists across container rebuilds"
    echo ""
    echo "• Variables configured:"
    echo "  - ANTHROPIC_AUTH_TOKEN (your LiteLLM client key)"
    echo "  - ANTHROPIC_BASE_URL (http://localhost:8080 via nginx)"
    echo ""
    echo "• To verify environment anytime:"
    echo "  echo \$ANTHROPIC_BASE_URL"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🚀 Next Steps:"
    echo ""
    echo "1. Test Claude Code authentication:"
    echo "   claude --version"
    echo ""
    echo "2. Test API connectivity (via nginx):"
    echo "   curl -H \"Authorization: Bearer \$ANTHROPIC_AUTH_TOKEN\" \\"
    echo "        http://localhost:8080/health"
    echo ""
    echo "3. Start using Claude Code:"
    echo "   claude"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ "$SOURCED" = true ]; then
        # Script was sourced - load environment in current shell
        source "$ENV_FILE"
        log_success "Environment loaded in current terminal!"
        echo ""
        echo "Test it now:"
        echo "  echo \$ANTHROPIC_BASE_URL"
    fi
    echo ""
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

    if [ ! -f "$ENV_FILE" ]; then
        echo "❌ Not configured"
        echo ""
        echo "Run: bash $0"
        return 1
    fi

    # Source and display (with secrets truncated)
    # shellcheck source=/dev/null
    source "$ENV_FILE" 2>/dev/null

    echo "Config file: $ENV_FILE"
    if [ -L "$ENV_FILE" ]; then
        echo "Symlink to:  $(readlink -f "$ENV_FILE")"
    fi
    echo ""
    echo "Variables:"
    echo "  ANTHROPIC_AUTH_TOKEN:  ${ANTHROPIC_AUTH_TOKEN:0:20}... (truncated)"
    echo "  ANTHROPIC_BASE_URL:    ${ANTHROPIC_BASE_URL:-<not set>}"
    echo "  DISABLE_TELEMETRY:     ${DISABLE_TELEMETRY:-<not set>}"
    echo "  DISABLE_AUTOUPDATER:   ${DISABLE_AUTOUPDATER:-<not set>}"
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

verify_environment() {
    # Silent mode - no prompts, just validate

    # Always set up symlink first (in case container was rebuilt)
    mkdir -p "$PERSISTENT_DIR"
    ln -sf "$PERSISTENT_FILE" "$ENV_FILE"

    # Ensure bashrc is configured to load environment (in case container was rebuilt)
    if [ -f "$BASHRC_FILE" ] && ! grep -q "Claude Code environment" "$BASHRC_FILE" 2>/dev/null; then
        cat >> "$BASHRC_FILE" <<'EOF'

# Claude Code environment - managed by config-ai-claudecode.sh
[ -f ~/.claude-code-env ] && source ~/.claude-code-env
EOF
    fi

    # Check if env file exists
    if [ ! -f "$ENV_FILE" ]; then
        # File doesn't exist - this is expected on first container creation
        # Exit silently without error
        return 0
    fi

    # File exists - validate it has required variables
    # shellcheck source=/dev/null
    source "$ENV_FILE" 2>/dev/null || return 1

    local missing_vars=()
    [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ] && missing_vars+=("ANTHROPIC_AUTH_TOKEN")
    [ -z "${ANTHROPIC_BASE_URL:-}" ] && missing_vars+=("ANTHROPIC_BASE_URL")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "⚠️  Claude Code environment exists but is incomplete. Missing: ${missing_vars[*]}"
        echo "   Run: bash .devcontainer/additions/config-ai-claudecode.sh"
        return 1
    fi

    # Environment is valid
    echo "✅ Claude Code environment verified: LiteLLM proxy configured"
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
            verify_environment
            exit $?
            ;;
        --help)
            echo "Usage: $0 [--show|--verify|--help]"
            echo ""
            echo "  (no args)  Configure Claude Code environment interactively"
            echo "  --show     Display current configuration"
            echo "  --verify   Restore from .devcontainer.secrets (non-interactive)"
            echo "  --help     Show this help"
            exit 0
            ;;
    esac

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🤖 Claude Code Environment Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "This script will configure Claude Code to use the LiteLLM proxy"
    echo "in the K8s cluster for authentication and API access."
    echo ""

    # Check if already configured
    check_if_already_configured

    # Prompt for API key
    prompt_for_api_key

    # Setup persistent storage
    setup_persistent_storage

    # Create environment file
    create_env_file

    # Update .bashrc
    update_bashrc

    # Load in current session
    load_environment_now

    # Test configuration
    test_configuration

    # Show completion
    show_completion
}

# Run main
main "$@"
