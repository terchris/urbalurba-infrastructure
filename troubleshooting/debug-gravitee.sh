#!/bin/bash
# debug-gravitee.sh - Script to collect debugging information for Gravitee APIM

NAMESPACE="default"
OUTPUT_FILE="debug-gravitee.txt"

echo "Collecting Gravitee debugging information..."

# Start with timestamp and cluster info
{
  echo "=== Gravitee APIM Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== Gravitee Pods ==="
  kubectl get pods -n $NAMESPACE | grep gravitee
  echo ""

  echo "=== Gravitee Services ==="
  kubectl get svc -n $NAMESPACE | grep gravitee
  echo ""

  echo "=== Gravitee Endpoints ==="
  kubectl get endpoints -n $NAMESPACE | grep gravitee
  echo ""

  echo "=== Gravitee Ingress Resources ==="
  kubectl get ingress -n $NAMESPACE | grep gravitee
  echo ""

  echo "=== Gravitee UI Ingress Details ==="
  kubectl describe ingress gravitee-apim-ui -n $NAMESPACE
  echo ""

  echo "=== Gravitee Management API Ingress Details ==="
  kubectl describe ingress gravitee-apim-api-management -n $NAMESPACE
  echo ""

  echo "=== Gravitee Gateway Ingress Details ==="
  kubectl describe ingress gravitee-apim-gateway -n $NAMESPACE
  echo ""

  echo "=== Ingress Classes ==="
  kubectl get ingressclass
  echo ""

  echo "=== Traefik Resources ==="
  echo "IngressRoutes:"
  kubectl get ingressroute.traefik.containo.us -n $NAMESPACE 2>/dev/null || echo "No IngressRoutes found"
  echo ""
  echo "Middlewares:"
  kubectl get middleware.traefik.containo.us -n $NAMESPACE 2>/dev/null || echo "No Middlewares found"
  echo ""

  echo "=== Traefik v1alpha1 API Resources ==="
  for resource in ingressroutes ingressroutetcps ingressrouteudps middlewares tlsoptions tlsstores traefikservices; do
    echo "${resource}:"
    kubectl get ${resource}.traefik.io -n $NAMESPACE 2>/dev/null || echo "No ${resource} found"
    echo ""
  done

  echo "=== Traefik ConfigMaps ==="
  kubectl get configmap -n $NAMESPACE | grep traefik
  echo ""

  echo "=== Gravitee UI Pod Logs (excluding health probes) ==="
  UI_POD=$(kubectl get pods -n $NAMESPACE | grep gravitee-apim-ui | awk '{print $1}')
  if [ -n "$UI_POD" ]; then
    echo "Pod name: $UI_POD"
    kubectl logs $UI_POD -n $NAMESPACE --tail=200 | grep -v "kube-probe" | grep -v '200 57325'
  else
    echo "No Gravitee UI pod found"
  fi
  echo ""

# Replace the existing Gateway pod logs section with:
echo "=== Gravitee Gateway Pod Logs (Errors and Warnings only) ==="
GATEWAY_POD=$(kubectl get pods -n $NAMESPACE | grep gravitee-apim-gateway | awk '{print $1}')
if [ -n "$GATEWAY_POD" ]; then
  echo "Pod name: $GATEWAY_POD"
  kubectl logs $GATEWAY_POD -n $NAMESPACE --tail=200 | grep -i -E 'error|exception|fail|cannot|warn|unable to connect'
else
  echo "No Gravitee Gateway pod found"
fi
echo ""

# Also replace the Management API logs section:
echo "=== Gravitee Management API Pod Logs (Errors and Warnings only) ==="
API_POD=$(kubectl get pods -n $NAMESPACE | grep gravitee-apim-api | awk '{print $1}')
if [ -n "$API_POD" ]; then
  echo "Pod name: $API_POD"
  kubectl logs $API_POD -n $NAMESPACE --tail=200 | grep -i -E 'error|exception|fail|cannot|warn|unable to connect'
else
  echo "No Gravitee API pod found"
fi
echo ""

  echo "=== Traefik Pod Logs (if available) ==="
  TRAEFIK_POD=$(kubectl get pods -n $NAMESPACE | grep traefik | head -1 | awk '{print $1}')
  if [ -n "$TRAEFIK_POD" ]; then
    kubectl logs $TRAEFIK_POD -n $NAMESPACE
  else
    echo "No Traefik pod found in $NAMESPACE namespace. Checking in kube-system..."
    TRAEFIK_POD=$(kubectl get pods -n kube-system | grep traefik | head -1 | awk '{print $1}')
    if [ -n "$TRAEFIK_POD" ]; then
      kubectl logs $TRAEFIK_POD -n kube-system
    else
      echo "No Traefik pod found."
    fi
  fi
  echo ""

  echo "=== Traefik Service Information ==="
  kubectl get svc -n $NAMESPACE | grep traefik || echo "No Traefik service found in $NAMESPACE namespace"
  kubectl get svc -n kube-system | grep traefik || echo "No Traefik service found in kube-system namespace"
  echo ""

  echo "=== Checking Nginx Services (if any) ==="
  kubectl get svc -n $NAMESPACE | grep nginx || echo "No Nginx service found in $NAMESPACE namespace"
  echo ""

  echo "=== Pod-to-Service Network Check ==="
  echo "Attempting to curl from UI pod to Gravitee API service..."
  kubectl exec $UI_POD -n $NAMESPACE -- curl -s -I gravitee-apim-api:8083/management/apis 2>/dev/null || echo "Failed to connect from UI pod to API service"
  echo ""

  echo "=== Additional Information ==="
  echo "Node IP addresses:"
  kubectl get nodes -o wide
  echo ""
  
  echo "Events related to Gravitee:"
  kubectl get events -n $NAMESPACE | grep -i gravitee
  echo ""

} > "$OUTPUT_FILE"

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now share this file to help with troubleshooting."