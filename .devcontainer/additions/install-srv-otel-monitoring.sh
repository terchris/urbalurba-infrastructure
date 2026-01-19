#!/bin/bash
# file: .devcontainer/additions/install-srv-otel-monitoring.sh
#
# Install OpenTelemetry Collector for devcontainer monitoring when connected to our network.
# For usage information, run: ./install-srv-otel-monitoring.sh --help
#
# Uses:
# - script_exporter (v3.1.0) https://github.com/ricoberger/script_exporter
#   Collects custom metrics by executing shell scripts (memory, disk, process stats)
# - OpenTelemetry Collector Contrib (v0.140.1) https://github.com/open-telemetry/opentelemetry-collector-contrib
#   Extended version with Prometheus/Loki/Tempo exporters, resource processors for multi-tenant tagging
#------------------------------------------------------------------------------
# CONFIGURATION - Modify this section for each new script
#------------------------------------------------------------------------------

# --- Script Metadata ---
SCRIPT_ID="srv-otel"
SCRIPT_VER="0.0.1"
SCRIPT_NAME="OpenTelemetry Monitoring"
SCRIPT_DESCRIPTION="Install OpenTelemetry Collector for devcontainer monitoring when connected to our network"
SCRIPT_CATEGORY="BACKGROUND_SERVICES"
SCRIPT_CHECK_COMMAND="([ -f /usr/bin/otelcol-contrib ] || command -v otelcol-contrib >/dev/null 2>&1) && ([ -f /usr/local/bin/script_exporter ] || command -v script_exporter >/dev/null 2>&1)"

# --- Extended Metadata (for website documentation) ---
SCRIPT_TAGS="opentelemetry otel monitoring observability metrics prometheus"
SCRIPT_ABSTRACT="OpenTelemetry Collector for devcontainer monitoring with metrics and log collection."
SCRIPT_LOGO="srv-otel-logo.webp"
SCRIPT_WEBSITE="https://opentelemetry.io"
SCRIPT_SUMMARY="OpenTelemetry Collector Contrib with script_exporter for comprehensive devcontainer monitoring. Collects custom metrics via shell scripts, supports Prometheus/Loki/Tempo exporters, and provides resource processors for multi-tenant tagging."
SCRIPT_RELATED="srv-nginx"

# Commands for dev-setup.sh menu integration
SCRIPT_COMMANDS=(
    "Action||Install OpenTelemetry Collector||false|"
    "Action|--uninstall|Uninstall OpenTelemetry Collector||false|"
    "Info|--help|Show help and usage information||false|"
)

# OTel Collector configuration
OTEL_VERSION="0.140.1"  # Latest stable version as of 2025-11
OTEL_PACKAGE_NAME="otelcol-contrib"
OTEL_CONFIG_DIR="/workspace/.devcontainer/additions/otel"

# script_exporter configuration (for custom metrics collection)
SCRIPT_EXPORTER_VERSION="3.1.0"  # Latest stable version as of 2025-01
SCRIPT_EXPORTER_BINARY="/usr/local/bin/script_exporter"
SCRIPT_EXPORTER_CONFIG="${OTEL_CONFIG_DIR}/script-exporter-config.yaml"

# System packages (curl is in base image, but needed for downloads)
PACKAGES_SYSTEM=()

# VS Code extensions
EXTENSIONS=()

#------------------------------------------------------------------------------

# Source auto-enable library
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/tool-auto-enable.sh"

# Source logging library
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/logging.sh"

#------------------------------------------------------------------------------

# Before running installation, we need to add any required repositories or setup
pre_installation_setup() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo "🔧 Preparing for uninstallation..."
    else
        echo "🔧 Performing pre-installation setup..."

        # Create config directory
        mkdir -p "$OTEL_CONFIG_DIR"

        # Check prerequisites
        if [ -f "${SCRIPT_DIR}/config-devcontainer-identity.sh" ]; then
            echo "✅ Found prerequisite: config-devcontainer-identity.sh"
        else
            echo "⚠️  Prerequisite missing: config-devcontainer-identity.sh"
        fi
    fi
}

