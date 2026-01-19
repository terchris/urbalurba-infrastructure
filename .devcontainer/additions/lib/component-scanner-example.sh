#!/bin/bash
# file: .devcontainer/additions/lib/component-scanner-example.sh
# Example usage of the component-scanner.sh library

# Source the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/component-scanner.sh"

echo "=========================================="
echo "Component Scanner Library Examples"
echo "Version: $COMPONENT_SCANNER_VERSION"
echo "=========================================="
echo ""

# Example 1: Extract single metadata field
echo "Example 1: Extract SCRIPT_NAME from install-dev-python.sh"
echo "-------------------------------------------"
script_name=$(extract_script_metadata "/workspace/.devcontainer/additions/install-dev-python.sh" "SCRIPT_NAME")
echo "Script Name: $script_name"
echo ""

# Example 2: Check if component is installed
echo "Example 2: Check if Python is installed"
echo "-------------------------------------------"
check_cmd=$(extract_script_metadata "/workspace/.devcontainer/additions/install-dev-python.sh" "SCRIPT_CHECK_COMMAND")
if check_component_installed "$check_cmd"; then
    echo "Result: Python IS installed"
else
    echo "Result: Python is NOT installed"
fi
echo ""

# Example 3: Scan all install scripts
echo "Example 3: Scan all install scripts (first 5)"
echo "-------------------------------------------"
echo "Format: basename | name | description | category | check_command"
scan_install_scripts "/workspace/.devcontainer/additions" | head -5 | while IFS=$'\t' read -r basename name desc cat check; do
    echo "  - $name ($cat)"
    echo "    Script: $basename"
    echo "    Check: $check"
    echo ""
done

# Example 4: Count components by category
echo "Example 4: Count components by category"
echo "-------------------------------------------"
declare -A category_counts
while IFS=$'\t' read -r basename name desc cat check; do
    category_counts[$cat]=$((${category_counts[$cat]:-0} + 1))
done < <(scan_install_scripts "/workspace/.devcontainer/additions")

for category in "${!category_counts[@]}"; do
    echo "  $category: ${category_counts[$category]} components"
done
echo ""

# Example 5: Scan service scripts
echo "Example 5: Scan all service scripts"
echo "-------------------------------------------"
echo "Format: start | stop | name | description | category | check"
while IFS=$'\t' read -r start stop name desc cat check; do
    echo "  - $name ($cat)"
    echo "    Start: $start"
    echo "    Stop: ${stop:-none}"
    echo "    Check: $check"
    echo ""
done < <(scan_service_scripts "/workspace/.devcontainer/additions")

# Example 6: Check installed vs not installed
echo "Example 6: List installed vs not installed components"
echo "-------------------------------------------"
installed_count=0
not_installed_count=0

while IFS=$'\t' read -r basename name desc cat check; do
    if check_component_installed "$check"; then
        echo "  [INSTALLED] $name"
        ((installed_count++))
    else
        ((not_installed_count++))
    fi
done < <(scan_install_scripts "/workspace/.devcontainer/additions")

echo ""
echo "Summary: $installed_count installed, $not_installed_count not installed"
echo ""

echo "=========================================="
echo "Examples Complete!"
echo "=========================================="
