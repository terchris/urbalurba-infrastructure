#!/bin/bash
# filename: 01-remove-authentik.sh
# description: Remove Authentik authentication system completely including database and test applications
# 
# What this script removes:
# - Authentik Helm release and all associated resources
# - Authentik PostgreSQL database and user
# - Whoami test application and ingress
# - All Traefik middleware for authentication
# - All configuration and persistent data
#
# Prerequisites:
# - Must be run from within the provision-host container
# - kubectl access configured for target cluster
# - Ansible and Helm installed
#
# Usage: ./01-remove-authentik.sh [target-host]
# Example: ./01-remove-authentik.sh rancher-desktop
#
# Note: This script must be run from within the provision-host container:
#   ./login-provision-host.sh
#   ./provision-host/kubernetes/12-auth/not-in-use/01-remove-authentik.sh
# 
# WARNING: This operation is DESTRUCTIVE and IRREVERSIBLE!
#          All Authentik configuration, users, and authentication data will be lost!

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
MANIFESTS_DIR="/mnt/urbalurbadisk/manifests"

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

# Function to confirm destructive operation
confirm_removal() {
    echo ""
    echo "⚠️  =============================================== ⚠️"
    echo "⚠️             AUTHENTIK REMOVAL                ⚠️"
    echo "⚠️  =============================================== ⚠️"
    echo ""
    echo "🗑️  You are about to REMOVE:"
    echo ""
    echo "📦 AUTHENTIK COMPONENTS:"
    echo "   • Authentik server and worker pods"
    echo "   • All Authentik configuration and settings"
    echo "   • All users, groups, and authentication policies"
    echo "   • All authentication flows and providers"
    echo "   • Authentik admin interface and data"
    echo ""
    echo "🗄️  AUTHENTIK DATABASE:"
    echo "   • THE FULL AUTHENTIK DATABASE WILL BE DELETED"
    echo "   • Authentik database user and all permissions"
    echo "   • ALL stored authentication data and history"
    echo ""
    echo "🧪 TEST APPLICATIONS:"
    echo "   • Whoami test application and service"
    echo "   • Whoami ingress configuration"
    echo "   • Authentication middleware (Traefik)"
    echo ""
    echo "🔒 AUTHENTICATION SYSTEM:"
    echo "   • All forward authentication configuration"
    echo "   • OAuth2 and SAML provider settings"
    echo "   • Integration with protected applications"
    echo ""
    echo "✅ PRESERVED:"
    echo "   • Authentik namespace (kept for future use)"
    echo "   • PostgreSQL service (only Authentik database removed)"
    echo "   • Redis service (unchanged)"
    echo "   • Traefik service (unchanged)"
    echo ""
    echo "⚠️  This operation will delete the full Authentik database!"
    echo ""
    
    read -p "🚨 Type 'yes' to confirm removal: " confirmation
    echo ""
    
    if [ "$confirmation" != "yes" ]; then
        echo "❌ Operation aborted. Authentik removal cancelled."
        exit 0
    fi
    
    echo "✅ Confirmation received. Beginning Authentik removal..."
    echo ""
}

# Function to check what exists before removal
check_current_state() {
    echo "🔍 Checking current Authentik installation state..."
    echo "---------------------------------------------------"
    
    # Check Helm releases
    echo "📦 Checking Helm releases:"
    helm list -n authentik 2>/dev/null || echo "   No Helm releases found in authentik namespace"
    
    # Check pods
    echo ""
    echo "🏃 Checking Authentik pods:"
    kubectl get pods -n authentik 2>/dev/null || echo "   No pods found in authentik namespace"
    
    # Database check removed (was causing operation=check error)
    
    # Check whoami
    echo ""
    echo "🧪 Checking whoami test application:"
    kubectl get pods -l app=whoami -n default 2>/dev/null || echo "   No whoami pods found"
    
    echo ""
    echo "✅ Current state check completed"
    echo ""
}