# Custom installation logic for OTel Collector
install_otel_collector() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Uninstalling OpenTelemetry Collector..."
        echo ""

        # Stop running collector
        if pgrep -f "otelcol.*--config" >/dev/null 2>&1; then
            echo "⚠️  Stopping running collector..."
            sudo pkill -f "otelcol.*--config" || true
            sleep 2
        fi

        # Check if package is installed
        if dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
            echo "   Removing package: $OTEL_PACKAGE_NAME"

            if sudo apt-get remove -y "$OTEL_PACKAGE_NAME"; then
                echo "✅ Package removed successfully"

                # Clean up dependencies
                echo "   Cleaning up unused dependencies..."
                sudo apt-get autoremove -y
            else
                echo "❌ Failed to remove package"
                return 1
            fi
        else
            echo "ℹ️  Package not installed: $OTEL_PACKAGE_NAME"
        fi

        # Remove logs (optional)
        if [ -f "/var/log/otelcol.log" ]; then
            echo "   Found log file: /var/log/otelcol.log"
            if [ "${FORCE_MODE}" -eq 1 ]; then
                sudo rm -f /var/log/otelcol.log
                echo "   Removed log file"
            else
                echo "   To remove logs, run: sudo rm -f /var/log/otelcol.log"
            fi
        fi

        echo ""
        echo "ℹ️  Config directory preserved: $OTEL_CONFIG_DIR"
        echo "   To remove manually: rm -rf $OTEL_CONFIG_DIR"
        echo ""
        return
    fi

    echo ""
    echo "📦 Installing OpenTelemetry Collector v${OTEL_VERSION}..."
    echo ""

    # Detect architecture
    local DEB_ARCH
    DEB_ARCH=$(detect_architecture)
    if [ "$DEB_ARCH" = "unknown" ]; then
        echo "❌ Unsupported architecture"
        return 1
    fi

    echo "   Architecture: $DEB_ARCH"
    echo "   Version: $OTEL_VERSION"
    echo ""

    # Check if already installed
    if dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
        INSTALLED_VERSION=$(dpkg-query -W -f='${Version}' "$OTEL_PACKAGE_NAME" 2>/dev/null)
        if [ "$INSTALLED_VERSION" = "$OTEL_VERSION" ]; then
            echo "✅ OpenTelemetry Collector v${OTEL_VERSION} is already installed"
            return 0
        else
            echo "ℹ️  Found existing version: $INSTALLED_VERSION"
            echo "   Upgrading to: $OTEL_VERSION"
        fi
    fi

    # Construct download URL
    DEB_FILE="${OTEL_PACKAGE_NAME}_${OTEL_VERSION}_linux_${DEB_ARCH}.deb"
    URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/${DEB_FILE}"

    echo "📥 Downloading Debian package from GitHub releases..."
    echo "   $URL"
    echo ""

    # Download to temp file
    TEMP_DEB=$(mktemp --suffix=.deb)
    if ! curl -L -o "$TEMP_DEB" "$URL"; then
        echo "❌ Failed to download OTel Collector package"
        rm -f "$TEMP_DEB"
        return 1
    fi

    echo "✅ Download complete"
    echo ""
    echo "📦 Installing Debian package..."

    # Install with dpkg
    if ! sudo dpkg -i "$TEMP_DEB"; then
        echo "⚠️  Package installation had issues, attempting to fix dependencies..."
        # Fix any dependency issues
        sudo apt-get install -f -y

        # Verify installation succeeded
        if ! dpkg -l "$OTEL_PACKAGE_NAME" 2>/dev/null | grep -q "^ii"; then
            echo "❌ Failed to install package"
            rm -f "$TEMP_DEB"
            return 1
        fi
    fi

    # Cleanup
    rm -f "$TEMP_DEB"

    echo "✅ Package installed successfully"
    echo ""

    # Verify installation
    if command -v otelcol-contrib >/dev/null 2>&1 && otelcol-contrib --version >/dev/null 2>&1; then
        VERSION_OUTPUT=$(otelcol-contrib --version 2>&1 | head -1)
        echo "✅ Installation verified: $VERSION_OUTPUT"
        return 0
    else
        echo "❌ Installation verification failed"
        return 1
    fi
}

