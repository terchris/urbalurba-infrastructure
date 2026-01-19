#!/bin/bash
# File: .devcontainer/additions/lib/git-identity.sh
# Purpose: Library for auto-detecting git repository and developer identity
# Used by: config-git.sh --verify, service-otel-monitoring.sh
#
# This library provides functions to:
# - Parse git remote URLs (GitHub, Azure DevOps, generic)
# - Detect developer email from git config or fallback
# - Calculate TS_HOSTNAME with hash for uniqueness
# - Export all values to .git-identity file

#------------------------------------------------------------------------------
# GIT URL PARSING
#------------------------------------------------------------------------------

# Parse a git remote URL and export GIT_PROVIDER, GIT_ORG, GIT_PROJECT, GIT_REPO
# Supports:
#   - GitHub: https://github.com/org/repo.git or git@github.com:org/repo.git
#   - Azure DevOps: https://dev.azure.com/org/project/_git/repo
#                   git@ssh.dev.azure.com:v3/org/project/repo
#   - Generic: Falls back to extracting last path component
#
# Usage: parse_git_remote_url "https://github.com/terchris/devcontainer-toolbox.git"
# After: GIT_PROVIDER="github", GIT_ORG="terchris", GIT_REPO="devcontainer-toolbox"
#
parse_git_remote_url() {
    local url="$1"

    # Reset values
    export GIT_PROVIDER=""
    export GIT_ORG=""
    export GIT_PROJECT=""
    export GIT_REPO=""
    export GIT_REPO_FULL=""

    if [ -z "$url" ]; then
        return 1
    fi

    # GitHub HTTPS: https://github.com/org/repo.git
    if [[ "$url" =~ github\.com[/:]([^/]+)/([^/]+)(\.git)?$ ]]; then
        GIT_PROVIDER="github"
        GIT_ORG="${BASH_REMATCH[1]}"
        GIT_REPO="${BASH_REMATCH[2]%.git}"
        GIT_REPO_FULL="${GIT_ORG}/${GIT_REPO}"
        return 0
    fi

    # GitHub SSH: git@github.com:org/repo.git
    if [[ "$url" =~ git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        GIT_PROVIDER="github"
        GIT_ORG="${BASH_REMATCH[1]}"
        GIT_REPO="${BASH_REMATCH[2]%.git}"
        GIT_REPO_FULL="${GIT_ORG}/${GIT_REPO}"
        return 0
    fi

    # Azure DevOps HTTPS: https://dev.azure.com/org/project/_git/repo
    if [[ "$url" =~ dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)(\.git)?$ ]]; then
        GIT_PROVIDER="azure-devops"
        GIT_ORG="${BASH_REMATCH[1]}"
        GIT_PROJECT="${BASH_REMATCH[2]}"
        GIT_REPO="${BASH_REMATCH[3]%.git}"
        GIT_REPO_FULL="${GIT_ORG}/${GIT_PROJECT}/${GIT_REPO}"
        return 0
    fi

    # Azure DevOps SSH: git@ssh.dev.azure.com:v3/org/project/repo
    if [[ "$url" =~ ssh\.dev\.azure\.com:v3/([^/]+)/([^/]+)/([^/]+)(\.git)?$ ]]; then
        GIT_PROVIDER="azure-devops"
        GIT_ORG="${BASH_REMATCH[1]}"
        GIT_PROJECT="${BASH_REMATCH[2]}"
        GIT_REPO="${BASH_REMATCH[3]%.git}"
        GIT_REPO_FULL="${GIT_ORG}/${GIT_PROJECT}/${GIT_REPO}"
        return 0
    fi

    # Azure DevOps old format: https://org@dev.azure.com/org/project/_git/repo
    if [[ "$url" =~ @dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)(\.git)?$ ]]; then
        GIT_PROVIDER="azure-devops"
        GIT_ORG="${BASH_REMATCH[1]}"
        GIT_PROJECT="${BASH_REMATCH[2]}"
        GIT_REPO="${BASH_REMATCH[3]%.git}"
        GIT_REPO_FULL="${GIT_ORG}/${GIT_PROJECT}/${GIT_REPO}"
        return 0
    fi

    # Generic fallback: extract repo name from last path component
    GIT_PROVIDER="unknown"
    GIT_REPO=$(basename "$url" .git)
    GIT_REPO_FULL="$GIT_REPO"
    return 0
}

