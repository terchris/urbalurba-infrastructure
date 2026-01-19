#!/bin/bash
# File: .devcontainer/additions/lib/display-utils.sh
# Purpose: Shared library for display formatting and box drawing
# Used by: postCreateCommand.sh, dev-setup.sh, dev-env.sh
#
# This library provides common functions for consistent visual formatting across
# all devcontainer management scripts.
#
# Functions:
#   draw_line()          - Draw horizontal separator line
#   draw_heavy_line()    - Draw heavy separator line
#   draw_box_top()       - Draw box top border
#   draw_box_title()     - Draw box with title
#   draw_box_bottom()    - Draw box bottom border
#   draw_title_bar()     - Draw centered title with separator
#   format_status()      - Format status with emoji
#   draw_summary_line()  - Draw summary separator line

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Default widths for different output contexts
# dev-env.sh uses 67 chars (wider for detailed info)
# postCreateCommand.sh uses 61 chars (narrower for terminal output)
# dev-setup.sh uses dialog (no box drawing needed)

# Box drawing characters
readonly BOX_H="─"        # Horizontal line
readonly BOX_V="│"        # Vertical line
readonly BOX_TL="┌"       # Top-left corner
readonly BOX_TR="┐"       # Top-right corner
readonly BOX_BL="└"       # Bottom-left corner
readonly BOX_BR="┘"       # Bottom-right corner
readonly HEAVY_H="═"      # Heavy horizontal line
readonly LINE_H="━"       # Line horizontal

#------------------------------------------------------------------------------
# Line Drawing Functions
#------------------------------------------------------------------------------

