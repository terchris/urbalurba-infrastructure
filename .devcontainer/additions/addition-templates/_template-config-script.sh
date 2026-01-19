#!/bin/bash
# file: .devcontainer/additions/_template-config-script.sh
#
# TEMPLATE: Copy this file when creating new configuration scripts
# Rename to: config-[setting-name].sh
# Example: config-git-user.sh, config-aws-credentials.sh
#
# Usage:
#   bash .devcontainer/additions/config-[name].sh           # Interactive configuration
#   bash .devcontainer/additions/config-[name].sh --verify  # Non-interactive restoration from .devcontainer.secrets
#
# Configuration scripts should be:
#   - Interactive (prompt user for input)
#   - Idempotent (safe to run multiple times)
#   - Support reconfiguration (allow updating existing config)
#   - Validate user input
#   - Provide clear feedback
#   - Support --verify flag for automatic restoration from .devcontainer.secrets
#
#------------------------------------------------------------------------------
# METADATA PATTERN - Required for automatic script discovery
#------------------------------------------------------------------------------
#
# The dev-setup.sh menu system uses the component-scanner library to automatically
# discover and display all config scripts. To make your script visible in the menu,
# you must define these four metadata fields in the CONFIGURATION section below:
#
# SCRIPT_NAME - Human-readable name displayed in the menu (2-4 words)
#   Example: "Developer Identity"
#
# SCRIPT_DESCRIPTION - Brief description of what this configures (one sentence)
#   Example: "Configure your identity for devcontainer monitoring"
#
# SCRIPT_CATEGORY - Category for menu organization
#   Common options: INFRA_CONFIG, USER_CONFIG, SECURITY, CREDENTIALS
#   Example: "INFRA_CONFIG"
#
# SCRIPT_CHECK_COMMAND - Shell command to check if already configured
#   - Must return exit code 0 if configured, 1 if not configured
#   - Should suppress all output (use >/dev/null 2>&1)
#   - Should be fast (run in < 1 second)
#   - Should check actual configuration state, not just file existence
#   Examples:
#     "[ -f ~/.config-file ] && grep -q '^key=value' ~/.config-file"
#     "git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1"
#     "[ -f ~/.aws/credentials ] && grep -q '^\[default\]' ~/.aws/credentials"
#
# For more details, see: .devcontainer/additions/README-additions.md
#
#------------------------------------------------------------------------------
# --VERIFY FLAG PATTERN - For automatic restoration from .devcontainer.secrets
#------------------------------------------------------------------------------
#
# The --verify flag enables automatic, non-interactive restoration of configurations
# from the /workspace/.devcontainer.secrets folder during devcontainer setup. This allows
# configurations to persist across container rebuilds.
#
# THE --VERIFY CONTRACT:
#
# When your script is called with --verify flag:
#   1. Run NON-INTERACTIVELY (no prompts, minimal output)
#   2. Check if configuration exists in /workspace/.devcontainer.secrets/
#   3. If found, restore it (symlink or copy to home directory)
#   4. Return exit code 0 if successfully restored
#   5. Return exit code 1 if not found in .devcontainer.secrets (SILENT FAILURE - this is normal!)
#   6. DO NOT create new configurations or prompt user
#
# IMPORTANT: Exit code 1 is NOT an error - it just means "config not in .devcontainer.secrets yet"
# This is expected behavior for configs the user hasn't configured yet.
# The system handles this gracefully (silent during restoration, loud if actually required).
#
# IMPLEMENTATION PATTERN:
#
# Add a verify function and handler at the beginning of your script:
#
#   verify_your_config() {
#       local .devcontainer.secrets_path="/workspace/.devcontainer.secrets/your-config-file"
#       local home_path="$HOME/.your-config-file"
#
#       # Check if exists in .devcontainer.secrets
#       if [ -f "$.devcontainer.secrets_path" ]; then
#           # Restore (symlink recommended for live updates)
#           ln -sf "$.devcontainer.secrets_path" "$home_path"
#           echo "✅ Your configuration restored"
#           return 0
#       fi
#       # Not found in .devcontainer.secrets (silent failure)
#       return 1
#   }
#
#   # Handle --verify flag (add BEFORE main function)
#   if [ "${1:-}" = "--verify" ]; then
#       verify_your_config
#       exit $?
#   fi
#
# WHY THIS MATTERS - Two-Layer System:
#
# project-installs.sh automatically calls restore_all_configurations() which:
#   - Discovers ALL config-*.sh scripts automatically
#   - Runs each with --verify flag
#   - Restores configurations from .devcontainer.secrets if they exist
#   - Reports only successful restorations (SILENT for missing configs)
#
# Your script will be automatically discovered and restored - no hardcoding needed!
#
# TWO-LAYER APPROACH:
#
# Layer 1: Silent Config Restoration (restore_all_configurations)
#   - Runs BEFORE tool installation
#   - Attempts to restore ALL configs from .devcontainer.secrets
#   - Shows ✅ for successful restorations
#   - SILENT for missing configs (no noise)
#   - Non-blocking - always continues
#
# Layer 2: Loud Tool Prerequisites (install_project_tools)
#   - Runs DURING tool installation for ENABLED tools
#   - Checks PREREQUISITE_CONFIGS field in install scripts
#   - Shows ⚠️ error if REQUIRED config is missing
#   - Blocks tool installation until prerequisites met
#   - Clear fix instructions provided
#
# This means:
#   - User doesn't see warnings for configs they don't need (silent)
#   - User DOES see errors for configs required by enabled tools (loud)
#   - Clean, non-noisy output with precise error reporting
#
# TOPSECRET FOLDER:
#
# The /workspace/.devcontainer.secrets folder is:
#   - Git-ignored (never committed)
#   - Persists across container rebuilds
#   - Stored on host machine
#   - Used for credentials, API keys, config files, etc.
#
# When user configures your script interactively, save a symlink target in .devcontainer.secrets:
#   - Interactive: User provides values → Saved to /workspace/.devcontainer.secrets/your-config
#   - Rebuild: --verify restores from /workspace/.devcontainer.secrets/your-config automatically
#
#------------------------------------------------------------------------------
# CONFIGURATION METADATA - For dev-setup.sh menu discovery
#------------------------------------------------------------------------------

