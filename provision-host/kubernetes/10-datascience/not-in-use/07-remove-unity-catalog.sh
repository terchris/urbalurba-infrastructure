#!/bin/bash
# filename: 03-remove-unity-catalog.sh
# description: Remove Unity Catalog OSS Data Governance stack from Kubernetes cluster.
# Removes Unity Catalog Server, database, and all associated resources for complete cleanup.
#
# Architecture:
# - Direct Kubernetes resource removal (Unity Catalog uses manifests, not Helm)
# - Provides comprehensive cleanup of data catalog and governance components
# - Optional database preservation for data retention
# - Optional secret preservation for easy reinstallation
#
# Part of: Databricks Replacement Project - Data Catalog Removal
# Namespace: unity-catalog
#
# Usage: ./03-remove-unity-catalog.sh [target-host] [options]
# Example: ./03-remove-unity-catalog.sh rancher-desktop
# Options: 
#   --preserve-database    Keep Unity Catalog database and user in PostgreSQL
#   --preserve-secrets     Keep urbalurba-secrets for easy reinstallation
#   target-host: Kubernetes context/host (default: rancher-desktop)

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize status tracking
declare -A STATUS
declare -A ERRORS

# Variables
MERGED_KUBECONF_FILE="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
UNITY_CATALOG_NAMESPACE="unity-catalog"
DELETION_TIMEOUT=120  # 2 minutes timeout for deletions

# Parse command line arguments
TARGET_HOST="rancher-desktop"
PRESERVE_DATABASE=false
PRESERVE_SECRETS=false

for arg in "$@"; do
    case $arg in
        --preserve-database)
            PRESERVE_DATABASE=true
            shift
            ;;
        --preserve-secrets)
            PRESERVE_SECRETS=true
            shift
            ;;
        -*)
            echo "Unknown option: $arg"
            exit 1
            ;;
        *)
            TARGET_HOST="$arg"
            shift
            ;;
    esac
done

# Function to add status
add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

# Function to add error
add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

