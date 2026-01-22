#!/bin/bash
# uis-docs.sh - Generate JSON documentation for UIS website
#
# Scans service and tool scripts for metadata and generates JSON files
# for the Docusaurus website.
#
# Usage:
#   ./uis-docs.sh [output-dir]
#
# Outputs:
#   - services.json   - All services with metadata
#   - categories.json - Category definitions
#   - tools.json      - Optional CLI tools
#
# Environment:
#   OUTPUT_DIR - Override output directory (default: website/src/data)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UIS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$UIS_DIR/lib"
SERVICES_DIR="$UIS_DIR/services"
TOOLS_DIR="$UIS_DIR/tools"

# Source libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/categories.sh"
source "$LIB_DIR/service-scanner.sh"

# Default output directory
# In container: /mnt/urbalurbadisk/website/src/data
# On host: derive from script location
_detect_output_dir() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
        return 0
    fi

    # Container path
    if [[ -d "/mnt/urbalurbadisk/website" ]]; then
        echo "/mnt/urbalurbadisk/website/src/data"
        return 0
    fi

    # Host path: derive from script location (provision-host/uis/manage -> website/src/data)
    local base_dir
    base_dir="$(cd "$SCRIPT_DIR/../../.." && pwd)"
    if [[ -d "$base_dir/website" ]]; then
        echo "$base_dir/website/src/data"
        return 0
    fi

    # Fallback
    echo "./website/src/data"
}

OUTPUT_DIR="${OUTPUT_DIR:-$(_detect_output_dir "${1:-}")}"

# ============================================================
# JSON Generation Functions
# ============================================================

# Escape string for JSON
json_escape() {
    local str="$1"
    # Escape backslash, double quote, and control characters
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Generate services.json from all service scripts
generate_services_json() {
    local output_file="$OUTPUT_DIR/services.json"
    log_info "Generating services.json..."

    local temp_file
    temp_file=$(mktemp)
    echo '{"services": [' > "$temp_file"

    local first=true
    local script

    # Find all service scripts
    while IFS= read -r -d '' script; do
        [[ -f "$script" ]] || continue
        [[ "$(basename "$script")" == _* ]] && continue

        # Extract metadata by parsing the file
        local id="" name="" desc="" cat="" abstract="" logo="" website="" playbook="" manifest="" priority=""

        while IFS= read -r line; do
            case "$line" in
                SCRIPT_ID=*)
                    id="${line#SCRIPT_ID=}"
                    id="${id//\"/}"
                    id="${id//\'/}"
                    ;;
                SCRIPT_NAME=*)
                    name="${line#SCRIPT_NAME=}"
                    name="${name//\"/}"
                    name="${name//\'/}"
                    ;;
                SCRIPT_DESCRIPTION=*)
                    desc="${line#SCRIPT_DESCRIPTION=}"
                    desc="${desc//\"/}"
                    desc="${desc//\'/}"
                    ;;
                SCRIPT_CATEGORY=*)
                    cat="${line#SCRIPT_CATEGORY=}"
                    cat="${cat//\"/}"
                    cat="${cat//\'/}"
                    ;;
                SCRIPT_ABSTRACT=*)
                    abstract="${line#SCRIPT_ABSTRACT=}"
                    abstract="${abstract//\"/}"
                    abstract="${abstract//\'/}"
                    ;;
                SCRIPT_LOGO=*)
                    logo="${line#SCRIPT_LOGO=}"
                    logo="${logo//\"/}"
                    logo="${logo//\'/}"
                    ;;
                SCRIPT_WEBSITE=*)
                    website="${line#SCRIPT_WEBSITE=}"
                    website="${website//\"/}"
                    website="${website//\'/}"
                    ;;
                SCRIPT_PLAYBOOK=*)
                    playbook="${line#SCRIPT_PLAYBOOK=}"
                    playbook="${playbook//\"/}"
                    playbook="${playbook//\'/}"
                    ;;
                SCRIPT_MANIFEST=*)
                    manifest="${line#SCRIPT_MANIFEST=}"
                    manifest="${manifest//\"/}"
                    manifest="${manifest//\'/}"
                    ;;
                SCRIPT_PRIORITY=*)
                    priority="${line#SCRIPT_PRIORITY=}"
                    priority="${priority//\"/}"
                    priority="${priority//\'/}"
                    ;;
            esac
        done < "$script"

        # Skip if no ID found
        [[ -z "$id" ]] && continue

        # Add comma if not first
        [[ "$first" != "true" ]] && echo "," >> "$temp_file"
        first=false

        # Escape strings for JSON
        name=$(json_escape "${name:-$id}")
        desc=$(json_escape "${desc:-}")
        abstract=$(json_escape "${abstract:-$desc}")

        # Output JSON object
        cat >> "$temp_file" <<EOF
  {
    "id": "$id",
    "type": "service",
    "name": "$name",
    "description": "$desc",
    "category": "${cat:-CORE}",
    "abstract": "$abstract",
    "logo": "${logo:-}",
    "website": "${website:-}",
    "playbook": "${playbook:-}",
    "manifest": "${manifest:-}",
    "priority": ${priority:-50}
  }