# Install script_exporter for custom metrics collection
install_script_exporter() {
    if [ "${UNINSTALL_MODE}" -eq 1 ]; then
        echo ""
        echo "🗑️  Uninstalling script_exporter..."
        echo ""

        # Stop running script_exporter
        if pgrep -f "script_exporter.*--config" >/dev/null 2>&1; then
            echo "⚠️  Stopping running script_exporter..."
            sudo pkill -f "script_exporter.*--config" || true
            sleep 2
        fi

        # Remove binary
        if [ -f "$SCRIPT_EXPORTER_BINARY" ]; then
            echo "   Removing binary: $SCRIPT_EXPORTER_BINARY"
            if sudo rm -f "$SCRIPT_EXPORTER_BINARY"; then
                echo "✅ Binary removed successfully"
            else
                echo "❌ Failed to remove binary"
                return 1
            fi
        else
            echo "ℹ️  Binary not installed: $SCRIPT_EXPORTER_BINARY"
        fi

        # Remove log if exists
        if [ -f "/tmp/script-exporter.log" ]; then
            if [ "${FORCE_MODE}" -eq 1 ]; then
                sudo rm -f /tmp/script-exporter.log
                echo "   Removed log file"
            fi
        fi

        echo ""
        return
    fi

    echo ""
    echo "📦 Installing script_exporter v${SCRIPT_EXPORTER_VERSION}..."
    echo ""

    # Detect architecture
    local BIN_ARCH
    BIN_ARCH=$(detect_architecture)
    if [ "$BIN_ARCH" = "unknown" ]; then
        echo "❌ Unsupported architecture"
        return 1
    fi

    echo "   Architecture: $BIN_ARCH"
    echo "   Version: $SCRIPT_EXPORTER_VERSION"
    echo ""

    # Check if already installed
    if [ -f "$SCRIPT_EXPORTER_BINARY" ]; then
        INSTALLED_VERSION=$("$SCRIPT_EXPORTER_BINARY" --version 2>&1 | grep -oP 'version=v\K[0-9.]+' || echo "unknown")
        if [ "$INSTALLED_VERSION" = "$SCRIPT_EXPORTER_VERSION" ]; then
            echo "✅ script_exporter v${SCRIPT_EXPORTER_VERSION} is already installed"
            return 0
        else
            echo "ℹ️  Found existing version: $INSTALLED_VERSION"
            echo "   Upgrading to: $SCRIPT_EXPORTER_VERSION"
        fi
    fi

    # Construct download URL
    ARCHIVE_NAME="script_exporter-linux-${BIN_ARCH}.tar.gz"
    URL="https://github.com/ricoberger/script_exporter/releases/download/v${SCRIPT_EXPORTER_VERSION}/${ARCHIVE_NAME}"

    echo "📥 Downloading archive from GitHub releases..."
    echo "   $URL"
    echo ""

    # Download to temp file
    TEMP_ARCHIVE=$(mktemp --suffix=.tar.gz)
    if ! curl -L -o "$TEMP_ARCHIVE" "$URL"; then
        echo "❌ Failed to download script_exporter archive"
        rm -f "$TEMP_ARCHIVE"
        return 1
    fi

    echo "✅ Download complete"
    echo ""
    echo "📦 Extracting and installing binary to $SCRIPT_EXPORTER_BINARY..."

    # Extract and install binary
    TEMP_DIR=$(mktemp -d)
    if ! tar -xzf "$TEMP_ARCHIVE" -C "$TEMP_DIR"; then
        echo "❌ Failed to extract archive"
        rm -f "$TEMP_ARCHIVE"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Find the binary (should be script_exporter in the extracted directory)
    EXTRACTED_BINARY=$(find "$TEMP_DIR" -name "script_exporter" -type f | head -1)
    if [ -z "$EXTRACTED_BINARY" ]; then
        echo "❌ Could not find script_exporter binary in archive"
        rm -f "$TEMP_ARCHIVE"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    # Install binary
    sudo mv "$EXTRACTED_BINARY" "$SCRIPT_EXPORTER_BINARY"
    sudo chmod +x "$SCRIPT_EXPORTER_BINARY"

    # Cleanup
    rm -f "$TEMP_ARCHIVE"
    rm -rf "$TEMP_DIR"

    echo "✅ Binary installed successfully"
    echo ""

    # Verify installation
    if command -v script_exporter >/dev/null 2>&1 && script_exporter --version >/dev/null 2>&1; then
        VERSION_OUTPUT=$(script_exporter --version 2>&1 | head -1)
        echo "✅ Installation verified: $VERSION_OUTPUT"
        return 0
    else
        echo "❌ Installation verification failed"
        return 1
    fi
}