#------------------------------------------------------------------------------
# DEVELOPER EMAIL DETECTION
#------------------------------------------------------------------------------

# Detect developer email with fallbacks
# Priority:
#   1. Existing GIT_USER_EMAIL environment variable
#   2. .git-identity file
#   3. git config --global user.email
#   4. HOST_USER@localhost
#
# Usage: detect_git_user_email
# After: GIT_USER_EMAIL is set
#
detect_git_user_email() {
    local identity_file="/workspace/.devcontainer.secrets/env-vars/.git-identity"

    # Priority 1: Already set in environment
    if [ -n "${GIT_USER_EMAIL:-}" ]; then
        return 0
    fi

    # Priority 2: Load from .git-identity file
    if [ -f "$identity_file" ]; then
        # shellcheck source=/dev/null
        source "$identity_file" 2>/dev/null
        if [ -n "${GIT_USER_EMAIL:-}" ]; then
            return 0
        fi
    fi

    # Priority 3: Git config
    local git_email
    git_email=$(git config --global user.email 2>/dev/null || echo "")
    if [ -n "$git_email" ]; then
        export GIT_USER_EMAIL="$git_email"
        return 0
    fi

    # Priority 4: Fallback to HOST_USER@localhost
    local host_user="${HOST_USER:-$(whoami)}"
    export GIT_USER_EMAIL="${host_user}@localhost"
    return 0
}

#------------------------------------------------------------------------------
# TS_HOSTNAME CALCULATION
#------------------------------------------------------------------------------

