#!/bin/bash
# filename: 01-setup-authentik.sh
# description: Setup Authentik authentication system with forward auth, OAuth2, SAML, and MFA support
# 
# Architecture:
# - Authentik server and worker pods with PostgreSQL backend
# - Traefik forward authentication middleware
# - Embedded outpost for forward auth integration
# - Whoami test application for verification
# - Complete authentication flow with redirect handling
#
# Prerequisites:
# - PostgreSQL database running in default namespace
# - Redis running in default namespace  
# - Traefik deployed and configured
# - urbalurba-secrets in authentik namespace
# - Helm repos configured
#
# Usage: ./01-setup-authentik.sh [target-host] [deploy-test-apps]
# Example: ./01-setup-authentik.sh rancher-desktop true
#
# Note: This script must be run from within the provision-host container:
#   ./login-provision-host.sh
#   ./provision-host/kubernetes/12-auth/not-in-use/01-setup-authentik.sh
# 
# Deployment: 
#   MANUAL - Must be run manually (in not-in-use/ subfolder)
#   Move to main folder to enable auto-deployment during install-rancher.sh
#
# TODO: Configuration Management Improvements
# =========================================
# Current Stage: Using hardcoded configuration (manifests/070-authentik-complete-hardcoded.yaml)
# 
# Next Stage: Migrate to using variables from Kubernetes secrets
# - Replace hardcoded values with secret references
# - Update Helm values to use secret-based configuration
# - Remove dependency on hardcoded configuration files
#
# Final Stage: Clean up legacy configuration files
# - Remove manifests/070-authentik-config.yaml (no longer needed)
# - Remove manifests/070-authentik-minimal.yaml (no longer needed)
# - Keep only the production-ready secret-based configuration
#
# Benefits of migration:
# - Better security through centralized secret management
# - Easier configuration updates without code changes
# - Better compliance with Kubernetes best practices
# - Simplified deployment and maintenance

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
PLAYBOOK_PATH_SETUP_AUTHENTIK="$ANSIBLE_DIR/playbooks/070-setup-authentik.yml"

# Check if TARGET_HOST is provided as an argument, otherwise set default
TARGET_HOST=${1:-"rancher-desktop"}
DEPLOY_TEST_APPS=${2:-true}

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
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$TARGET_HOST -e deploy_test_apps=$DEPLOY_TEST_APPS $extra_args
    local result=$?
    check_command_success "$step" $result
    return $result
}

# Function to check Kubernetes secret
check_secret() {
    local namespace="authentik"
    local secret_name="urbalurba-secrets"
    
    echo "Checking if $secret_name exists in $namespace namespace..."
    kubectl get secret $secret_name -n $namespace &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Secret '$secret_name' not found in namespace '$namespace'"
        echo "Please create the secret before running this script"
        echo ""
        echo "Example:"
        echo "kubectl create secret generic $secret_name -n $namespace \\"
        echo "  --from-literal=AUTHENTIK_SECRET_KEY=your-secret-key \\"
        echo "  --from-literal=AUTHENTIK_POSTGRESQL__PASSWORD=your-postgres-password"
        return 1
    fi
    
    echo "Secret '$secret_name' found in namespace '$namespace'"
    return 0
}

# Function to check dependencies
check_dependencies() {
    echo "Checking system dependencies..."
    
    # Check PostgreSQL
    kubectl get pods -n default | grep -q postgresql
    if [ $? -ne 0 ]; then
        echo "❌ PostgreSQL not found in default namespace"
        echo "   Required: PostgreSQL deployment running in 'default' namespace"
        echo "   Solutions:"
        echo "   1. Deploy PostgreSQL: ./provision-host/kubernetes/02-databases/01-setup-postgresql.sh"
        echo "   2. Check status: kubectl get pods -n default | grep postgres"
        return 1
    fi
    
    # Check Redis  
    kubectl get pods -n default | grep -q redis
    if [ $? -ne 0 ]; then
        echo "❌ Redis not found in default namespace"
        echo "   Required: Redis deployment running in 'default' namespace"
        echo "   Solutions:"
        echo "   1. Deploy Redis: ./provision-host/kubernetes/03-queues/01-setup-redis.sh"
        echo "   2. Check status: kubectl get pods -n default | grep redis"
        return 1
    fi
    
    # Check Traefik
    kubectl get pods -n traefik-system &>/dev/null || kubectl get pods -n kube-system | grep -q traefik
    if [ $? -ne 0 ]; then
        echo "❌ Traefik not found"
        echo "   Required: Traefik ingress controller running"
        echo "   Solutions:"
        echo "   1. Check Traefik status: kubectl get pods -A | grep traefik"
        echo "   2. Deploy Traefik if needed"
        return 1
    fi
    
    echo "✅ All dependencies found"
    return 0
}

# Function to check if Helm repos are added
check_helm_repos() {
    echo "Checking Helm repositories..."
    local required_repos=("authentik")
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
        echo "All required Helm repositories are present"
    fi
    
    return 0
}

