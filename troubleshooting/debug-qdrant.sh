#!/bin/bash
# debug-qdrant.sh - Script to collect debugging information for Qdrant in a Kubernetes cluster
# This script gathers detailed information about Qdrant deployment, configuration, and performance

# Set variables
OUTPUT_FILE="debug-qdrant.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}
QDRANT_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=qdrant -o name 2>/dev/null | head -1)
QDRANT_SVC=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=qdrant -o name 2>/dev/null | head -1)

# Remove previous debug file if it exists
if [ -f "$OUTPUT_FILE" ]; then
  rm "$OUTPUT_FILE"
fi

echo "Collecting Qdrant debugging information in namespace $NAMESPACE..."
echo "Output will be saved to $OUTPUT_FILE"

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
  print_section "Qdrant Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Check if Qdrant is found
  if [ -z "$QDRANT_POD" ]; then
    echo "Error: No Qdrant pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if Qdrant is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-qdrant.sh <namespace>" | tee -a "$OUTPUT_FILE"
    exit 1
  fi
  
  # Step counter initialization
  STEP=1
  
  print_section "Qdrant Basic Information"
  
  # Find all resources related to Qdrant
  run_command "kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant Resources" $STEP
  STEP=$((STEP+1))
  
  # Get Qdrant pod information
  print_section "Qdrant Pod Status"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o wide" "Qdrant Pod List" $STEP
  STEP=$((STEP+1))
  
  # Get Qdrant service information
  print_section "Qdrant Service Details"
  run_command "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=qdrant -o wide" "Qdrant Service List" $STEP
  STEP=$((STEP+1))
  
  # Get persistent volume claims for Qdrant
  print_section "Qdrant Storage Status"
  run_command "kubectl get pvc -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant PVC List" $STEP
  STEP=$((STEP+1))
  
  # Get Qdrant config maps and secrets (without exposing secret values)
  print_section "Qdrant Configuration"
  run_command "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=qdrant" "Qdrant ConfigMap List" $STEP
  STEP=$((STEP+1))
  
  # Get pod resource usage
  print_section "Qdrant Resource Usage"
  QDRANT_POD_NAME=$(echo "$QDRANT_POD" | sed 's/^pod\///')
  if [ -n "$QDRANT_POD_NAME" ]; then
    run_command "kubectl top pod -n $NAMESPACE $QDRANT_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "Qdrant Pod Resource Usage" $STEP
    STEP=$((STEP+1))
  else
    echo "No Qdrant pod found to retrieve resource usage" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check Qdrant API connectivity and endpoints
  print_section "Qdrant API Connectivity Tests"
  
  # Extract Qdrant service details
  if [ -n "$QDRANT_SVC" ]; then
    QDRANT_SVC_NAME=$(echo "$QDRANT_SVC" | sed 's/^service\///')
    QDRANT_PORT=$(kubectl get svc -n $NAMESPACE $QDRANT_SVC_NAME -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null)
    
    if [ -n "$QDRANT_PORT" ]; then
      # Test connection with curl from a temporary pod
      echo "Testing Qdrant API connection..." | tee -a "$OUTPUT_FILE"
      
      # Health check
      run_command "kubectl run curl-test-qdrant --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$QDRANT_SVC_NAME:$QDRANT_PORT/health" "Qdrant Health Check" $STEP
      STEP=$((STEP+1))
      
      # List collections
      run_command "kubectl run curl-test-qdrant --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$QDRANT_SVC_NAME:$QDRANT_PORT/collections" "Qdrant Collections List" $STEP
      STEP=$((STEP+1))
    else
      echo "Could not determine Qdrant service port" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No Qdrant service found to test API" | tee -a "$OUTPUT_FILE"
  fi
  
  # Get pod logs
  print_section "Qdrant Logs Analysis"
  if [ -n "$QDRANT_POD_NAME" ]; then
    # Check for error patterns in logs
    run_command "kubectl logs -n $NAMESPACE $QDRANT_POD_NAME | grep -i 'error\\|warn\\|fail' | tail -20" "Recent Errors and Warnings" $STEP
    STEP=$((STEP+1))
  else
    echo "No Qdrant pod found to retrieve logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Qdrant storage usage
  print_section "Qdrant Storage Usage"
  if [ -n "$QDRANT_POD_NAME" ]; then
    run_command "kubectl exec -n $NAMESPACE $QDRANT_POD_NAME -- df -h /qdrant/storage /qdrant/snapshots 2>/dev/null || echo 'Unable to check storage usage'" "Qdrant Storage Usage" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check events related to Qdrant
  print_section "Qdrant-Related Events"
  run_command "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'qdrant' | tail -15" "Recent Qdrant Events" $STEP
  STEP=$((STEP+1))
  
  # Check for network policies affecting Qdrant
  print_section "Network Policies"
  run_command "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace" $STEP
  STEP=$((STEP+1))
  
  # Analyze the results and provide a meaningful summary
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
  
  # Check API connectivity using the health check results
  HEALTH_CHECK_RESULT=$(grep "curl-test-qdrant deleted" "$OUTPUT_FILE" | wc -l)
  if [ "$HEALTH_CHECK_RESULT" -lt 2 ]; then
    echo "❌ Issue: Qdrant API health check failed - service may be unreachable" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Qdrant API is responding correctly" | tee -a "$OUTPUT_FILE"
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
  STORAGE_USAGE=$(grep -A 2 "Step.*Storage Usage" "$OUTPUT_FILE" | grep "%" | awk '{print $5}' | sed 's/%//')
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
  
  # Check for network policies that might block Qdrant
  if grep -q "app=qdrant" <<< "$(kubectl get networkpolicies -n $NAMESPACE -o yaml 2>/dev/null)"; then
    echo "⚠️ Found network policies that may affect Qdrant - verify they allow necessary traffic" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ No restrictive network policies found for Qdrant" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check collections
  if grep -q "collections" "$OUTPUT_FILE" && grep -q "name" "$OUTPUT_FILE"; then
    COLLECTION_COUNT=$(grep -o "name" "$OUTPUT_FILE" | wc -l)
    echo "✅ Qdrant has $COLLECTION_COUNT collections" | tee -a "$OUTPUT_FILE"
  else
    echo "⚠️ Unable to verify collections - may need to check collection status" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Final summary
  echo "" | tee -a "$OUTPUT_FILE"
  echo "Overall Qdrant Status: $OVERALL_STATUS" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Found $ISSUES_FOUND potential issues that may need attention." | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Unhealthy" ]; then
      echo "Critical issues detected - Qdrant may not be functioning correctly!" | tee -a "$OUTPUT_FILE"
    else
      echo "Non-critical issues detected - Qdrant is operational but may benefit from optimizations." | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No issues detected - Qdrant appears to be functioning correctly!" | tee -a "$OUTPUT_FILE"
  fi
  
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Only show relevant troubleshooting recommendations if issues found
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    print_section "Troubleshooting Recommendations"
    
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
    
    if grep -q "network policies that may affect Qdrant" "$OUTPUT_FILE"; then
      echo "• Review network policies: kubectl describe networkpolicy -n $NAMESPACE" | tee -a "$OUTPUT_FILE"
    fi
  fi

  print_section "Debug Summary"
  echo "Qdrant debug information collected and saved to $OUTPUT_FILE"
  echo "Completed $((STEP-1)) diagnostic checks on your Qdrant installation"
  echo ""
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Overall status: $OVERALL_STATUS"
    echo "Found $ISSUES_FOUND potential issues that may need attention"
    echo "See the Qdrant Health Analysis section for details and specific troubleshooting steps"
  else
    echo "Overall status: Healthy"
    echo "All diagnostics passed - your Qdrant installation appears to be functioning correctly"
  fi
  echo ""
  echo "For more information, refer to the Qdrant documentation at https://qdrant.tech/documentation/"
}