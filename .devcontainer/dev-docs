#!/bin/bash
# file: .devcontainer/manage/dev-docs.sh
#
# Generates comprehensive documentation by running all install scripts with --help
# Output: website/docs/tools/index.mdx (overview), website/docs/commands.md (commands), README.md (updated)
#
# Usage:
#   dev-docs                          # Generate full manual
#   dev-docs --help                   # Show this help
#   dev-docs --dry-run                # Preview without writing
#   dev-docs --category LANGUAGE_DEV  # Only specific category
#   dev-docs --verbose                # Show detailed progress

#------------------------------------------------------------------------------
# Script Metadata (for component scanner)
#------------------------------------------------------------------------------
SCRIPT_ID="dev-docs"
SCRIPT_NAME="Generate Docs"
SCRIPT_DESCRIPTION="Generate documentation (tools.md, commands.md)"
SCRIPT_CATEGORY="CONTRIBUTOR_TOOLS"
SCRIPT_CHECK_COMMAND="true"

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly SCRIPT_DIR

# Handle both cases:
# 1. Running from .devcontainer/manage/ (symlink resolved or direct execution)
# 2. Running from .devcontainer/ root (when script is a copy, not symlink - e.g., from zip extraction)
if [[ "$(basename "$SCRIPT_DIR")" == "manage" ]]; then
    DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
    MANAGE_DIR="$SCRIPT_DIR"
else
    # Script is in .devcontainer/ root (copy from zip extraction)
    DEVCONTAINER_DIR="$SCRIPT_DIR"
    MANAGE_DIR="$SCRIPT_DIR/manage"
fi
readonly DEVCONTAINER_DIR
readonly MANAGE_DIR
readonly ADDITIONS_DIR="$DEVCONTAINER_DIR/additions"
readonly WORKSPACE_ROOT="$DEVCONTAINER_DIR/.."
readonly TOOLS_DIR="${WORKSPACE_ROOT}/website/docs/tools"
readonly OUTPUT_FILE="${TOOLS_DIR}/index.mdx"
readonly OUTPUT_FILE_COMMANDS="${WORKSPACE_ROOT}/website/docs/commands.md"
readonly README_FILE="${WORKSPACE_ROOT}/README.md"
readonly TOOLS_JSON="${WORKSPACE_ROOT}/website/src/data/tools.json"
readonly CATEGORIES_JSON="${WORKSPACE_ROOT}/website/src/data/categories.json"

# Source logging library
# shellcheck source=/dev/null
source "${ADDITIONS_DIR}/lib/logging.sh"

# Source categories library
# shellcheck source=/dev/null
source "${ADDITIONS_DIR}/lib/categories.sh"

# Source component scanner library (for scan_manage_scripts)
# shellcheck source=/dev/null
source "${ADDITIONS_DIR}/lib/component-scanner.sh"

# Options
DRY_RUN=0
VERBOSE=0
FILTER_CATEGORY=""

# Category script lists (populated by discover_scripts)
SCRIPTS_LANGUAGE_DEV=""
SCRIPTS_AI_TOOLS=""
SCRIPTS_CLOUD_TOOLS=""
SCRIPTS_DATA_ANALYTICS=""
SCRIPTS_INFRA_CONFIG=""

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

show_help() {
    cat << EOF
dev-docs - Generate comprehensive documentation

Usage:
  dev-docs                          # Generate full documentation
  dev-docs --help                   # Show this help
  dev-docs --dry-run                # Preview without writing files
  dev-docs --category LANGUAGE_DEV  # Only specific category
  dev-docs --verbose                # Show detailed progress

Output:
  website/docs/tools/index.mdx     - Overview table with links to tool pages
  website/docs/tools/<category>/   - Category folders with individual tool pages
  website/docs/commands.md         - Command reference (dev-* commands)
  website/src/data/tools.json      - Tool metadata for React components
  website/src/data/categories.json - Category metadata for React components
  README.md                        - Tools summary (between markers)

Categories:
  LANGUAGE_DEV    - $(get_category_short_description "LANGUAGE_DEV")
  AI_TOOLS        - $(get_category_short_description "AI_TOOLS")
  CLOUD_TOOLS     - $(get_category_short_description "CLOUD_TOOLS")
  DATA_ANALYTICS  - $(get_category_short_description "DATA_ANALYTICS")
  INFRA_CONFIG    - $(get_category_short_description "INFRA_CONFIG")

Examples:
  # Generate full documentation
  dev-docs

  # Preview what would be generated
  dev-docs --dry-run

  # Only generate development tools section
  dev-docs --category LANGUAGE_DEV --verbose

EOF
}

# Detect script type from filename prefix
# Args: $1=script_path
# Returns: install, config, service, or unknown
detect_script_type() {
    local script_path=$1
    local basename=$(basename "$script_path")

    if [[ "$basename" == install-* ]]; then
        echo "install"
    elif [[ "$basename" == config-* ]]; then
        echo "config"
    elif [[ "$basename" == service-* ]] || [[ "$basename" == install-srv-* ]]; then
        echo "service"
    else
        echo "unknown"
    fi
}

# Extract a metadata field from a script file
# Args: $1=script_path, $2=field_name
# Returns: field value or empty string
extract_script_field() {
    local script_path=$1
    local field_name=$2

    # Extract value between quotes (handles both " and ')
    local value=$(grep "^${field_name}=" "$script_path" | head -1 | sed 's/^[^=]*=["'"'"']\{0,1\}//' | sed 's/["'"'"']\{0,1\}$//')
    echo "$value"
}

# Extract all extended metadata from a script
# Args: $1=script_path
# Sets global variables: _SCRIPT_TAGS, _SCRIPT_ABSTRACT, _SCRIPT_LOGO, _SCRIPT_WEBSITE, _SCRIPT_SUMMARY, _SCRIPT_RELATED
extract_extended_metadata() {
    local script_path=$1

    _SCRIPT_TAGS=$(extract_script_field "$script_path" "SCRIPT_TAGS")
    _SCRIPT_ABSTRACT=$(extract_script_field "$script_path" "SCRIPT_ABSTRACT")
    _SCRIPT_LOGO=$(extract_script_field "$script_path" "SCRIPT_LOGO")
    _SCRIPT_WEBSITE=$(extract_script_field "$script_path" "SCRIPT_WEBSITE")
    _SCRIPT_SUMMARY=$(extract_script_field "$script_path" "SCRIPT_SUMMARY")
    _SCRIPT_RELATED=$(extract_script_field "$script_path" "SCRIPT_RELATED")
}