# Main execution
main() {
    echo "Starting Authentik Authentication System Setup on $TARGET_HOST"
    echo "-----------------------------------------------------------"
    
    # Check prerequisites
    check_dependencies || return 1
    check_secret || return 1
    check_helm_repos
    
    # Run whoami setup first (independent verification)
    echo ""
    echo "Step 1: Setting up whoami test application..."
    echo "-----------------------------------------------------------"
    cd $ANSIBLE_DIR && ansible-playbook playbooks/025-setup-whoami-testpod.yml
    local whoami_result=$?
    if [ $whoami_result -ne 0 ]; then
        add_status "Whoami Setup" "Fail"
        add_error "Whoami Setup" "Whoami test application setup failed with exit code $whoami_result"
        print_summary
        return 1
    fi
    add_status "Whoami Setup" "OK"
    
    echo ""
    echo "Step 2: Running main Authentik deployment..."
    echo "-----------------------------------------------------------"
    
    # Run the Ansible playbook to set up Authentik
    run_playbook "Setup Authentik Authentication System" "$PLAYBOOK_PATH_SETUP_AUTHENTIK" || {
        echo "⚠️  Ansible playbook completed with warnings or errors"
        echo ""
        echo "📝 Common Issues and Solutions:"
        echo "  • External access test failures are NORMAL during deployment"
        echo "  • These failures don't mean the deployment is broken"
        echo "  • Check if pods are running and healthy instead"
        echo ""
        echo "🔍 Check Deployment Status:"
        echo "  kubectl get pods -n authentik"
        echo "  kubectl get svc -n authentik"
        echo "  kubectl get ingress -n authentik"
        echo ""
        echo "✅ Deployment is successful if:"
        echo "  • 2+ pods are Running in authentik namespace"
        echo "  • Services are created and healthy"
        echo "  • Ingress is configured"
        echo ""
        echo "🌐 Test External Access (from host machine):"
        echo "  curl -I http://authentik.localhost/if/admin/"
        echo "  curl -L http://whoami.localhost"
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the 'urbalurba-secrets' secret exists and has all required keys"
        echo "  - Verify dependencies: PostgreSQL, Redis, and Traefik must be running"
    }
    
    print_summary
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Print summary
print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "The Authentik Authentication System has been deployed to the 'authentik' namespace."
        echo ""
        echo "Components installed:"
        echo "- Authentik server and worker pods"
        echo "- PostgreSQL database integration"
        echo "- Traefik forward authentication middleware"
        echo "- Whoami test application"
        echo "- Complete authentication flow"
        echo ""
        
        # Verify deployment status
        echo "Verifying deployment status..."
        echo "Note: Some pods might still be initializing."
        
        # Count running pods
        RUNNING_PODS=$(kubectl get pods -n authentik | grep Running | wc -l)
        TOTAL_PODS=$(kubectl get pods -n authentik | grep -v NAME | wc -l)
        INIT_PODS=$(kubectl get pods -n authentik | grep -E 'ContainerCreating|Init:' | wc -l)
        
        echo "Running pods: $RUNNING_PODS / $TOTAL_PODS"
        echo "Initializing pods: $INIT_PODS"
        
        if [ "$INIT_PODS" -gt 0 ]; then
            echo "Some pods are still initializing. This is normal for first-time deployments."
            echo "Authentik may take 5-10 minutes to become fully ready."
        fi
        
        echo ""
        echo "🎉 Authentik Authentication System Setup Complete!"
        echo ""
        echo "🔑 Access Information:"
        echo "  Admin Interface: http://authentik.localhost/if/admin/"
        echo "  Default Login: admin@urbalurba.local"
        echo "  Default Password: SecretPassword1"
        echo ""
        echo "🧪 Test Authentication:"
        echo "  1. Visit: http://whoami.localhost"
        echo "  2. Should redirect to: http://authentik.localhost/if/flow/..."
        echo "  3. Login with admin credentials"
        echo "  4. Should redirect back to whoami with authentication headers"
        echo ""
        echo "🔍 Important Notes:"
        echo "  • External access tests may fail during deployment (this is normal)"
        echo "  • External access requires host machine DNS resolution for *.localhost"
        echo "  • The deployment is successful if pods are running and healthy"
        echo ""
        echo "🔧 Verification Commands:"
        echo "  Check pods: kubectl get pods -n authentik"
        echo "  Check ingress: kubectl get ingress -n authentik"
        echo "  Check middleware: kubectl get middleware -n default"
        echo "  Check logs: kubectl logs -n authentik deployment/authentik-server"
        echo "  Test external access: curl -I http://authentik.localhost/if/admin/"
        echo ""
        echo "🎯 Architecture Deployed:"
        echo "  User Request → Traefik → Forward Auth Middleware →"
        echo "  Authentik Embedded Outpost → OAuth2 Redirect → Authentik Login →"
        echo "  OAuth2 Callback → Whoami Application (with auth headers)"
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the 'authentik' namespace exists: kubectl get ns authentik"
        echo "  - Check if pods are running: kubectl get pods -n authentik"
        echo "  - Check PostgreSQL: kubectl get pods -n default | grep postgres"
        echo "  - Check Redis: kubectl get pods -n default | grep redis"
        echo "  - Check Traefik: kubectl get pods -A | grep traefik"
        echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n authentik"
        echo "  - Check Helm releases: helm list -n authentik"
        echo "  - Make sure the 'urbalurba-secrets' secret exists and has all required keys"
        echo "  - Verify dependencies: PostgreSQL, Redis, and Traefik must be running"
    fi
}

# Run the main function and exit with its return code
main
exit $?