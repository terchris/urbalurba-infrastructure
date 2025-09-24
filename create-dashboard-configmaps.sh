#!/bin/bash
# create-dashboard-configmaps.sh
# Creates Kubernetes ConfigMaps from Grafana dashboard JSON files

set -e

DASHBOARD_DIR="manifests/grafana-dashboards"
OUTPUT_FILE="manifests/235-grafana-dashboards.yaml"
NAMESPACE="monitoring"

echo "# file: /mnt/urbalurbadisk/manifests/235-grafana-dashboards.yaml" > "$OUTPUT_FILE"
echo "# Grafana dashboards as ConfigMaps for sidecar auto-discovery" >> "$OUTPUT_FILE"
echo "#" >> "$OUTPUT_FILE"
echo "# Description:" >> "$OUTPUT_FILE"
echo "# - Creates ConfigMaps containing Grafana dashboard JSON files" >> "$OUTPUT_FILE"
echo "# - Uses label 'grafana_dashboard: \"1\"' for sidecar discovery" >> "$OUTPUT_FILE"
echo "# - Dashboards will be automatically loaded by Grafana sidecar" >> "$OUTPUT_FILE"
echo "#" >> "$OUTPUT_FILE"
echo "# Usage:" >> "$OUTPUT_FILE"
echo "#   kubectl apply -f manifests/235-grafana-dashboards.yaml" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

for dashboard_file in "$DASHBOARD_DIR"/*.json; do
    if [[ -f "$dashboard_file" ]]; then
        # Extract filename without path and extension
        filename=$(basename "$dashboard_file")
        name_without_ext="${filename%.json}"

        # Create safe ConfigMap name
        configmap_name="grafana-dashboard-$(echo "$name_without_ext" | sed 's/[^a-zA-Z0-9-]/-/g' | tr '[:upper:]' '[:lower:]')"

        echo "Creating ConfigMap for $filename..."

        cat << EOF >> "$OUTPUT_FILE"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configmap_name
  namespace: $NAMESPACE
  labels:
    grafana_dashboard: "1"
data:
  $filename: |
$(sed 's/^/    /' "$dashboard_file")

EOF
    fi
done

echo "Dashboard ConfigMaps created in $OUTPUT_FILE"
echo ""
echo "To apply the dashboards:"
echo "  kubectl apply -f $OUTPUT_FILE"