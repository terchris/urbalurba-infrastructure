#!/bin/bash
# File: .devcontainer/additions/otel/scripts/rancher-vm-k8s-status.sh
# Purpose: Collect K8s status and pod counts for resource waste monitoring
# Output: Prometheus metrics format
#
# Detects:
# - disabled: K8s not running (no K8s-related containers)
# - enabled_unused: K8s running, only system pods (wasting RAM)
# - enabled_active: K8s running with user workloads
#
# K8s detection:
# - Rancher Desktop runs K8s in containers with names like: k8s_*, rancher/*, lima-*
# - System namespaces: kube-system, kube-public, kube-node-lease, cattle-*, rancher-*
# - User workloads: Everything else

set -e

#------------------------------------------------------------------------------
# K8s Container Detection
#------------------------------------------------------------------------------

# List all K8s-related containers
get_k8s_containers() {
    # K8s containers typically have these name patterns:
    # - k8s_* (Kubernetes pods)
    # - rancher/* (Rancher system containers)
    # - lima-rancher-desktop (Lima VM for Rancher)
    docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^k8s_|^rancher|^lima-rancher' || true
}

# Count containers in system namespaces
count_system_pods() {
    # System namespaces typically contain:
    # - kube-system, kube-public, kube-node-lease
    # - cattle-system, fleet-*, rancher-* (Rancher management)
    # - coredns, etcd, kube-*, metrics-server
    docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^k8s_' | grep -E '_kube-system_|_kube-public_|_kube-node-lease_|_cattle-|_fleet-|_rancher-|_coredns|_etcd|_metrics-server' | wc -l | tr -d ' '
}

# Count all K8s pods (k8s_* containers)
count_total_pods() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^k8s_' | wc -l | tr -d ' '
}

#------------------------------------------------------------------------------
# Status Determination
#------------------------------------------------------------------------------

determine_k8s_status() {
    local total_pods=$1
    local system_pods=$2
    local user_pods=$3

    if [ "$total_pods" -eq 0 ]; then
        echo "disabled"
    elif [ "$user_pods" -eq 0 ]; then
        echo "enabled_unused"
    else
        echo "enabled_active"
    fi
}

#------------------------------------------------------------------------------
# Metrics Output
#------------------------------------------------------------------------------

output_metrics() {
    local status=$1
    local total=$2
    local system=$3
    local user=$4

    # Total K8s pods
    echo "# HELP devcontainer_k8s_pods_total Total K8s containers running"
    echo "# TYPE devcontainer_k8s_pods_total gauge"
    echo "devcontainer_k8s_pods_total $total"

    # System pods
    echo ""
    echo "# HELP devcontainer_k8s_pods_system System pods (kube-system, etc.)"
    echo "# TYPE devcontainer_k8s_pods_system gauge"
    echo "devcontainer_k8s_pods_system $system"

    # User pods
    echo ""
    echo "# HELP devcontainer_k8s_pods_user User workload pods"
    echo "# TYPE devcontainer_k8s_pods_user gauge"
    echo "devcontainer_k8s_pods_user $user"

    # Status metric (1 for the active status label)
    echo ""
    echo "# HELP devcontainer_k8s_status K8s status (disabled, enabled_unused, enabled_active)"
    echo "# TYPE devcontainer_k8s_status gauge"

    # Output 1 for the current status, 0 for others
    for s in "disabled" "enabled_unused" "enabled_active"; do
        if [ "$s" = "$status" ]; then
            echo "devcontainer_k8s_status{status=\"$s\"} 1"
        else
            echo "devcontainer_k8s_status{status=\"$s\"} 0"
        fi
    done
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        echo "# ERROR: docker command not found"
        output_metrics "disabled" 0 0 0
        exit 0
    fi

    # Check if docker is running
    if ! docker info &> /dev/null; then
        echo "# ERROR: docker daemon not accessible"
        output_metrics "disabled" 0 0 0
        exit 0
    fi

    # Count pods
    local total_pods
    local system_pods
    local user_pods

    total_pods=$(count_total_pods)
    system_pods=$(count_system_pods)
    user_pods=$((total_pods - system_pods))

    # Ensure user_pods is not negative
    if [ "$user_pods" -lt 0 ]; then
        user_pods=0
    fi

    # Determine status
    local status
    status=$(determine_k8s_status "$total_pods" "$system_pods" "$user_pods")

    # Output metrics
    output_metrics "$status" "$total_pods" "$system_pods" "$user_pods"
}

main "$@"
