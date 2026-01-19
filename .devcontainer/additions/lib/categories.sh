#!/bin/bash
# file: .devcontainer/additions/lib/categories.sh
#
# Central definition of script categories using a table structure
# Source this file to get category constants and helper functions
#
# Usage:
#   source "${SCRIPT_DIR}/lib/categories.sh"
#   name=$(get_category_name "LANGUAGE_DEV")
#   abstract=$(get_category_abstract "LANGUAGE_DEV")
#   summary=$(get_category_summary "LANGUAGE_DEV")
#   tags=$(get_category_tags "LANGUAGE_DEV")

#------------------------------------------------------------------------------
# Category Table
#------------------------------------------------------------------------------
# Format: CATEGORY_ORDER|CATEGORY_ID|CATEGORY_NAME|CATEGORY_ABSTRACT|CATEGORY_SUMMARY|CATEGORY_TAGS|CATEGORY_LOGO
#
# Field descriptions:
#   CATEGORY_ORDER   - Display order (lower numbers first)
#   CATEGORY_ID      - Unique identifier (UPPERCASE_UNDERSCORE)
#   CATEGORY_NAME    - Human-readable name for display
#   CATEGORY_ABSTRACT - Brief description (50-150 chars) for cards
#   CATEGORY_SUMMARY  - Detailed description (150-500 chars) for detail pages
#   CATEGORY_TAGS     - Space-separated search keywords
#   CATEGORY_LOGO     - Logo filename (optional, in website/static/img/categories/src/)
#
# To add a new category:
# 1. Add a new line to the table below
# 2. Set CATEGORY_ORDER to control display order (lower numbers first)
# 3. Use UPPERCASE_UNDERSCORE format for CATEGORY_ID
# 4. CATEGORY_ABSTRACT should be 50-150 characters
# 5. CATEGORY_SUMMARY can be more detailed (150-500 characters)
# 6. CATEGORY_TAGS are space-separated keywords for search

# Only declare if not already set (prevents errors when sourced multiple times)
if [[ -z "${CATEGORY_TABLE+x}" ]]; then
    readonly CATEGORY_TABLE="
0|SYSTEM_COMMANDS|System Commands|DevContainer management commands for setup and maintenance.|DevContainer management commands (setup, update, services, help). Essential tools for managing your development environment.|system devcontainer setup management commands|system-commands-logo.webp
1|LANGUAGE_DEV|Development Tools|Programming language development environments and tools.|Complete development setups for Python, TypeScript, Go, Rust, .NET, and Bash. Each includes language-specific tooling and VS Code extensions.|programming languages code development ide python typescript go rust|language-dev-logo.webp
2|AI_TOOLS|AI & Machine Learning Tools|AI and machine learning development tools.|AI and machine learning development tools including Claude Code for AI-assisted coding and other ML utilities.|ai artificial intelligence machine learning ml claude code|ai-tools-logo.webp
3|CLOUD_TOOLS|Cloud & Infrastructure Tools|Cloud platform tools and SDKs.|Cloud platform CLIs and SDKs for Azure, AWS, and GCP. Manage cloud resources directly from your development environment.|cloud azure aws gcp infrastructure sdk cli|cloud-tools-logo.webp
4|DATA_ANALYTICS|Data & Analytics Tools|Data analysis, visualization, and engineering tools.|Data analysis, visualization, and data engineering tools including Jupyter, pandas, and database clients. Connect to data platforms.|data analytics jupyter pandas visualization database|data-analytics-logo.webp
5|BACKGROUND_SERVICES|Background Services & Daemons|Background services and daemons for development.|Background services and daemons including nginx reverse proxy, OTEL collector, and monitoring services. Run services locally.|services daemon background nginx monitoring otel|background-services-logo.webp
6|INFRA_CONFIG|Infrastructure & Configuration|Infrastructure as Code and configuration management.|Infrastructure as Code, configuration management, and DevOps tools including Kubernetes, Terraform, and Ansible.|infrastructure devops kubernetes terraform ansible configuration|infra-config-logo.webp
7|CONTRIBUTOR_TOOLS|Contributor Tools|Tools for contributors and maintainers.|Tools for contributors and maintainers including documentation generators, test runners, and development utilities.|contributor maintainer development tools testing docs|contributor-tools-logo.webp
"
fi

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

# Parse category table and return specific field for a category
# Args: $1=category_id, $2=field_number
# Fields: 1=order, 2=id, 3=name, 4=abstract, 5=summary, 6=tags, 7=logo
_get_category_field() {
    local category_id=$1
    local field_num=$2

    echo "$CATEGORY_TABLE" | grep -v "^$" | while IFS='|' read -r cat_order cat_id cat_name cat_abstract cat_summary cat_tags cat_logo; do
        if [[ "$cat_id" == "$category_id" ]]; then
            case $field_num in
                1) echo "$cat_order" ;;
                2) echo "$cat_id" ;;
                3) echo "$cat_name" ;;
                4) echo "$cat_abstract" ;;
                5) echo "$cat_summary" ;;
                6) echo "$cat_tags" ;;
                7) echo "$cat_logo" ;;
            esac
            return 0
        fi
    done
    return 1
}

