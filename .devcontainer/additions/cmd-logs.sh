#!/bin/bash
# file: .devcontainer/additions/cmd-logs.sh
#
# Usage:
#   cmd-logs.sh --status           # Show log sizes and status
#   cmd-logs.sh --clean            # Clean logs based on rules
#   cmd-logs.sh --clean --dry-run  # Preview what would be cleaned
#   cmd-logs.sh --tail <source>    # Tail logs from a source
#   cmd-logs.sh --scheduled        # Run cleanup on 24h schedule (for supervisor)
#   cmd-logs.sh --help             # Show all commands
#
# Purpose:
#   Centralized log management for devcontainer - view, monitor, and clean logs
#   from all sources (OTEL, nginx, supervisor, install/setup scripts)
#
# Author: Terje Christensen
# Created: December 2024
#
#------------------------------------------------------------------------------
# SCRIPT METADATA - For dev-setup.sh discovery
#------------------------------------------------------------------------------

SCRIPT_ID="cmd-logs"
SCRIPT_NAME="Log Management"
SCRIPT_VER="1.0.0"
SCRIPT_DESCRIPTION="View, monitor, and clean devcontainer logs"
SCRIPT_CATEGORY="INFRA_CONFIG"
SCRIPT_PREREQUISITES=""

#------------------------------------------------------------------------------
# LOG CLEANUP CONFIGURATION
# Edit these arrays to add/remove log locations
#------------------------------------------------------------------------------

# Logs to truncate when over max size (keeps file, clears content)
# Format: "path:max_size_mb"
# Supports glob patterns
TRUNCATE_LOGS=(
    "/var/log/otelcol-metrics.log:10"
    "/var/log/otelcol-lifecycle.log:10"
    "/var/log/nginx/error.log:10"
    "/var/log/nginx/*-error.log:5"
    "/var/log/nginx/*-access.log:5"
    "/var/log/script-exporter.log:5"
)

# Directories to clean old files from
# Format: "path:max_age_days"
CLEAN_DIRS=(
    "/tmp/devcontainer-install:7"
    "/tmp/devcontainer-setup:7"
    "/tmp/devcontainer-tests:3"
)

# Supervisor logs (handled by supervisor rotation, but can force clean)
# Format: "path:max_size_mb"
SUPERVISOR_LOGS=(
    "/var/log/supervisor/*.log:10"
)

#------------------------------------------------------------------------------
# SCRIPT_COMMANDS DEFINITIONS - Single source of truth
#------------------------------------------------------------------------------

# Format: category|flag|description|function|requires_arg|param_prompt
SCRIPT_COMMANDS=(
    "Information|--status|Show log sizes and status|cmd_status|false|"
    "Cleanup|--clean|Clean logs based on configured rules|cmd_clean|false|"
    "Cleanup|--clean-dry|Preview what would be cleaned (dry run)|cmd_clean_dry|false|"
    "Monitoring|--tail|Tail logs from a source|cmd_tail|true|Source (otel/nginx/supervisor/install/setup)"
    "Scheduler|--scheduled|Run cleanup on 24h schedule|cmd_scheduled|false|"
)

#------------------------------------------------------------------------------

set -euo pipefail

# Source libraries
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

# Convert bytes to human readable format (pure bash, no bc dependency)
human_readable_size() {
    local bytes="$1"
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        local kb=$((bytes * 10 / 1024))
        echo "$((kb / 10)).$((kb % 10)) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        local mb=$((bytes * 10 / 1048576))
        echo "$((mb / 10)).$((mb % 10)) MB"
    else
        local gb=$((bytes * 100 / 1073741824))
        echo "$((gb / 100)).$((gb % 100)) GB"
    fi
}

# Get file size in bytes (handles missing files)
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c%s "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get directory size and file count
get_dir_info() {
    local dir="$1"
    if [ -d "$dir" ]; then
        local size count oldest
        size=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo "0")
        count=$(find "$dir" -type f 2>/dev/null | wc -l || echo "0")
        if [ "$count" -gt 0 ]; then
            oldest=$(find "$dir" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f1 | cut -d'T' -f1 || echo "unknown")
        else
            oldest="n/a"
        fi
        echo "$size $count $oldest"
    else
        echo "0 0 n/a"
    fi
}