# Extract a package array from a script file
# Args: $1=script_path, $2=array_name (e.g., PACKAGES_SYSTEM)
# Returns: newline-separated list of package entries
extract_package_array() {
    local script_path=$1
    local array_name=$2

    # Use awk to extract content between ARRAY_NAME=( and the closing )
    # Handles both single-line and multi-line arrays
    local content
    content=$(awk -v arr="${array_name}" '
        # Match the start of the array
        $0 ~ "^"arr"=\\(" {
            capturing = 1
            # Remove the array assignment prefix
            sub("^"arr"=\\(", "")
            # Check if single-line array (ends with ) on same line)
            if (/)$/) {
                sub(/\)$/, "")
                if (length($0) > 0 && $0 !~ /^[[:space:]]*$/) print
                capturing = 0
                next
            }
            # Print remaining content on first line if any
            if (length($0) > 0 && $0 !~ /^[[:space:]]*$/) print
            next
        }
        # While capturing, look for closing )
        capturing {
            # Check if this line ends the array
            if (/^[[:space:]]*\)/ || /\)$/) {
                sub(/\)$/, "")
                sub(/^[[:space:]]*\)/, "")
                if (length($0) > 0 && $0 !~ /^[[:space:]]*$/) print
                capturing = 0
                next
            }
            print
        }
    ' "$script_path" 2>/dev/null | \
        grep -v '^[[:space:]]*$' | \
        grep -v '^[[:space:]]*#' | \
        sed 's/^[[:space:]]*//' | \
        sed 's/[[:space:]]*$//' | \
        sed 's/"//g' | \
        sed "s/'//g")

    echo "$content"
}

# Get the system package URL base for the current distribution
# Returns URL like "https://packages.debian.org/bookworm" or "https://packages.ubuntu.com/jammy"
get_system_package_url_base() {
    local os_id=""
    local codename=""

    if [[ -f /etc/os-release ]]; then
        os_id=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
        codename=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    fi

    case "$os_id" in
        debian)
            echo "https://packages.debian.org/${codename}"
            ;;
        ubuntu)
            echo "https://packages.ubuntu.com/${codename}"
            ;;
        *)
            # Fallback to Debian Bookworm (the devcontainer's distro)
            # This ensures links work even when generating docs on macOS
            echo "https://packages.debian.org/bookworm"
            ;;
    esac
}

# Cache the system package URL base (computed once)
SYSTEM_PKG_URL_BASE=""

# Format package array as markdown table with links
# Args: $1=table_title, $2=package_content (newline-separated), $3=package_type (system|npm|pip|cargo|go|pwsh|dotnet|java)
# Returns: markdown table string
format_package_table() {
    local title=$1
    local content=$2
    local pkg_type=${3:-""}

    # Initialize system package URL base if not set
    if [[ -z "$SYSTEM_PKG_URL_BASE" ]] && [[ "$pkg_type" == "system" ]]; then
        SYSTEM_PKG_URL_BASE=$(get_system_package_url_base)
    fi

    if [[ -z "$content" ]]; then
        return
    fi

    echo "## $title"
    echo ""
    echo "| Package | Description |"
    echo "|---------|-------------|"

    echo "$content" | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        local pkg=""
        local desc=""

        # Check if line has a comment (description after #)
        if [[ "$line" == *"#"* ]]; then
            pkg="${line%%#*}"
            desc="${line#*#}"
            pkg=$(echo "$pkg" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            desc=$(echo "$desc" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        elif [[ "$line" == *" - "* ]]; then
            # Check if it looks like "package - description"
            pkg="${line%% - *}"
            desc="${line#* - }"
            pkg=$(echo "$pkg" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            desc=$(echo "$desc" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        else
            # Just package name
            pkg=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        fi

        # Create link based on package type
        local pkg_link=""
        case "$pkg_type" in
            system)
                # Link to Debian/Ubuntu package page if we know the distro
                if [[ -n "$SYSTEM_PKG_URL_BASE" ]]; then
                    pkg_link="[${pkg}](${SYSTEM_PKG_URL_BASE}/${pkg})"
                else
                    pkg_link="\`${pkg}\`"
                fi
                ;;
            npm)
                pkg_link="[${pkg}](https://www.npmjs.com/package/${pkg})"
                ;;
            pip)
                pkg_link="[${pkg}](https://pypi.org/project/${pkg})"
                ;;
            cargo)
                pkg_link="[${pkg}](https://crates.io/crates/${pkg})"
                ;;
            go)
                # Go packages are usually full URLs or module paths
                if [[ "$pkg" == http* ]]; then
                    pkg_link="[${pkg}](${pkg})"
                else
                    pkg_link="[${pkg}](https://pkg.go.dev/${pkg})"
                fi
                ;;
            pwsh)
                pkg_link="[${pkg}](https://www.powershellgallery.com/packages/${pkg})"
                ;;
            dotnet)
                pkg_link="[${pkg}](https://www.nuget.org/packages/${pkg})"
                ;;
            *)
                # Java and others - no useful registry links
                pkg_link="\`${pkg}\`"
                ;;
        esac

        echo "| ${pkg_link} | $desc |"
    done
    echo ""
}

# Format VS Code extensions as markdown table with marketplace links
# Args: $1=extension_content (newline-separated)
# Format: "ExtensionName (publisher.extension-id) - Description"
# Returns: markdown table with clickable links
format_extensions_table() {
    local content=$1

    if [[ -z "$content" ]]; then
        return
    fi

    echo "## VS Code Extensions"
    echo ""
    echo "| Extension | Description |"
    echo "|-----------|-------------|"

    echo "$content" | while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Parse format: "ExtensionName (publisher.extension-id) - Description"
        if [[ "$line" =~ ^([^(]+)\(([^)]+)\)(.*)$ ]]; then
            local ext_name="${BASH_REMATCH[1]}"
            local ext_id="${BASH_REMATCH[2]}"
            local rest="${BASH_REMATCH[3]}"

            # Clean up whitespace
            ext_name=$(echo "$ext_name" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            ext_id=$(echo "$ext_id" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

            # Extract description (after " - ")
            local desc=""
            if [[ "$rest" == *" - "* ]]; then
                desc="${rest#* - }"
                desc=$(echo "$desc" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            fi

            # Create marketplace link
            local marketplace_url="https://marketplace.visualstudio.com/items?itemName=${ext_id}"
            echo "| [${ext_name}](${marketplace_url}) | $desc |"
        else
            # Fallback: just display as-is
            echo "| $line | |"
        fi
    done
    echo ""
}

# Escape string for JSON output
json_escape() {
    local str=$1
    # Escape backslashes, double quotes, and control characters
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Convert space-separated string to JSON array
# Args: $1=space-separated string
# Returns: JSON array string like ["item1","item2"]
to_json_array() {
    local input=$1
    if [[ -z "$input" ]]; then
        echo "[]"
        return
    fi

    local result="["
    local first=1
    for item in $input; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            result+=","
        fi
        result+="\"$(json_escape "$item")\""
    done
    result+="]"
    echo "$result"
}

# Add script to appropriate category variable
add_to_category() {
    local category=$1
    local script_path=$2

    case "$category" in
        LANGUAGE_DEV)
            SCRIPTS_LANGUAGE_DEV="${SCRIPTS_LANGUAGE_DEV}${script_path} "
            ;;
        AI_TOOLS)
            SCRIPTS_AI_TOOLS="${SCRIPTS_AI_TOOLS}${script_path} "
            ;;
        CLOUD_TOOLS)
            SCRIPTS_CLOUD_TOOLS="${SCRIPTS_CLOUD_TOOLS}${script_path} "
            ;;
        DATA_ANALYTICS)
            SCRIPTS_DATA_ANALYTICS="${SCRIPTS_DATA_ANALYTICS}${script_path} "
            ;;
        INFRA_CONFIG)
            SCRIPTS_INFRA_CONFIG="${SCRIPTS_INFRA_CONFIG}${script_path} "
            ;;
    esac
}

# Get scripts for a category
get_category_scripts() {
    local category=$1

    case "$category" in
        LANGUAGE_DEV) echo "$SCRIPTS_LANGUAGE_DEV" ;;
        AI_TOOLS) echo "$SCRIPTS_AI_TOOLS" ;;
        CLOUD_TOOLS) echo "$SCRIPTS_CLOUD_TOOLS" ;;
        DATA_ANALYTICS) echo "$SCRIPTS_DATA_ANALYTICS" ;;
        INFRA_CONFIG) echo "$SCRIPTS_INFRA_CONFIG" ;;
        *) echo "" ;;
    esac
}

# Map category ID to folder name for URL-friendly paths
get_category_folder() {
    local category=$1
    case "$category" in
        LANGUAGE_DEV) echo "development-tools" ;;
        AI_TOOLS) echo "ai-machine-learning" ;;
        CLOUD_TOOLS) echo "cloud-infrastructure" ;;
        DATA_ANALYTICS) echo "data-analytics" ;;
        INFRA_CONFIG) echo "infrastructure-configuration" ;;
        *) echo "" ;;
    esac
}

# Map tool ID to filename (strip common prefixes, use kebab-case)
get_tool_filename() {
    local tool_id=$1
    # Remove common prefixes like dev-, tool-, install-
    local name="${tool_id#dev-}"
    name="${name#tool-}"
    name="${name#install-}"
    # Convert to lowercase (already should be)
    echo "$name"
}