# Post-installation notes
post_installation_message() {
    local otel_version
    otel_version=$(otelcol-contrib --version 2>/dev/null | head -1 || echo "not found")

    local script_exp_version
    script_exp_version=$(script_exporter --version 2>/dev/null | head -1 || echo "not found")

    echo
    echo "🎉 Installation complete!"
    echo "   OTEL Collector: $otel_version"
    echo "   script_exporter: $script_exp_version"
    echo
    echo "Next steps:"
    echo "1. Configure identity: bash .devcontainer/additions/config-devcontainer-identity.sh"
    echo "2. Start service: bash .devcontainer/additions/service-otel-monitoring.sh start"
    echo "3. View dashboards: http://grafana.localhost"
    echo
    echo "Docs: $OTEL_CONFIG_DIR/README-otel.md"
    echo
}

# Post-uninstallation notes
post_uninstallation_message() {
    echo
    echo "🏁 Uninstallation complete!"
    if command -v otelcol-contrib >/dev/null 2>&1; then
        echo "   ⚠️  OTEL Collector still found in PATH"
    else
        echo "   ✅ OTEL Collector removed"
    fi
    if [ -f "$SCRIPT_EXPORTER_BINARY" ]; then
        echo "   ⚠️  script_exporter still found"
    else
        echo "   ✅ script_exporter removed"
    fi
    echo
    echo "Note: Config preserved at $OTEL_CONFIG_DIR"
    echo "To remove: rm -rf $OTEL_CONFIG_DIR ~/.devcontainer-identity"
    echo
}

#------------------------------------------------------------------------------
# ARGUMENT PARSING
#------------------------------------------------------------------------------

# Initialize mode flags
DEBUG_MODE=0
UNINSTALL_MODE=0
FORCE_MODE=0

# Source common installation patterns library (needed for --help)
source "${SCRIPT_DIR}/lib/install-common.sh"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_script_help
            exit 0
            ;;
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --uninstall)
            UNINSTALL_MODE=1
            shift
            ;;
        --force)
            FORCE_MODE=1
            shift
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Usage: $0 [--help] [--debug] [--uninstall] [--force]" >&2
            echo "Description: $SCRIPT_DESCRIPTION"
            exit 1
            ;;
    esac
done

# Export mode flags
export DEBUG_MODE
export UNINSTALL_MODE
export FORCE_MODE

#------------------------------------------------------------------------------
# SOURCE CORE SCRIPTS
#------------------------------------------------------------------------------

# Source core installation scripts
source "${SCRIPT_DIR}/lib/core-install-system.sh"
source "${SCRIPT_DIR}/lib/core-install-extensions.sh"

# Note: lib/install-common.sh already sourced earlier (needed for --help)

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

# Function to process installations
process_installations() {
    # Custom OpenTelemetry Collector installation first
    install_otel_collector || exit 1

    # Then script_exporter
    install_script_exporter || exit 1

    # Then use standard processing from lib/install-common.sh
    process_standard_installations
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

if [ "${UNINSTALL_MODE}" -eq 1 ]; then
    show_install_header "uninstall"
    pre_installation_setup
    process_installations
    post_uninstallation_message

    # Remove from auto-enable config
    auto_disable_tool
else
    show_install_header
    pre_installation_setup
    process_installations
    post_installation_message

    # Auto-enable for container rebuild
    auto_enable_tool
fi

echo "✅ Script execution finished."
exit 0
