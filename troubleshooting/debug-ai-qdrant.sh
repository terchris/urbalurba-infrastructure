#!/bin/bash
# debug-ai-qdrant.sh - Script to collect debugging information for Qdrant in a Kubernetes cluster
# This script gathers detailed information about Qdrant deployment, configuration, and performance

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ai-qdrant-${TIMESTAMP}.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ai-qdrant-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    # Get list of files sorted by time (newest first), skip the first $files_to_keep files, and remove the rest
    ls -t "$OUTPUT_DIR"/debug-ai-qdrant-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

echo "Collecting Qdrant debugging information..."
echo "This may take a few minutes, please be patient..."

# Function to print section headers
print_section() {
  echo "=== $1 ===" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
}

# Function to run kubectl commands and append output to the debug file
run_kubectl() {
  local cmd=$1
  local description=$2
  
  echo "Step: Collecting $description..." | tee -a "$OUTPUT_FILE"
  echo "$ $cmd" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Run the command and capture its output
  local output
  output=$(eval "$cmd" 2>&1)
  local status=$?
  
  # Write the output to the file and console
  echo "$output" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Log the status to the console
  if [ $status -eq 0 ]; then
    if [ -z "$output" ]; then
      echo "  Result: No data found" | tee -a "$OUTPUT_FILE"
    else
      echo "  Result: Success" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "  Result: Command failed with status $status" | tee -a "$OUTPUT_FILE"
  fi
  echo "" | tee -a "$OUTPUT_FILE"
}