EOF
    done < <(find "$SERVICES_DIR" -name "*.sh" -type f -print0 2>/dev/null | sort -z)

    echo ']}' >> "$temp_file"
    mv "$temp_file" "$output_file"

    local count
    count=$(grep -c '"id":' "$output_file" || echo 0)
    log_success "Generated $output_file ($count services)"
}

# Generate categories.json from categories.sh definitions
generate_categories_json() {
    local output_file="$OUTPUT_DIR/categories.json"
    log_info "Generating categories.json..."

    # Use the function from categories.sh
    generate_categories_json_internal > "$output_file"

    local count
    count=$(grep -c '"id":' "$output_file" || echo 0)
    log_success "Generated $output_file ($count categories)"
}

# Generate tools.json from tool scripts
generate_tools_json() {
    local output_file="$OUTPUT_DIR/tools.json"
    log_info "Generating tools.json..."

    local temp_file
    temp_file=$(mktemp)
    echo '{"tools": [' > "$temp_file"

    local first=true

    # Built-in tools
    local builtin_tools=(
        "kubectl|Kubernetes CLI|Command-line tool for Kubernetes"
        "k9s|K9s|Terminal UI for Kubernetes"
        "helm|Helm|Kubernetes package manager"
        "ansible|Ansible|Automation and configuration management"
    )

    for entry in "${builtin_tools[@]}"; do
        local id name desc
        IFS='|' read -r id name desc <<< "$entry"

        [[ "$first" != "true" ]] && echo "," >> "$temp_file"
        first=false

        cat >> "$temp_file" <<EOF
  {
    "id": "$id",
    "type": "tool",
    "name": "$name",
    "description": "$desc",
    "builtin": true
  }
EOF
    done

    # Optional tools from install scripts
    for script in "$TOOLS_DIR"/install-*.sh; do
        [[ -f "$script" ]] || continue

        # Extract metadata by parsing the file
        local id="" name="" desc="" cat="" size="" website=""

        while IFS= read -r line; do
            case "$line" in
                TOOL_ID=*)
                    id="${line#TOOL_ID=}"
                    id="${id//\"/}"
                    id="${id//\'/}"
                    ;;
                TOOL_NAME=*)
                    name="${line#TOOL_NAME=}"
                    name="${name//\"/}"
                    name="${name//\'/}"
                    ;;
                TOOL_DESCRIPTION=*)
                    desc="${line#TOOL_DESCRIPTION=}"
                    desc="${desc//\"/}"
                    desc="${desc//\'/}"
                    ;;
                TOOL_CATEGORY=*)
                    cat="${line#TOOL_CATEGORY=}"
                    cat="${cat//\"/}"
                    cat="${cat//\'/}"
                    ;;
                TOOL_SIZE=*)
                    size="${line#TOOL_SIZE=}"
                    size="${size//\"/}"
                    size="${size//\'/}"
                    ;;
                TOOL_WEBSITE=*)
                    website="${line#TOOL_WEBSITE=}"
                    website="${website//\"/}"
                    website="${website//\'/}"
                    ;;
            esac
        done < "$script"

        # Skip if no ID found
        [[ -z "$id" ]] && continue

        [[ "$first" != "true" ]] && echo "," >> "$temp_file"
        first=false

        # Escape strings for JSON
        name=$(json_escape "${name:-$id}")
        desc=$(json_escape "${desc:-}")

        cat >> "$temp_file" <<EOF
  {
    "id": "$id",
    "type": "tool",
    "name": "$name",
    "description": "$desc",
    "category": "${cat:-TOOLS}",
    "size": "${size:-unknown}",
    "website": "${website:-}",
    "builtin": false
  }
EOF
    done

    echo ']}' >> "$temp_file"
    mv "$temp_file" "$output_file"

    local count
    count=$(grep -c '"id":' "$output_file" || echo 0)
    log_success "Generated $output_file ($count tools)"
}

# Validate generated JSON files
validate_json() {
    local output_file="$1"
    local name="$2"

    if command -v jq &>/dev/null; then
        if jq . "$output_file" >/dev/null 2>&1; then
            log_info "$name is valid JSON"
            return 0
        else
            log_error "$name is NOT valid JSON"
            return 1
        fi
    else
        log_warn "jq not installed, skipping JSON validation"
        return 0
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    print_section "UIS Documentation Generator"
    echo ""
    echo "Output directory: $OUTPUT_DIR"
    echo ""

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Generate JSON files
    generate_services_json
    generate_categories_json
    generate_tools_json

    echo ""

    # Validate JSON files
    local all_valid=true
    validate_json "$OUTPUT_DIR/services.json" "services.json" || all_valid=false
    validate_json "$OUTPUT_DIR/categories.json" "categories.json" || all_valid=false
    validate_json "$OUTPUT_DIR/tools.json" "tools.json" || all_valid=false

    echo ""
    if [[ "$all_valid" == "true" ]]; then
        log_success "JSON generation complete"
    else
        log_error "Some JSON files failed validation"
        exit 1
    fi
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
