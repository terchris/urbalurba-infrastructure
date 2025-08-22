#!/bin/bash
# filename: 01-setup-authentik.sh
# description: Setup Authentik authentication system with forward auth, OAuth2, SAML, and MFA support using Ansible playbook.
# Also installs the dependencies for authentik:
# - Database: PostgreSQL with authentik database and user setup
# - Cache: Redis for background tasks and caching
# - Middleware: Traefik forward auth middleware configuration
# - Test app: Whoami application for verification
#
# Architecture:
# - Authentik server and worker pods with PostgreSQL backend
# - Traefik forward authentication middleware
# - Embedded outpost for forward auth integration
# - Whoami test application for verification
# - Complete authentication flow with redirect handling
#
# All services are set up in the namespace named: authentik and requires you to set secrets needed for the services to work.
#
# Usage: ./01-setup-authentik.sh [target-host] [deploy_test_apps]
# Example: ./01-setup-authentik.sh rancher-desktop true
#   target-host: Kubernetes context/host (default: rancher-desktop)
#   deploy_test_apps: true (default) or false (to skip test applications)

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

# Main execution
main() {
    echo "Starting Authentik Authentication System setup on $TARGET_HOST"
    echo "-----------------------------------------------------------"
    
    # Run the Ansible playbook to set up Authentik
    run_playbook "Setup Authentik Authentication System" "$PLAYBOOK_PATH_SETUP_AUTHENTIK" || return 1
    
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
        echo "- PostgreSQL database integration with authentik database"
        echo "- Redis cache integration"
        echo "- Traefik forward authentication middleware"
        echo "- Whoami test application with authentication"
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
        echo "🎯 Architecture:"
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
