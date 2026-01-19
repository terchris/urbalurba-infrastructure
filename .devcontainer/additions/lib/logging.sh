#!/bin/bash
# File: .devcontainer/additions/lib/logging.sh
# Purpose: Shared logging functions for all install scripts
# Usage: source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------
# LOGGING SETUP
#------------------------------------------------------------------------------

# Auto-setup logging directory
LOG_DIR="${DEVCONTAINER_LOG_DIR:-/tmp/devcontainer-install}"
mkdir -p "$LOG_DIR"

# Create tool-specific log with timestamp
# Use script filename for log (not SCRIPT_NAME which may have spaces/special chars)
LOG_SCRIPT_NAME=$(basename "$0" .sh)  # e.g., "install-dev-golang"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$LOG_DIR/${LOG_SCRIPT_NAME}-${TIMESTAMP}.log"

# Set SCRIPT_NAME only if not already defined (preserve display name from script)
SCRIPT_NAME=${SCRIPT_NAME:-$LOG_SCRIPT_NAME}

# Export for subprocesses
export CURRENT_LOG_FILE="$LOG_FILE"

#------------------------------------------------------------------------------
# REDIRECT ALL OUTPUT
#------------------------------------------------------------------------------

# Redirect all stdout and stderr to both terminal and log file
# This uses exec to redirect the entire script's output
exec > >(tee -a "$LOG_FILE")
exec 2>&1

#------------------------------------------------------------------------------
# LOGGING FUNCTIONS (optional - for structured logging)
#------------------------------------------------------------------------------

log_info() {
    echo "[$(date +%H:%M:%S)] ℹ️  $*" >&2
}

log_success() {
    echo "[$(date +%H:%M:%S)] ✅ $*" >&2
}

log_error() {
    echo "[$(date +%H:%M:%S)] ❌ $*" >&2
}

log_warning() {
    echo "[$(date +%H:%M:%S)] ⚠️  $*" >&2
}

#------------------------------------------------------------------------------
# INITIALIZATION
#------------------------------------------------------------------------------

# Show log location at start
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Logging to: $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
