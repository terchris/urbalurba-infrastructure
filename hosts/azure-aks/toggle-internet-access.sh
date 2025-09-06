#!/bin/bash

# File: hosts/azure-aks/toggle-internet-access.sh
#
# Description:
# Toggle internet access for AKS cluster by switching Traefik service type
# between LoadBalancer (internet accessible) and ClusterIP (internal only)
#
# Usage:
# ./toggle-internet-access.sh [on|off]
#   on  - Enable internet access (LoadBalancer)
#   off - Disable internet access (ClusterIP)
#   (no parameter) - Show current status
#
# Prerequisites:
# - kubectl configured with azure-aks context
# - Traefik deployed in kube-system namespace

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we're in provision-host or need to use docker exec
run_kubectl() {
    if [[ -f /.dockerenv ]] && [[ -d /mnt/urbalurbadisk ]]; then
        # We're inside provision-host container
        export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all
        kubectl config use-context azure-aks >/dev/null 2>&1
        kubectl "$@"
    else
        # We're on host machine, need to use docker exec
        docker exec provision-host bash -c "export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all && kubectl config use-context azure-aks >/dev/null 2>&1 && kubectl $*"
    fi
}

# Function to get current service type and external IP
get_current_status() {
    local service_info
    service_info=$(run_kubectl get svc traefik -n kube-system -o jsonpath='{.spec.type},{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "NotFound,")
    
    local service_type="${service_info%,*}"
    local external_ip="${service_info#*,}"
    
    echo "$service_type,$external_ip"
}

# Function to display current status
show_status() {
    print_status "Checking current internet access status..."
    
    local status_info
    status_info=$(get_current_status)
    local service_type="${status_info%,*}"
    local external_ip="${status_info#*,}"
    
    if [[ "$service_type" == "NotFound" ]]; then
        print_error "Traefik service not found in kube-system namespace"
        print_warning "Make sure Traefik is deployed and you're connected to the azure-aks cluster"
        exit 1
    fi
    
    echo
    echo "=== AKS Cluster Internet Access Status ==="
    echo "Service Type: $service_type"
    
    if [[ "$service_type" == "LoadBalancer" ]]; then
        if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
            print_success "✅ INTERNET ACCESS: ENABLED"
            echo "External IP: $external_ip"
            echo "Cluster is accessible from the internet at: http://$external_ip"
        else
            print_warning "⏳ INTERNET ACCESS: PENDING"
            echo "LoadBalancer is configured but external IP is not yet assigned"
            echo "Run 'kubectl get svc traefik -n kube-system' to monitor IP assignment"
        fi
    else
        print_warning "🔒 INTERNET ACCESS: DISABLED"
        echo "Cluster is only accessible from within the cluster network"
    fi
    echo
}

# Function to enable internet access
enable_internet() {
    print_status "Enabling internet access..."
    
    local current_type="${1%,*}"
    
    if [[ "$current_type" == "LoadBalancer" ]]; then
        print_warning "Internet access is already enabled"
        show_status
        return 0
    fi
    
    print_status "Changing Traefik service type to LoadBalancer..."
    run_kubectl patch svc traefik -n kube-system -p '{"spec":{"type":"LoadBalancer"}}'
    
    print_success "Service type changed to LoadBalancer"
    print_status "Waiting for external IP assignment (this may take 1-2 minutes)..."
    
    # Wait for external IP assignment
    local attempts=0
    local max_attempts=24  # 2 minutes with 5-second intervals
    
    while [[ $attempts -lt $max_attempts ]]; do
        local status_info
        status_info=$(get_current_status)
        local external_ip="${status_info#*,}"
        
        if [[ -n "$external_ip" && "$external_ip" != "null" && "$external_ip" != "" ]]; then
            print_success "✅ Internet access enabled!"
            echo "External IP assigned: $external_ip"
            echo "Cluster is now accessible at: http://$external_ip"
            return 0
        fi
        
        echo -n "."
        sleep 5
        ((attempts++))
    done
    
    echo
    print_warning "External IP assignment is taking longer than expected"
    print_status "Check status with: kubectl get svc traefik -n kube-system"
}

# Function to disable internet access
disable_internet() {
    print_status "Disabling internet access..."
    
    local status_info="$1"
    local current_type="${status_info%,*}"
    local external_ip="${status_info#*,}"
    
    if [[ "$current_type" == "ClusterIP" ]]; then
        print_warning "Internet access is already disabled"
        show_status
        return 0
    fi
    
    if [[ -n "$external_ip" && "$external_ip" != "null" ]]; then
        print_warning "Current external IP ($external_ip) will be released"
    fi
    
    print_status "Changing Traefik service type to ClusterIP..."
    run_kubectl patch svc traefik -n kube-system -p '{"spec":{"type":"ClusterIP"}}'
    
    print_success "✅ Internet access disabled!"
    print_status "Cluster is now only accessible from within the cluster network"
}

# Main script logic
main() {
    local action="$1"
    
    # Validate we can connect to the cluster
    print_status "Connecting to azure-aks cluster..."
    if ! get_current_status >/dev/null 2>&1; then
        print_error "Failed to connect to azure-aks cluster"
        print_warning "Make sure:"
        print_warning "1. provision-host container is running"
        print_warning "2. kubectl is configured with azure-aks context"
        print_warning "3. Traefik is deployed in kube-system namespace"
        exit 1
    fi
    
    case "$action" in
        "on"|"enable")
            local status_info
            status_info=$(get_current_status)
            enable_internet "$status_info"
            ;;
        "off"|"disable")
            local status_info
            status_info=$(get_current_status)
            disable_internet "$status_info"
            ;;
        "status"|"")
            show_status
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [on|off|status]"
            echo
            echo "Commands:"
            echo "  on, enable   - Enable internet access (LoadBalancer)"
            echo "  off, disable - Disable internet access (ClusterIP)"  
            echo "  status       - Show current status (default if no parameter)"
            echo "  help         - Show this help message"
            echo
            echo "Examples:"
            echo "  $0           # Show current status"
            echo "  $0 on        # Enable internet access"
            echo "  $0 off       # Disable internet access"
            ;;
        *)
            print_error "Invalid parameter: $action"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"