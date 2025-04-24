#!/bin/bash
# debug-nginx.sh - Script to collect debugging information for Nginx in Kubernetes
# This script runs commands inside the Kubernetes cluster to debug Nginx

# Set variables
OUTPUT_FILE="debug-nginx.txt"

echo "Collecting Nginx debugging information from Kubernetes cluster..."
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
  echo "=== Nginx in Kubernetes Debug Information ==="
  echo "Date: $(date)"
  echo "Kubernetes Context: $(kubectl config current-context)"
  echo ""

  echo "=== Nginx Pods ==="
  NGINX_PODS=$(find_pods_by_name "nginx")
  echo "$NGINX_PODS"
  echo ""
  
  # Extract namespace and pod name for the first nginx pod
  if echo "$NGINX_PODS" | grep -v "No pods" > /dev/null; then
    NGINX_NS=$(echo "$NGINX_PODS" | head -1 | awk '{print $1}')
    NGINX_POD=$(echo "$NGINX_PODS" | head -1 | awk '{print $2}')
    
    echo "=== Nginx Pod Details ==="
    echo "Using pod: $NGINX_POD in namespace: $NGINX_NS"
    kubectl describe pod -n $NGINX_NS $NGINX_POD
    echo ""
    
    echo "=== Nginx Pod Logs ==="
    kubectl logs -n $NGINX_NS $NGINX_POD | tail -50
    echo ""
    
    echo "=== Nginx Configuration ==="
    echo "Checking nginx.conf:"
    exec_in_pod $NGINX_NS $NGINX_POD cat /etc/nginx/nginx.conf
    echo ""
    
    echo "Checking default.conf:"
    exec_in_pod $NGINX_NS $NGINX_POD cat /etc/nginx/conf.d/default.conf 2>/dev/null || exec_in_pod $NGINX_NS $NGINX_POD ls -la /etc/nginx/conf.d/
    echo ""
    
    echo "=== Nginx -T Configuration Dump ==="
    exec_in_pod $NGINX_NS $NGINX_POD nginx -T
    echo ""
    
    echo "=== Nginx Status ==="
    exec_in_pod $NGINX_NS $NGINX_POD nginx -s status 2>/dev/null || exec_in_pod $NGINX_NS $NGINX_POD ps aux | grep nginx
    echo ""
    
    echo "=== Nginx Version ==="
    exec_in_pod $NGINX_NS $NGINX_POD nginx -v
    echo ""

    echo "=== Nginx Environment Variables ==="
    exec_in_pod $NGINX_NS $NGINX_POD env | sort
    echo ""
    
    echo "=== Nginx Process List ==="
    exec_in_pod $NGINX_NS $NGINX_POD ps aux
    echo ""
    
    echo "=== Nginx Network Configuration ==="
    exec_in_pod $NGINX_NS $NGINX_POD ip addr
    echo ""
    
    echo "=== Nginx Network Connections ==="
    exec_in_pod $NGINX_NS $NGINX_POD netstat -tulpn 2>/dev/null || exec_in_pod $NGINX_NS $NGINX_POD ss -tulpn
    echo ""
  else
    echo "No Nginx pods found, skipping Nginx-specific checks"
  fi

  echo "=== Nginx Services ==="
  NGINX_SERVICES=$(kubectl get svc -A | grep -i nginx)
  echo "$NGINX_SERVICES"
  echo ""
  
  # Extract first nginx service details if found
  if echo "$NGINX_SERVICES" | grep -v "No services" > /dev/null; then
    NGINX_SVC_NS=$(echo "$NGINX_SERVICES" | head -1 | awk '{print $1}')
    NGINX_SVC_NAME=$(echo "$NGINX_SERVICES" | head -1 | awk '{print $2}')
    
    echo "=== Nginx Service Details ==="
    echo "Using service: $NGINX_SVC_NAME in namespace: $NGINX_SVC_NS"
    kubectl describe svc -n $NGINX_SVC_NS $NGINX_SVC_NAME
    echo ""
  fi

  echo "=== Nginx Ingress Resources ==="
  kubectl get ingress -A | grep -i nginx
  echo ""
  
  echo "=== Nginx ConfigMaps ==="
  kubectl get configmap -A | grep -i nginx
  echo ""
  
  # If any nginx config maps found, show their content
  NGINX_CM=$(kubectl get configmap -A | grep -i nginx | head -1)
  if [ -n "$NGINX_CM" ]; then
    NGINX_CM_NS=$(echo "$NGINX_CM" | awk '{print $1}')
    NGINX_CM_NAME=$(echo "$NGINX_CM" | awk '{print $2}')
    
    echo "=== Nginx ConfigMap Content ==="
    echo "ConfigMap: $NGINX_CM_NAME in namespace: $NGINX_CM_NS"
    kubectl get configmap -n $NGINX_CM_NS $NGINX_CM_NAME -o yaml
    echo ""
  fi
  
  echo "=== Nginx Secrets ==="
  kubectl get secrets -A | grep -i nginx
  echo ""
  
  echo "=== Nginx Deployments ==="
  kubectl get deployments -A | grep -i nginx
  echo ""
  
  # If any nginx deployments found, show their details
  NGINX_DEPLOY=$(kubectl get deployments -A | grep -i nginx | head -1)
  if [ -n "$NGINX_DEPLOY" ]; then
    NGINX_DEPLOY_NS=$(echo "$NGINX_DEPLOY" | awk '{print $1}')
    NGINX_DEPLOY_NAME=$(echo "$NGINX_DEPLOY" | awk '{print $2}')
    
    echo "=== Nginx Deployment Details ==="
    echo "Deployment: $NGINX_DEPLOY_NAME in namespace: $NGINX_DEPLOY_NS"
    kubectl describe deployment -n $NGINX_DEPLOY_NS $NGINX_DEPLOY_NAME
    echo ""
  fi

  echo "=== Node Information ==="
  kubectl get nodes -o wide
  echo ""
  
  echo "=== Service Endpoint Information ==="
  if [ -n "$NGINX_SVC_NAME" ]; then
    echo "Nginx Service Endpoints:"
    kubectl get endpoints -n $NGINX_SVC_NS $NGINX_SVC_NAME -o yaml
  fi
  echo ""
  
  echo "=== Recent Nginx-related Events ==="
  kubectl get events --sort-by='.lastTimestamp' | grep -i nginx | tail -20
  echo ""

  echo "=== Connectivity Tests ==="
  # Get the IPs for related services
  if [ -n "$NGINX_SVC_NAME" ]; then
    NGINX_SVC_IP=$(kubectl get svc -n $NGINX_SVC_NS $NGINX_SVC_NAME -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    NGINX_SVC_PORT=$(kubectl get svc -n $NGINX_SVC_NS $NGINX_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    # Find a Traefik pod to test from
    TRAEFIK_POD=$(kubectl get pods -A | grep -i traefik | grep -v "Completed" | head -1)
    if [ -n "$TRAEFIK_POD" ]; then
      TRAEFIK_NS=$(echo "$TRAEFIK_POD" | awk '{print $1}')
      TRAEFIK_POD_NAME=$(echo "$TRAEFIK_POD" | awk '{print $2}')
      
      echo "Testing connectivity from Traefik pod to Nginx service:"
      exec_in_pod $TRAEFIK_NS $TRAEFIK_POD_NAME curl -s -I "http://$NGINX_SVC_IP:$NGINX_SVC_PORT" || echo "Could not connect to Nginx service from Traefik pod"
    fi
    
    # Test from Nginx pod to itself
    if [ -n "$NGINX_POD" ]; then
      echo "Testing connectivity from Nginx pod to itself:"
      exec_in_pod $NGINX_NS $NGINX_POD curl -s -I "http://localhost:80" || echo "Could not connect to Nginx locally"
    fi
  fi
  echo ""
  
  # Check if connections are being handled by Nginx (helpful if multiple ingress controllers exist)
  if [ -n "$NGINX_POD" ]; then
    echo "=== Checking Active Connections ==="
    exec_in_pod $NGINX_NS $NGINX_POD cat /var/log/nginx/access.log | tail -10 || echo "Could not access Nginx logs"
    echo ""
  fi

  echo "=== Suggested Next Steps ==="
  echo "1. If Tailscale Funnel is sending traffic to Nginx instead of Traefik, you can:"
  echo ""
  echo "   a) Reconfigure Tailscale Funnel to point directly to Traefik"
  echo ""
  echo "   b) OR, configure Nginx to proxy to Traefik by adding to nginx.conf:"
  echo ""
  echo "      location /apim/ {"
  echo "          proxy_pass http://traefik-service-ip:80/apim/;"
  echo "          proxy_set_header Host \$host;"
  echo "          proxy_set_header X-Real-IP \$remote_addr;"
  echo "          proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
  echo "          proxy_set_header X-Forwarded-Proto \$scheme;"
  echo "      }"
  echo ""
  echo "2. To edit the Nginx configuration:"
  if [ -n "$NGINX_CM_NAME" ]; then
    echo "   kubectl edit configmap -n $NGINX_CM_NS $NGINX_CM_NAME"
  else
    echo "   kubectl edit configmap nginx-config -n <namespace> # replace with actual configmap name"
  fi
  echo ""
  echo "3. After editing configuration, restart the Nginx pod:"
  if [ -n "$NGINX_POD" ]; then
    echo "   kubectl delete pod -n $NGINX_NS $NGINX_POD"
  else
    echo "   kubectl delete pod <nginx-pod-name> -n <namespace> # to force config reload"
  fi
  echo ""
  echo "4. Check Nginx configuration syntax before applying:"
  if [ -n "$NGINX_POD" ]; then
    echo "   kubectl exec -n $NGINX_NS $NGINX_POD -- nginx -t"
  else
    echo "   kubectl exec <nginx-pod-name> -n <namespace> -- nginx -t"
  fi

} > "$OUTPUT_FILE"

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Nginx issues in Kubernetes."