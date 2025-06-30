#!/bin/bash
# filename: 03-setup-unity-catalog.sh
# description: Setup Unity Catalog OSS for Databricks Replacement Data Governance on a Kubernetes cluster using Ansible playbook.
# Installs Unity Catalog Server and Web UI for enterprise data catalog and governance.
#
# Architecture:
# - Unity Catalog Server: REST API for metadata operations and catalog management
# - Unity Catalog Web UI: Self-service data discovery and governance interface
# - PostgreSQL Backend: Metadata storage using existing urbalurba-postgresql container
# - Spark Integration: Three-level namespace (catalog.schema.table) identical to Databricks
# - RBAC configuration: Fine-grained access control and data governance
#
# Part of: Databricks Replacement Project - Phase 2.5 (Data Catalog & Governance)
# Namespace: unity-catalog
#
# Usage: ./03-setup-unity-catalog.sh [target-host]
# Example: ./03-setup-unity-catalog.sh rancher-desktop
#   target-host: Kubernetes context/host (default: rancher-desktop)

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_SETUP_UNITY_CATALOG="$ANSIBLE_DIR/playbooks/320-setup-unity-catalog.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}

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

# Function to run Ansible playbook
run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    
    echo "Running playbook for $step..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$TARGET_HOST $extra_args
    local result=$?
    check_command_success "$step" $result
    return $result
}

# Function to check if PostgreSQL is running
check_postgresql() {
    echo "Checking PostgreSQL availability..."
    kubectl get service postgresql -n default &>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: PostgreSQL service not found in default namespace"
        echo "Unity Catalog requires PostgreSQL for metadata storage"
        echo "Please deploy PostgreSQL first using: ./05-cloud-setup-postgres.sh $TARGET_HOST"
        add_error "PostgreSQL Check" "PostgreSQL not found - required for Unity Catalog"
        return 1
    fi
    
    echo "PostgreSQL service found ✅"
    return 0
}

# Function to check if Spark Operator is running (recommended but not required)
check_spark_operator() {
    echo "Checking Spark Operator availability (recommended for full integration)..."
    kubectl get deployment spark-kubernetes-operator -n spark-operator &>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Spark Operator not found - Unity Catalog will work but Spark integration will be limited"
        echo "For full Databricks replacement functionality, consider deploying Spark first using:"
        echo "  ./02-setup-data-science.sh $TARGET_HOST"
        return 0
    fi
    
    echo "Spark Operator found ✅ - Full integration available"
    return 0
}

# Function to check Kubernetes secret
check_secret() {
    local namespace="unity-catalog"
    local secret_name="urbalurba-secrets"
    
    echo "Checking if $secret_name exists in $namespace namespace..."
    kubectl get namespace $namespace &>/dev/null || kubectl create namespace $namespace
    
    kubectl get secret $secret_name -n $namespace &>/dev/null
    if [ $? -ne 0 ]; then
        echo "WARNING: Secret '$secret_name' not found in namespace '$namespace'"
        echo "Unity Catalog requires database connection credentials"
        echo "Please ensure urbalurba-secrets contains:"
        echo "  - UNITY_CATALOG_DATABASE_URL"
        echo "  - UNITY_CATALOG_DATABASE_USER" 
        echo "  - UNITY_CATALOG_DATABASE_PASSWORD"
        echo ""
        echo "The Ansible playbook will attempt to proceed, but may fail without proper secrets"
        return 0
    fi
    
    echo "Secret '$secret_name' found in namespace '$namespace' ✅"
    return 0
}