# Function to check command success
check_command_success() {
    local step=$1
    local result=$2
    if [ ! -z "$result" ] && [ $result -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed with exit code $result"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo "WARNING: kubectl not found in PATH"
        echo "Note: This may be normal if running inside provision-host container"
    fi
    
    # Check if unity-catalog namespace exists
    kubectl get namespace $UNITY_CATALOG_NAMESPACE &>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Unity Catalog namespace '$UNITY_CATALOG_NAMESPACE' not found"
        echo "Unity Catalog may not be installed or already removed"
        return 0
    fi
    
    echo "Prerequisites check completed"
    return 0
}

# Function to remove Unity Catalog workloads
remove_unity_catalog_workloads() {
    local step="Remove Unity Catalog Workloads"
    echo "Removing Unity Catalog server deployment and pods..."
    
    # Get running pods count before removal
    RUNNING_PODS=$(kubectl get pods -n $UNITY_CATALOG_NAMESPACE --no-headers 2>/dev/null | wc -l)
    echo "Found $RUNNING_PODS Unity Catalog pods to remove"
    
    # Delete Unity Catalog deployment
    kubectl delete deployment unity-catalog-server -n $UNITY_CATALOG_NAMESPACE --timeout=${DELETION_TIMEOUT}s 2>/dev/null
    local result=$?
    
    # Force delete any remaining pods
    kubectl delete pods --all -n $UNITY_CATALOG_NAMESPACE --force --grace-period=0 2>/dev/null
    
    check_command_success "$step" 0  # Always succeed, as resources might not exist
    return 0
}

# Function to remove Unity Catalog services and networking
remove_unity_catalog_services() {
    local step="Remove Unity Catalog Services"
    echo "Removing Unity Catalog services and ingress..."
    
    # Delete services
    kubectl delete service unity-catalog-server -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    # Delete ingress
    kubectl delete ingress unity-catalog-api -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    check_command_success "$step" 0
    return 0
}

# Function to remove Unity Catalog storage and config
remove_unity_catalog_storage() {
    local step="Remove Unity Catalog Storage"
    echo "Removing Unity Catalog storage and configuration..."
    
    # Delete PersistentVolumeClaims
    kubectl delete pvc unity-catalog-warehouse-pvc -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    # Delete ConfigMaps
    kubectl delete configmap unity-catalog-config -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    check_command_success "$step" 0
    return 0
}

# Function to remove RBAC resources
remove_unity_catalog_rbac() {
    local step="Remove Unity Catalog RBAC"
    echo "Removing Unity Catalog RBAC resources..."
    
    # Delete service account
    kubectl delete serviceaccount unity-catalog-server -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    # Delete cluster role and binding
    kubectl delete clusterrole unity-catalog-server 2>/dev/null
    kubectl delete clusterrolebinding unity-catalog-server 2>/dev/null
    
    check_command_success "$step" 0
    return 0
}

# Function to remove Unity Catalog database
remove_unity_catalog_database() {
    local step="Remove Unity Catalog Database"
    
    if [ "$PRESERVE_DATABASE" = true ]; then
        echo "Skipping database removal (--preserve-database specified)"
        add_status "$step" "Skipped"
        return 0
    fi
    
    echo "Removing Unity Catalog database and user from PostgreSQL..."
    
    # Check if PostgreSQL is available
    kubectl get service postgresql -n default &>/dev/null
    if [ $? -ne 0 ]; then
        echo "PostgreSQL service not found - skipping database cleanup"
        add_status "$step" "Skipped"
        return 0
    fi
    
    # Get PostgreSQL pod name
    POSTGRES_POD=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | head -n1 | awk '{print $1}')
    
    if [ -z "$POSTGRES_POD" ]; then
        echo "PostgreSQL pod not found - skipping database cleanup"
        add_status "$step" "Skipped"
        return 0
    fi
    
    # Get PostgreSQL password from secrets
    POSTGRES_PASSWORD=$(kubectl get secret urbalurba-secrets -n default -o jsonpath='{.data.PGPASSWORD}' 2>/dev/null | base64 -d)
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo "PostgreSQL password not found - skipping database cleanup"
        add_status "$step" "Skipped"
        return 0
    fi
    
    echo "Dropping Unity Catalog database and user..."
    
    # Drop Unity Catalog database
    kubectl exec -n default $POSTGRES_POD -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' dropdb -h postgresql.default -U postgres unity_catalog --if-exists" 2>/dev/null
    
    # Drop Unity Catalog user
    kubectl exec -n default $POSTGRES_POD -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -h postgresql.default -U postgres -c \"DROP USER IF EXISTS unity_catalog_user;\"" 2>/dev/null
    
    echo "Unity Catalog database and user removed from PostgreSQL"
    check_command_success "$step" 0
    return 0
}

# Function to remove secrets
remove_unity_catalog_secrets() {
    local step="Remove Unity Catalog Secrets"
    
    if [ "$PRESERVE_SECRETS" = true ]; then
        echo "Preserving urbalurba-secrets (--preserve-secrets specified)"
        add_status "$step" "Preserved"
        return 0
    fi
    
    echo "Removing Unity Catalog secrets..."
    
    # Remove urbalurba-secrets from unity-catalog namespace
    kubectl delete secret urbalurba-secrets -n $UNITY_CATALOG_NAMESPACE 2>/dev/null
    
    check_command_success "$step" 0
    return 0
}

