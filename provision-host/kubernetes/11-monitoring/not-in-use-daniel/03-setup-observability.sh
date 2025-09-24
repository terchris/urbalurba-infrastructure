#!/bin/bash
# filename: 03-setup-observability.sh
# description: Setup Observability Stack (Grafana, Loki, Tempo, Prometheus, OpenTelemetry Collector) on a Kubernetes cluster using Ansible playbook.
#
# This script deploys the observability stack in the 'monitoring' namespace using the Ansible playbook 030-setup-observability.yml.
# It checks for required secrets, runs the playbook, and summarizes the deployment status.
#
# Usage: ./03-setup-observability.sh [kube-context]
# Example: ./03-setup-observability.sh rancher-desktop
#   kube-context: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize associative arrays for status and errors
declare -A STATUS
declare -A ERRORS

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../../../ansible"
PLAYBOOK_PATH_OBSERVABILITY="$ANSIBLE_DIR/playbooks/030-setup-observability.yml"
NAMESPACE="monitoring"

# Check if KUBE_CONTEXT is provided as an argument, otherwise set default
KUBE_CONTEXT=${1:-"rancher-desktop"}

add_status() {
    local step=$1
    local status=$2
    STATUS["$step"]=$status
}

add_error() {
    local step=$1
    local error=$2
    ERRORS["$step"]="${ERRORS[$step]}${ERRORS[$step]:+$'\n'}$error"
}

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

check_secret() {
    local namespace="$NAMESPACE"
    local secret_name="urbalurba-secrets"
    echo "Checking if $secret_name exists in $namespace namespace..."
    kubectl get secret $secret_name -n $namespace &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Secret '$secret_name' not found in namespace '$namespace'"
        echo "Please create the secret before running this script"
        echo ""
        echo "Example:"
        echo "kubectl create secret generic $secret_name -n $namespace \
  --from-literal=grafana-admin-user=your-user \
  --from-literal=grafana-admin-password=your-password"
        return 1
    fi
    echo "Secret '$secret_name' found in namespace '$namespace'"
    return 0
}

run_playbook() {
    local step=$1
    local playbook=$2
    local extra_args=${3:-""}
    echo "Running playbook for $step..."
    cd $ANSIBLE_DIR && ansible-playbook $playbook -e kube_context=$KUBE_CONTEXT $extra_args
    local result=$?
    check_command_success "$step" $result
    return $result
}

main() {
    echo "Starting Observability Stack setup on $KUBE_CONTEXT"
    echo "---------------------------------------------"
    check_secret || return 1
    run_playbook "Setup Observability Stack" "$PLAYBOOK_PATH_OBSERVABILITY" || return 1
    print_summary
    return ${#ERRORS[@]}
}

print_summary() {
    echo "---------- Installation Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
        echo ""
        echo "Observability stack has been deployed to the '$NAMESPACE' namespace."
        echo ""
        echo "You can check the pods with: kubectl get pods -n $NAMESPACE"
        echo "You can check the services with: kubectl get svc -n $NAMESPACE"
        echo "You can check the ingresses with: kubectl get ingress -n $NAMESPACE"
        echo ""
        echo "To access the UIs:"
        echo "- Grafana: http://grafana.localhost"
        echo "- Loki: http://loki.localhost"
        echo "- Tempo: http://tempo.localhost"
        echo "- Prometheus: http://prometheus.localhost"
        echo "- OTEL Collector: http://otel-collector.localhost"
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check pod status: kubectl get pods -n $NAMESPACE"
        echo "  - View logs: kubectl logs -f <pod-name> -n $NAMESPACE"
        echo "  - Restart a deployment: kubectl rollout restart deployment/<name> -n $NAMESPACE"
    else
        echo "Errors occurred during installation:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "Troubleshooting tips:"
        echo "  - Check if the '$NAMESPACE' namespace exists: kubectl get ns $NAMESPACE"
        echo "  - Check if pods are running: kubectl get pods -n $NAMESPACE"
        echo "  - Check logs of a specific pod: kubectl logs -f <pod-name> -n $NAMESPACE"
        echo "  - Check Helm releases: helm list -n $NAMESPACE"
        echo "  - Make sure the 'urbalurba-secrets' secret exists and has all required keys"
    fi
}

main
exit $? 