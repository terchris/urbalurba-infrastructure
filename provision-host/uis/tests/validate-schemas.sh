#!/bin/bash
# validate-schemas.sh - Validate generated JSON files against their schemas
#
# Usage:
#   ./validate-schemas.sh              # Validate all JSON files
#   ./validate-schemas.sh services     # Validate specific file
#
# Requires: python3 with jsonschema module
#   pip install jsonschema

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WEBSITE_DATA="$PROJECT_ROOT/website/src/data"
SCHEMA_DIR="$WEBSITE_DATA/schemas"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation pairs: json_file:schema_file
declare -a VALIDATIONS=(
    "services.json:service.schema.json"
    "categories.json:category.schema.json"
    "stacks.json:stack.schema.json"
    "tools.json:tool.schema.json"
)

# Check for Python and jsonschema
check_dependencies() {
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Error: python3 is required${NC}"
        exit 1
    fi

    if ! python3 -c "import jsonschema" 2>/dev/null; then
        echo -e "${YELLOW}Installing jsonschema module...${NC}"
        pip3 install jsonschema --quiet
    fi
}

# Validate a single JSON file against its schema
# For array-based files (services, categories, tools), validates each item
validate_json() {
    local json_file="$1"
    local schema_file="$2"
    local json_path="$WEBSITE_DATA/$json_file"
    local schema_path="$SCHEMA_DIR/$schema_file"

    if [[ ! -f "$json_path" ]]; then
        echo -e "${RED}✗ $json_file not found${NC}"
        return 1
    fi

    if [[ ! -f "$schema_path" ]]; then
        echo -e "${RED}✗ $schema_file not found${NC}"
        return 1
    fi

    # Python validation script
    python3 - "$json_path" "$schema_path" "$json_file" <<'PYTHON'
import json
import sys
from jsonschema import validate, ValidationError, Draft7Validator

json_path = sys.argv[1]
schema_path = sys.argv[2]
json_name = sys.argv[3]

with open(json_path) as f:
    data = json.load(f)

with open(schema_path) as f:
    schema = json.load(f)

errors = []

# Determine if this is an array-based file or itemList
if json_name == "services.json":
    # services.json has { services: [...] }
    items = data.get("services", [])
    item_name = "service"
elif json_name == "categories.json":
    # categories.json has { categories: [...] }
    items = data.get("categories", [])
    item_name = "category"
elif json_name == "tools.json":
    # tools.json has { tools: [...] }
    items = data.get("tools", [])
    item_name = "tool"
elif json_name == "stacks.json":
    # stacks.json has { itemListElement: [...] }
    items = data.get("itemListElement", [])
    item_name = "stack"
else:
    items = [data]
    item_name = "item"

# Validate each item
validator = Draft7Validator(schema)
for i, item in enumerate(items):
    item_errors = list(validator.iter_errors(item))
    if item_errors:
        item_id = item.get("id") or item.get("identifier") or f"index {i}"
        for error in item_errors:
            path = ".".join(str(p) for p in error.absolute_path) or "(root)"
            errors.append(f"  {item_name} '{item_id}' - {path}: {error.message}")

if errors:
    print(f"FAIL:{len(errors)}")
    for e in errors[:10]:  # Limit output
        print(e)
    if len(errors) > 10:
        print(f"  ... and {len(errors) - 10} more errors")
    sys.exit(1)
else:
    print(f"OK:{len(items)}")
    sys.exit(0)
PYTHON
}

# Run validation
run_validation() {
    local target="${1:-all}"
    local passed=0
    local failed=0

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}JSON Schema Validation${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    for validation in "${VALIDATIONS[@]}"; do
        local json_file="${validation%%:*}"
        local schema_file="${validation##*:}"
        local base_name="${json_file%.json}"

        # Skip if not matching target
        if [[ "$target" != "all" && "$target" != "$base_name" ]]; then
            continue
        fi

        printf "%-20s → %-25s " "$json_file" "$schema_file"

        local result
        if result=$(validate_json "$json_file" "$schema_file" 2>&1); then
            local count="${result#OK:}"
            echo -e "${GREEN}✓ PASS${NC} ($count items)"
            ((passed++))
        else
            local error_count="${result#FAIL:}"
            error_count="${error_count%%$'\n'*}"
            echo -e "${RED}✗ FAIL${NC} ($error_count errors)"
            echo "$result" | tail -n +2
            ((failed++))
        fi
    done

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All validations passed ($passed files)${NC}"
        return 0
    else
        echo -e "${RED}$failed validation(s) failed, $passed passed${NC}"
        return 1
    fi
}

# Main
main() {
    check_dependencies
    run_validation "${1:-all}"
}

main "$@"