# Expand glob pattern and return matching files
expand_glob() {
    local pattern="$1"
    # Use compgen to expand glob, returns empty if no matches
    compgen -G "$pattern" 2>/dev/null || true
}

#------------------------------------------------------------------------------
# Command Functions - Information
#------------------------------------------------------------------------------

cmd_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Log Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local total_bytes=0

    # OTEL Logs
    echo "🔭 OTEL Logs:"
    for entry in "${TRUNCATE_LOGS[@]}"; do
        local pattern="${entry%%:*}"
        if [[ "$pattern" == /var/log/otelcol* ]]; then
            local files
            files=$(expand_glob "$pattern")
            if [ -n "$files" ]; then
                while IFS= read -r file; do
                    local size
                    size=$(get_file_size "$file")
                    total_bytes=$((total_bytes + size))
                    printf "   %-40s %s\n" "$(basename "$file")" "$(human_readable_size "$size")"
                done <<< "$files"
            fi
        fi
    done
    echo ""

    # Nginx Logs
    echo "🌐 Nginx Logs:"
    if [ -d "/var/log/nginx" ]; then
        local nginx_total=0
        local nginx_count=0
        for file in /var/log/nginx/*.log; do
            if [ -f "$file" ]; then
                local size
                size=$(get_file_size "$file")
                nginx_total=$((nginx_total + size))
                nginx_count=$((nginx_count + 1))
            fi
        done
        total_bytes=$((total_bytes + nginx_total))
        printf "   %-40s %s (%d files)\n" "/var/log/nginx/" "$(human_readable_size "$nginx_total")" "$nginx_count"
    else
        echo "   (directory not found)"
    fi
    echo ""

    # Supervisor Logs
    echo "📋 Supervisor Logs:"
    if [ -d "/var/log/supervisor" ]; then
        local sup_total=0
        local sup_count=0
        for file in /var/log/supervisor/*.log; do
            if [ -f "$file" ]; then
                local size
                size=$(get_file_size "$file")
                sup_total=$((sup_total + size))
                sup_count=$((sup_count + 1))
            fi
        done
        total_bytes=$((total_bytes + sup_total))
        printf "   %-40s %s (%d files)\n" "/var/log/supervisor/" "$(human_readable_size "$sup_total")" "$sup_count"
    else
        echo "   (directory not found)"
    fi
    echo ""

    # Temp Install/Setup Logs
    echo "📁 Temporary Logs:"
    for entry in "${CLEAN_DIRS[@]}"; do
        local dir="${entry%%:*}"
        local max_days="${entry##*:}"
        if [ -d "$dir" ]; then
            read -r size count oldest <<< "$(get_dir_info "$dir")"
            total_bytes=$((total_bytes + size))
            printf "   %-40s %s (%d files, oldest: %s)\n" "$dir/" "$(human_readable_size "$size")" "$count" "$oldest"
        else
            printf "   %-40s %s\n" "$dir/" "(not found)"
        fi
    done
    echo ""

    # Other logs
    echo "📝 Other Logs:"
    local other_logs=("/var/log/script-exporter.log")
    for file in "${other_logs[@]}"; do
        if [ -f "$file" ]; then
            local size
            size=$(get_file_size "$file")
            total_bytes=$((total_bytes + size))
            printf "   %-40s %s\n" "$(basename "$file")" "$(human_readable_size "$size")"
        fi
    done
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "📦 Total: %s\n" "$(human_readable_size "$total_bytes")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#------------------------------------------------------------------------------
# Command Functions - Cleanup
#------------------------------------------------------------------------------

do_clean() {
    local dry_run="${1:-false}"
    local freed_bytes=0
    local action_verb="Cleaning"
    local result_verb="Freed"

    if [ "$dry_run" = "true" ]; then
        action_verb="Would clean"
        result_verb="Would free"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$dry_run" = "true" ]; then
        echo "🔍 Dry Run - Preview of cleanup"
    else
        echo "🧹 Cleaning logs..."
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Truncate large log files
    echo "📄 Truncating large files:"
    for entry in "${TRUNCATE_LOGS[@]}"; do
        local pattern="${entry%%:*}"
        local max_mb="${entry##*:}"
        local max_bytes=$((max_mb * 1024 * 1024))

        local files
        files=$(expand_glob "$pattern")
        if [ -n "$files" ]; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local size
                    size=$(get_file_size "$file")
                    if [ "$size" -gt "$max_bytes" ]; then
                        freed_bytes=$((freed_bytes + size))
                        if [ "$dry_run" = "true" ]; then
                            printf "   Would truncate: %-30s (was %s, limit %sMB)\n" "$(basename "$file")" "$(human_readable_size "$size")" "$max_mb"
                        else
                            sudo truncate -s 0 "$file" 2>/dev/null || true
                            printf "   ✓ Truncated: %-30s (was %s)\n" "$(basename "$file")" "$(human_readable_size "$size")"
                        fi
                    fi
                fi
            done <<< "$files"
        fi
    done

    # Also check supervisor logs
    for entry in "${SUPERVISOR_LOGS[@]}"; do
        local pattern="${entry%%:*}"
        local max_mb="${entry##*:}"
        local max_bytes=$((max_mb * 1024 * 1024))

        local files
        files=$(expand_glob "$pattern")
        if [ -n "$files" ]; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local size
                    size=$(get_file_size "$file")
                    if [ "$size" -gt "$max_bytes" ]; then
                        freed_bytes=$((freed_bytes + size))
                        if [ "$dry_run" = "true" ]; then
                            printf "   Would truncate: %-30s (was %s, limit %sMB)\n" "$(basename "$file")" "$(human_readable_size "$size")" "$max_mb"
                        else
                            sudo truncate -s 0 "$file" 2>/dev/null || true
                            printf "   ✓ Truncated: %-30s (was %s)\n" "$(basename "$file")" "$(human_readable_size "$size")"
                        fi
                    fi
                fi
            done <<< "$files"
        fi
    done
    echo ""

    # Delete old files from temp directories
    echo "📁 Deleting old files:"
    for entry in "${CLEAN_DIRS[@]}"; do
        local dir="${entry%%:*}"
        local max_days="${entry##*:}"

        if [ -d "$dir" ]; then
            local old_files
            old_files=$(find "$dir" -type f -mtime +"$max_days" 2>/dev/null || true)
            if [ -n "$old_files" ]; then
                local count=0
                local dir_freed=0
                while IFS= read -r file; do
                    local size
                    size=$(get_file_size "$file")
                    dir_freed=$((dir_freed + size))
                    count=$((count + 1))
                    if [ "$dry_run" != "true" ]; then
                        rm -f "$file" 2>/dev/null || true
                    fi
                done <<< "$old_files"
                freed_bytes=$((freed_bytes + dir_freed))
                if [ "$dry_run" = "true" ]; then
                    printf "   Would delete from %-25s: %d files older than %d days (%s)\n" "$dir/" "$count" "$max_days" "$(human_readable_size "$dir_freed")"
                else
                    printf "   ✓ Deleted from %-25s: %d files older than %d days (%s)\n" "$dir/" "$count" "$max_days" "$(human_readable_size "$dir_freed")"
                fi
            else
                printf "   - %-35s: no files older than %d days\n" "$dir/" "$max_days"
            fi
        fi
    done
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "💾 %s: %s\n" "$result_verb" "$(human_readable_size "$freed_bytes")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

cmd_clean() {
    do_clean "false"
}

cmd_clean_dry() {
    do_clean "true"
}

#------------------------------------------------------------------------------
# Command Functions - Monitoring
#------------------------------------------------------------------------------

cmd_tail() {
    local source="$1"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Tailing logs: $source"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "(Press Ctrl+C to stop)"
    echo ""

    case "$source" in
        otel|otel-metrics)
            if [ -f "/var/log/otelcol-metrics.log" ]; then
                tail -f /var/log/otelcol-metrics.log
            else
                log_error "OTEL metrics log not found"
                return 1
            fi
            ;;
        otel-lifecycle)
            if [ -f "/var/log/otelcol-lifecycle.log" ]; then
                tail -f /var/log/otelcol-lifecycle.log
            else
                log_error "OTEL lifecycle log not found"
                return 1
            fi
            ;;
        nginx)
            if [ -d "/var/log/nginx" ]; then
                tail -f /var/log/nginx/*.log 2>/dev/null || log_error "No nginx logs found"
            else
                log_error "Nginx log directory not found"
                return 1
            fi
            ;;
        supervisor)
            if [ -d "/var/log/supervisor" ]; then
                tail -f /var/log/supervisor/*.log 2>/dev/null || log_error "No supervisor logs found"
            else
                log_error "Supervisor log directory not found"
                return 1
            fi
            ;;
        install)
            if [ -d "/tmp/devcontainer-install" ]; then
                # Tail the most recent install log
                local latest
                latest=$(ls -t /tmp/devcontainer-install/*.log 2>/dev/null | head -1)
                if [ -n "$latest" ]; then
                    echo "Latest: $latest"
                    echo ""
                    tail -f "$latest"
                else
                    log_error "No install logs found"
                    return 1
                fi
            else
                log_error "Install log directory not found"
                return 1
            fi
            ;;
        setup)
            if [ -d "/tmp/devcontainer-setup" ]; then
                # Tail the most recent setup log
                local latest
                latest=$(ls -t /tmp/devcontainer-setup/*.log 2>/dev/null | head -1)
                if [ -n "$latest" ]; then
                    echo "Latest: $latest"
                    echo ""
                    tail -f "$latest"
                else
                    log_error "No setup logs found"
                    return 1
                fi
            else
                log_error "Setup log directory not found"
                return 1
            fi
            ;;
        *)
            log_error "Unknown source: $source"
            echo ""
            echo "Available sources:"
            echo "  otel, otel-metrics  - OTEL metrics collector log"
            echo "  otel-lifecycle      - OTEL lifecycle collector log"
            echo "  nginx               - All nginx logs"
            echo "  supervisor          - All supervisor logs"
            echo "  install             - Latest install script log"
            echo "  setup               - Latest dev-setup.sh log"
            return 1
            ;;
    esac
}

#------------------------------------------------------------------------------
# Command Functions - Scheduler
#------------------------------------------------------------------------------

cmd_scheduled() {
    log_info "Starting scheduled log cleanup (runs every 24 hours)"
    log_info "Press Ctrl+C to stop"
    echo ""

    while true; do
        echo ""
        echo "════════════════════════════════════════════════════════"
        echo "🕐 $(date '+%Y-%m-%d %H:%M:%S') - Running scheduled cleanup"
        echo "════════════════════════════════════════════════════════"

        do_clean "false"

        echo ""
        log_info "Next cleanup in 24 hours..."
        sleep 86400
    done
}

#------------------------------------------------------------------------------
# Help and Argument Parsing
#------------------------------------------------------------------------------

show_help() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_generate_help >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Generate help from SCRIPT_COMMANDS array
    cmd_framework_generate_help SCRIPT_COMMANDS "cmd-logs.sh" "$SCRIPT_VER"

    # Add examples section
    echo ""
    echo "Tail sources: otel, otel-lifecycle, nginx, supervisor, install, setup"
    echo ""
    echo "Examples:"
    echo "  cmd-logs.sh --status                 # Show all log sizes"
    echo "  cmd-logs.sh --clean-dry              # Preview cleanup"
    echo "  cmd-logs.sh --clean                  # Run cleanup"
    echo "  cmd-logs.sh --tail otel              # Follow OTEL logs"
    echo "  cmd-logs.sh --tail nginx             # Follow nginx logs"
    echo ""
}

parse_args() {
    # Source framework if not already loaded
    if ! declare -f cmd_framework_parse_args >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR}/lib/cmd-framework.sh"
    fi

    # Use framework to parse arguments
    cmd_framework_parse_args SCRIPT_COMMANDS "cmd-logs.sh" "$@"
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    parse_args "$@"
}

main "$@"