# Get name for a category (human-readable display name)
get_category_name() {
    local category=$1
    local result=$(_get_category_field "$category" 3)
    if [[ -n "$result" ]]; then
        echo "$result"
    else
        echo "$category"
    fi
}

# Backward compatibility alias
get_category_display_name() {
    get_category_name "$1"
}

# Get abstract for a category (brief description, 50-150 chars)
get_category_abstract() {
    local category=$1
    _get_category_field "$category" 4
}

# Backward compatibility alias
get_category_short_description() {
    get_category_abstract "$1"
}

# Get summary for a category (detailed description, 150-500 chars)
get_category_summary() {
    local category=$1
    _get_category_field "$category" 5
}

# Backward compatibility alias
get_category_description() {
    get_category_summary "$1"
}

# Get tags for a category (space-separated keywords)
get_category_tags() {
    local category=$1
    _get_category_field "$category" 6
}

# Get logo filename for a category
get_category_logo() {
    local category=$1
    _get_category_field "$category" 7
}

# Get order for a category (display order number)
get_category_order() {
    local category=$1
    _get_category_field "$category" 1
}

# Backward compatibility alias
get_category_sort_order() {
    get_category_order "$1"
}

# Get all category IDs in sort order
get_all_category_ids() {
    echo "$CATEGORY_TABLE" | grep -v "^$" | sort -t'|' -k1 -n | cut -d'|' -f2
}

# Validate that a category ID is valid
is_valid_category() {
    local category=$1
    echo "$CATEGORY_TABLE" | grep -v "^$" | cut -d'|' -f2 | grep -q "^${category}$"
}

# List all categories in table format (machine-readable)
# Output format: CATEGORY_ORDER|CATEGORY_ID|CATEGORY_NAME|CATEGORY_ABSTRACT|CATEGORY_SUMMARY|CATEGORY_TAGS|CATEGORY_LOGO
list_categories() {
    echo "$CATEGORY_TABLE" | grep -v "^$" | sort -t'|' -k1 -n
}

# List all categories with just ID and name
list_categories_simple() {
    echo "$CATEGORY_TABLE" | grep -v "^$" | sort -t'|' -k1 -n | while IFS='|' read -r cat_order cat_id cat_name rest; do
        printf "%-20s %s\n" "$cat_id" "$cat_name"
    done
}

#------------------------------------------------------------------------------
# Display Functions
#------------------------------------------------------------------------------

# Show all categories and their descriptions (human-readable)
show_all_categories() {
    echo "Available Script Categories:"
    echo ""
    echo "$CATEGORY_TABLE" | grep -v "^$" | sort -t'|' -k1 -n | while IFS='|' read -r cat_order cat_id cat_name cat_abstract cat_summary cat_tags cat_logo; do
        printf "  %-20s %-30s\n" "$cat_id" "$cat_name"
        printf "  %-20s %s\n" "" "$cat_summary"
        echo ""
    done
}

# Show categories as a table
show_categories_table() {
    echo "Category Table:"
    echo ""
    printf "%-5s %-20s %-30s %-60s\n" "ORDER" "ID" "NAME" "ABSTRACT"
    printf "%-5s %-20s %-30s %-60s\n" "-----" "--" "----" "--------"
    echo "$CATEGORY_TABLE" | grep -v "^$" | sort -t'|' -k1 -n | while IFS='|' read -r cat_order cat_id cat_name cat_abstract cat_summary cat_tags cat_logo; do
        printf "%-5s %-20s %-30s %-60s\n" "$cat_order" "$cat_id" "$cat_name" "$cat_abstract"
    done
}

#------------------------------------------------------------------------------
# Category Constants (for convenience)
#------------------------------------------------------------------------------
# These are generated from the table and can be used in scripts for validation

# Only declare if not already set (prevents errors when sourced multiple times)
if [[ -z "${CATEGORY_LANGUAGE_DEV+x}" ]]; then
    readonly CATEGORY_SYSTEM_COMMANDS="SYSTEM_COMMANDS"
    readonly CATEGORY_LANGUAGE_DEV="LANGUAGE_DEV"
    readonly CATEGORY_AI_TOOLS="AI_TOOLS"
    readonly CATEGORY_CLOUD_TOOLS="CLOUD_TOOLS"
    readonly CATEGORY_DATA_ANALYTICS="DATA_ANALYTICS"
    readonly CATEGORY_BACKGROUND_SERVICES="BACKGROUND_SERVICES"
    readonly CATEGORY_INFRA_CONFIG="INFRA_CONFIG"
    readonly CATEGORY_CONTRIBUTOR_TOOLS="CONTRIBUTOR_TOOLS"
fi

# Array of all category IDs in sort order (for iteration)
# Populated dynamically from the table
_populate_category_order() {
    CATEGORY_ORDER=()
    while IFS= read -r cat_id; do
        CATEGORY_ORDER+=("$cat_id")
    done < <(get_all_category_ids)
}

# Populate the array when sourced
_populate_category_order
