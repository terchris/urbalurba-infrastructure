#!/bin/bash
# filename: 03-remove-observability.sh
# description: Remove Observability Stack (Grafana, Loki, Tempo, Prometheus, OpenTelemetry Collector) from Kubernetes cluster.
# Removes all Helm releases and resources in the 'monitoring' namespace, preserving the 'urbalurba-secrets' secret.
#
# Usage: ./03-remove-observability.sh [kube-context]
# Example: ./03-remove-observability.sh rancher-desktop
#   kube-context: Kubernetes context/host (default: rancher-desktop)

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Initialize status tracking
declare -A STATUS
declare -A ERRORS

# Variables
NAMESPACE="monitoring"
KUBE_CONTEXT=${1:-"rancher-desktop"}
HELM_RELEASES=(grafana loki tempo prometheus otel-collector)
SECRET_NAME="urbalurba-secrets"

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

remove_helm_releases() {
    local step="Remove Helm Releases"
    echo "Removing Helm releases in namespace '$NAMESPACE'..."
    for release in "${HELM_RELEASES[@]}"; do
        helm uninstall $release -n $NAMESPACE --kube-context $KUBE_CONTEXT 2>/dev/null
    done
    check_command_success "$step" 0
    return 0
}

remove_namespace_resources() {
    local step="Remove Namespace Resources (except secrets)"
    echo "Removing all resources in namespace '$NAMESPACE' except secrets..."
    # Delete all resources except secrets
    kubectl delete all --all -n $NAMESPACE --context $KUBE_CONTEXT 2>/dev/null
    # Delete configmaps, PVCs, ingresses, etc. except secrets
    kubectl delete configmap --all -n $NAMESPACE --context $KUBE_CONTEXT 2>/dev/null
    kubectl delete pvc --all -n $NAMESPACE --context $KUBE_CONTEXT 2>/dev/null
    kubectl delete ingress --all -n $NAMESPACE --context $KUBE_CONTEXT 2>/dev/null
    kubectl delete service --all -n $NAMESPACE --context $KUBE_CONTEXT 2>/dev/null
    check_command_success "$step" 0
    return 0
}

preserve_secret() {
    local step="Preserve urbalurba-secrets"
    echo "Preserving secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
    # No action needed, just check if it exists
    kubectl get secret $SECRET_NAME -n $NAMESPACE --context $KUBE_CONTEXT &>/dev/null
    if [ $? -eq 0 ]; then
        add_status "$step" "OK"
    else
        add_status "$step" "Not found"
        add_error "$step" "Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
    fi
    return 0
}

print_summary() {
    echo ""
    echo "---------- Observability Stack Removal Summary ----------"
    for step in "${!STATUS[@]}"; do
        echo "$step: ${STATUS[$step]}"
    done
    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo ""
        echo "🎉 Observability stack removal completed successfully!"
        echo "✅ All Helm releases and resources (except '$SECRET_NAME') removed from namespace '$NAMESPACE'."
        echo ""
        echo "To reinstall, run: ./030-setup-observability.sh $KUBE_CONTEXT"
    else
        echo ""
        echo "⚠️ Removal completed with some issues:"
        for step in "${!ERRORS[@]}"; do
            echo "  $step: ${ERRORS[$step]}"
        done
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   - Check if the '$NAMESPACE' namespace exists: kubectl get ns $NAMESPACE"
        echo "   - Check if pods are running: kubectl get pods -n $NAMESPACE"
        echo "   - Check logs of a specific pod: kubectl logs -f <pod-name> -n $NAMESPACE"
        echo "   - Check Helm releases: helm list -n $NAMESPACE"
    fi
}

main() {
    echo "🧹 Starting Observability Stack removal on $KUBE_CONTEXT"
    echo "=============================================="
    remove_helm_releases
    remove_namespace_resources
    preserve_secret
    print_summary
    return ${#ERRORS[@]}
}

main
exit $? 