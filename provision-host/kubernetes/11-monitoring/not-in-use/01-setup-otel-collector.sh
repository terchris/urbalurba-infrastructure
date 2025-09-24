#!/bin/bash

# File: provision-host/kubernetes/11-monitoring/not-in-use/01-setup-otel-collector.sh
# Description: Deploy OpenTelemetry Collector for trace/log collection
# Usage: ./01-setup-otel-collector.sh [target-host]
# Example: ./01-setup-otel-collector.sh rancher-desktop

set -e

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/231-setup-otel-collector.yml"

# Default target host
DEFAULT_TARGET_HOST="rancher-desktop"

# Get target host from parameter or use default
TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"

echo "=========================================="
echo "OpenTelemetry Collector Deployment"
echo "=========================================="
echo "Target Host: $TARGET_HOST"
echo "Playbook: $PLAYBOOK_PATH"
echo

# Validate ansible playbook exists
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: Ansible playbook not found at $PLAYBOOK_PATH"
    exit 1
fi

# Execute ansible playbook
echo "Deploying OpenTelemetry Collector..."
ansible-playbook "$PLAYBOOK_PATH" -e "target_host=$TARGET_HOST"

echo
echo "✅ OpenTelemetry Collector deployment completed!"
echo
echo "Access:"
echo "  📊 OTLP gRPC endpoint: otel-collector.monitoring.svc.cluster.local:4317"
echo "  📊 OTLP HTTP endpoint: otel-collector.monitoring.svc.cluster.local:4318"
echo
echo "Next steps:"
echo "  🔄 Deploy Tempo: ./02-setup-tempo.sh $TARGET_HOST"
echo "  📋 Deploy Loki: ./03-setup-loki.sh $TARGET_HOST"