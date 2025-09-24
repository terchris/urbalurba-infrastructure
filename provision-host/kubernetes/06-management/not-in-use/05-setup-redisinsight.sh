#!/bin/bash
# filename: 05-setup-redisinsight.sh
# description: Setup RedisInsight for Redis administration using Ansible playbook
# usage: ./05-setup-redisinsight.sh [target-host]
# example: ./05-setup-redisinsight.sh rancher-desktop

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
PLAYBOOK_PATH_SETUP_REDISINSIGHT="$ANSIBLE_DIR/playbooks/651-adm-redisinsight.yml"

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
    if [ $? -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Command failed"
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

    echo "🔧 05-setup-redisinsight.sh: Running Ansible playbook for RedisInsight deployment..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e target_host=$TARGET_HOST $extra_args
    local ansible_exit_code=$?

    if [ $ansible_exit_code -ne 0 ]; then
        add_status "$step" "Fail"
        add_error "$step" "Ansible playbook failed with exit code $ansible_exit_code"
        return 1
    else
        add_status "$step" "OK"
        return 0
    fi
}

# Test Kubernetes connection
test_connection() {
    echo "Testing connection to Kubernetes context $TARGET_HOST..."

    # Check if context exists
    if ! kubectl config get-contexts "$TARGET_HOST" &>/dev/null; then
        add_status "Test connection" "Fail"
        add_error "Test connection" "Context $TARGET_HOST not found in kubeconfig"
        echo "Available contexts:"
        kubectl config get-contexts
        return 1
    fi

    # Switch to context and check nodes
    kubectl config use-context "$TARGET_HOST" >/dev/null 2>&1
    if kubectl get nodes &>/dev/null; then
        local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        echo "Successfully connected to $TARGET_HOST (${node_count} nodes)"
        check_command_success "Test connection"
        return 0
    else
        add_status "Test connection" "Fail"
        add_error "Test connection" "Cannot reach Kubernetes API for context $TARGET_HOST"
        return 1
    fi
}

# Main execution
main() {
    echo "🗃️  05-setup-redisinsight.sh: Setting up RedisInsight on Kubernetes cluster..."
    echo "📍 Target Host: $TARGET_HOST"
    echo "📋 Playbook: $PLAYBOOK_PATH_SETUP_REDISINSIGHT"
    echo ""

    test_connection || return 1

    run_playbook "Setup RedisInsight" "$PLAYBOOK_PATH_SETUP_REDISINSIGHT" || return 1

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
        echo "✅ 05-setup-redisinsight.sh: RedisInsight setup completed successfully!"
        echo "🎯 Target: $TARGET_HOST"
        echo "📝 Note: RedisInsight is now available for Redis administration"
        echo "🌐 Access: Use port-forward or ingress to access RedisInsight web interface"
        echo "🗄️ Redis: Add Redis connections manually in the RedisInsight interface"
        echo ""
        echo "💡 Quick Access Commands:"
        echo "   Port-forward: kubectl port-forward svc/redisinsight 8080:5540"
        echo "   Web UI: http://redisinsight.localhost"
        echo ""
        echo "🔗 Add Redis Connection (if Redis is deployed):"
        echo "   Host: redis-master.default.svc.cluster.local"
        echo "   Port: 6379"
        echo ""
        echo "🏗️ Storage: Uses cluster's default storage class for portability"
        echo "   Supports: AKS, EKS, GKE, Rancher, MicroK8s, and others"
    else
        echo ""
        echo "❌ Errors occurred during RedisInsight installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
    fi
}

# Run the main function and exit with its return code
main
exit $?