# --- Core Metadata (required for dev-setup.sh) ---
SCRIPT_ID="config-[name]"  # Unique identifier (must match filename without .sh)
SCRIPT_VER="0.0.1"  # Script version - displayed during configuration
SCRIPT_NAME="[Configuration Name]"
SCRIPT_DESCRIPTION="Configure [setting/credential/identity] for [purpose]"
SCRIPT_CATEGORY="INFRA_CONFIG"  # Options: LANGUAGE_DEV, AI_TOOLS, CLOUD_TOOLS, DATA_ANALYTICS, BACKGROUND_SERVICES, INFRA_CONFIG
SCRIPT_CHECK_COMMAND="[ -f ~/.config-file ] && grep -q '^key=value' ~/.config-file"
SCRIPT_PREREQUISITES=""  # Example: "config-other.sh" or "" if none - comma-separated for multiple

# --- Extended Metadata (for website documentation) ---
# These fields are for the documentation website only, NOT used by dev-setup.sh
SCRIPT_TAGS="[keyword1] [keyword2] [keyword3]"  # Space-separated search keywords
SCRIPT_ABSTRACT="[Brief 1-2 sentence description, 50-150 characters]"  # For tool cards
# Optional fields (uncomment if applicable):
# SCRIPT_LOGO="[script-id]-logo.webp"  # Logo file in website/static/img/tools/src/
# SCRIPT_WEBSITE="https://[official-website]"  # Official tool URL
# SCRIPT_SUMMARY="[Detailed 3-5 sentence description, 150-500 characters]"  # For tool detail pages
# SCRIPT_RELATED="[related-id-1] [related-id-2]"  # Space-separated related tool IDs

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Configure [setting] interactively||false|"
    "Action|--show|Display current configuration||false|"
    "Action|--verify|Restore from .devcontainer.secrets||false|"
    "Info|--help|Show help information||false|"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source logging library for automatic logging to /tmp/devcontainer-install/
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration file paths
CONFIG_FILE="$HOME/.your-config-file"
# Add other files as needed

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
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