# Main output collection
{
  print_section "Qdrant Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Check if Qdrant is found
  QDRANT_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=qdrant -o name 2>/dev/null | head -1)
  if [ -z "$QDRANT_POD" ]; then
    echo "Error: No Qdrant pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if Qdrant is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-ai-qdrant.sh <namespace>" | tee -a "$OUTPUT_FILE"
    exit 1
  fi
  
  # Basic Qdrant information
  print_section "Qdrant Basic Information"
  run_kubectl "kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant Resources"
  
  # Pod information
  print_section "Qdrant Pod Status"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o wide" "Qdrant Pod List"
  run_kubectl "kubectl describe pods -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant Pod Details"
  
  # Service information
  print_section "Qdrant Service Details"
  run_kubectl "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o wide" "Qdrant Service List"
  run_kubectl "kubectl describe svc -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant Service Details"
  
  # Storage information
  print_section "Qdrant Storage Status"
  run_kubectl "kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant PVC List"
  run_kubectl "kubectl describe pvc -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant PVC Details"
  
  # Configuration
  print_section "Qdrant Configuration"
  run_kubectl "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant ConfigMap List"
  run_kubectl "kubectl get secrets -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant Secret List"
  
  # Resource usage
  print_section "Qdrant Resource Usage"
  QDRANT_POD_NAME=$(echo "$QDRANT_POD" | sed 's/^pod\///')
  if [ -n "$QDRANT_POD_NAME" ]; then
    run_kubectl "kubectl top pod -n $NAMESPACE $QDRANT_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "Qdrant Pod Resource Usage"
  fi
  
  # API connectivity tests
  print_section "Qdrant API Connectivity Tests"
  QDRANT_SVC=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=qdrant -o name 2>/dev/null | head -1)
  if [ -n "$QDRANT_SVC" ]; then
    QDRANT_SVC_NAME=$(echo "$QDRANT_SVC" | sed 's/^service\///')
    QDRANT_PORT=$(kubectl get svc -n $NAMESPACE $QDRANT_SVC_NAME -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null)
    
    if [ -n "$QDRANT_PORT" ]; then
      run_kubectl "kubectl run curl-test-qdrant --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$QDRANT_SVC_NAME:$QDRANT_PORT/health" "Qdrant Health Check"
      run_kubectl "kubectl run curl-test-qdrant --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$QDRANT_SVC_NAME:$QDRANT_PORT/collections" "Qdrant Collections List"
    fi
  fi
  
  # Logs analysis
  print_section "Qdrant Logs Analysis"
  if [ -n "$QDRANT_POD_NAME" ]; then
    run_kubectl "kubectl logs -n $NAMESPACE $QDRANT_POD_NAME | grep -i 'error\\|warn\\|fail' | tail -20" "Recent Errors and Warnings"
    run_kubectl "kubectl logs -n $NAMESPACE $QDRANT_POD_NAME --tail=100" "Recent Logs"
  fi
  
  # Storage usage
  print_section "Qdrant Storage Usage"
  if [ -n "$QDRANT_POD_NAME" ]; then
    run_kubectl "kubectl exec -n $NAMESPACE $QDRANT_POD_NAME -- df -h /qdrant/storage /qdrant/snapshots 2>/dev/null || echo 'Unable to check storage usage'" "Qdrant Storage Usage"
  fi
  
  # Events
  print_section "Qdrant-Related Events"
  run_kubectl "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'qdrant' | tail -15" "Recent Qdrant Events"
  
  # Network policies
  print_section "Network Policies"
  run_kubectl "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace"
  
  # Health analysis
  print_section "Qdrant Health Analysis"
  
  # Initialize status variables
  OVERALL_STATUS="Healthy"
  ISSUES_FOUND=0
  
  # Check pod status
  POD_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Issue: Qdrant pod is not in Running state (current state: $POD_STATUS)" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Qdrant pod is running correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check PVC status
  PVC_STATUS=$(kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o jsonpath='{.items[*].status.phase}' | grep -v "Bound" | wc -l)
  if [ "$PVC_STATUS" -gt 0 ]; then
    echo "❌ Issue: One or more Qdrant PVCs are not properly bound" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ All Qdrant PVCs are properly bound" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check API connectivity
  if grep -q "curl-test-qdrant deleted" "$OUTPUT_FILE"; then
    echo "✅ Qdrant API is responding correctly" | tee -a "$OUTPUT_FILE"
  else
    echo "❌ Issue: Qdrant API health check failed - service may be unreachable" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check for error logs
  ERROR_COUNT=$(grep -i "error" "$OUTPUT_FILE" | grep -v "No errors found" | grep -v "grep -i 'error\\|warn\\|fail'" | wc -l)
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️ Found $ERROR_COUNT references to errors in the logs - review the log analysis section" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ No obvious errors found in the logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check storage usage
  STORAGE_USAGE=$(grep -A 2 "Storage Usage" "$OUTPUT_FILE" | grep "%" | awk '{print $5}' | sed 's/%//')
  if [ ! -z "$STORAGE_USAGE" ] && [ "$STORAGE_USAGE" -gt 85 ]; then
    echo "⚠️ Storage usage is high ($STORAGE_USAGE%) - consider expanding capacity" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif [ ! -z "$STORAGE_USAGE" ]; then
    echo "✅ Storage usage is acceptable ($STORAGE_USAGE%)" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check resource usage
  if grep -q "CPU.*[7-9][0-9]" "$OUTPUT_FILE" || grep -q "CPU.*100" "$OUTPUT_FILE"; then
    echo "⚠️ CPU usage appears high - consider increasing resource limits" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ CPU usage appears normal" | tee -a "$OUTPUT_FILE"
  fi
  
  if grep -q "MEMORY.*[8-9][0-9]%" "$OUTPUT_FILE" || grep -q "MEMORY.*100%" "$OUTPUT_FILE"; then
    echo "⚠️ Memory usage appears high - consider increasing resource limits" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Memory usage appears normal" | tee -a "$OUTPUT_FILE"
  fi
  
  # Final summary
  print_section "Summary and Recommendations"
  echo "Overall Qdrant Status: $OVERALL_STATUS" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Found $ISSUES_FOUND potential issues that may need attention:" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    if grep -q "pod is not in Running state" "$OUTPUT_FILE"; then
      echo "• Check pod events: kubectl describe pod -n $NAMESPACE $QDRANT_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Review pod logs: kubectl logs -n $NAMESPACE $QDRANT_POD_NAME" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "PVCs are not properly bound" "$OUTPUT_FILE"; then
      echo "• Verify PVC status: kubectl describe pvc -n $NAMESPACE -l app.kubernetes.io/name=qdrant" | tee -a "$OUTPUT_FILE"
      echo "• Check storage class: kubectl get sc" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "API health check failed" "$OUTPUT_FILE"; then
      echo "• Verify service endpoints: kubectl get endpoints -n $NAMESPACE qdrant" | tee -a "$OUTPUT_FILE"
      echo "• Check pod networking: kubectl exec -n $NAMESPACE $QDRANT_POD_NAME -- curl localhost:6333/health" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "references to errors in the logs" "$OUTPUT_FILE"; then
      echo "• Examine full logs: kubectl logs -n $NAMESPACE $QDRANT_POD_NAME | grep -i error" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Storage usage is high" "$OUTPUT_FILE"; then
      echo "• Increase PVC size: kubectl patch pvc -n $NAMESPACE qdrant-storage-qdrant-0 -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"20Gi\"}}}}' (if storage class supports expansion)" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "CPU usage appears high\|Memory usage appears high" "$OUTPUT_FILE"; then
      echo "• Adjust resource limits in your Helm chart or deployment YAML" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No issues detected - Qdrant appears to be functioning correctly!" | tee -a "$OUTPUT_FILE"
  fi
  
  echo "" | tee -a "$OUTPUT_FILE"
  echo "For more information, refer to the Qdrant documentation at https://qdrant.tech/documentation/" | tee -a "$OUTPUT_FILE"
} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Qdrant issues."

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES"