#!/bin/bash
# categories.sh - UIS Service Category Definitions
#
# Defines the service categories used to organize UIS services.
# Compatible with bash 3.x (macOS default) and bash 4.x+
#
# Categories map to the manifest numbering scheme:
#   000-099: Core infrastructure
#   030-039: Monitoring
#   040-099: Databases
#   070-079: Authentication
#   200-229: AI services
#   600-799: Management tools
#
# Usage:
#   source /path/to/categories.sh
#   get_category_name "MONITORING"    # Returns "Observability"
#   is_valid_category "AI"            # Returns 0 (true)

# Guard against multiple sourcing
[[ -n "${_UIS_CATEGORIES_LOADED:-}" ]] && return 0
_UIS_CATEGORIES_LOADED=1

# Category definitions as indexed arrays (bash 3.x compatible)
# Format: ID|Display Name|Description|tags|icon
_CATEGORY_DATA=(
    "CORE|Core Infrastructure|Essential infrastructure services|core,infrastructure|server"
    "MONITORING|Observability|Metrics, logs, and tracing|monitoring,observability|chart-line"
    "DATABASES|Databases|Data storage and caching services|database,storage|database"
    "AI|AI & ML|AI and machine learning services|ai,ml,llm|brain"
    "AUTHENTICATION|Authentication|Identity and access management|auth,sso|shield"
    "QUEUES|Message Queues|Async messaging and event streams|queue,messaging|inbox"
    "SEARCH|Search|Full-text search and indexing|search,indexing|search"
    "MANAGEMENT|Management|Admin tools and GitOps|admin,management|cog"
    "DATASCIENCE|Data Science|Analytics and machine learning platforms|datascience,analytics|flask"
    "NETWORK|Networking|VPN tunnels and network access|network,vpn|globe"
)

# Category display order (just the IDs)
CATEGORY_ORDER=(CORE MONITORING DATABASES AI AUTHENTICATION QUEUES SEARCH MANAGEMENT DATASCIENCE NETWORK)

# Internal: Find category data by ID
# Usage: _find_category_data "MONITORING"
# Returns: The full data string or empty if not found
_find_category_data() {
    local cat_id="$1"
    local entry
    for entry in "${_CATEGORY_DATA[@]}"; do
        local id="${entry%%|*}"
        if [[ "$id" == "$cat_id" ]]; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

# Get display name for a category
# Usage: get_category_name "MONITORING"
# Output: "Observability"
get_category_name() {
    local cat_id="$1"
    local data
    data=$(_find_category_data "$cat_id") || return 1
    # Format: ID|Name|Description|tags|icon
    local rest="${data#*|}"  # Remove ID|
    echo "${rest%%|*}"       # Get Name (before next |)
}

# Get description for a category
# Usage: get_category_description "MONITORING"
# Output: "Metrics, logs, and tracing"
get_category_description() {
    local cat_id="$1"
    local data
    data=$(_find_category_data "$cat_id") || return 1
    # Format: ID|Name|Description|tags|icon
    local rest="${data#*|}"      # Remove ID|
    rest="${rest#*|}"            # Remove Name|
    echo "${rest%%|*}"           # Get Description (before next |)
}

# Get tags for a category
# Usage: get_category_tags "MONITORING"
# Output: "monitoring,observability"
get_category_tags() {
    local cat_id="$1"
    local data
    data=$(_find_category_data "$cat_id") || return 1
    # Format: ID|Name|Description|tags|icon
    local rest="${data#*|}"      # Remove ID|
    rest="${rest#*|}"            # Remove Name|
    rest="${rest#*|}"            # Remove Description|
    echo "${rest%%|*}"           # Get tags (before next |)
}

# Get icon for a category
# Usage: get_category_icon "MONITORING"
# Output: "chart-line"
get_category_icon() {
    local cat_id="$1"
    local data
    data=$(_find_category_data "$cat_id") || return 1
    # Format: ID|Name|Description|tags|icon
    echo "${data##*|}"           # Get icon (after last |)
}

# Check if a category ID is valid
# Usage: is_valid_category "MONITORING"
# Returns: 0 if valid, 1 if not
is_valid_category() {
    local cat_id="$1"
    _find_category_data "$cat_id" >/dev/null 2>&1
}

# List all category IDs in display order
# Usage: list_categories
# Output: One category ID per line
list_categories() {
    local cat_id
    for cat_id in "${CATEGORY_ORDER[@]}"; do
        echo "$cat_id"
    done
}

# Generate JSON output for categories (used by uis-docs.sh)
# Usage: generate_categories_json_internal
# Output: JSON object with categories array
generate_categories_json_internal() {
    echo '{"categories": ['
    local first=true
    local order=0
    local cat_id

    for cat_id in "${CATEGORY_ORDER[@]}"; do
        [[ "$first" != "true" ]] && echo ","
        first=false

        local name desc icon
        name=$(get_category_name "$cat_id")
        desc=$(get_category_description "$cat_id")
        icon=$(get_category_icon "$cat_id")

        cat <<EOF
    {
      "id": "$cat_id",
      "name": "$name",
      "order": $order,
      "description": "$desc",
      "icon": "$icon"
    }
EOF
        ((order++))
    done

    echo ']}'
}

# Print categories in a formatted table
# Usage: print_categories_table
print_categories_table() {
    printf "%-15s %-25s %s\n" "ID" "NAME" "DESCRIPTION"
    printf "%-15s %-25s %s\n" "───────────────" "─────────────────────────" "───────────────────────────"

    local cat_id
    for cat_id in "${CATEGORY_ORDER[@]}"; do
        local name desc
        name=$(get_category_name "$cat_id")
        desc=$(get_category_description "$cat_id")
        printf "%-15s %-25s %s\n" "$cat_id" "$name" "$desc"
    done
}