#------------------------------------------------------------------------------
# CONFIGURATION FUNCTIONS
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# VERIFY FUNCTION - For non-interactive restoration from .devcontainer.secrets
#------------------------------------------------------------------------------
# This function is called with --verify flag by project-installs.sh
# It should restore configuration from .devcontainer.secrets without user interaction
#
verify_your_config() {
    # Path to config in .devcontainer.secrets (persists across rebuilds)
    local TOPSECRET_PATH="/workspace/.devcontainer.secrets/your-config-file"

    # Path where config should be restored (typically in home directory)
    local HOME_CONFIG_PATH="$HOME/.your-config-file"

    # Optional: Ensure bashrc loads environment variables (for configs with env vars)
    # This ensures variables are automatically loaded in new terminals after rebuild
    # Only needed if your config exports environment variables that should be available in shells
    #
    # local BASHRC_FILE="$HOME/.bashrc"
    # if [ -f "$BASHRC_FILE" ] && ! grep -q "your-config-file" "$BASHRC_FILE" 2>/dev/null; then
    #     cat >> "$BASHRC_FILE" <<'EOF'
    #
    # # Your configuration - managed by config-your-name.sh
    # [ -f ~/.your-config-file ] && source ~/.your-config-file
    # EOF
    # fi

    # Check if configuration exists in .devcontainer.secrets
    if [ -f "$TOPSECRET_PATH" ]; then
        # Restore configuration (symlink recommended for live updates)
        ln -sf "$TOPSECRET_PATH" "$HOME_CONFIG_PATH"

        # Optional: Restore additional files if needed
        # if [ -f "/workspace/.devcontainer.secrets/your-other-file" ]; then
        #     ln -sf "/workspace/.devcontainer.secrets/your-other-file" "$HOME/.your-other-file"
        # fi

        # Success message (keep minimal)
        echo "✅ Your configuration restored"
        return 0
    fi

    # Configuration not found in .devcontainer.secrets (silent failure)
    return 1
}

#------------------------------------------------------------------------------
# INTERACTIVE CONFIGURATION FUNCTIONS
#------------------------------------------------------------------------------

check_if_already_configured() {
    # Check if configuration already exists
    if eval "$SCRIPT_CHECK_COMMAND"; then
        echo ""
        log_warn "Configuration already exists!"
        echo ""
        echo "Current configuration:"
        # Display current configuration values
        # Example:
        # echo "   Setting 1: $(get_config_value 'setting1')"
        # echo "   Setting 2: $(get_config_value 'setting2')"
        echo ""
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            log_info "Keeping existing configuration"
            exit 0
        fi
        echo ""
        log_info "Reconfiguring..."
    fi
}

prompt_for_configuration() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Configuration Input"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Prompt for configuration values
    # Example:
    # read -p "Enter setting name: " SETTING_NAME
    # read -p "Enter value: " SETTING_VALUE
    # read -s -p "Enter password (hidden): " PASSWORD
    # echo ""

    # Validate inputs
    # if [ -z "$SETTING_NAME" ]; then
    #     log_error "Setting name is required"
    #     exit 1
    # fi
}

validate_configuration() {
    log_info "Validating configuration..."

    # Add validation logic
    # Examples:
    # - Check for required fields
    # - Validate format (email, URL, etc.)
    # - Test connectivity if applicable
    # - Verify credentials if applicable

    # if ! validate_format "$EMAIL"; then
    #     log_error "Invalid email format"
    #     exit 1
    # fi

    log_success "Configuration validated"
}

