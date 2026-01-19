#!/bin/bash
#
# utilities.sh - Reusable utility functions for cmd-*.sh scripts
#
# Purpose:
#   Provides common utility functions for:
#   - Date range calculations (cross-platform Linux/macOS)
#   - Number formatting (currency, thousands separators)
#   - Other generic helpers
#
# Usage:
#   source "${SCRIPT_DIR}/lib/utilities.sh"
#
#   # Calculate date ranges
#   read start_date end_date <<< $(get_date_range "month")
#   read start_date end_date <<< $(get_date_range "week")
#
#   # Format numbers
#   echo "Cost: $(format_currency 12.50)"      # Output: $12.50
#   echo "Count: $(format_number 1234567)"     # Output: 1,234,567
#
# Author: DevContainer Toolbox Team
# Date: 2025-11-26
#

set -euo pipefail

#------------------------------------------------------------------------------
# Calculate date ranges
#
# Usage: get_date_range <range_type>
#
# Arguments:
#   range_type - One of: month, week, 30days, today
#
# Returns: Two space-separated dates in YYYY-MM-DD format via stdout
#   start_date end_date
#
# Examples:
#   # Current month (1st to today)
#   read start end <<< $(get_date_range "month")
#
#   # Last 7 days
#   read start end <<< $(get_date_range "week")
#
#   # Last 30 days
#   read start end <<< $(get_date_range "30days")
#
#   # Today only
#   read start end <<< $(get_date_range "today")
#
# Notes:
#   - Works on both Linux (date -d) and macOS (date -v)
#   - All dates are in UTC
#   - Returns 1 on unknown range type
#
#------------------------------------------------------------------------------
get_date_range() {
    local range="$1"
    local start_date=""
    local end_date=""

    end_date=$(date -u +%Y-%m-%d)

    case "$range" in
        month)
            # Current month (from 1st to today)
            start_date=$(date -u +%Y-%m-01)
            ;;
        week)
            # Last 7 days
            start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d)
            ;;
        30days)
            # Last 30 days
            start_date=$(date -u -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-30d +%Y-%m-%d)
            ;;
        today)
            # Today only
            start_date="$end_date"
            ;;
        *)
            echo "ERROR: Unknown date range: $range" >&2
            echo "Valid values: month, week, 30days, today" >&2
            return 1
            ;;
    esac

    echo "${start_date} ${end_date}"
}

#------------------------------------------------------------------------------
# Format amount as currency
#
# Usage: format_currency <amount>
#
# Arguments:
#   amount - Numeric value (integer or decimal)
#
# Returns: Formatted string with dollar sign and 2 decimal places
#
# Examples:
#   format_currency 12.5      # Output: $12.50
#   format_currency 1234.567  # Output: $1234.57
#   format_currency 0         # Output: $0.00
#
#------------------------------------------------------------------------------
format_currency() {
    local amount="$1"
    printf "\$%.2f" "$amount"
}

#------------------------------------------------------------------------------
# Format number with thousand separators
#
# Usage: format_number <number>
#
# Arguments:
#   number - Integer value
#
# Returns: Formatted string with comma separators
#
# Examples:
#   format_number 1234567     # Output: 1,234,567
#   format_number 1000        # Output: 1,000
#   format_number 999         # Output: 999
#
# Notes:
#   - Falls back to raw number if printf %'d not supported
#   - Works on most Linux/macOS systems
#
#------------------------------------------------------------------------------
format_number() {
    local num="$1"
    printf "%'d" "$num" 2>/dev/null || echo "$num"
}

#------------------------------------------------------------------------------
# Library version info
#------------------------------------------------------------------------------

UTILITIES_VERSION="1.0.0"
UTILITIES_LOADED=1
