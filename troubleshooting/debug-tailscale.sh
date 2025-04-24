#!/bin/bash
# debug-tailscale.sh - Script to collect debugging information for Tailscale in Kubernetes
# This script runs commands inside the Kubernetes cluster to debug Tailscale Funnel

# Set variables
OUTPUT_FILE="debug-tailscale.txt"

echo "Collecting Tailscale debugging information from Kubernetes cluster..."
echo "This may take a moment..."

# Find pods by partial name across all namespaces
find_pods_by_name() {
  local name_pattern=$1
  kubectl get pods -A | grep -i "$name_pattern" | grep -v "Completed" || echo "No pods matching '$name_pattern' found"
}

# Execute command in a specific pod
exec_in_pod() {
  local namespace=$1
  local pod=$2
  shift 2
  
  kubectl exec -n "$namespace" "$pod" -- "$@" 2>&1 || echo "Command failed: $*"
}

# Main output
{
  echo "=== Tailscale in Kubernetes Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== Tailscale Pods ==="
  TAILSCALE_PODS=$(find_pods_by_name "tailscale")
  echo "$TAILSCALE_PODS"
  echo ""
  
  # Extract namespace and pod name for the first tailscale pod
  if echo "$TAILSCALE_PODS" | grep -v "No pods" > /dev/null; then
    TAILSCALE_NS=$(echo "$TAILSCALE_PODS" | head -1 | awk '{print $1}')
    TAILSCALE_POD=$(echo "$TAILSCALE_PODS" | head -1 | awk '{print $2}')
    
    echo "=== Tailscale Pod Details ==="
    echo "Using pod: $TAILSCALE_POD in namespace: $TAILSCALE_NS"
    kubectl describe pod -n $TAILSCALE_NS $TAILSCALE_POD
    echo ""
    
    echo "=== Tailscale Pod Logs ==="
    kubectl logs -n $TAILSCALE_NS $TAILSCALE_POD | tail -50
    echo ""
    
    echo "=== Tailscale Status (if available) ==="
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD tailscale status
    echo ""
    
    echo "=== Tailscale Funnel Status (if available) ==="
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD tailscale funnel status
    echo ""
    
    echo "=== Tailscale Environment Variables ==="
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD env | grep -i tailscale
    echo ""
    
    echo "=== Tailscale Network Configuration ==="
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD ip addr
    echo ""
  else
    echo "No Tailscale pods found, skipping Tailscale-specific checks"
  fi

  echo "=== Traefik Pods ==="
  TRAEFIK_PODS=$(find_pods_by_name "traefik")
  echo "$TRAEFIK_PODS"
  echo ""
  
  # Extract namespace and pod name for the first traefik pod
  if echo "$TRAEFIK_PODS" | grep -v "No pods" > /dev/null; then
    TRAEFIK_NS=$(echo "$TRAEFIK_PODS" | head -1 | awk '{print $1}')
    TRAEFIK_POD=$(echo "$TRAEFIK_PODS" | head -1 | awk '{print $2}')
    
    echo "=== Traefik Pod Details ==="
    echo "Using pod: $TRAEFIK_POD in namespace: $TRAEFIK_NS"
    kubectl describe pod -n $TRAEFIK_NS $TRAEFIK_POD
    echo ""
  fi

  echo "=== Tailscale-related Services ==="
  TAILSCALE_SERVICES=$(kubectl get svc -A | grep -i tailscale)
  echo "$TAILSCALE_SERVICES"
  echo ""
  
  # Extract first tailscale service details if found
  if echo "$TAILSCALE_SERVICES" | grep -v "No services" > /dev/null; then
    TAILSCALE_SVC_NS=$(echo "$TAILSCALE_SERVICES" | head -1 | awk '{print $1}')
    TAILSCALE_SVC_NAME=$(echo "$TAILSCALE_SERVICES" | head -1 | awk '{print $2}')
    
    echo "=== Tailscale Service Details ==="
    echo "Using service: $TAILSCALE_SVC_NAME in namespace: $TAILSCALE_SVC_NS"
    kubectl describe svc -n $TAILSCALE_SVC_NS $TAILSCALE_SVC_NAME
    echo ""
  fi

  echo "=== Traefik Services ==="
  TRAEFIK_SERVICES=$(kubectl get svc -A | grep -i traefik)
  echo "$TRAEFIK_SERVICES"
  echo ""
  
  # Extract first traefik service details if found
  if echo "$TRAEFIK_SERVICES" | grep -v "No services" > /dev/null; then
    TRAEFIK_SVC_NS=$(echo "$TRAEFIK_SERVICES" | head -1 | awk '{print $1}')
    TRAEFIK_SVC_NAME=$(echo "$TRAEFIK_SERVICES" | head -1 | awk '{print $2}')
    
    echo "=== Traefik Service Details ==="
    echo "Using service: $TRAEFIK_SVC_NAME in namespace: $TRAEFIK_SVC_NS"
    kubectl describe svc -n $TRAEFIK_SVC_NS $TRAEFIK_SVC_NAME
    echo ""
  fi

  echo "=== Tailscale-related Ingress Resources ==="
  kubectl get ingress -A | grep -i tailscale
  echo ""
  
  echo "=== Tailscale ConfigMaps ==="
  if [ -n "$TAILSCALE_NS" ]; then
    kubectl get configmap -n $TAILSCALE_NS
  else
    kubectl get configmap -A | grep -i tailscale
  fi
  echo ""
  
  echo "=== Tailscale Secrets ==="
  if [ -n "$TAILSCALE_NS" ]; then
    kubectl get secrets -n $TAILSCALE_NS
  else
    kubectl get secrets -A | grep -i tailscale
  fi
  echo ""
  
  echo "=== Tailscale Custom Resources ==="
  kubectl api-resources | grep -i tailscale
  echo ""
  
  # If any tailscale custom resources found, list them
  TAILSCALE_CRD=$(kubectl api-resources | grep -i tailscale | head -1 | awk '{print $1}')
  if [ -n "$TAILSCALE_CRD" ]; then
    echo "=== $TAILSCALE_CRD Resources ==="
    kubectl get $TAILSCALE_CRD -A
    echo ""
  fi

  echo "=== Node Information ==="
  kubectl get nodes -o wide
  echo ""
  
  echo "=== LoadBalancer Services ==="
  kubectl get svc -A | grep LoadBalancer
  echo ""
  
  echo "=== Recent Tailscale-related Events ==="
  kubectl get events --sort-by='.lastTimestamp' | grep -i tailscale | tail -20
  echo ""

  echo "=== Connectivity Tests ==="
  if [ -n "$TAILSCALE_POD" ] && [ -n "$TRAEFIK_SVC_NAME" ]; then
    echo "Testing connectivity from Tailscale pod to Traefik service:"
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD curl -s -I http://$TRAEFIK_SVC_NAME.$TRAEFIK_SVC_NS.svc.cluster.local 2>/dev/null || echo "Could not connect to Traefik service from Tailscale pod"
  fi
  echo ""

  echo "=== DNS Information ==="
  if [ -n "$TAILSCALE_POD" ]; then
    echo "Tailscale pod DNS information:"
    exec_in_pod $TAILSCALE_NS $TAILSCALE_POD cat /etc/resolv.conf
  fi
  echo ""

  echo "=== Tailscale Funnel Suggested Solutions ==="
  echo "1. If needed, reconfigure Tailscale Funnel to point to Traefik service:"
  if [ -n "$TAILSCALE_POD" ] && [ -n "$TRAEFIK_SVC_NAME" ]; then
    TRAEFIK_IP=$(kubectl get svc -n $TRAEFIK_SVC_NS $TRAEFIK_SVC_NAME -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    echo "   kubectl exec -n $TAILSCALE_NS $TAILSCALE_POD -- tailscale funnel reset"
    echo "   kubectl exec -n $TAILSCALE_NS $TAILSCALE_POD -- tailscale funnel 443 $TRAEFIK_IP:80"
  else
    echo "   Unable to determine exact command due to missing pod or service information"
  fi
  echo ""
  echo "2. If using Tailscale Operator, check the custom resources configuration:"
  if [ -n "$TAILSCALE_CRD" ]; then
    echo "   kubectl get $TAILSCALE_CRD -A"
  else
    echo "   kubectl get ts -A # (if the CRD exists)"
  fi
  echo ""
  echo "3. To verify Tailscale Funnel is working correctly:"
  if [ -n "$TAILSCALE_POD" ]; then
    echo "   kubectl exec -n $TAILSCALE_NS $TAILSCALE_POD -- tailscale funnel status"
  else
    echo "   Unable to determine exact command due to missing pod information"
  fi
  echo ""
  echo "4. Check if the Tailscale pod has the correct permissions to access Traefik"

} > "$OUTPUT_FILE"

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Tailscale Funnel issues in Kubernetes."