show_configuration_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Configuration Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Display configuration summary (without sensitive data)
    # Example:
    # echo "   Setting 1:    ${SETTING_1}"
    # echo "   Setting 2:    ${SETTING_2}"
    # echo "   Password:     ********"

    echo ""
    read -p "Does this look correct? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_warn "Configuration cancelled"
        echo "Please run the script again to reconfigure."
        exit 1
    fi
}

write_configuration() {
    log_info "Writing configuration..."

    # IMPORTANT: Save to .devcontainer.secrets folder for persistence across rebuilds
    # Then create symlink from home directory to .devcontainer.secrets
    #
    # Example:
    # TOPSECRET_CONFIG="/workspace/.devcontainer.secrets/your-config-file"
    # cat > "$TOPSECRET_CONFIG" <<EOF
    # SETTING_1="${SETTING_1}"
    # SETTING_2="${SETTING_2}"
    # EOF
    #
    # # Set permissions on .devcontainer.secrets file
    # chmod 600 "$TOPSECRET_CONFIG"  # For sensitive files
    # chmod 644 "$TOPSECRET_CONFIG"  # For non-sensitive files
    #
    # # Create symlink from home to .devcontainer.secrets (this is what gets checked)
    # ln -sf "$TOPSECRET_CONFIG" "$CONFIG_FILE"
    #
    # This way:
    #   - Original file in /workspace/.devcontainer.secrets/ (persists across rebuilds)
    #   - Symlink in $HOME/.config-file (used by applications)
    #   - verify_your_config() can restore the symlink on rebuild

    log_success "Configuration saved: $CONFIG_FILE"
}

update_shell_environment() {
    # Optional: Add configuration to shell profile
    # This section is only needed if configuration should be loaded in every shell

    log_info "Updating shell environment..."

    # Example: Add source line to .bashrc
    # local BASHRC_FILE="$HOME/.bashrc"
    # if grep -q "your-config-file" "$BASHRC_FILE" 2>/dev/null; then
    #     log_info ".bashrc already configured (skipping)"
    #     return 0
    # fi
    #
    # cat >> "$BASHRC_FILE" <<'EOF'
    #
    # # Your configuration - managed by config-your-name.sh
    # [ -f ~/.your-config-file ] && source ~/.your-config-file
    # EOF

    log_success "Shell environment updated"
}

run_post_configuration_tasks() {
    # Optional: Run any post-configuration tasks
    # Examples:
    # - Test the configuration
    # - Initialize related services
    # - Create additional required files/directories

    log_info "Running post-configuration tasks..."

    # Add your post-configuration logic here

    log_success "Post-configuration tasks complete"
}

show_completion_message() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 Configuration Complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "Your configuration has been saved"
    echo ""

    # Add specific completion messages
    # Example:
    # echo "📝 Important Notes:"
    # echo ""
    # echo "• Configuration file: $CONFIG_FILE"
    # echo "• To verify your configuration:"
    # echo "  [command to verify]"
    # echo ""
    # echo "• To update your configuration, run this script again"
    # echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_success "You can now use your configured settings!"
    echo ""
}

#------------------------------------------------------------------------------
# --VERIFY FLAG HANDLER
#------------------------------------------------------------------------------
# This must be placed BEFORE main() function
# When called with --verify, restore from .devcontainer.secrets and exit
#
if [ "${1:-}" = "--verify" ]; then
    verify_your_config
    exit $?
fi

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 $SCRIPT_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "$SCRIPT_DESCRIPTION"
    echo "Script version: $SCRIPT_VER"
    echo ""

    # Check if already configured
    check_if_already_configured

    # Prompt for configuration values
    prompt_for_configuration

    # Validate the configuration
    validate_configuration

    # Show summary and confirm
    show_configuration_summary

    # Write configuration to file
    write_configuration

    # Update shell environment (optional)
    # update_shell_environment

    # Run post-configuration tasks (optional)
    # run_post_configuration_tasks

    # Show completion message
    show_completion_message
}

# Run main function
main "$@"
