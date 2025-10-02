#!/bin/bash

# Complete Monitoring Stack Setup Script
# Orchestrates installation of all monitoring components via individual setup scripts

set -e

TARGET_HOST=${1:-rancher-desktop}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Complete Monitoring Stack Setup"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo ""
echo "🚀 This will install the complete observability stack:"
echo "   1. Prometheus (metrics backend)"
echo "   2. Tempo (traces backend)"
echo "   3. Loki (logs backend)"
echo "   4. OTEL Collector (telemetry collection)"
echo "   5. Grafana (visualization)"
echo "   6. Test Data (validation)"
echo ""
echo "📝 Installation order ensures proper dependencies"
echo ""

# Track installation status
FAILED_COMPONENTS=()
SUCCESS_COMPONENTS=()

# Function to run component setup
run_component_setup() {
    local component_name=$1
    local script_name=$2

    echo ""
    echo "=========================================="
    echo "Installing: $component_name"
    echo "=========================================="

    if bash "$SCRIPT_DIR/$script_name" "$TARGET_HOST"; then
        SUCCESS_COMPONENTS+=("$component_name")
        echo "✅ $component_name installation completed"
    else
        FAILED_COMPONENTS+=("$component_name")
        echo "❌ $component_name installation failed"
        echo "⚠️  Continuing with remaining components..."
    fi
}

# Install components in dependency order
echo "🚀 Starting monitoring stack installation..."
echo ""

# 1. Prometheus (metrics backend) - must be first
run_component_setup "Prometheus" "01-setup-prometheus.sh"

# 2. Tempo (traces backend)
run_component_setup "Tempo" "02-setup-tempo.sh"

# 3. Loki (logs backend)
run_component_setup "Loki" "03-setup-loki.sh"

# 4. OTEL Collector (depends on Prometheus, Tempo, Loki)
run_component_setup "OTEL Collector" "04-setup-otel-collector.sh"

# 5. Grafana (visualization layer)
run_component_setup "Grafana" "05-setup-grafana.sh"

# 6. Test Data (validation)
run_component_setup "Test Data" "06-setup-testdata.sh"

# Display installation summary
echo ""
echo "=========================================="
echo "INSTALLATION SUMMARY"
echo "=========================================="
echo ""

if [ ${#SUCCESS_COMPONENTS[@]} -gt 0 ]; then
    echo "✅ Successfully installed components:"
    for component in "${SUCCESS_COMPONENTS[@]}"; do
        echo "   - $component"
    done
    echo ""
fi

if [ ${#FAILED_COMPONENTS[@]} -gt 0 ]; then
    echo "❌ Failed components:"
    for component in "${FAILED_COMPONENTS[@]}"; do
        echo "   - $component"
    done
    echo ""
    echo "⚠️  Some components failed to install. Check the logs above for details."
    echo ""
fi

# Display overall status
echo "=========================================="
if [ ${#FAILED_COMPONENTS[@]} -eq 0 ]; then
    echo "🎉 MONITORING STACK INSTALLATION COMPLETED SUCCESSFULLY!"
    echo "=========================================="
    echo ""
    echo "📊 All Components Deployed:"
    echo "   ✅ Prometheus (metrics backend)"
    echo "   ✅ Tempo (traces backend)"
    echo "   ✅ Loki (logs backend)"
    echo "   ✅ OTEL Collector (telemetry collection)"
    echo "   ✅ Grafana (visualization)"
    echo "   ✅ Test Data (validation dashboards)"
    echo ""
    echo "🔗 OTLP Pipeline:"
    echo "   Application → OTEL Collector (4318/4317) → Loki/Tempo/Prometheus → Grafana"
    echo ""
    echo "🌐 Access Points:"
    echo "   - Grafana: http://grafana.localhost"
    echo "   - Installation Test Suite: http://grafana.localhost/d/installation-test-suite"
    echo ""
    echo "🧪 Verification:"
    echo "   kubectl get pods -n monitoring"
    echo "   helm list -n monitoring"
    echo ""
    exit 0
else
    echo "⚠️  MONITORING STACK INSTALLATION COMPLETED WITH ERRORS"
    echo "=========================================="
    echo ""
    echo "Successful: ${#SUCCESS_COMPONENTS[@]} components"
    echo "Failed: ${#FAILED_COMPONENTS[@]} components"
    echo ""
    echo "Please review the errors above and retry failed components individually."
    echo ""
    exit 1
fi