#!/bin/bash
# File: .devcontainer/additions/lib/supervisor-autostart.sh
# Purpose: Auto-start supervisord on shell initialization if services are enabled
# Usage: Source this file in .bashrc

# Function to start supervisord if not running and services are enabled
start_supervisord_if_needed() {
    local ENABLED_SERVICES_CONF="/workspace/.devcontainer.extend/enabled-services.conf"

    # Check if supervisord is already running
    if pgrep supervisord > /dev/null 2>&1; then
        return 0
    fi

    # Check if there are any enabled services
    if [ ! -f "$ENABLED_SERVICES_CONF" ]; then
        return 0
    fi

    # Count enabled services (skip comments and empty lines)
    local enabled_count=0
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        enabled_count=$((enabled_count + 1))
    done < "$ENABLED_SERVICES_CONF"

    # If no services are enabled, don't start supervisord
    if [ $enabled_count -eq 0 ]; then
        return 0
    fi

    # Start supervisord silently in background
    sudo supervisord -c /etc/supervisor/supervisord.conf > /dev/null 2>&1 &

    # Give it a moment to start
    sleep 1

    # Verify it started
    if pgrep supervisord > /dev/null 2>&1; then
        echo "✅ Started supervisord with $enabled_count enabled service(s)"
        echo "   Use 'dev-services status' to see running services"
    fi
}

# Only run on interactive shells to avoid breaking scripts
if [[ $- == *i* ]]; then
    start_supervisord_if_needed
fi
