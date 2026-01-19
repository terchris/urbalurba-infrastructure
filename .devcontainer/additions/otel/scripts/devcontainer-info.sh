#!/bin/bash
# File: .devcontainer/additions/otel/scripts/devcontainer-info.sh
# Script to collect devcontainer information about installed components
# Outputs Prometheus metrics format

# Determine script directory to find library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="/workspace/.devcontainer/additions/lib"

# Source the component scanner library
if [[ -f "$LIB_DIR/component-scanner.sh" ]]; then
    source "$LIB_DIR/component-scanner.sh"
else
    echo "Error: component-scanner.sh library not found" >&2
    exit 1
fi

ADDITIONS_DIR="/workspace/.devcontainer/additions"

echo "# HELP devcontainer_component_installed Whether a devcontainer component is installed (1=installed, 0=not installed)"
echo "# TYPE devcontainer_component_installed gauge"

# Use library to scan components
while IFS=$'\t' read -r script_basename script_name script_desc script_cat check_cmd; do
    # Generate component ID
    script_id="${script_basename#install-}"
    script_id="${script_id%.sh}"

    # Check if installed using library
    is_installed=0
    if check_component_installed "$check_cmd"; then
        is_installed=1
    fi

    # Sanitize for Prometheus
    script_name=$(echo "$script_name" | sed 's/[^a-zA-Z0-9 _-]//g')
    script_desc=$(echo "$script_desc" | sed 's/[^a-zA-Z0-9 _.,+()-]/ /g')

    # Output metric with labels
    echo "devcontainer_component_installed{component_id=\"$script_id\",component_name=\"$script_name\",category=\"$script_cat\",description=\"$script_desc\"} $is_installed"
done < <(scan_install_scripts "$ADDITIONS_DIR")

# Get OS and container info
echo ""
echo "# HELP devcontainer_info Static information about the devcontainer"
echo "# TYPE devcontainer_info gauge"

OS_NAME=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
OS_VERSION=$(grep '^VERSION=' /etc/os-release | cut -d'"' -f2)
KERNEL_VERSION=$(uname -r)

echo "devcontainer_info{os_name=\"$OS_NAME\",os_version=\"$OS_VERSION\",kernel_version=\"$KERNEL_VERSION\"} 1"