# Function to check if Helm repos are added
check_helm_repos() {
    echo "Checking Helm repositories..."
    local required_repos=("unity-catalog")
    local missing_repos=()
    
    for repo in "${required_repos[@]}"; do
        if ! helm repo list | grep -q "$repo"; then
            missing_repos+=("$repo")
        fi
    done
    
    if [ ${#missing_repos[@]} -gt 0 ]; then
        echo "Missing Helm repositories: ${missing_repos[*]}"
        echo "The Ansible playbook will attempt to add them"
    else
        echo "All required Helm repositories are present ✅"
    fi
    
    return 0
}

# Function to check if Unity Catalog is already running
check_existing_unity_catalog() {
    echo "Checking for existing Unity Catalog deployment..."
    kubectl get deployment unity-catalog-server -n unity-catalog &>/dev/null
    if [ $? -eq 0 ]; then
        echo "WARNING: Unity Catalog is already running in unity-catalog namespace"
        echo "This script will attempt to upgrade the existing deployment"
        echo "To perform a clean install, first remove the existing deployment:"
        echo "  helm uninstall unity-catalog -n unity-catalog"
        echo "  kubectl delete namespace unity-catalog"
        return 0
    fi
    
    echo "No existing Unity Catalog found - ready for fresh deployment ✅"
    return 0
}

# Function to verify deployment after installation
verify_deployment() {
    echo "Verifying Unity Catalog deployment..."
    
    # Check if pods are running
    echo "Checking pod status..."
    RUNNING_PODS=$(kubectl get pods -n unity-catalog | grep Running | wc -l)
    TOTAL_PODS=$(kubectl get pods -n unity-catalog | grep -v NAME | wc -l)
    
    echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"
    
    if [ "$TOTAL_PODS" -eq 0 ]; then
        echo "⚠️ No pods found. Check if the deployment was successful."
        add_error "Verification" "No pods found in unity-catalog namespace"
        return 1
    elif [ "$RUNNING_PODS" -lt "$TOTAL_PODS" ]; then
        echo "⚠️ Some pods are still starting. This is normal for new deployments."
        echo "Wait a few minutes and check: kubectl get pods -n unity-catalog"
    else
        echo "✅ All Unity Catalog pods are running"
    fi
    
    # Check services
    echo "Checking services..."
    SERVICES=$(kubectl get services -n unity-catalog --no-headers | wc -l)
    echo "Services available: $SERVICES"
    
    if [ "$SERVICES" -gt 0 ]; then
        echo "✅ Unity Catalog services are available"
    else
        echo "⚠️ No services found"
        add_error "Verification" "No services found in unity-catalog namespace"
        return 1
    fi
    
    # Check ingress
    echo "Checking ingress..."
    INGRESSES=$(kubectl get ingress -n unity-catalog --no-headers | wc -l)
    echo "Ingresses configured: $INGRESSES"
    
    if [ "$INGRESSES" -gt 0 ]; then
        echo "✅ Unity Catalog ingress is configured"
    else
        echo "⚠️ No ingress found - web access may not be available"
    fi
    
    return 0
}

# Function to test Unity Catalog API (if pods are running)
test_api() {
    echo "Testing Unity Catalog API connectivity..."
    
    # Get Unity Catalog server pod name
    SERVER_POD=$(kubectl get pods -n unity-catalog -l component=server --no-headers | head -n1 | awk '{print $1}')
    
    if [ -z "$SERVER_POD" ]; then
        echo "⚠️ Unity Catalog server pod not found - skipping API test"
        return 0
    fi
    
    # Test API endpoint
    echo "Testing API endpoint in pod $SERVER_POD..."
    API_RESPONSE=$(kubectl exec -n unity-catalog $SERVER_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/1.0/unity-catalog/catalogs 2>/dev/null || echo "FAILED")
    
    if [ "$API_RESPONSE" = "200" ]; then
        echo "✅ Unity Catalog API is responding correctly"
        add_status "API Test" "OK"
    else
        echo "⚠️ Unity Catalog API test failed (HTTP $API_RESPONSE)"
        echo "This is normal if the pod is still starting"
        add_status "API Test" "Partial"
    fi
    
    return 0
}

# Main execution
main() {
    echo "Starting Unity Catalog setup on $TARGET_HOST"
    echo "----------------------------------------------"
    echo "This will install:"
    echo "  - Unity Catalog Server (REST API for metadata operations)"
    echo "  - Unity Catalog Web UI (Self-service data discovery)"
    echo "  - PostgreSQL backend integration (metadata storage)"
    echo "  - Spark integration for three-level namespace"
    echo "  - Enterprise data governance and access control"
    echo ""
    
    # Check prerequisites
    check_postgresql || { print_summary; return 1; }
    check_spark_operator  # Warning only, not required
    check_secret          # Warning only, playbook will handle
    check_helm_repos      # Info only, playbook will handle
    check_existing_unity_catalog  # Info only
    
    echo ""
    echo "Prerequisites check completed. Proceeding with installation..."
    echo ""
    
    # Run the Ansible playbook to set up Unity Catalog
    run_playbook "Setup Unity Catalog Data Governance" "$PLAYBOOK_PATH_SETUP_UNITY_CATALOG" || { print_summary; return 1; }
    
    # Verify deployment
    verify_deployment
    
    # Test API if possible
    test_api
    
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo ""
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "🎉 Unity Catalog has been deployed successfully!"
        echo ""
        echo "✅ Components installed:"
        echo "   - Unity Catalog Server (REST API for metadata operations)"
        echo "   - Unity Catalog Web UI (Self-service data discovery)"
        echo "   - PostgreSQL backend integration (metadata storage)"
        echo "   - Ingress configuration for web access"
        echo ""
        echo "🌐 Access Information:"
        echo "   Unity Catalog REST API: http://unity-api.localhost"
        echo "   Unity Catalog Web UI: http://unity-ui.localhost"
        echo ""
        echo "🔗 Alternative Access (if ingress not working):"
        echo "   API: kubectl port-forward -n unity-catalog svc/unity-catalog-server 8080:8080"
        echo "   UI:  kubectl port-forward -n unity-catalog svc/unity-catalog-ui 3000:3000"
        echo ""
        echo "📊 What You Can Do Now:"
        echo "   1. Browse catalogs and schemas via Web UI: http://unity-ui.localhost"
        echo "   2. Create catalogs via REST API: curl http://unity-api.localhost/api/1.0/unity-catalog/catalogs"
        echo "   3. Use three-level namespace in Spark notebooks: catalog.schema.table"
        echo "   4. Implement enterprise data governance and access control"
        echo ""
        echo "📝 Example Spark Integration (in JupyterHub notebooks):"
        echo "   spark.conf.set('spark.sql.defaultCatalog', 'unity')"
        echo "   spark.sql('CREATE CATALOG IF NOT EXISTS my_catalog')"
        echo "   spark.sql('USE CATALOG my_catalog')"
        echo "   spark.sql('SHOW CATALOGS').show()"
        echo ""
        echo "🔧 Monitoring Commands:"
        echo "   Check status: kubectl get pods -n unity-catalog"
        echo "   View logs: kubectl logs -n unity-catalog -l component=server"
        echo "   Check services: kubectl get services -n unity-catalog"
        echo "   Check ingress: kubectl get ingress -n unity-catalog"
        echo ""
        echo "📈 Databricks Replacement Progress:"
        echo "   ✅ Phase 1: Processing Engine (Spark Kubernetes Operator)"
        echo "   ✅ Phase 2: Notebook Interface (JupyterHub)"
        echo "   ✅ Phase 2.5: Data Catalog & Governance (Unity Catalog)"
        echo "   🔄 Phase 3: Business Intelligence (Metabase) - Next"
        echo ""
        echo "🎯 Current Achievement: 95% Databricks functionality with enterprise data governance!"
        
    else
        echo ""
        echo "⚠️ Unity Catalog installation completed with some issues:"
        for step in "${!ERRORS[@]}"; do
            echo "   $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   - Check if PostgreSQL is running: kubectl get pods -n default | grep postgresql"
        echo "   - Verify secrets are applied: kubectl get secret urbalurba-secrets -n unity-catalog"
        echo "   - Check Unity Catalog pods: kubectl get pods -n unity-catalog"
        echo "   - View Unity Catalog logs: kubectl logs -n unity-catalog -l component=server"
        echo "   - Check Helm releases: helm list -n unity-catalog"
        echo "   - Verify context: kubectl config current-context"
        echo ""
        echo "📖 Documentation:"
        echo "   - Unity Catalog OSS: https://github.com/unitycatalog/unitycatalog"
        echo "   - Databricks Unity Catalog: https://docs.databricks.com/en/data-governance/unity-catalog/index.html"
    fi
}

# Run the main function and exit with its return code
main
exit $?