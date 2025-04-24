#!/bin/bash
# debug-traefik.sh - Script to collect debugging information for Traefik

# Set variables
NAMESPACE="kube-system"  # Default namespace for Traefik installation
ALT_NAMESPACE="default"  # Alternative namespace to check if not found in kube-system
OUTPUT_FILE="debug-traefik.txt"

echo "Collecting Traefik debugging information..."
echo "This may take a moment..."

{
  echo "=== Traefik Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== Traefik Pods ==="
  kubectl get pods -n $NAMESPACE | grep -i traefik
  if [ $? -ne 0 ]; then
    echo "No Traefik pods found in $NAMESPACE namespace. Checking $ALT_NAMESPACE..."
    kubectl get pods -n $ALT_NAMESPACE | grep -i traefik
    if [ $? -ne 0 ]; then
      echo "No Traefik pods found in $ALT_NAMESPACE namespace either."
    else
      # If found in alternative namespace, use that for subsequent commands
      NAMESPACE=$ALT_NAMESPACE
    fi
  fi
  echo ""

  echo "=== Traefik Pod Details ==="
  TRAEFIK_POD=$(kubectl get pods -n $NAMESPACE -l app=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$TRAEFIK_POD" ]; then
    # Try alternative labels if the default one didn't work
    TRAEFIK_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi

  if [ -n "$TRAEFIK_POD" ]; then
    kubectl describe pod $TRAEFIK_POD -n $NAMESPACE
  else
    echo "Could not find Traefik pod with standard labels."
    # List all pods and try to find Traefik
    echo "Listing all pods in $NAMESPACE namespace:"
    kubectl get pods -n $NAMESPACE -o wide
  fi
  echo ""

  echo "=== Traefik Services ==="
  kubectl get svc -n $NAMESPACE | grep -i traefik
  if [ $? -ne 0 ]; then
    echo "No Traefik services found in $NAMESPACE namespace. Checking $ALT_NAMESPACE..."
    kubectl get svc -n $ALT_NAMESPACE | grep -i traefik
  fi
  echo ""

  echo "=== Traefik Service Details ==="
  TRAEFIK_SVC=$(kubectl get svc -n $NAMESPACE -l app=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$TRAEFIK_SVC" ]; then
    # Try alternative labels
    TRAEFIK_SVC=$(kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi

  if [ -n "$TRAEFIK_SVC" ]; then
    kubectl describe svc $TRAEFIK_SVC -n $NAMESPACE
  else
    echo "Could not find Traefik service with standard labels."
  fi
  echo ""

  echo "=== Traefik ConfigMap ==="
  kubectl get configmap -n $NAMESPACE | grep -i traefik
  if [ $? -eq 0 ]; then
    TRAEFIK_CM=$(kubectl get configmap -n $NAMESPACE -l app=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$TRAEFIK_CM" ]; then
      # Try alternative labels or just take the first one with traefik in the name
      TRAEFIK_CM=$(kubectl get configmap -n $NAMESPACE | grep -i traefik | head -1 | awk '{print $1}')
    fi
    
    if [ -n "$TRAEFIK_CM" ]; then
      echo ""
      echo "=== Traefik ConfigMap Content ==="
      kubectl get configmap $TRAEFIK_CM -n $NAMESPACE -o yaml
    fi
  else
    echo "No Traefik ConfigMaps found in $NAMESPACE namespace."
  fi
  echo ""

  echo "=== Traefik Custom Resources ==="
  
  # Check for Traefik CRDs
  echo "IngressRoute Resources:"
  kubectl get ingressroute.traefik.containo.us --all-namespaces 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "IngressRoute CRD not found. Checking for newer API version..."
    kubectl get ingressroute.traefik.io --all-namespaces 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "No IngressRoute resources found."
    fi
  fi
  echo ""
  
  echo "Middleware Resources:"
  kubectl get middleware.traefik.containo.us --all-namespaces 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Middleware CRD not found. Checking for newer API version..."
    kubectl get middleware.traefik.io --all-namespaces 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "No Middleware resources found."
    fi
  fi
  echo ""
  
  echo "TLSOption Resources:"
  kubectl get tlsoption.traefik.containo.us --all-namespaces 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "TLSOption CRD not found. Checking for newer API version..."
    kubectl get tlsoption.traefik.io --all-namespaces 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "No TLSOption resources found."
    fi
  fi
  echo ""
  
  echo "TraefikService Resources:"
  kubectl get traefikservice.traefik.containo.us --all-namespaces 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "TraefikService CRD not found. Checking for newer API version..."
    kubectl get traefikservice.traefik.io --all-namespaces 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "No TraefikService resources found."
    fi
  fi
  echo ""

  echo "=== Traefik IngressClass ==="
  kubectl get ingressclass traefik -o yaml 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "No 'traefik' IngressClass found."
    echo "Available IngressClasses:"
    kubectl get ingressclass
  fi
  echo ""

  if [ -n "$TRAEFIK_POD" ]; then
    echo "=== Traefik Pod Logs (Last 100 lines) ==="
    kubectl logs $TRAEFIK_POD -n $NAMESPACE --tail=100
    echo ""
    
    echo "=== Traefik Configuration Dump ==="
    kubectl exec -n $NAMESPACE $TRAEFIK_POD -- traefik version 2>/dev/null
    echo ""
    
    echo "=== Checking for traefik command line args ==="
    kubectl describe pod $TRAEFIK_POD -n $NAMESPACE | grep -A20 "Command:"
    echo ""
  fi

  echo "=== Ingress Resources ==="
  kubectl get ingress --all-namespaces
  echo ""
  
  echo "=== Gravitee-related Ingress Details ==="
  kubectl get ingress -l app.kubernetes.io/instance=gravitee-apim -o yaml 2>/dev/null
  echo ""

  echo "=== Tailscale Funnel Configuration (if available) ==="
  # This command might not work if tailscale CLI is not installed
  if command -v tailscale &> /dev/null; then
    tailscale funnel status 2>/dev/null
    if [ $? -ne 0 ]; then
      echo "Could not get Tailscale funnel status. Command failed or not available."
    fi
  else
    echo "Tailscale CLI not available. Cannot check funnel status."
  fi
  echo ""

  echo "=== Node Information ==="
  kubectl get nodes -o wide
  echo ""

  echo "=== Network Policy Information ==="
  kubectl get networkpolicies --all-namespaces
  echo ""

  echo "=== Events Related to Traefik or Ingress ==="
  kubectl get events --all-namespaces | grep -i "traefik\|ingress"
  echo ""

  echo "=== Suggested Next Steps ==="
  echo "1. Check if the Traefik IngressClass matches what's specified in your ingress resources"
  echo "2. Verify Traefik is configured to handle the specified host names"
  echo "3. Check if Tailscale Funnel is properly routing to the Traefik service"
  echo "4. Consider creating Traefik-specific IngressRoute resources if standard Ingress isn't working"
  echo "5. Verify there are no NetworkPolicies blocking traffic"

} > "$OUTPUT_FILE"

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Traefik issues."