# Calculate TS_HOSTNAME from email and host hostname
# Format: dev-{sanitized-email}-{sanitized-hostname}
# Max length: 63 characters (DNS hostname limit)
#
# With shared Tailscale container, the hostname identifies the developer+machine
# (not the repo). This allows multiple repos to share one Tailscale connection.
#
# Usage: calculate_ts_hostname "terje@christensen.no" "NRX-PF5FWHPC"
# Returns: dev-terje-christensen-no-nrx-pf5fwhpc
#
calculate_ts_hostname() {
    local email="${1:-}"
    local host_hostname="${2:-}"

    # Sanitize email: @ -> -, . -> -, lowercase, remove invalid chars
    local email_sanitized
    email_sanitized=$(echo "$email" | sed 's/@/-/g' | sed 's/\./-/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

    # Truncate email to reasonable length (max 30 chars)
    email_sanitized="${email_sanitized:0:30}"

    # Sanitize hostname: lowercase, remove invalid chars
    local hostname_sanitized
    hostname_sanitized=$(echo "$host_hostname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')

    # Truncate hostname (max 25 chars)
    hostname_sanitized="${hostname_sanitized:0:25}"

    # Construct Tailscale hostname
    local ts_hostname="dev-${email_sanitized}-${hostname_sanitized}"

    # Remove any double hyphens
    ts_hostname=$(echo "$ts_hostname" | sed 's/--*/-/g')

    # Ensure max 63 chars (DNS limit)
    ts_hostname="${ts_hostname:0:63}"

    # Remove trailing hyphens
    ts_hostname="${ts_hostname%-}"

    echo "$ts_hostname"
}

#------------------------------------------------------------------------------
# MAIN DETECTION FUNCTION
#------------------------------------------------------------------------------

# Detect all git identity information and export to environment
# Exports:
#   GIT_USER_EMAIL, GIT_USER_NAME
#   GIT_PROVIDER, GIT_ORG, GIT_PROJECT, GIT_REPO, GIT_REPO_FULL
#   GIT_BRANCH
#   TS_HOSTNAME (calculated)
#
# Usage: detect_git_identity
#
detect_git_identity() {
    local workspace_dir="${1:-/workspace}"

    # Change to workspace if needed
    if [ -d "$workspace_dir" ]; then
        cd "$workspace_dir" || return 1
    fi

    # Detect email
    detect_git_user_email

    # Detect name from git config
    export GIT_USER_NAME
    GIT_USER_NAME=$(git config --global user.name 2>/dev/null || echo "Developer")

    # Detect remote URL and parse it
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")

    if [ -n "$remote_url" ]; then
        parse_git_remote_url "$remote_url"
    else
        # Fallback: use folder name as repo
        export GIT_PROVIDER="local"
        export GIT_ORG=""
        export GIT_PROJECT=""
        export GIT_REPO
        GIT_REPO=$(basename "$workspace_dir")
        export GIT_REPO_FULL="$GIT_REPO"
    fi

    # Detect current branch
    export GIT_BRANCH
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    # Calculate TS_HOSTNAME using email and host hostname
    # HOST_HOSTNAME comes from config-host-info.sh (sourced via .host-info)
    # Fallback to "devcontainer" if not set
    local host_hostname="${HOST_HOSTNAME:-devcontainer}"

    # If .host-info exists and HOST_HOSTNAME not set, try to source it
    if [ -z "$HOST_HOSTNAME" ] && [ -f "/workspace/.devcontainer.secrets/env-vars/.host-info" ]; then
        # shellcheck source=/dev/null
        source "/workspace/.devcontainer.secrets/env-vars/.host-info" 2>/dev/null
        host_hostname="${HOST_HOSTNAME:-devcontainer}"
    fi

    export TS_HOSTNAME
    TS_HOSTNAME=$(calculate_ts_hostname "$GIT_USER_EMAIL" "$host_hostname")
}

#------------------------------------------------------------------------------
# SAVE TO FILE
#------------------------------------------------------------------------------

# Save all git identity variables to .git-identity file
# This file is sourced by service-otel-monitoring.sh
#
# Usage: save_git_identity_to_file
#
save_git_identity_to_file() {
    local identity_dir="/workspace/.devcontainer.secrets/env-vars"
    local identity_file="$identity_dir/.git-identity"

    # Ensure directory exists
    mkdir -p "$identity_dir"

    # Write all variables
    cat > "$identity_file" <<EOF
# Git identity - managed by config-git.sh --verify
# This file is auto-generated and persists across container rebuilds
# Last updated: $(date -Iseconds)

# Developer identity
export GIT_USER_NAME="${GIT_USER_NAME:-}"
export GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

# Git repository info
export GIT_PROVIDER="${GIT_PROVIDER:-}"
export GIT_ORG="${GIT_ORG:-}"
export GIT_PROJECT="${GIT_PROJECT:-}"
export GIT_REPO="${GIT_REPO:-}"
export GIT_REPO_FULL="${GIT_REPO_FULL:-}"
export GIT_BRANCH="${GIT_BRANCH:-}"

# Calculated values
export TS_HOSTNAME="${TS_HOSTNAME:-}"

# Legacy compatibility (maps to new values)
export DEVELOPER_ID="${GIT_USER_EMAIL:-}"
export DEVELOPER_EMAIL="${GIT_USER_EMAIL:-}"
export PROJECT_NAME="${GIT_REPO:-}"
EOF

    # Set permissions
    chmod 600 "$identity_file"

    return 0
}

#------------------------------------------------------------------------------
# DISPLAY FUNCTION
#------------------------------------------------------------------------------

# Display current git identity (for debugging)
#
show_git_identity() {
    echo "Git Identity:"
    echo "  GIT_USER_NAME:  ${GIT_USER_NAME:-<not set>}"
    echo "  GIT_USER_EMAIL: ${GIT_USER_EMAIL:-<not set>}"
    echo ""
    echo "Repository:"
    echo "  GIT_PROVIDER:   ${GIT_PROVIDER:-<not set>}"
    echo "  GIT_ORG:        ${GIT_ORG:-<not set>}"
    echo "  GIT_PROJECT:    ${GIT_PROJECT:-<not set>}"
    echo "  GIT_REPO:       ${GIT_REPO:-<not set>}"
    echo "  GIT_REPO_FULL:  ${GIT_REPO_FULL:-<not set>}"
    echo "  GIT_BRANCH:     ${GIT_BRANCH:-<not set>}"
    echo ""
    echo "Calculated:"
    echo "  TS_HOSTNAME:    ${TS_HOSTNAME:-<not set>}"
}
