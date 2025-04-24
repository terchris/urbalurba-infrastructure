#!/bin/bash
# debug-redis.sh - Script to collect debugging information for Redis in Kubernetes
# This script runs commands inside the Kubernetes cluster to debug Redis

# Set variables
OUTPUT_FILE="debug-redis.txt"

echo "Collecting Redis debugging information from Kubernetes cluster..."
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

# Run redis-cli command in pod
redis_cli() {
  local namespace="$1"
  local pod="$2"
  local command="$3"
  local args="${4:-}"
  local auth_args=""
  
  # Get password from Kubernetes secrets
  local password
  password=$(kubectl get secret -n default urbalurba-secrets -o jsonpath="{.data.REDIS_PASSWORD}" 2>/dev/null | base64 -d)
  
  if [ -n "$password" ]; then
    auth_args="-a $password"
  fi
  
  # Execute the command (adding --no-auth-warning to avoid warnings)
  kubectl exec -n "$namespace" "$pod" -- redis-cli $auth_args --no-auth-warning $args $command
}

# Main output
{
  echo "Starting Redis debug information collection..." >&2

  echo "=== Redis in Kubernetes Debug Information ===" > "$OUTPUT_FILE"
  echo "Date: $(date)" >> "$OUTPUT_FILE"
  echo "Kubernetes Context: $(kubectl config current-context)" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  echo "Step 1: Checking Redis Pods..." >&2
  echo "=== Redis Pods ===" | tee -a "$OUTPUT_FILE"
  REDIS_PODS=$(find_pods_by_name "redis")
  echo "$REDIS_PODS" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  if echo "$REDIS_PODS" | grep -v "No pods" > /dev/null; then
    REDIS_NS=$(echo "$REDIS_PODS" | head -1 | awk '{print $1}')
    REDIS_POD=$(echo "$REDIS_PODS" | head -1 | awk '{print $2}')
    
    echo "Step 2: Getting Redis Pod Details..." >&2
    echo "=== Redis Pod Details ===" | tee -a "$OUTPUT_FILE"
    echo "Using pod: $REDIS_POD in namespace: $REDIS_NS" | tee -a "$OUTPUT_FILE"
    kubectl describe pod -n "$REDIS_NS" "$REDIS_POD" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 3: Fetching Redis Pod Logs..." >&2
    echo "=== Redis Pod Logs ===" | tee -a "$OUTPUT_FILE"
    kubectl logs -n "$REDIS_NS" "$REDIS_POD" | tail -50 | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 4: Checking Redis Configuration..." >&2
    echo "=== Redis Configuration ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" cat /etc/redis/redis.conf 2>/dev/null || 
      exec_in_pod "$REDIS_NS" "$REDIS_POD" cat /usr/local/etc/redis/redis.conf 2>/dev/null ||
      exec_in_pod "$REDIS_NS" "$REDIS_POD" cat /data/redis.conf 2>/dev/null ||
      exec_in_pod "$REDIS_NS" "$REDIS_POD" cat /etc/redis.conf 2>/dev/null ||
      echo "Could not locate Redis configuration file" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 5: Checking Redis Environment Variables..." >&2
    echo "=== Redis Environment Variables ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" env | grep -i redis | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 6: Getting Redis Info (All Sections)..." >&2
    echo "=== Redis Info ===" | tee -a "$OUTPUT_FILE"
    redis_cli "$REDIS_NS" "$REDIS_POD" INFO | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 7: Getting Redis Client List..." >&2
    echo "=== Redis Client List ===" | tee -a "$OUTPUT_FILE"
    redis_cli "$REDIS_NS" "$REDIS_POD" "CLIENT LIST" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 8: Getting Redis Database Size..." >&2
    echo "=== Redis Database Size ===" | tee -a "$OUTPUT_FILE"
    redis_cli "$REDIS_NS" "$REDIS_POD" DBSIZE | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 9: Getting Redis Memory Usage..." >&2
    echo "=== Redis Memory Usage ===" | tee -a "$OUTPUT_FILE"
    redis_cli "$REDIS_NS" "$REDIS_POD" "MEMORY STATS" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 10: Getting Redis Process List..." >&2
    echo "=== Redis Process List ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" ps aux | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 11: Getting Redis Network Configuration..." >&2
    echo "=== Redis Network Configuration ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" ip addr | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 12: Getting Redis Network Connections..." >&2
    echo "=== Redis Network Connections ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" netstat -tulpn 2>/dev/null || exec_in_pod "$REDIS_NS" "$REDIS_POD" ss -tulpn | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    echo "Step 13: Getting Redis Disk Usage..." >&2
    echo "=== Redis Disk Usage ===" | tee -a "$OUTPUT_FILE"
    exec_in_pod "$REDIS_NS" "$REDIS_POD" df -h | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
  else
    echo "No Redis pods found, skipping Redis-specific checks" | tee -a "$OUTPUT_FILE"
  fi

  # Continue with service checks...
  echo "Step 14: Checking Redis Services..." >&2
  echo "=== Redis Services ===" | tee -a "$OUTPUT_FILE"
  kubectl get svc -A | grep -i redis | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  # Extract first redis service details if found
  if echo "$REDIS_SERVICES" | grep -v "No services" > /dev/null; then
    REDIS_SVC_NS=$(echo "$REDIS_SERVICES" | head -1 | awk '{print $1}')
    REDIS_SVC_NAME=$(echo "$REDIS_SERVICES" | head -1 | awk '{print $2}')
    
    echo "=== Redis Service Details ===" | tee -a "$OUTPUT_FILE"
    echo "Using service: $REDIS_SVC_NAME in namespace: $REDIS_SVC_NS" | tee -a "$OUTPUT_FILE"
    kubectl describe svc -n $REDIS_SVC_NS $REDIS_SVC_NAME | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
  fi

  echo "=== Redis ConfigMaps ===" | tee -a "$OUTPUT_FILE"
  kubectl get configmap -A | grep -i redis | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  # If any redis config maps found, show their content
  REDIS_CM=$(kubectl get configmap -A | grep -i redis | head -1)
  if [ -n "$REDIS_CM" ]; then
    REDIS_CM_NS=$(echo "$REDIS_CM" | awk '{print $1}')
    REDIS_CM_NAME=$(echo "$REDIS_CM" | awk '{print $2}')
    
    echo "=== Redis ConfigMap Content ===" | tee -a "$OUTPUT_FILE"
    echo "ConfigMap: $REDIS_CM_NAME in namespace: $REDIS_CM_NS" | tee -a "$OUTPUT_FILE"
    kubectl get configmap -n $REDIS_CM_NS $REDIS_CM_NAME -o yaml | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
  fi

  echo "=== Redis Secrets ===" | tee -a "$OUTPUT_FILE"
  kubectl get secrets -A | grep -i redis | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  echo "=== Redis StatefulSets ===" | tee -a "$OUTPUT_FILE"
  REDIS_STS=$(kubectl get statefulset -A | grep -i redis)
  echo "$REDIS_STS" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  # If any redis statefulsets found, show their details
  if echo "$REDIS_STS" | grep -v "No resources" > /dev/null; then
    REDIS_STS_NS=$(echo "$REDIS_STS" | head -1 | awk '{print $1}')
    REDIS_STS_NAME=$(echo "$REDIS_STS" | head -1 | awk '{print $2}')
    
    echo "=== Redis StatefulSet Details ===" | tee -a "$OUTPUT_FILE"
    echo "StatefulSet: $REDIS_STS_NAME in namespace: $REDIS_STS_NS" | tee -a "$OUTPUT_FILE"
    kubectl describe statefulset -n $REDIS_STS_NS $REDIS_STS_NAME | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
  fi

  echo "=== Redis Deployments ===" | tee -a "$OUTPUT_FILE"
  REDIS_DEPLOY=$(kubectl get deployments -A | grep -i redis)
  echo "$REDIS_DEPLOY" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  # If any redis deployments found, show their details
  if echo "$REDIS_DEPLOY" | grep -v "No resources" > /dev/null; then
    REDIS_DEPLOY_NS=$(echo "$REDIS_DEPLOY" | head -1 | awk '{print $1}')
    REDIS_DEPLOY_NAME=$(echo "$REDIS_DEPLOY" | head -1 | awk '{print $2}')
    
    echo "=== Redis Deployment Details ===" | tee -a "$OUTPUT_FILE"
    echo "Deployment: $REDIS_DEPLOY_NAME in namespace: $REDIS_DEPLOY_NS" | tee -a "$OUTPUT_FILE"
    kubectl describe deployment -n $REDIS_DEPLOY_NS $REDIS_DEPLOY_NAME | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
  fi

  echo "=== Redis PersistentVolumeClaims ===" | tee -a "$OUTPUT_FILE"
  kubectl get pvc -A | grep -i redis | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  echo "=== Redis Service Endpoint Information ===" | tee -a "$OUTPUT_FILE"
  if [ -n "$REDIS_SVC_NAME" ]; then
    echo "Redis Service Endpoints:" | tee -a "$OUTPUT_FILE"
    kubectl get endpoints -n $REDIS_SVC_NS $REDIS_SVC_NAME -o yaml | tee -a "$OUTPUT_FILE"
  fi
  echo "" | tee -a "$OUTPUT_FILE"

  echo "=== Recent Redis-related Events ===" | tee -a "$OUTPUT_FILE"
  kubectl get events --sort-by='.lastTimestamp' | grep -i redis | tail -20 | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

  echo "=== Connectivity Tests ===" | tee -a "$OUTPUT_FILE"
  # Check if Redis is reachable from other pods
  if [ -n "$REDIS_SVC_NAME" ] && [ -n "$REDIS_NS" ]; then
    REDIS_SVC_IP=$(kubectl get svc -n $REDIS_SVC_NS $REDIS_SVC_NAME -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    REDIS_SVC_PORT=$(kubectl get svc -n $REDIS_SVC_NS $REDIS_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    # Try to find a gravitee pod to test connectivity
    GRAVITEE_POD=$(kubectl get pods -A | grep -i gravitee | grep -v "Completed" | head -1)
    if [ -n "$GRAVITEE_POD" ]; then
      GRAVITEE_NS=$(echo "$GRAVITEE_POD" | awk '{print $1}')
      GRAVITEE_POD_NAME=$(echo "$GRAVITEE_POD" | awk '{print $2}')
      
      echo "Testing Redis connectivity from Gravitee pod:" | tee -a "$OUTPUT_FILE"
      exec_in_pod $GRAVITEE_NS $GRAVITEE_POD_NAME nc -zv $REDIS_SVC_IP $REDIS_SVC_PORT 2>&1 || 
        exec_in_pod $GRAVITEE_NS $GRAVITEE_POD_NAME telnet $REDIS_SVC_IP $REDIS_SVC_PORT 2>&1 ||
        echo "Could not test connectivity (nc/telnet not available)" | tee -a "$OUTPUT_FILE"
    fi
  fi
  echo "" | tee -a "$OUTPUT_FILE"

  echo "=== Redis Resource Utilization ===" | tee -a "$OUTPUT_FILE"
  if [ -n "$REDIS_POD" ]; then
    echo "Getting Redis resource usage..." | tee -a "$OUTPUT_FILE"
    kubectl top pod -n $REDIS_NS $REDIS_POD 2>/dev/null || echo "Metrics server not available" | tee -a "$OUTPUT_FILE"
  fi
  echo "" | tee -a "$OUTPUT_FILE"

} 2>&1

echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Redis issues in Kubernetes."