# Draw horizontal line separator
#
# Parameters:
#   $1 - width: Width of the line (default: 61)
#   $2 - char: Character to use (default: ━)
#
# Output:
#   Prints line to stdout
#
draw_line() {
    local width="${1:-61}"
    local char="${2:-━}"

    if [ "$width" -eq 61 ] && [ "$char" = "━" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    elif [ "$width" -eq 67 ] && [ "$char" = "━" ]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    elif [ "$char" = "─" ]; then
        # Regular horizontal line for summary
        if [ "$width" -eq 61 ]; then
            echo "─────────────────────────────────────────────────────────────"
        elif [ "$width" -eq 67 ]; then
            echo "─────────────────────────────────────────────────────────────────"
        else
            # Fallback - build the string with sed
            local line=$(printf "%-${width}s" "" | sed 's/ /─/g')
            echo "$line"
        fi
    else
        # Fallback for custom character - build with sed
        local line=$(printf "%-${width}s" "" | sed "s/ /${char}/g")
        echo "$line"
    fi
}

# Draw heavy horizontal line separator (for major sections)
#
# Parameters:
#   $1 - width: Width of the line (default: 67)
#
# Output:
#   Prints heavy line to stdout
#
draw_heavy_line() {
    local width="${1:-67}"
    if [ "$width" -eq 67 ]; then
        echo "═══════════════════════════════════════════════════════════════════"
    elif [ "$width" -eq 61 ]; then
        echo "═══════════════════════════════════════════════════════════"
    else
        # Fallback for custom widths - build the string
        local line=$(printf "%-${width}s" "" | sed 's/ /═/g')
        echo "$line"
    fi
}

#------------------------------------------------------------------------------
# Box Drawing Functions
#------------------------------------------------------------------------------

# Draw box top border
#
# Parameters:
#   $1 - width: Width of the box (default: 67)
#
# Output:
#   Prints: ┌─────────...─────┐
#
draw_box_top() {
    local width="${1:-67}"
    if [ "$width" -eq 67 ]; then
        echo "┌─────────────────────────────────────────────────────────────────┐"
    elif [ "$width" -eq 61 ]; then
        echo "┌─────────────────────────────────────────────────────────────┐"
    else
        # Fallback for custom widths - build the string
        local inner_width=$((width - 2))
        local line=$(printf "%-${inner_width}s" "" | sed 's/ /─/g')
        echo "┌${line}┐"
    fi
}

# Draw box bottom border
#
# Parameters:
#   $1 - width: Width of the box (default: 67)
#
# Output:
#   Prints: └─────────...─────┘
#
draw_box_bottom() {
    local width="${1:-67}"
    if [ "$width" -eq 67 ]; then
        echo "└─────────────────────────────────────────────────────────────────┘"
    elif [ "$width" -eq 61 ]; then
        echo "└─────────────────────────────────────────────────────────────┘"
    else
        # Fallback for custom widths - build the string
        local inner_width=$((width - 2))
        local line=$(printf "%-${inner_width}s" "" | sed 's/ /─/g')
        echo "└${line}┘"
    fi
}

# Draw box with left-aligned title
#
# Parameters:
#   $1 - title: Title text
#   $2 - width: Width of the box (default: 67)
#
# Output:
#   Prints:
#   ┌─────────────────────────────────────┐
#   │ TITLE TEXT                          │
#   └─────────────────────────────────────┘
#
draw_box_title() {
    local title="$1"
    local width="${2:-67}"
    local inner_width=$((width - 2))

    # Top border
    draw_box_top "$width"

    # Title line with padding
    local title_len=${#title}
    local padding=$((inner_width - title_len - 1))
    printf "%s %s%*s%s\n" "$BOX_V" "$title" "$padding" "" "$BOX_V"

    # Bottom border
    draw_box_bottom "$width"
}

# Draw box with content lines
#
# Parameters:
#   $1 - title: Title text
#   $2 - width: Width of the box (default: 67)
#   $@ - content_lines: Content lines to display in box
#
# Output:
#   Prints:
#   ┌─────────────────────────────────────┐
#   │ TITLE TEXT                          │
#   ├─────────────────────────────────────┤
#   │ Content line 1                      │
#   │ Content line 2                      │
#   └─────────────────────────────────────┘
#
# Usage:
#   draw_box_with_content "My Title" 50 "Line 1" "Line 2" "Line 3"
#
draw_box_with_content() {
    local title="$1"
    local width="${2:-67}"
    shift 2
    local content_lines=("$@")

    local inner_width=$((width - 2))

    # Top border
    draw_box_top "$width"

    # Title line
    local title_len=${#title}
    local padding=$((inner_width - title_len - 1))
    printf "%s %s%*s%s\n" "$BOX_V" "$title" "$padding" "" "$BOX_V"

    # Middle separator (optional, for styled boxes)
    # printf "%s%*s%s\n" "├" "$inner_width" | tr ' ' "$BOX_H" | sed "s/$/┤/"

    # Content lines
    for line in "${content_lines[@]}"; do
        local line_len=${#line}
        local padding=$((inner_width - line_len))
        printf "%s%s%*s%s\n" "$BOX_V" "$line" "$padding" "" "$BOX_V"
    done

    # Bottom border
    draw_box_bottom "$width"
}

#------------------------------------------------------------------------------
# Title Bar Functions
#------------------------------------------------------------------------------

# Draw centered title with heavy separators
#
# Parameters:
#   $1 - title: Title text
#   $2 - width: Width of the title bar (default: 67)
#
# Output:
#   Prints:
#   ═══════════════════════════════════════
#            TITLE TEXT
#   ═══════════════════════════════════════
#
draw_title_bar() {
    local title="$1"
    local width="${2:-67}"

    # Top separator
    draw_heavy_line "$width"

    # Centered title
    local title_len=${#title}
    local padding=$(((width - title_len) / 2))
    printf "%*s%s\n" "$padding" "" "$title"

    # Bottom separator
    draw_heavy_line "$width"
}

#------------------------------------------------------------------------------
# Status Formatting Functions
#------------------------------------------------------------------------------

# Format status message with emoji
#
# Parameters:
#   $1 - status: Status type (success, error, warning, info, skip, enabled, disabled)
#   $2 - message: Message text
#
# Output:
#   Prints formatted status message
#
# Example:
#   format_status "success" "Tool installed"
#   Output: ✅ Tool installed
#
format_status() {
    local status="$1"
    local message="$2"

    case "$status" in
        success|ok|installed)
            echo "✅ $message"
            ;;
        error|fail|failed)
            echo "❌ $message"
            ;;
        warning|warn)
            echo "⚠️  $message"
            ;;
        info)
            echo "ℹ️  $message"
            ;;
        skip|skipped)
            echo "⏸️  $message"
            ;;
        enabled|active)
            echo "✅ $message"
            ;;
        disabled|inactive)
            echo "❌ $message"
            ;;
        running)
            echo "🟢 $message"
            ;;
        stopped)
            echo "⭕ $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Get status emoji only (without message)
#
# Parameters:
#   $1 - status: Status type
#
# Output:
#   Prints just the emoji
#
get_status_emoji() {
    local status="$1"

    case "$status" in
        success|ok|installed|enabled|active)
            echo "✅"
            ;;
        error|fail|failed|disabled|inactive)
            echo "❌"
            ;;
        warning|warn)
            echo "⚠️ "
            ;;
        info)
            echo "ℹ️ "
            ;;
        skip|skipped)
            echo "⏸️ "
            ;;
        running)
            echo "🟢"
            ;;
        stopped)
            echo "⭕"
            ;;
        *)
            echo "  "
            ;;
    esac
}

#------------------------------------------------------------------------------
# Summary and Report Functions
#------------------------------------------------------------------------------

# Draw summary separator line (for installation summaries, etc.)
#
# Parameters:
#   $1 - width: Width of the line (default: 61)
#
# Output:
#   Prints: ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
draw_summary_line() {
    local width="${1:-61}"
    draw_line "$width" "$LINE_H"
}

# Draw summary box with statistics
#
# Parameters:
#   $1 - title: Summary title (e.g., "Installation Summary")
#   $@ - stat_lines: Statistics lines (e.g., "Installed: 5", "Skipped: 2")
#
# Output:
#   Prints:
#   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#   📊 Installation Summary:
#      Installed: 5
#      Skipped: 2
#   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
draw_summary_box() {
    local title="$1"
    shift
    local stat_lines=("$@")

    draw_summary_line 61
    echo "📊 $title:"
    for line in "${stat_lines[@]}"; do
        echo "   $line"
    done
    draw_summary_line 61
}

#------------------------------------------------------------------------------
# Terminal Control Functions
#------------------------------------------------------------------------------

# Reset terminal state (useful after commands that corrupt terminal)
#
# Some commands (like supervisor with tee) leave terminal without proper CR/LF
# This function sends carriage return + newline to reset cursor position
#
reset_terminal() {
    printf "\r\n"
    sleep 0.1
}

# Clear screen and move cursor to top
#
clear_screen() {
    printf "\033[2J\033[H"
}

#------------------------------------------------------------------------------
# Printf Variants (for postCreateCommand.sh compatibility)
#------------------------------------------------------------------------------

# Print line with terminal control characters (for postCreateCommand.sh)
#
# Parameters:
#   $1 - width: Width of the line (default: 61)
#
# Output:
#   Prints: ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n
#
printf_line() {
    local width="${1:-61}"
    if [ "$width" -eq 61 ]; then
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
    elif [ "$width" -eq 67 ]; then
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\r\n"
    else
        # Fallback for custom widths - build with sed
        local line=$(printf "%-${width}s" "" | sed 's/ /━/g')
        printf "%s\r\n" "$line"
    fi
}

# Print formatted message with terminal control (for postCreateCommand.sh)
#
# Parameters:
#   $@ - message: Message to print
#
# Output:
#   Prints: message\r\n
#
printf_msg() {
    printf "%s\r\n" "$*"
}

#------------------------------------------------------------------------------
# Helper Functions for Padding and Alignment
#------------------------------------------------------------------------------

# Pad string to specified width (left-aligned)
#
# Parameters:
#   $1 - text: Text to pad
#   $2 - width: Target width
#
# Output:
#   Prints padded text
#
pad_right() {
    local text="$1"
    local width="$2"
    local text_len=${#text}
    local padding=$((width - text_len))
    printf "%s%*s" "$text" "$padding" ""
}

# Pad string to specified width (right-aligned)
#
# Parameters:
#   $1 - text: Text to pad
#   $2 - width: Target width
#
# Output:
#   Prints padded text
#
pad_left() {
    local text="$1"
    local width="$2"
    printf "%*s" "$width" "$text"
}

# Center text within specified width
#
# Parameters:
#   $1 - text: Text to center
#   $2 - width: Target width
#
# Output:
#   Prints centered text
#
center_text() {
    local text="$1"
    local width="$2"
    local text_len=${#text}
    local padding=$(((width - text_len) / 2))
    printf "%*s%s\n" "$padding" "" "$text"
}