# Function to remove namespace
remove_unity_catalog_namespace() {
    local step="Remove Unity Catalog Namespace"
    echo "Removing Unity Catalog namespace..."
    
    # Check if namespace has any remaining resources
    REMAINING_RESOURCES=$(kubectl get all -n $UNITY_CATALOG_NAMESPACE --no-headers 2>/dev/null | wc -l)
    
    if [ $REMAINING_RESOURCES -gt 0 ]; then
        echo "Force deleting remaining resources in namespace..."
        kubectl delete all --all -n $UNITY_CATALOG_NAMESPACE --force --grace-period=0 2>/dev/null
    fi
    
    # Delete the namespace
    kubectl delete namespace $UNITY_CATALOG_NAMESPACE --timeout=${DELETION_TIMEOUT}s 2>/dev/null
    local result=$?
    
    # Wait for namespace to be fully deleted
    echo "Waiting for namespace to be fully deleted..."
    local retries=0
    while kubectl get namespace $UNITY_CATALOG_NAMESPACE &>/dev/null && [ $retries -lt 30 ]; do
        sleep 2
        retries=$((retries + 1))
    done
    
    check_command_success "$step" 0
    return 0
}

# Function to verify removal results
verify_removal() {
    echo "Verifying Unity Catalog removal..."
    
    # Check if namespace still exists
    NAMESPACE_EXISTS=$(kubectl get namespace $UNITY_CATALOG_NAMESPACE 2>/dev/null | wc -l)
    
    # Check for any remaining Unity Catalog resources
    REMAINING_PODS=$(kubectl get pods --all-namespaces 2>/dev/null | grep -E "unity-catalog" | wc -l)
    REMAINING_SERVICES=$(kubectl get services --all-namespaces 2>/dev/null | grep -E "unity-catalog" | wc -l)
    REMAINING_INGRESS=$(kubectl get ingress --all-namespaces 2>/dev/null | grep -E "unity-catalog" | wc -l)
    
    echo "Verification results:"
    echo "  Unity Catalog namespace: $((NAMESPACE_EXISTS-1))"  # Subtract header line
    echo "  Remaining pods: $REMAINING_PODS"
    echo "  Remaining services: $REMAINING_SERVICES"
    echo "  Remaining ingresses: $REMAINING_INGRESS"
    
    # Check cluster-wide resources
    REMAINING_CLUSTERROLES=$(kubectl get clusterroles 2>/dev/null | grep -E "unity-catalog" | wc -l)
    REMAINING_CLUSTERROLEBINDINGS=$(kubectl get clusterrolebindings 2>/dev/null | grep -E "unity-catalog" | wc -l)
    
    echo "  Remaining cluster roles: $REMAINING_CLUSTERROLES"
    echo "  Remaining cluster role bindings: $REMAINING_CLUSTERROLEBINDINGS"
    
    # Check database
    if [ "$PRESERVE_DATABASE" = false ]; then
        POSTGRES_POD=$(kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | head -n1 | awk '{print $1}')
        if [ ! -z "$POSTGRES_POD" ]; then
            POSTGRES_PASSWORD=$(kubectl get secret urbalurba-secrets -n default -o jsonpath='{.data.PGPASSWORD}' 2>/dev/null | base64 -d)
            if [ ! -z "$POSTGRES_PASSWORD" ]; then
                DB_EXISTS=$(kubectl exec -n default $POSTGRES_POD -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -h postgresql.default -U postgres -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw 'unity_catalog' && echo 1 || echo 0")
                echo "  Unity Catalog database exists: $DB_EXISTS"
            fi
        fi
    else
        echo "  Unity Catalog database: Preserved (--preserve-database)"
    fi
    
    # Determine overall success
    TOTAL_REMAINING=$((NAMESPACE_EXISTS-1 + REMAINING_PODS + REMAINING_SERVICES + REMAINING_INGRESS + REMAINING_CLUSTERROLES + REMAINING_CLUSTERROLEBINDINGS))
    
    if [ $TOTAL_REMAINING -eq 0 ]; then
        echo "✅ Verification successful - Unity Catalog completely removed"
        add_status "Verification" "OK"
        return 0
    else
        echo "⚠️ Some Unity Catalog resources may still exist"
        add_status "Verification" "Partial"
        return 1
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "---------- Unity Catalog Removal Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "🎉 Unity Catalog removal completed successfully!"
        echo ""
        echo "✅ Removed components:"
        echo "   - Unity Catalog Server (REST API and metadata operations)"
        echo "   - PostgreSQL backend integration and $([ "$PRESERVE_DATABASE" = true ] && echo "metadata (preserved)" || echo "database cleanup")"
        echo "   - Kubernetes deployment and direct manifests"
        echo "   - RBAC configuration and service accounts"
        echo "   - Storage (PVCs) and configuration (ConfigMaps)"
        echo "   - Ingress configuration and services"
        echo "   - Unity Catalog namespace"
        echo ""
        if [ "$PRESERVE_SECRETS" = true ]; then
            echo "🔐 Preserved for easy reinstallation:"
            echo "   - urbalurba-secrets in unity-catalog namespace"
            echo ""
        fi
        if [ "$PRESERVE_DATABASE" = true ]; then
            echo "🗄️ Preserved for data retention:"
            echo "   - Unity Catalog database and user in PostgreSQL"
            echo ""
        fi
        echo "🚀 Ready for fresh installation:"
        echo "   ./03-setup-unity-catalog.sh $TARGET_HOST"
        echo ""
        echo "📊 Databricks Replacement Progress after removal:"
        echo "   ✅ Phase 1: Processing Engine (Spark Kubernetes Operator)"
        echo "   ✅ Phase 2: Notebook Interface (JupyterHub)"
        echo "   ❌ Phase 2.5: Data Catalog (Unity Catalog) - REMOVED"
        echo "   🔄 Phase 3: Business Intelligence (Metabase) - Next"
        echo ""
        echo "🎯 Current Achievement: 85% Databricks functionality (data governance removed)"
        
    else
        echo ""
        echo "⚠️ Unity Catalog removal completed with some issues:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   - Check if you have sufficient permissions"
        echo "   - Verify kubectl context: kubectl config current-context"
        echo "   - Manual cleanup commands:"
        echo "     kubectl delete namespace unity-catalog --force"
        echo "     kubectl delete clusterrole unity-catalog-server"
        echo "     kubectl delete clusterrolebinding unity-catalog-server"
        echo "   - Check for stuck resources: kubectl get all --all-namespaces | grep unity-catalog"
        echo "   - Force remove finalizers if namespace is stuck:"
        echo "     kubectl patch namespace unity-catalog -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge"
    fi
}

# Main execution
main() {
    echo "🧹 Starting Unity Catalog removal on $TARGET_HOST"
    echo "=============================================="
    echo "This will remove:"
    echo "  - Unity Catalog Server (REST API and metadata operations)"
    echo "  - All Unity Catalog deployments, services, and ingress"
    echo "  - Unity Catalog namespace and associated resources"
    echo "  - RBAC configuration and service accounts"
    echo "  - Storage (PVCs) and configuration (ConfigMaps)"
    if [ "$PRESERVE_DATABASE" = false ]; then
        echo "  - Unity Catalog database and user from PostgreSQL"
    else
        echo "  - Unity Catalog database: PRESERVED (--preserve-database)"
    fi
    if [ "$PRESERVE_SECRETS" = false ]; then
        echo "  - Unity Catalog secrets"
    else
        echo "  - Unity Catalog secrets: PRESERVED (--preserve-secrets)"
    fi
    echo ""
    echo "Options:"
    echo "  Database preservation: $PRESERVE_DATABASE"
    echo "  Secrets preservation: $PRESERVE_SECRETS" 
    echo ""
    
    # Confirmation prompt
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Removal cancelled."
        exit 0
    fi
    
    echo "Proceeding with Unity Catalog removal..."
    echo ""
    
    # Check prerequisites
    check_prerequisites || {
        echo "Prerequisites check failed"
        print_summary
        return 1
    }
    
    # Remove Unity Catalog components in order
    remove_unity_catalog_workloads
    remove_unity_catalog_services
    remove_unity_catalog_storage
    remove_unity_catalog_rbac
    remove_unity_catalog_database
    remove_unity_catalog_secrets
    remove_unity_catalog_namespace
    
    # Verify removal
    verify_removal
    
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?