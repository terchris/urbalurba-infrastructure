#!/bin/bash
# filename: create-kubernetes-secrets.sh
# description: Modular secrets management system with backward compatibility
#
# This script:
# 1. Auto-initializes secrets-config/ from secrets-templates/ on first run
# 2. Generates kubernetes-secrets.yml from modular templates
# 3. Maintains backward compatibility with existing automation
#
# Exit codes:
# 0 - Success
# 1 - Error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define paths
SECRETS_TEMPLATES_DIR="$SCRIPT_DIR/secrets-templates"
SECRETS_CONFIG_DIR="$SCRIPT_DIR/secrets-config"
SECRETS_GENERATED_DIR="$SCRIPT_DIR/secrets-generated"
KUBERNETES_DIR="$SCRIPT_DIR/kubernetes"
FINAL_SECRETS_FILE="$KUBERNETES_DIR/kubernetes-secrets.yml"

# Backward compatibility: also check for legacy template
LEGACY_TEMPLATE="$KUBERNETES_DIR/kubernetes-secrets-template.yml"

echo "Kubernetes Secrets Generator (Modular)"
echo "====================================="
echo

# Function to show error and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Check if we have the new modular system
if [ -d "$SECRETS_TEMPLATES_DIR" ]; then
    echo "Using modular secrets management system..."

    # Step 1: Auto-initialize secrets-config if it doesn't exist
    if [ ! -d "$SECRETS_CONFIG_DIR" ]; then
        echo "First time setup: Initializing secrets-config/ from templates..."
        cp -r "$SECRETS_TEMPLATES_DIR" "$SECRETS_CONFIG_DIR" || error_exit "Failed to copy templates"
        echo "✅ Created secrets-config/ - you can now customize your secrets there"
        echo
    fi

    # Step 2: Create generated directory if needed
    mkdir -p "$SECRETS_GENERATED_DIR"
    mkdir -p "$KUBERNETES_DIR"

    # Step 3: Check for required files
    COMMON_VALUES_TEMPLATE="$SECRETS_CONFIG_DIR/00-common-values.env.template"
    MASTER_TEMPLATE="$SECRETS_CONFIG_DIR/00-master-secrets.yml.template"

    if [ ! -f "$COMMON_VALUES_TEMPLATE" ]; then
        error_exit "Common values template not found: $COMMON_VALUES_TEMPLATE"
    fi

    if [ ! -f "$MASTER_TEMPLATE" ]; then
        error_exit "Master secrets template not found: $MASTER_TEMPLATE"
    fi

    # Step 4: Generate common values
    echo "Generating common values..."
    GENERATED_COMMON_VALUES="$SECRETS_GENERATED_DIR/00-common-values.env"

    # Process the common values template (replace any ${VARIABLE} references)
    # For now, we'll copy it directly since the template should have actual values
    cp "$COMMON_VALUES_TEMPLATE" "$GENERATED_COMMON_VALUES" || error_exit "Failed to generate common values"

    echo "Loading common values from: $GENERATED_COMMON_VALUES"

    # Step 5: Load common values as environment variables
    if [ -f "$GENERATED_COMMON_VALUES" ]; then
        # Export all variables from the common values file
        set -a  # Enable automatic export of variables
        source "$GENERATED_COMMON_VALUES" || error_exit "Failed to load common values"
        set +a  # Disable automatic export
    fi

    # Step 6: Generate to temporary file first for validation
    echo "Generating kubernetes secrets from master template..."
    TEMP_SECRETS_FILE="$KUBERNETES_DIR/kubernetes-secrets.yml.tmp"

    # Use envsubst to substitute variables in the master template
    envsubst < "$MASTER_TEMPLATE" > "$TEMP_SECRETS_FILE" || error_exit "Failed to generate secrets file"

    # Step 6b: Process ConfigMaps
    echo "Processing ConfigMaps..."
    CONFIGMAPS_TEMPLATES_DIR="$SECRETS_TEMPLATES_DIR/configmaps"
    CONFIGMAPS_CONFIG_DIR="$SECRETS_CONFIG_DIR/configmaps"

    # Initialize configmaps directory if templates exist but config doesn't
    if [ -d "$CONFIGMAPS_TEMPLATES_DIR" ] && [ ! -d "$CONFIGMAPS_CONFIG_DIR" ]; then
        echo "Initializing ConfigMaps from templates..."
        cp -r "$CONFIGMAPS_TEMPLATES_DIR" "$CONFIGMAPS_CONFIG_DIR" || error_exit "Failed to copy configmap templates"
        echo "✅ Created configmaps/ - you can now customize your ConfigMaps there"
    fi

    # Process ConfigMaps if directory exists
    if [ -d "$CONFIGMAPS_CONFIG_DIR" ]; then
        echo "Discovering ConfigMaps..."

        # Find all template files in configmaps directory
        find "$CONFIGMAPS_CONFIG_DIR" -name "*.template" -type f | while read -r template_file; do
            # Get relative path from configmaps dir
            rel_path="${template_file#$CONFIGMAPS_CONFIG_DIR/}"
            echo "  Found: $rel_path"

            # Extract namespace and category from path
            # Example: monitoring/dashboards/my-dashboard.json.template
            namespace=$(echo "$rel_path" | cut -d'/' -f1)
            category=$(echo "$rel_path" | cut -d'/' -f2)
            filename=$(basename "$template_file" .template)
            base_name=$(basename "$filename" | sed 's/\.[^.]*$//')

            # Generate ConfigMap name
            configmap_name="${namespace}-${category}-${base_name}"
            # Sanitize name (lowercase, replace special chars)
            configmap_name=$(echo "$configmap_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

            echo "  Generating ConfigMap: $configmap_name in namespace $namespace"

            # Process template with envsubst for variable substitution
            content=$(envsubst < "$template_file")

            # Determine labels based on directory conventions
            labels=""
            if [[ "$category" == "dashboards" ]]; then
                labels="    grafana_dashboard: \"1\""
            elif [[ "$category" == "nginx" ]]; then
                labels="    app: nginx"
            elif [[ "$category" == "otel" ]]; then
                labels="    app.kubernetes.io/name: otel-collector"
            else
                labels="    managed-by: secrets-pipeline"
            fi

            # Append ConfigMap to temporary file
            cat >> "$TEMP_SECRETS_FILE" << EOF

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configmap_name
  namespace: $namespace
  labels:
$labels
data:
  $filename: |
$(echo "$content" | sed 's/^/    /')
EOF
        done

        echo "✅ ConfigMaps processing completed"
    fi

    # Step 7: Validate BEFORE overwriting
    echo "Validating generated secrets file..."
    VALIDATION_PASSED=true
    if command -v kubectl >/dev/null 2>&1; then
        kubectl apply --dry-run=client -f "$TEMP_SECRETS_FILE" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Generated secrets file YAML validation passed"
        else
            echo "⚠️  Warning: Generated secrets file failed Kubernetes validation"
            echo "   This might be normal if some namespaces don't exist yet"
            VALIDATION_PASSED=false
        fi
    else
        echo "⚠️  kubectl not available, skipping YAML validation"
    fi

    # Step 8: Backup existing file if it exists
    if [ -f "$FINAL_SECRETS_FILE" ]; then
        BACKUP_FILE="$KUBERNETES_DIR/kubernetes-secrets.yml.backup-$(date +%Y%m%d-%H%M%S)"
        echo "Backing up existing secrets to: $BACKUP_FILE"
        cp "$FINAL_SECRETS_FILE" "$BACKUP_FILE"
    fi

    # Step 9: Move validated file to final location
    mv "$TEMP_SECRETS_FILE" "$FINAL_SECRETS_FILE" || error_exit "Failed to move secrets file to final location"

    echo
    echo "✅ Secrets generation completed!"
    echo "Generated file: $FINAL_SECRETS_FILE"
    echo
    echo "To deploy secrets:"
    echo "  kubectl apply -f $FINAL_SECRETS_FILE"
    echo
    echo "To customize values:"
    echo "  Edit files in: $SECRETS_CONFIG_DIR"
    echo "  Then run: $0"

    exit 0

# Backward compatibility: Fall back to legacy system
elif [ -f "$LEGACY_TEMPLATE" ]; then
    echo "Using legacy secrets management system..."
    echo "Note: Consider upgrading to the modular system for better maintainability"
    echo

    # Legacy behavior: Check if secrets file exists
    if [ ! -f "$FINAL_SECRETS_FILE" ]; then
        echo "Kubernetes secrets file not found at: $FINAL_SECRETS_FILE"
        echo ""
        echo "There is a template file that contains default values."
        echo "You should copy and edit it to add your own secrets."
        echo "Read doc/kubernetes-secrets-readme.md for more information."
        echo ""
        echo "But if you just want the system to run, you can continue with default values."
        echo ""

        read -p "Do you want to continue with default values? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "To create the secrets file:"
            echo "1. Copy the template:"
            echo "   cp $LEGACY_TEMPLATE $FINAL_SECRETS_FILE"
            echo ""
            echo "2. Edit the file with your values:"
            echo "   # The file contains all necessary variables with descriptions"
            echo "   # Each variable has a comment explaining its purpose"
            echo "   # Replace the placeholder values with your actual values"
            echo ""
            echo "For detailed information about the secrets and their default values,"
            echo "please read doc/kubernetes-secrets-readme.md"
            echo ""
            echo "After editing the file, run './install-rancher.sh' again to continue the installation."
            exit 1
        fi
        echo "Using default values from kubernetes-secrets-template.yml"
        cp "$LEGACY_TEMPLATE" "$FINAL_SECRETS_FILE" || error_exit "Failed to copy legacy template"
        echo "Kubernetes secrets file created at: $FINAL_SECRETS_FILE"
        exit 0
    fi

    echo "Kubernetes secrets file exists at: $FINAL_SECRETS_FILE"
    exit 0

else
    error_exit "No secrets templates found. Expected either:
  - Modular system: $SECRETS_TEMPLATES_DIR/
  - Legacy system: $LEGACY_TEMPLATE"
fi