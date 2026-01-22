#!/bin/bash
# test-metadata.sh - Validate service metadata
#
# Tests that all service scripts have required metadata fields.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/test-framework.sh"

# Determine services directory (works both in container and on host)
if [[ -d "/mnt/urbalurbadisk/provision-host/uis/services" ]]; then
    SERVICES_DIR="/mnt/urbalurbadisk/provision-host/uis/services"
else
    SERVICES_DIR="$(cd "$SCRIPT_DIR/../../services" && pwd)"
fi

print_test_section "Phase 2: Metadata Validation Tests"
echo "Services directory: $SERVICES_DIR"

REQUIRED_FIELDS=(SCRIPT_ID SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_CATEGORY)

# Count services
service_count=0
for script in "$SERVICES_DIR"/*/*.sh; do
    [[ -f "$script" ]] && ((service_count++))
done

echo "Found $service_count service scripts"
echo ""

for script in "$SERVICES_DIR"/*/*.sh; do
    [[ -f "$script" ]] || continue
    script_basename=$(basename "$script")

    # Clear previous values
    unset SCRIPT_ID SCRIPT_NAME SCRIPT_DESCRIPTION SCRIPT_CATEGORY

    # Source script to get metadata
    source "$script" 2>/dev/null

    for field in "${REQUIRED_FIELDS[@]}"; do
        start_test "$script_basename has $field"
        # Use indirect reference to get field value
        eval "value=\${$field}"
        if [[ -n "$value" ]]; then
            pass_test
        else
            fail_test "$field is empty or not defined"
        fi
    done
done

print_summary
