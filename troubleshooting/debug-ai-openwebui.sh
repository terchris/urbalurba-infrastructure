#!/bin/bash
# debug-ai-openwebui.sh - Script to collect debugging information for Open WebUI in a Kubernetes cluster
# This script gathers detailed information about Open WebUI deployment, configuration, and connectivity

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ai-openwebui-${TIMESTAMP}.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}
OPENWEBUI_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=open-webui -o name 2>/dev/null | head -1)
OPENWEBUI_SVC=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/component=open-webui -o name 2>/dev/null | head -1)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ai-openwebui-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    ls -t "$OUTPUT_DIR"/debug-ai-openwebui-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

echo "Collecting Open WebUI debugging information in namespace $NAMESPACE..."
echo "Output will be saved to $OUTPUT_FILE"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl command not found. Please install kubectl first." | tee -a "$OUTPUT_FILE"
  exit 1
fi

# Function to print section headers
print_section() {
  echo "=== $1 ===" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

# Function to run commands and append output to the debug file
run_command() {
  local cmd=$1
  local description=$2
  local step_number=$3
  
  echo "Step $step_number: Collecting $description..." | tee -a "$OUTPUT_FILE"
  echo "$ $cmd" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Run the command and capture its output
  local output
  output=$(eval "$cmd" 2>&1)
  local status=$?
  
  # Write the output to the file
  echo "$output" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Log the status to the console
  if [ $status -eq 0 ]; then
    if [ -z "$output" ]; then
      echo "  Result: No data found" | tee -a "$OUTPUT_FILE"
    else
      echo "  Result: Success" 
    fi
  else
    echo "  Result: Command failed with status $status" | tee -a "$OUTPUT_FILE"
  fi
  echo ""
}

# Main output collection
{
  print_section "Open WebUI Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Check if Open WebUI is found
  if [ -z "$OPENWEBUI_POD" ]; then
    echo "Error: No Open WebUI pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if Open WebUI is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-ai-openwebui.sh <namespace>" | tee -a "$OUTPUT_FILE"
    exit 1
  fi
  
  # Step counter initialization
  STEP=1
  
  print_section "Open WebUI Basic Information"
  
  # Find all resources related to Open WebUI
  run_command "kubectl get all -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI Resources" $STEP
  STEP=$((STEP+1))
  
  # Get version of Open WebUI
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[0].spec.containers[0].image}'" "Open WebUI Version" $STEP
  STEP=$((STEP+1))
  
  # Get Open WebUI pod information
  print_section "Open WebUI Pod Status"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o wide" "Open WebUI Pod List" $STEP
  STEP=$((STEP+1))
  
  # Get detailed pod description for troubleshooting
  run_command "kubectl describe pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI Pod Details" $STEP
  STEP=$((STEP+1))
  
  # Get restart count
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}'" "Pod Restart Count" $STEP
  STEP=$((STEP+1))
  
  # Get Open WebUI service information
  print_section "Open WebUI Service Details"
  run_command "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o wide" "Open WebUI Service List" $STEP
  STEP=$((STEP+1))
  
  # Get persistent volume claims
  print_section "Open WebUI Storage"
  run_command "kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI PVC List" $STEP
  STEP=$((STEP+1))
  
  # Check PVC details if they exist
  if kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui &>/dev/null; then
    run_command "kubectl describe pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI PVC Details" $STEP
    STEP=$((STEP+1))
  fi
  
  # Get ingress resources if any
  print_section "Open WebUI Ingress"
  run_command "kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/component=open-webui 2>/dev/null || echo 'No ingress resources found'" "Open WebUI Ingress Resources" $STEP
  STEP=$((STEP+1))
  
  # Check ingress details if they exist
  if kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/component=open-webui &>/dev/null; then
    run_command "kubectl describe ingress -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI Ingress Details" $STEP
    STEP=$((STEP+1))
  fi
  
  # Get pod resource usage
  print_section "Open WebUI Resource Usage"
  OPENWEBUI_POD_NAME=$(echo "$OPENWEBUI_POD" | sed 's/^pod\///')
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    run_command "kubectl top pod -n $NAMESPACE $OPENWEBUI_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "Open WebUI Pod Resource Usage" $STEP
    STEP=$((STEP+1))
  else
    echo "No Open WebUI pod found to retrieve resource usage" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check resource limits and requests
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    run_command "kubectl get pod -n $NAMESPACE $OPENWEBUI_POD_NAME -o jsonpath='{.spec.containers[0].resources}'" "Resource Limits and Requests" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check environment variables for key configuration
  print_section "Open WebUI Configuration"
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    # Check for critical environment variables
    run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep -E 'TIKA|QDRANT|OPENAI|OLLAMA|REDIS|VECTOR|RAG|DATABASE|ENV|HOST|PORT|ENABLE_'" "Configuration Environment Variables" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check database path
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- ls -la /app/backend/data/ 2>/dev/null || echo 'Unable to access data directory'" "Database Files" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check for pip package issues
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- pip check 2>/dev/null || echo 'Unable to check pip packages'" "Pip Package Dependency Check" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check API connectivity
  print_section "Open WebUI API Connectivity Tests"
  if [ -n "$OPENWEBUI_SVC" ]; then
    OPENWEBUI_SVC_NAME=$(echo "$OPENWEBUI_SVC" | sed 's/^service\///')
    OPENWEBUI_PORT=$(kubectl get svc -n $NAMESPACE $OPENWEBUI_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -n "$OPENWEBUI_PORT" ]; then
      # Test connection with curl from a temporary pod
      echo "Testing Open WebUI API connection..." | tee -a "$OUTPUT_FILE"
      
      # Health check
      run_command "kubectl run curl-test-openwebui --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$OPENWEBUI_SVC_NAME:$OPENWEBUI_PORT/health" "Open WebUI Health Check" $STEP
      STEP=$((STEP+1))
      
      # Check if DB is initialized
      run_command "kubectl run curl-test-openwebui --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$OPENWEBUI_SVC_NAME:$OPENWEBUI_PORT/health/db" "Open WebUI Database Health Check" $STEP
      STEP=$((STEP+1))
    else
      echo "Could not determine Open WebUI service port" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No Open WebUI service found to test API" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check for integration with Ollama
  print_section "Ollama Integration"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=ollama || echo 'No Ollama pods found'" "Ollama Pods" $STEP
  STEP=$((STEP+1))
  
  # Test Ollama connectivity from Open WebUI
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    OLLAMA_URL=$(kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep OLLAMA_BASE_URL | cut -d= -f2 2>/dev/null)
    if [ -n "$OLLAMA_URL" ]; then
      run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- curl -s $OLLAMA_URL/api/version 2>/dev/null || echo 'Cannot connect to Ollama service'" "Ollama Connectivity Test" $STEP
      STEP=$((STEP+1))
    fi
  fi
  
  # Check for Pipelines integration
  print_section "Pipelines Integration"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=pipelines || echo 'No Pipelines pods found'" "Pipelines Pods" $STEP
  STEP=$((STEP+1))
  
  # Test Pipelines connectivity if enabled
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    PIPELINES_ENABLED=$(kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep -i "PIPELINES" | wc -l 2>/dev/null)
    if [ "$PIPELINES_ENABLED" -gt 0 ]; then
      PIPELINES_URL=$(kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep -i "PIPELINES_URL" | cut -d= -f2 2>/dev/null)
      if [ -n "$PIPELINES_URL" ]; then
        run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- curl -s $PIPELINES_URL/health 2>/dev/null || echo 'Cannot connect to Pipelines service'" "Pipelines Connectivity Test" $STEP
        STEP=$((STEP+1))
      fi
    fi
  fi
  
  # Check for Tika integration
  print_section "Tika Integration" 
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=tika || echo 'No Tika pods found'" "Tika Pods" $STEP
  STEP=$((STEP+1))
  
  # Test Tika connectivity if configured
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    TIKA_URL=$(kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep TIKA_SERVER_URL | cut -d= -f2 2>/dev/null)
    if [ -n "$TIKA_URL" ]; then
      run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- curl -s $TIKA_URL/tika 2>/dev/null || echo 'Cannot connect to Tika service'" "Tika Connectivity Test" $STEP
      STEP=$((STEP+1))
    fi
  fi
  
  # Check for Qdrant or vector database integration
  print_section "Vector Database Integration"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=qdrant || echo 'No Qdrant pods found'" "Qdrant Pods" $STEP
  STEP=$((STEP+1))
  
  # Test Qdrant connectivity if configured
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    QDRANT_URI=$(kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- env | grep QDRANT_URI | cut -d= -f2 2>/dev/null)
    if [ -n "$QDRANT_URI" ]; then
      run_command "kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- curl -s $QDRANT_URI/health 2>/dev/null || echo 'Cannot connect to Qdrant service'" "Qdrant Connectivity Test" $STEP
      STEP=$((STEP+1))
    fi
  fi
  
  # Get pod logs
  print_section "Open WebUI Logs Analysis"
  if [ -n "$OPENWEBUI_POD_NAME" ]; then
    # Check for error patterns in logs
    run_command "kubectl logs -n $NAMESPACE $OPENWEBUI_POD_NAME --tail=100 | grep -i 'error\\|warn\\|exception\\|fail' | tail -20" "Recent Errors and Warnings" $STEP
    STEP=$((STEP+1))
    
    # Check startup logs for critical information
    run_command "kubectl logs -n $NAMESPACE $OPENWEBUI_POD_NAME --tail=50 | grep -i 'starting\\|initialized\\|ready\\|listening\\|running'" "Startup Information" $STEP
    STEP=$((STEP+1))
    
    # Check previous container logs if restarts detected
    RESTART_COUNT=$(kubectl get pods -n $NAMESPACE $OPENWEBUI_POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
    if [ "$RESTART_COUNT" -gt 0 ]; then
      run_command "kubectl logs -n $NAMESPACE $OPENWEBUI_POD_NAME --previous --tail=50 | grep -i 'error\\|exception\\|fatal'" "Previous Container Crash Logs" $STEP
      STEP=$((STEP+1))
    fi
  else
    echo "No Open WebUI pod found to retrieve logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check events related to Open WebUI
  print_section "Open WebUI-Related Events"
  run_command "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'open-webui\\|openwebui' | tail -15" "Recent Open WebUI Events" $STEP
  STEP=$((STEP+1))
  
  # Check for network policies
  print_section "Network Policies"
  run_command "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace" $STEP
  STEP=$((STEP+1))
  
  # Check for ConfigMaps used by Open WebUI
  print_section "ConfigMaps and Secrets"
  run_command "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI ConfigMaps" $STEP
  STEP=$((STEP+1))
  
  # Check secrets (without exposing values)
  run_command "kubectl get secret -n $NAMESPACE -l app.kubernetes.io/component=open-webui" "Open WebUI Secrets" $STEP
  STEP=$((STEP+1))
  
  # Analyze the results and provide a meaningful summary
  print_section "Open WebUI Health Analysis"
  
  # Initialize status variables
  OVERALL_STATUS="Healthy"
  ISSUES_FOUND=0
  
  # Check pod status
  POD_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Issue: Open WebUI pod is not in Running state (current state: $POD_STATUS)" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Open WebUI pod is running correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check pod ready status
  POD_READY=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  if [ "$POD_READY" != "true" ]; then
    echo "❌ Issue: Open WebUI container is not ready" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Open WebUI container is ready and accepting connections" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check pod restarts
  RESTART_COUNT=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
  if [ "$RESTART_COUNT" -gt 5 ]; then
    echo "❌ Issue: Open WebUI pod has restarted $RESTART_COUNT times - indicates stability problems" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif [ "$RESTART_COUNT" -gt 1 ]; then
    echo "⚠️ Warning: Open WebUI pod has restarted $RESTART_COUNT times" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Open WebUI pod restart count is low ($RESTART_COUNT)" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check PVC status
  PVC_STATUS=$(kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -v "Bound" | wc -l)
  if [ "$PVC_STATUS" -gt 0 ]; then
    echo "❌ Issue: One or more Open WebUI PVCs are not properly bound" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif [ -z "$(kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui 2>/dev/null)" ]; then
    echo "⚠️ Warning: No persistent storage found for Open WebUI - data may be lost on pod restarts" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Open WebUI persistent storage is correctly configured" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check API connectivity using the health check results
  HEALTH_CHECK_RESULT=$(grep -i "healthz" "$OUTPUT_FILE" || grep -i "200 OK" "$OUTPUT_FILE" || grep -i "health" "$OUTPUT_FILE" | grep -v "No" | wc -l)
  if [ "$HEALTH_CHECK_RESULT" -lt 1 ]; then
    echo "❌ Issue: Open WebUI API health check failed - service may be unreachable" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Open WebUI API is responding correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check database health
  DB_HEALTH_CHECK=$(grep -i "db.*healthy\|database.*connected" "$OUTPUT_FILE" | wc -l)
  if [ "$DB_HEALTH_CHECK" -lt 1 ]; then
    echo "⚠️ Warning: Database health check information not found - verify database connectivity" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Database connectivity appears normal" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check for error logs
  ERROR_COUNT=$(grep -i -E "error|exception|failure" "$OUTPUT_FILE" | grep -v "No errors found" | grep -v "grep -i 'error\\|warn\\|exception\\|fail'" | wc -l)
  if [ "$ERROR_COUNT" -gt 5 ]; then
    echo "❌ Issue: Found $ERROR_COUNT significant errors in the logs - review the log analysis section" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️ Warning: Found $ERROR_COUNT errors or warnings in the logs" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ No obvious errors found in the logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check resource usage
  CPU_USAGE=$(grep "CPU(cores)" -A 1 "$OUTPUT_FILE" | tail -1 | awk '{print $2}' 2>/dev/null)
  if [ ! -z "$CPU_USAGE" ]; then
    CPU_VALUE=$(echo $CPU_USAGE | sed 's/m//')
    if [ "$CPU_VALUE" -gt 800 ]; then
      echo "⚠️ CPU usage is high ($CPU_USAGE) - Open WebUI may be under heavy load" | tee -a "$OUTPUT_FILE"
      if [ "$OVERALL_STATUS" = "Healthy" ]; then
        OVERALL_STATUS="Warning"
      fi
      ISSUES_FOUND=$((ISSUES_FOUND+1))
    else
      echo "✅ CPU usage is normal ($CPU_USAGE)" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  # Check memory usage
  MEMORY_USAGE=$(grep "MEMORY(bytes)" -A 1 "$OUTPUT_FILE" | tail -1 | awk '{print $3}' 2>/dev/null)
  if [ ! -z "$MEMORY_USAGE" ]; then
    if [[ "$MEMORY_USAGE" == *Gi ]]; then
      MEMORY_VALUE=$(echo $MEMORY_USAGE | sed 's/Gi//')
      if (( $(echo "$MEMORY_VALUE > 1" | bc -l) )); then
        echo "⚠️ Memory usage is high ($MEMORY_USAGE) - close to the limit" | tee -a "$OUTPUT_FILE"
        if [ "$OVERALL_STATUS" = "Healthy" ]; then
          OVERALL_STATUS="Warning"
        fi
        ISSUES_FOUND=$((ISSUES_FOUND+1))
      else
        echo "✅ Memory usage is normal ($MEMORY_USAGE)" | tee -a "$OUTPUT_FILE"
      fi
    elif [[ "$MEMORY_USAGE" == *Mi ]]; then
      MEMORY_MI=$(echo $MEMORY_USAGE | sed 's/Mi//')
      if [ "$MEMORY_MI" -gt 900 ]; then
        echo "⚠️ Memory usage is high ($MEMORY_USAGE) - close to the limit" | tee -a "$OUTPUT_FILE"
        if [ "$OVERALL_STATUS" = "Healthy" ]; then
          OVERALL_STATUS="Warning"
        fi
        ISSUES_FOUND=$((ISSUES_FOUND+1))
      else
        echo "✅ Memory usage is normal ($MEMORY_USAGE)" | tee -a "$OUTPUT_FILE"
      fi
    fi
  fi
  
  # Check for Ollama integration
  if grep -q "ollama" "$OUTPUT_FILE" && ! grep -q "No Ollama pods found" "$OUTPUT_FILE"; then
    echo "✅ Ollama integration detected" | tee -a "$OUTPUT_FILE"
    
    # Check if OLLAMA_BASE_URL is configured and connectivity
    if grep -q "OLLAMA_BASE_URL" "$OUTPUT_FILE"; then
      echo "  ✅ OLLAMA_BASE_URL environment variable is configured" | tee -a "$OUTPUT_FILE"
      
      # Check if Ollama connectivity test succeeded
      if grep -q "version" "$OUTPUT_FILE" && grep -q "Ollama Connectivity Test" "$OUTPUT_FILE"; then
        echo "  ✅ Ollama connectivity verified" | tee -a "$OUTPUT_FILE"
      else
        echo "  ❌ Issue: Ollama connectivity failed - check network and Ollama service" | tee -a "$OUTPUT_FILE"
        if [ "$OVERALL_STATUS" = "Healthy" ]; then
          OVERALL_STATUS="Warning"
        fi
        ISSUES_FOUND=$((ISSUES_FOUND+1))
      fi
    else
      echo "  ⚠️ OLLAMA_BASE_URL environment variable not found" | tee -a "$OUTPUT_FILE"
      if [ "$OVERALL_STATUS" = "Healthy" ]; then
        OVERALL_STATUS="Warning"
      fi
      ISSUES_FOUND=$((ISSUES_FOUND+1))
    fi
  else
    echo "ℹ️ No Ollama integration detected - using different LLM backend" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check for Pipelines integration
  if grep -q "pipelines" "$OUTPUT_FILE" && ! grep -q "No Pipelines pods found" "$OUTPUT_FILE"; then
    echo "✅ Pipelines integration detected" | tee -a "$OUTPUT_FILE"
    
    # Check Pipelines connectivity
    if grep -q "Pipelines Connectivity Test" "$OUTPUT_FILE" && ! grep -q "Cannot connect to Pipelines" "$OUTPUT_FILE"; then
      echo "  ✅ Pipelines connectivity verified" | tee -a "$OUTPUT_FILE"
    else
      echo "  ⚠️ Warning: Pipelines connectivity issue detected" | tee -a "$OUTPUT_FILE"
      if [ "$OVERALL_STATUS" = "Healthy" ]; then
        OVERALL_STATUS="Warning"
      fi
      ISSUES_FOUND=$((ISSUES_FOUND+1))
    fi
  else
    echo "ℹ️ No Pipelines integration detected - advanced features may be limited" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check for Vector DB integration
  if grep -q "VECTOR_DB" "$OUTPUT_FILE"; then
    VECTOR_DB=$(grep -i "VECTOR_DB" "$OUTPUT_FILE" | sed 's/.*=//' | tr -d '\r')
    echo "✅ Vector DB integration detected ($VECTOR_DB)" | tee -a "$OUTPUT_FILE"
    
    # Check Vector DB connectivity
    if grep -q "Qdrant Connectivity Test" "$OUTPUT_FILE" && ! grep -q "Cannot connect to Qdrant" "$OUTPUT_FILE"; then
      echo "  ✅ Vector DB connectivity verified" | tee -a "$OUTPUT_FILE"
    else
      echo "  ⚠️ Warning: Vector DB connectivity issue detected" | tee -a "$OUTPUT_FILE"
      if [ "$OVERALL_STATUS" = "Healthy" ]; then
        OVERALL_STATUS="Warning"
      fi
      ISSUES_FOUND=$((ISSUES_FOUND+1))
    fi
  else
    echo "ℹ️ No Vector DB integration detected - vector search features may be limited" | tee -a "$OUTPUT_FILE"
  fi
  
  # Final summary
  print_section "Final Summary"
  echo "Overall Status: $OVERALL_STATUS" | tee -a "$OUTPUT_FILE"
  echo "Total Issues Found: $ISSUES_FOUND" | tee -a "$OUTPUT_FILE"
  
  if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo "✅ Open WebUI appears to be functioning normally" | tee -a "$OUTPUT_FILE"
  elif [ "$OVERALL_STATUS" = "Warning" ]; then
    echo "⚠️ Open WebUI has some minor issues that should be investigated" | tee -a "$OUTPUT_FILE"
  else
    echo "❌ Open WebUI has critical issues that need immediate attention" | tee -a "$OUTPUT_FILE"
  fi
  
  echo "" | tee -a "$OUTPUT_FILE"
  echo "Debug information has been saved to $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
  echo "Please review the detailed information above and in the output file for troubleshooting." | tee -a "$OUTPUT_FILE"
  
  # Only show relevant troubleshooting recommendations if issues found
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    print_section "Troubleshooting Recommendations"
    
    if grep -q "pod is not in Running state\|pod is not ready" "$OUTPUT_FILE"; then
      echo "• Check pod events: kubectl describe pod -n $NAMESPACE $OPENWEBUI_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Review pod logs: kubectl logs -n $NAMESPACE $OPENWEBUI_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod's liveness/readiness probes in the deployment" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "API health check failed" "$OUTPUT_FILE"; then
      echo "• Verify service endpoints: kubectl get endpoints -n $NAMESPACE $OPENWEBUI_SVC_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod networking: kubectl exec -n $NAMESPACE $OPENWEBUI_POD_NAME -- curl localhost:$OPENWEBUI_PORT/health" | tee -a "$OUTPUT_FILE"
      echo "• Restart the Open WebUI pod: kubectl delete pod -n $NAMESPACE $OPENWEBUI_POD_NAME" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "references to errors in the logs" "$OUTPUT_FILE"; then
      echo "• Examine full logs: kubectl logs -n $NAMESPACE $OPENWEBUI_POD_NAME | grep -i 'error\\|exception'" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "CPU usage is high\|Memory usage is high" "$OUTPUT_FILE"; then
      echo "• Increase resources in your deployment YAML:" | tee -a "$OUTPUT_FILE"
      echo "  resources:" | tee -a "$OUTPUT_FILE"
      echo "    requests:" | tee -a "$OUTPUT_FILE"
      echo "      memory: 1Gi       # Increase as needed" | tee -a "$OUTPUT_FILE"
      echo "      cpu: 500m         # Increase as needed" | tee -a "$OUTPUT_FILE"
      echo "    limits:" | tee -a "$OUTPUT_FILE"
      echo "      memory: 2Gi       # Increase as needed" | tee -a "$OUTPUT_FILE"
      echo "      cpu: 1000m        # Increase as needed" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "PVCs are not properly bound" "$OUTPUT_FILE"; then
      echo "• Check PVC status: kubectl describe pvc -n $NAMESPACE -l app.kubernetes.io/component=open-webui" | tee -a "$OUTPUT_FILE"
      echo "• Verify storage class configuration" | tee -a "$OUTPUT_FILE"
      echo "• Check for storage capacity issues" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Ollama connectivity failed" "$OUTPUT_FILE"; then
      echo "• Verify Ollama service is running: kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=ollama" | tee -a "$OUTPUT_FILE"
      echo "• Check OLLAMA_BASE_URL configuration" | tee -a "$OUTPUT_FILE"
      echo "• Verify network policies allow communication" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Pipelines connectivity issue" "$OUTPUT_FILE"; then
      echo "• Verify Pipelines service is running: kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=pipelines" | tee -a "$OUTPUT_FILE"
      echo "• Check Pipelines URL configuration" | tee -a "$OUTPUT_FILE"
      echo "• Verify network policies allow communication" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Vector DB connectivity issue" "$OUTPUT_FILE"; then
      echo "• Verify Vector DB service is running: kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=qdrant" | tee -a "$OUTPUT_FILE"
      echo "• Check Vector DB URI configuration" | tee -a "$OUTPUT_FILE"
      echo "• Verify network policies allow communication" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  print_section "Debug Summary"
  echo "Open WebUI debug information collected and saved to $OUTPUT_FILE"
  echo "Completed $((STEP-1)) diagnostic checks on your Open WebUI installation"
  echo ""
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Overall status: $OVERALL_STATUS"
    echo "Found $ISSUES_FOUND potential issues that may need attention"
    echo "See the Open WebUI Health Analysis section for details and specific troubleshooting steps"
  else
    echo "Overall status: Healthy"
    echo "All diagnostics passed - your Open WebUI installation appears to be functioning correctly"
  fi
  echo ""
  echo "For more information, refer to the Open WebUI documentation at https://github.com/open-webui/open-webui"

} 2>&1

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES"

echo "Debug information has been collected and saved to $OUTPUT_FILE"