# Discover and categorize all install scripts
discover_scripts() {
    log_info "Discovering install scripts..."

    # Find all install-*.sh scripts (excluding template)
    while IFS= read -r script_path; do
        local script_name=$(basename "$script_path")

        # Skip template and tailscale (different structure)
        if [[ "$script_name" == *"template"* ]] || [[ "$script_name" == "install-tailscale.sh" ]]; then
            continue
        fi

        # Extract SCRIPT_CATEGORY and SCRIPT_ID
        local category=$(grep "^SCRIPT_CATEGORY=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
        local script_id=$(grep "^SCRIPT_ID=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)

        if [[ -n "$category" ]] && [[ -n "$script_id" ]]; then
            # Apply category filter if specified
            if [[ -n "$FILTER_CATEGORY" ]] && [[ "$category" != "$FILTER_CATEGORY" ]]; then
                continue
            fi

            add_to_category "$category" "$script_path"
            [[ $VERBOSE -eq 1 ]] && log_info "  Found: $script_name (category: $category, id: $script_id)"
        else
            log_warn "  Skipping $script_name: missing metadata"
        fi
    done < <(find "$ADDITIONS_DIR" -maxdepth 1 -name "install-*.sh" -type f | sort)
}

# Count total scripts across all categories
count_total_scripts() {
    local total=0
    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            total=$((total + $(echo "$scripts" | wc -w)))
        fi
    done
    echo "$total"
}

# Count categories with scripts
count_categories() {
    local count=0
    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            count=$((count + 1))
        fi
    done
    echo "$count"
}

# Generate table of contents
generate_toc() {
    local toc=""

    toc+="## Table of Contents\n\n"

    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            local category_name=$(get_category_display_name "$category")
            local anchor=$(echo "$category_name" | tr '[:upper:]' '[:lower:]' | tr -d '&,' | tr -s ' ' | tr ' ' '-')
            toc+="- [$category_name](#$anchor)\n"
        fi
    done

    toc+="\n---\n"
    echo -e "$toc"
}

# Generate categories overview
generate_categories_overview() {
    local overview=""

    overview+="## Categories\n\n"
    overview+="This manual is organized into the following categories:\n\n"

    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            local category_name=$(get_category_display_name "$category")
            local category_desc=$(get_category_description "$category")
            local script_count=$(echo "$scripts" | wc -w)

            overview+="### $category_name\n\n"
            overview+="$category_desc\n\n"
            overview+="**Scripts in this category:** $script_count\n\n"
        fi
    done

    overview+="---\n\n"
    echo -e "$overview"
}

# Generate tools summary table
generate_tools_summary() {
    local summary=""

    summary+="| Name | ID | Category | Description |\n"
    summary+="|------|----|---------|--------------|\n"

    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            local category_name=$(get_category_display_name "$category")
            local folder_name=$(get_category_folder "$category")

            for script_path in $scripts; do
                local script_name=$(grep "^SCRIPT_NAME=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
                local script_id=$(grep "^SCRIPT_ID=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
                local script_desc=$(grep "^SCRIPT_DESCRIPTION=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)

                # Create link to individual tool page
                local tool_filename=$(get_tool_filename "$script_id")

                summary+="| [$script_name]($folder_name/$tool_filename) | \`$script_id\` | $category_name | $script_desc |\n"
            done
        fi
    done

    summary+="\n"
    echo -e "$summary"
}

# Generate README tools summary (category-based overview)
generate_readme_tools_content() {
    local content=""
    local total_scripts=$(count_total_scripts)

    content+="**${total_scripts}+ development tools** ready to install with one click:\n\n"
    content+="| Category | Tools |\n"
    content+="|----------|-------|\n"

    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -n "$scripts" ]]; then
            local category_name=$(get_category_display_name "$category")
            local tool_names=""

            for script_path in $scripts; do
                local script_name=$(grep "^SCRIPT_NAME=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
                # Shorten name for README (remove common suffixes - order matters!)
                script_name=$(echo "$script_name" | \
                    sed 's/ Runtime & Development Tools//g' | \
                    sed 's/ Development Tools//g' | \
                    sed 's/ Tools$//g' | \
                    sed 's/Data & Analytics/Data Analytics/g' | \
                    sed 's/API Development/API/g' | \
                    sed 's/Infrastructure as Code/Terraform, Ansible/g' | \
                    sed 's/Development Utilities/Dev Utilities/g' | \
                    sed 's/Okta Identity Management/Okta/g' | \
                    sed 's/Microsoft Power Platform/Power Platform/g' | \
                    sed 's/Azure Application Development/Azure Dev/g' | \
                    sed 's/Azure Operations & Infrastructure Management/Azure Ops/g')
                if [[ -n "$tool_names" ]]; then
                    tool_names+=", "
                fi
                tool_names+="$script_name"
            done

            content+="| **$category_name** | $tool_names |\n"
        fi
    done

    echo -e "$content"
}

# Update README.md with tools content between markers
update_readme() {
    log_info "Updating README.md..."

    if [[ ! -f "$README_FILE" ]]; then
        log_warn "README.md not found, skipping update"
        return 0
    fi

    # Check for markers
    if ! grep -q "<!-- TOOLS_START" "$README_FILE"; then
        log_warn "TOOLS_START marker not found in README.md, skipping update"
        return 0
    fi

    if ! grep -q "<!-- TOOLS_END -->" "$README_FILE"; then
        log_warn "TOOLS_END marker not found in README.md, skipping update"
        return 0
    fi

    # Generate the new content to a temp file
    local content_file
    content_file=$(mktemp)
    generate_readme_tools_content > "$content_file"

    # Create output file
    local temp_file
    temp_file=$(mktemp)

    # Extract before, insert new content, extract after
    # 1. Get everything up to and including TOOLS_START marker
    sed -n '1,/<!-- TOOLS_START/p' "$README_FILE" > "$temp_file"

    # 2. Add the new content
    cat "$content_file" >> "$temp_file"

    # 3. Get everything from TOOLS_END marker onwards
    sed -n '/<!-- TOOLS_END/,$p' "$README_FILE" >> "$temp_file"

    # Replace original file
    mv "$temp_file" "$README_FILE"
    rm -f "$content_file"

    log_info "Updated: $README_FILE"
}

#------------------------------------------------------------------------------
# JSON Generation Functions
#------------------------------------------------------------------------------

# Generate tools.json with all tool metadata
generate_tools_json() {
    log_info "Generating tools.json..."

    local json="{\n  \"tools\": ["
    local first_tool=1

    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -z "$scripts" ]]; then
            continue
        fi

        for script_path in $scripts; do
            # Extract core metadata
            local script_id=$(extract_script_field "$script_path" "SCRIPT_ID")
            local script_name=$(extract_script_field "$script_path" "SCRIPT_NAME")
            local script_desc=$(extract_script_field "$script_path" "SCRIPT_DESCRIPTION")
            local script_category=$(extract_script_field "$script_path" "SCRIPT_CATEGORY")

            # Extract extended metadata
            extract_extended_metadata "$script_path"

            # Detect script type
            local script_type=$(detect_script_type "$script_path")

            # Add comma before tool (except first)
            if [[ $first_tool -eq 1 ]]; then
                first_tool=0
            else
                json+=","
            fi

            # Build JSON object for this tool
            json+="\n    {"
            json+="\n      \"id\": \"$(json_escape "$script_id")\","
            json+="\n      \"type\": \"$script_type\","
            json+="\n      \"name\": \"$(json_escape "$script_name")\","
            json+="\n      \"description\": \"$(json_escape "$script_desc")\","
            json+="\n      \"category\": \"$script_category\","
            json+="\n      \"tags\": $(to_json_array "$_SCRIPT_TAGS"),"
            json+="\n      \"abstract\": \"$(json_escape "$_SCRIPT_ABSTRACT")\""

            # Add optional fields only if they have values
            if [[ -n "$_SCRIPT_LOGO" ]]; then
                json+=",\n      \"logo\": \"$(json_escape "$_SCRIPT_LOGO")\""
            fi
            if [[ -n "$_SCRIPT_WEBSITE" ]]; then
                json+=",\n      \"website\": \"$(json_escape "$_SCRIPT_WEBSITE")\""
            fi
            if [[ -n "$_SCRIPT_SUMMARY" ]]; then
                json+=",\n      \"summary\": \"$(json_escape "$_SCRIPT_SUMMARY")\""
            fi
            if [[ -n "$_SCRIPT_RELATED" ]]; then
                json+=",\n      \"related\": $(to_json_array "$_SCRIPT_RELATED")"
            fi

            json+="\n    }"
        done
    done

    json+="\n  ]\n}"

    echo -e "$json"
}

# Generate categories.json with all category metadata
generate_categories_json() {
    log_info "Generating categories.json..."

    local json="{\n  \"categories\": ["
    local first_cat=1

    for category_id in "${CATEGORY_ORDER[@]}"; do
        # Get category metadata using helper functions from categories.sh
        local cat_name=$(get_category_name "$category_id")
        local cat_order=$(get_category_order "$category_id")
        local cat_abstract=$(get_category_abstract "$category_id")
        local cat_summary=$(get_category_summary "$category_id")
        local cat_tags=$(get_category_tags "$category_id")
        local cat_logo=$(get_category_logo "$category_id")

        # Add comma before category (except first)
        if [[ $first_cat -eq 1 ]]; then
            first_cat=0
        else
            json+=","
        fi

        # Build JSON object for this category
        json+="\n    {"
        json+="\n      \"id\": \"$category_id\","
        json+="\n      \"name\": \"$(json_escape "$cat_name")\","
        json+="\n      \"order\": $cat_order,"
        json+="\n      \"tags\": $(to_json_array "$cat_tags"),"
        json+="\n      \"abstract\": \"$(json_escape "$cat_abstract")\","
        json+="\n      \"summary\": \"$(json_escape "$cat_summary")\""

        # Add optional logo field only if it has a value
        if [[ -n "$cat_logo" ]]; then
            json+=",\n      \"logo\": \"$(json_escape "$cat_logo")\""
        fi

        json+="\n    }"
    done

    json+="\n  ]\n}"

    echo -e "$json"
}

# Format help output from a script
format_help_output() {
    local script_path=$1
    local script_name=$(basename "$script_path")

    [[ $VERBOSE -eq 1 ]] && log_info "    Running $script_name --help..."

    # Run script with --help and capture output
    local help_output
    if ! help_output=$(bash "$script_path" --help 2>&1); then
        log_error "    Failed to run $script_name --help"
        return 1
    fi

    # Filter out associative array errors and other bash errors
    help_output=$(echo "$help_output" | grep -v "declare: -A: invalid option" | grep -v "declare: usage:" | grep -v "syntax error: invalid arithmetic operator" | grep -v "Logging to:")

    # Extract just the main help section (skip the logging header)
    # Skip lines until we find the second separator line (after the logging header)
    # The help output starts with a separator line containing the script name
    help_output=$(echo "$help_output" | awk '/^━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━/{count++; if(count==2){found=1; next}} found')

    # Format as markdown code block
    echo '```'
    echo "$help_output"
    echo '```'
    echo ""
}

# Generate section for a category
generate_category_section() {
    local category=$1
    local section=""

    local scripts=$(get_category_scripts "$category")
    if [[ -z "$scripts" ]]; then
        return 0
    fi

    local category_name=$(get_category_display_name "$category")

    log_info "  Generating section: $category_name"

    section+="\n\n## $category_name\n\n"

    # Process each script in this category
    local script_count=0
    for script_path in $scripts; do
        local script_name=$(grep "^SCRIPT_NAME=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
        local script_id=$(grep "^SCRIPT_ID=" "$script_path" | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
        local script_basename=$(basename "$script_path")

        section+="### $script_name\n\n"

        # Extract extended metadata
        extract_extended_metadata "$script_path"

        # Show abstract as lead paragraph if available
        if [[ -n "$_SCRIPT_ABSTRACT" ]]; then
            section+="*$_SCRIPT_ABSTRACT*\n\n"
        fi

        section+="**Script ID:** \`$script_id\`  \n"
        section+="**Script:** \`$script_basename\`  \n"

        # Add website link if available
        if [[ -n "$_SCRIPT_WEBSITE" ]]; then
            section+="**Website:** [$_SCRIPT_WEBSITE]($_SCRIPT_WEBSITE)  \n"
        fi

        section+="**Command:** \`.devcontainer/additions/$script_basename --help\`\n\n"

        # Add summary if available (more detailed than abstract)
        if [[ -n "$_SCRIPT_SUMMARY" ]]; then
            section+="$_SCRIPT_SUMMARY\n\n"
        fi

        # Add tags if available
        if [[ -n "$_SCRIPT_TAGS" ]]; then
            local tags_formatted=$(echo "$_SCRIPT_TAGS" | tr ' ' ', ')
            section+="**Tags:** $tags_formatted\n\n"
        fi

        # Add related tools if available
        if [[ -n "$_SCRIPT_RELATED" ]]; then
            local related_links=""
            for rel_id in $_SCRIPT_RELATED; do
                if [[ -n "$related_links" ]]; then
                    related_links+=", "
                fi
                related_links+="\`$rel_id\`"
            done
            section+="**Related:** $related_links\n\n"
        fi

        # Add help output in collapsible section
        local help_content
        help_content=$(format_help_output "$script_path")
        section+="<details>\n<summary>Installation details (click to expand)</summary>\n\n"
        section+="$help_content\n"
        section+="</details>\n\n"

        section+="---\n\n"
        ((script_count++))
    done

    log_info "    Processed $script_count scripts in category"

    echo -e "$section"
}

#------------------------------------------------------------------------------
# Individual Tool Pages Generation
#------------------------------------------------------------------------------

# Generate _category_.json for a category folder
generate_category_json() {
    local category=$1
    local position=$2
    local folder_name=$(get_category_folder "$category")
    local label=$(get_category_display_name "$category")

    cat << EOF
{
  "label": "$label",
  "position": $position,
  "link": {
    "type": "doc",
    "id": "tools/$folder_name/index"
  }
}
EOF
}

# Generate category index.mdx with ToolGrid component
generate_category_index_mdx() {
    local category=$1
    local category_name=$(get_category_display_name "$category")
    local category_desc=$(get_category_description "$category")
    local category_summary=$(get_category_summary "$category")
    local category_logo=$(get_category_logo "$category")
    local scripts=$(get_category_scripts "$category")
    local script_count=$(echo "$scripts" | wc -w | tr -d ' ')

    cat << EOF
---
title: $category_name
hide_title: true
---

import ToolGrid from '@site/src/components/ToolGrid';
import useBaseUrl from '@docusaurus/useBaseUrl';

<div style={{display: 'flex', alignItems: 'flex-start', gap: '1.5rem', marginBottom: '2rem'}}>
  <img
    src={useBaseUrl('/img/categories/$category_logo')}
    alt="$category_name"
    style={{width: '120px', height: '120px', objectFit: 'contain'}}
  />
  <div>
    <h1 style={{marginTop: 0}}>$category_name</h1>
    <p style={{fontSize: '1.1rem', color: 'var(--ifm-color-emphasis-700)'}}>$category_summary</p>
  </div>
</div>

<ToolGrid category="$category" columns={2} />
EOF
}

# Generate individual tool MDX page
generate_tool_mdx() {
    local script_path=$1
    local category=$2

    # Extract metadata
    local script_id=$(extract_script_field "$script_path" "SCRIPT_ID")
    local script_name=$(extract_script_field "$script_path" "SCRIPT_NAME")
    local script_desc=$(extract_script_field "$script_path" "SCRIPT_DESCRIPTION")
    local script_basename=$(basename "$script_path")

    # Extract extended metadata
    extract_extended_metadata "$script_path"

    # Build related tools links
    local related_links=""
    if [[ -n "$_SCRIPT_RELATED" ]]; then
        related_links="relatedIds={["
        local first=1
        for rel_id in $_SCRIPT_RELATED; do
            if [[ $first -eq 1 ]]; then
                first=0
            else
                related_links+=", "
            fi
            related_links+="'$rel_id'"
        done
        related_links+="]}"
    fi

    # Build tags display
    local tags_display=""
    if [[ -n "$_SCRIPT_TAGS" ]]; then
        for tag in $_SCRIPT_TAGS; do
            tags_display+="\`$tag\` "
        done
    fi

    # Extract package arrays
    local pkg_system=$(extract_package_array "$script_path" "PACKAGES_SYSTEM")
    local pkg_node=$(extract_package_array "$script_path" "PACKAGES_NODE")
    local pkg_python=$(extract_package_array "$script_path" "PACKAGES_PYTHON")
    local pkg_cargo=$(extract_package_array "$script_path" "PACKAGES_CARGO")
    local pkg_go=$(extract_package_array "$script_path" "PACKAGES_GO")
    local pkg_pwsh=$(extract_package_array "$script_path" "PACKAGES_PWSH")
    local pkg_dotnet=$(extract_package_array "$script_path" "PACKAGES_DOTNET")
    local pkg_java=$(extract_package_array "$script_path" "PACKAGES_JAVA")
    local extensions=$(extract_package_array "$script_path" "EXTENSIONS")

    cat << EOF
---
title: $script_name
hide_title: true
---

import RelatedTools from '@site/src/components/RelatedTools';
import useBaseUrl from '@docusaurus/useBaseUrl';

EOF

    # Header with logo in a styled card
    if [[ -n "$_SCRIPT_LOGO" ]]; then
        cat << EOF
<div style={{
  display: 'flex',
  alignItems: 'flex-start',
  gap: '1.5rem',
  marginBottom: '1.5rem',
  padding: '1.5rem',
  background: 'var(--ifm-card-background-color)',
  borderRadius: '8px',
  border: '1px solid var(--ifm-color-emphasis-200)'
}}>
  <img
    src={useBaseUrl('/img/tools/$_SCRIPT_LOGO')}
    alt="$script_name"
    style={{width: '80px', height: '80px', objectFit: 'contain', flexShrink: 0}}
  />
  <div style={{flex: 1}}>
    <h1 style={{marginTop: 0, marginBottom: '0.5rem', fontSize: '1.75rem'}}>$script_name</h1>
EOF
        if [[ -n "$_SCRIPT_ABSTRACT" ]]; then
            echo "    <p style={{fontSize: '1rem', color: 'var(--ifm-color-emphasis-700)', marginBottom: '0.75rem'}}>$_SCRIPT_ABSTRACT</p>"
        fi
        # Add tags inline in header
        if [[ -n "$tags_display" ]]; then
            echo "    <div style={{display: 'flex', flexWrap: 'wrap', gap: '0.5rem'}}>"
            for tag in $_SCRIPT_TAGS; do
                echo "      <span style={{background: 'var(--ifm-color-emphasis-200)', padding: '0.2rem 0.6rem', borderRadius: '4px', fontSize: '0.75rem'}}>$tag</span>"
            done
            echo "    </div>"
        fi
        echo "  </div>"
        echo "</div>"
        echo ""
    else
        # No logo - simple header
        echo "# $script_name"
        echo ""
        if [[ -n "$_SCRIPT_ABSTRACT" ]]; then
            echo "*$_SCRIPT_ABSTRACT*"
            echo ""
        fi
        if [[ -n "$tags_display" ]]; then
            echo "**Tags:** $tags_display"
            echo ""
        fi
    fi

    # Summary (detailed description) in a highlighted box
    if [[ -n "$_SCRIPT_SUMMARY" ]]; then
        echo ":::info Overview"
        echo "$_SCRIPT_SUMMARY"
        echo ":::"
        echo ""
    fi

    # Quick info section
    echo "<div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '1.5rem'}}>"
    echo "  <div>"
    echo "    <strong>Script ID:</strong> <code>$script_id</code>"
    echo "  </div>"
    echo "  <div>"
    echo "    <strong>Script:</strong> <code>$script_basename</code>"
    echo "  </div>"
    if [[ -n "$_SCRIPT_WEBSITE" ]]; then
        echo "  <div>"
        echo "    <strong>Website:</strong> <a href=\"$_SCRIPT_WEBSITE\" target=\"_blank\">$_SCRIPT_WEBSITE</a>"
        echo "  </div>"
    fi
    echo "</div>"
    echo ""

    # What's Included section with package tables
    local has_packages=0
    if [[ -n "$pkg_system" ]] || [[ -n "$pkg_node" ]] || [[ -n "$pkg_python" ]] || \
       [[ -n "$pkg_cargo" ]] || [[ -n "$pkg_go" ]] || [[ -n "$pkg_pwsh" ]] || \
       [[ -n "$pkg_dotnet" ]] || [[ -n "$pkg_java" ]] || [[ -n "$extensions" ]]; then
        has_packages=1
    fi

    if [[ $has_packages -eq 1 ]]; then
        # System packages
        if [[ -n "$pkg_system" ]]; then
            format_package_table "System Packages" "$pkg_system" "system"
        fi

        # Language-specific packages
        if [[ -n "$pkg_node" ]]; then
            format_package_table "Node.js Packages (npm)" "$pkg_node" "npm"
        fi

        if [[ -n "$pkg_python" ]]; then
            format_package_table "Python Packages (pip)" "$pkg_python" "pip"
        fi

        if [[ -n "$pkg_cargo" ]]; then
            format_package_table "Rust Packages (cargo)" "$pkg_cargo" "cargo"
        fi

        if [[ -n "$pkg_go" ]]; then
            format_package_table "Go Packages" "$pkg_go" "go"
        fi

        if [[ -n "$pkg_pwsh" ]]; then
            format_package_table "PowerShell Modules" "$pkg_pwsh" "pwsh"
        fi

        if [[ -n "$pkg_dotnet" ]]; then
            format_package_table ".NET Packages" "$pkg_dotnet" "dotnet"
        fi

        if [[ -n "$pkg_java" ]]; then
            format_package_table "Java Packages" "$pkg_java" "java"
        fi

        # VS Code extensions (with marketplace links)
        if [[ -n "$extensions" ]]; then
            format_extensions_table "$extensions"
        fi
    fi

    # Installation section
    echo "## Installation"
    echo ""
    echo "Install via the interactive menu:"
    echo ""
    echo "\`\`\`bash"
    echo "dev-setup"
    echo "\`\`\`"
    echo ""
    echo "Or install directly:"
    echo ""
    echo "\`\`\`bash"
    echo ".devcontainer/additions/$script_basename"
    echo "\`\`\`"
    echo ""

    # Help output in collapsible section
    local help_content
    help_content=$(format_help_output "$script_path")
    echo "<details>"
    echo "<summary>Full installation options (click to expand)</summary>"
    echo ""
    echo "$help_content"
    echo "</details>"
    echo ""

    # Related tools
    if [[ -n "$_SCRIPT_RELATED" ]]; then
        echo "## Related Tools"
        echo ""
        echo "<RelatedTools $related_links />"
    fi
}

# Generate all category folders and tool pages
generate_tool_pages() {
    log_info "Generating individual tool pages..."

    local position=1
    for category in "${CATEGORY_ORDER[@]}"; do
        local scripts=$(get_category_scripts "$category")
        if [[ -z "$scripts" ]]; then
            continue
        fi

        local folder_name=$(get_category_folder "$category")
        local folder_path="${TOOLS_DIR}/${folder_name}"
        local category_name=$(get_category_display_name "$category")

        log_info "  Creating category: $category_name ($folder_name)"

        # Create folder
        mkdir -p "$folder_path"

        # Generate _category_.json
        generate_category_json "$category" "$position" > "${folder_path}/_category_.json"

        # Generate index.mdx
        generate_category_index_mdx "$category" > "${folder_path}/index.mdx"

        # Generate individual tool pages
        for script_path in $scripts; do
            local script_id=$(extract_script_field "$script_path" "SCRIPT_ID")
            local tool_filename=$(get_tool_filename "$script_id")
            local tool_path="${folder_path}/${tool_filename}.mdx"

            [[ $VERBOSE -eq 1 ]] && log_info "    Generating: ${tool_filename}.mdx"

            generate_tool_mdx "$script_path" "$category" > "$tool_path"
        done

        local script_count=$(echo "$scripts" | wc -w | tr -d ' ')
        log_info "    Generated $script_count tool pages"

        ((position++))
    done
}

#------------------------------------------------------------------------------
# Commands.md Generation (manage scripts)
#------------------------------------------------------------------------------

# Generate commands.md content from manage script metadata
generate_commands_md() {
    local content=""

    log_info "Generating commands.md..."

    content+="---\n"
    content+="sidebar_position: 4\n"
    content+="sidebar_label: Install Tools\n"
    content+="---\n\n"
    content+="# Install Tools\n\n"
    content+=":::note Auto-generated\n"
    content+="This page is auto-generated. Regenerate with: \`dev-docs\`\n"
    content+=":::\n\n"

    # dev-setup section with image
    content+="## dev-setup\n\n"
    content+="Run \`dev-setup\` to install development tools. The interactive menu lets you browse and install any of the available tools.\n\n"
    content+="![dev-setup menu](/img/dev-setup.png)\n\n"

    # Build arrays from scan_manage_scripts output
    declare -a cmd_names=()
    declare -a cmd_ids=()
    declare -a cmd_descriptions=()
    declare -a cmd_categories=()
    declare -a cmd_basenames=()

    while IFS=$'\t' read -r basename script_id name desc category check; do
        cmd_basenames+=("$basename")
        cmd_ids+=("$script_id")
        cmd_names+=("$name")
        cmd_descriptions+=("$desc")
        cmd_categories+=("$category")
    done < <(scan_manage_scripts "$MANAGE_DIR")

    # Add dev-setup manually (excluded from scanner to avoid recursion)
    cmd_basenames+=("dev-setup.sh")
    cmd_ids+=("dev-setup")
    cmd_names+=("Setup Menu")
    cmd_descriptions+=("Interactive menu for installing tools and managing services")
    cmd_categories+=("SYSTEM_COMMANDS")

    log_info "  Found ${#cmd_ids[@]} manage commands"

    # Quick Reference table
    content+="## Quick Reference\n\n"
    content+="| Command | Description |\n"
    content+="|---------|-------------|\n"

    # Sort by category, then by name within category
    # First SYSTEM_COMMANDS, then CONTRIBUTOR_TOOLS
    for cat in "SYSTEM_COMMANDS" "CONTRIBUTOR_TOOLS"; do
        for i in "${!cmd_ids[@]}"; do
            if [[ "${cmd_categories[$i]}" == "$cat" ]]; then
                local cmd_id="${cmd_ids[$i]}"
                local desc="${cmd_descriptions[$i]}"
                # Create anchor from command id
                local anchor=$(echo "$cmd_id" | tr -d '[:space:]')
                content+="| [\`$cmd_id\`](#$anchor) | $desc |\n"
            fi
        done
    done
    content+="\n---\n\n"

    # Detailed sections by category
    for cat in "SYSTEM_COMMANDS" "CONTRIBUTOR_TOOLS"; do
        local cat_name=$(get_category_display_name "$cat")
        local has_commands=0

        # Check if category has any commands
        for i in "${!cmd_ids[@]}"; do
            if [[ "${cmd_categories[$i]}" == "$cat" ]]; then
                has_commands=1
                break
            fi
        done

        [[ $has_commands -eq 0 ]] && continue

        content+="## $cat_name\n\n"

        for i in "${!cmd_ids[@]}"; do
            if [[ "${cmd_categories[$i]}" == "$cat" ]]; then
                local cmd_id="${cmd_ids[$i]}"
                local cmd_name="${cmd_names[$i]}"
                local desc="${cmd_descriptions[$i]}"
                local basename="${cmd_basenames[$i]}"

                content+="### $cmd_id\n\n"
                content+="$desc\n\n"
                content+="\`\`\`bash\n"
                content+="$cmd_id\n"

                # Add common flags if applicable
                case "$cmd_id" in
                    dev-update)
                        content+="$cmd_id --force   # Force update even if same version\n"
                        ;;
                    dev-services)
                        content+="$cmd_id status          # Show status of all services\n"
                        content+="$cmd_id start <name>    # Start a service\n"
                        content+="$cmd_id stop <name>     # Stop a service\n"
                        content+="$cmd_id logs <name>     # View service logs\n"
                        ;;
                    dev-check)
                        content+="$cmd_id --show    # Show current configuration\n"
                        ;;
                esac

                content+="\`\`\`\n\n"
            fi
        done

        content+="---\n\n"
    done

    # Add section about running install scripts directly
    content+="## Running Install Scripts Directly\n\n"
    content+="All install scripts can also be run directly:\n\n"
    content+="\`\`\`bash\n"
    content+="# Show help for a script\n"
    content+=".devcontainer/additions/install-dev-python.sh --help\n\n"
    content+="# Install with specific version\n"
    content+=".devcontainer/additions/install-dev-golang.sh --version 1.22.0\n\n"
    content+="# Uninstall\n"
    content+=".devcontainer/additions/install-dev-golang.sh --uninstall\n"
    content+="\`\`\`\n\n"
    content+="Use \`dev-setup\` for the interactive menu, or run scripts directly for automation.\n"

    echo -e "$content"
}

#------------------------------------------------------------------------------
# Main Generation Logic
#------------------------------------------------------------------------------

generate_manual() {
    local output=""

    # Discover all scripts
    discover_scripts

    # Count total scripts
    local total_scripts=$(count_total_scripts)
    local total_categories=$(count_categories)

    log_info "Found $total_scripts install scripts across $total_categories categories"

    if [[ $total_scripts -eq 0 ]]; then
        log_error "No install scripts found!"
        return 1
    fi

    # ===== Generate tools/index.mdx (overview with visual components) =====
    log_info "Generating tools/index.mdx (overview)..."
    output+="---\n"
    output+="sidebar_position: 3\n"
    output+="sidebar_label: Tools\n"
    output+="title: Available Tools\n"
    output+="---\n\n"
    output+="import CategoryGrid from '@site/src/components/CategoryGrid';\n\n"
    output+="# Available Tools\n\n"
    output+="All tools can be installed via \`dev-setup\` or by running the install script directly.\n\n"
    output+="<CategoryGrid />\n"

    # ===== Generate individual tool pages =====
    if [[ $DRY_RUN -eq 0 ]]; then
        generate_tool_pages
    else
        log_info "DRY RUN - Would generate individual tool pages in $TOOLS_DIR/"
    fi

    # ===== Generate commands.md (manage scripts) =====
    local commands
    commands=$(generate_commands_md)

    # ===== Generate JSON files for React components =====
    local tools_json
    tools_json=$(generate_tools_json)

    local categories_json
    categories_json=$(generate_categories_json)

    # Output result
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "DRY RUN - tools/index.md preview:"
        echo -e "$output" | head -50
        echo "..."
        log_info "DRY RUN - commands.md preview:"
        echo -e "$commands" | head -50
        echo "..."
        log_info "DRY RUN - tools.json preview:"
        echo -e "$tools_json" | head -30
        echo "..."
        log_info "DRY RUN - categories.json preview:"
        echo -e "$categories_json" | head -30
        echo "..."
        log_info "Total length: tools/index.md=$(echo -e "$output" | wc -l) lines, commands.md=$(echo -e "$commands" | wc -l) lines"
    else
        # Ensure docs directory exists
        mkdir -p "$(dirname "$OUTPUT_FILE")"

        # Ensure data directory exists for JSON files
        mkdir -p "$(dirname "$TOOLS_JSON")"

        # Write tools/index.md
        echo -e "$output" > "$OUTPUT_FILE"
        log_info "Written: $OUTPUT_FILE ($(wc -l < "$OUTPUT_FILE") lines)"

        # Write commands.md
        echo -e "$commands" > "$OUTPUT_FILE_COMMANDS"
        log_info "Written: $OUTPUT_FILE_COMMANDS ($(wc -l < "$OUTPUT_FILE_COMMANDS") lines)"

        # Write tools.json
        echo -e "$tools_json" > "$TOOLS_JSON"
        log_info "Written: $TOOLS_JSON"

        # Write categories.json
        echo -e "$categories_json" > "$CATEGORIES_JSON"
        log_info "Written: $CATEGORIES_JSON"

        # Update README.md
        update_readme
    fi

    return 0
}

#------------------------------------------------------------------------------
# Argument Parsing
#------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --category)
            if [[ -n "${2:-}" && "$2" != --* ]]; then
                FILTER_CATEGORY="$2"
                shift 2
            else
                log_error "Error: --category requires a value"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------

log_info "Starting manual generation..."

if [[ -n "$FILTER_CATEGORY" ]]; then
    log_info "Filtering to category: $FILTER_CATEGORY"
fi

if ! generate_manual; then
    log_error "Failed to generate manual"
    exit 1
fi

log_info "Manual generation complete!"

if [[ $DRY_RUN -eq 0 ]]; then
    log_info "You can view the manual at: $OUTPUT_FILE"
fi

exit 0