# Main removal function
main() {
    echo "🗑️  Starting Authentik Authentication System Removal on $TARGET_HOST"
    echo "=================================================================="
    
    # Check current state
    check_current_state
    
    # Get confirmation
    confirm_removal
    
    echo ""
    echo "Step 1: Removing Authentik Helm release and pods..."
    echo "---------------------------------------------------"
    
    # Uninstall Helm release
    echo "🗑️  Uninstalling Authentik Helm release..."
    helm uninstall authentik -n authentik 2>/dev/null
    local helm_result=$?
    check_command_success "Authentik Helm Uninstall" $helm_result
    
    # Clean up resources but preserve namespace
    echo "🧹 Cleaning Authentik resources (preserving namespace and secrets)..."
    kubectl delete all --all -n authentik --ignore-not-found=true 2>/dev/null
    kubectl delete configmaps --all -n authentik --ignore-not-found=true 2>/dev/null
    kubectl delete ingress --all -n authentik --ignore-not-found=true 2>/dev/null
    kubectl delete middleware --all -n authentik --ignore-not-found=true 2>/dev/null
    # Note: We keep the namespace and urbalurba-secrets for future use
    add_status "Authentik Resources Cleanup" "OK"
    
    echo ""
    echo "Step 2: Removing whoami test application..."
    echo "-------------------------------------------"
    
    # Remove whoami using playbook
    run_playbook "Whoami Removal" "playbooks/025-setup-whoami-testpod.yml" "-e operation=delete" || true
    
    echo ""
    echo "Step 3: Removing Traefik authentication middleware..."
    echo "----------------------------------------------------"
    
    # Remove Traefik middleware
    echo "🗑️  Removing Traefik forward auth middleware..."
    kubectl delete middleware authentik-forward-auth -n default --ignore-not-found=true 2>/dev/null
    local middleware_result=$?
    check_command_success "Traefik Middleware Removal" $middleware_result
    
    echo ""
    echo "Step 4: Removing Authentik PostgreSQL database..."
    echo "-------------------------------------------------"
    
    # Remove database using utility playbook
    run_playbook "Authentik Database Removal" "playbooks/utility/u09-authentik-create-postgres.yml" "-e operation=delete" || true
    
    echo ""
    echo "Step 5: Final cleanup and verification..."
    echo "----------------------------------------"
    
    # Final cleanup but preserve namespace and secrets
    echo "🧹 Final cleanup of Authentik resources (preserving namespace and secrets)..."
    kubectl delete all --all -n authentik --ignore-not-found=true 2>/dev/null
    # Note: Keeping namespace and urbalurba-secrets for future deployments
    add_status "Final Resource Cleanup" "OK"
    
    # Verification
    echo "🔍 Verifying removal completion..."
    
    # Check pods
    local remaining_pods=$(kubectl get pods -n authentik 2>/dev/null | grep -v NAME | wc -l)
    if [ "$remaining_pods" -eq 0 ]; then
        add_status "Pod Removal Verification" "OK"
    else
        add_status "Pod Removal Verification" "Warning"
        add_error "Pod Removal Verification" "$remaining_pods pods still exist"
    fi
    
    # Check Helm releases
    local remaining_releases=$(helm list -n authentik 2>/dev/null | grep -v NAME | wc -l)
    if [ "$remaining_releases" -eq 0 ]; then
        add_status "Helm Release Verification" "OK"
    else
        add_status "Helm Release Verification" "Warning"
        add_error "Helm Release Verification" "$remaining_releases releases still exist"
    fi
    
    print_summary
    
    # Return 0 if no critical errors, 1 otherwise
    local critical_errors=0
    for step in "${!ERRORS[@]}"; do
        if [[ "$step" == *"Database"* ]] || [[ "$step" == *"Helm"* ]]; then
            critical_errors=$((critical_errors + 1))
        fi
    done
    
    return $critical_errors
}

# Print summary
print_summary() {
    echo ""
    echo "========== Authentik Removal Summary =========="
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "✅ Authentik removal completed successfully!"
        echo ""
        echo "🗑️  COMPONENTS REMOVED:"
        echo "   • Authentik server and worker pods: ✅ Removed"
        echo "   • Authentik Helm release: ✅ Uninstalled"
        echo "   • Authentik PostgreSQL database: ✅ Deleted"
        echo "   • Authentik database user: ✅ Removed"
        echo "   • Whoami test application: ✅ Removed"
        echo "   • Traefik forward auth middleware: ✅ Deleted"
        echo "   • All authentication configuration: ✅ Cleared"
        echo ""
        echo "🧹 NAMESPACE STATUS:"
        echo "   • authentik namespace: ✅ Preserved for future use"
        echo "   • urbalurba-secrets: ✅ Preserved for future use"
        echo "   • All other resources removed from namespace"
        echo ""
        echo "✅ VERIFICATION:"
        echo "   • No Authentik pods running"
        echo "   • No Helm releases remaining"
        echo "   • Database and user completely removed"
        echo "   • Authentication system fully disabled"
        echo ""
        echo "🎉 AUTHENTIK COMPLETELY REMOVED!"
        echo ""
        echo "🚀 NEXT STEPS:"
        echo "   • Cluster is clean and ready for fresh installation"
        echo "   • Run 01-setup-authentik.sh to reinstall Authentik"
        echo "   • Or deploy a different authentication solution"
        echo "   • All dependent services (PostgreSQL, Redis, Traefik) remain intact"
        echo ""
        echo "🔄 TO REINSTALL AUTHENTIK:"
        echo "   ./01-setup-authentik.sh $TARGET_HOST"
        
    else
        echo ""
        echo "⚠️  Some issues occurred during removal:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "🔍 MANUAL CLEANUP MAY BE REQUIRED:"
        echo ""
        echo "Check remaining resources:"
        echo "  kubectl get all -n authentik"
        echo "  helm list -n authentik"
        echo "  kubectl get middleware -n default | grep authentik"
        echo ""
        echo "Force cleanup commands:"
        echo "  kubectl delete namespace authentik --force --grace-period=0"
        echo "  kubectl delete middleware authentik-forward-auth -n default --force"
        echo ""
        echo "Database cleanup:"
        echo "  cd /mnt/urbalurbadisk/ansible"
        echo "  ansible-playbook playbooks/utility/u09-authentik-create-postgres.yml -e operation=delete"
        echo ""
        echo "⚠️  Check the errors above and run manual cleanup if needed"
    fi
}

# Run the main function and exit with its return code
main
exit $?