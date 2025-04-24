#!/bin/bash
# debug-tika.sh - Script to collect debugging information for Apache Tika in a Kubernetes cluster
# This script gathers detailed information about Tika deployment, configuration, and performance

# Set variables
OUTPUT_FILE="debug-tika.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}
TIKA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tika -o name 2>/dev/null | head -1)
TIKA_SVC=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=tika -o name 2>/dev/null | head -1)

# Remove previous debug file if it exists
if [ -f "$OUTPUT_FILE" ]; then
  rm "$OUTPUT_FILE"
fi

echo "Collecting Apache Tika debugging information in namespace $NAMESPACE..."
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
  print_section "Apache Tika Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Check if Tika is found
  if [ -z "$TIKA_POD" ]; then
    echo "Error: No Apache Tika pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if Tika is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-tika.sh <namespace>" | tee -a "$OUTPUT_FILE"
    exit 1
  fi
  
  # Step counter initialization
  STEP=1
  
  print_section "Tika Basic Information"
  
  # Find all resources related to Tika
  run_command "kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika Resources" $STEP
  STEP=$((STEP+1))
  
  # Get Tika pod information
  print_section "Tika Pod Status"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o wide" "Tika Pod List" $STEP
  STEP=$((STEP+1))
  
  # Check pod readiness details
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].status.containerStatuses[0].ready}'" "Tika Pod Readiness" $STEP
  STEP=$((STEP+1))
  
  # Get Tika service information
  print_section "Tika Service Details"
  run_command "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=tika -o wide" "Tika Service List" $STEP
  STEP=$((STEP+1))
  
  # Get Tika config maps and secrets (without exposing secret values)
  print_section "Tika Configuration"
  run_command "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika ConfigMap List" $STEP
  STEP=$((STEP+1))
  
  # Get pod resource usage
  print_section "Tika Resource Usage"
  TIKA_POD_NAME=$(echo "$TIKA_POD" | sed 's/^pod\///')
  if [ -n "$TIKA_POD_NAME" ]; then
    run_command "kubectl top pod -n $NAMESPACE $TIKA_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "Tika Pod Resource Usage" $STEP
    STEP=$((STEP+1))
  else
    echo "No Tika pod found to retrieve resource usage" | tee -a "$OUTPUT_FILE"
  fi
  
  # Get pod environment variables (especially Java opts)
  print_section "Tika Environment Variables"
  if [ -n "$TIKA_POD_NAME" ]; then
    run_command "kubectl exec -n $NAMESPACE $TIKA_POD_NAME -- env | grep -i 'java\\|tika'" "Tika Java Environment Variables" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check Tika API connectivity and endpoints
  print_section "Tika API Connectivity Tests"
  
  # Extract Tika service details
  if [ -n "$TIKA_SVC" ]; then
    TIKA_SVC_NAME=$(echo "$TIKA_SVC" | sed 's/^service\///')
    TIKA_PORT=$(kubectl get svc -n $NAMESPACE $TIKA_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -n "$TIKA_PORT" ]; then
      # Test connection with curl from a temporary pod
      echo "Testing Tika API connection..." | tee -a "$OUTPUT_FILE"
      
      # Check server status
      run_command "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/tika" "Tika Server Status" $STEP
      STEP=$((STEP+1))
      
      # Check version info
      run_command "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/version" "Tika Version Info" $STEP
      STEP=$((STEP+1))
      
      # Check available parsers
      run_command "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/parsers" "Tika Available Parsers" $STEP
      STEP=$((STEP+1))
    else
      echo "Could not determine Tika service port" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No Tika service found to test API" | tee -a "$OUTPUT_FILE"
  fi
  
  # Get pod logs
  print_section "Tika Logs Analysis"
  if [ -n "$TIKA_POD_NAME" ]; then
    # Check for error patterns in logs
    run_command "kubectl logs -n $NAMESPACE $TIKA_POD_NAME --tail=100 | grep -i 'error\\|warn\\|exception\\|fail' | tail -20" "Recent Errors and Warnings" $STEP
    STEP=$((STEP+1))
  else
    echo "No Tika pod found to retrieve logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check Java memory usage
  print_section "Java Memory Usage"
  if [ -n "$TIKA_POD_NAME" ]; then
    run_command "kubectl exec -n $NAMESPACE $TIKA_POD_NAME -- ps -o pid,rss,command | grep -i java || echo 'Unable to check memory usage'" "Java Process Memory Usage" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check events related to Tika
  print_section "Tika-Related Events"
  run_command "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'tika' | tail -15" "Recent Tika Events" $STEP
  STEP=$((STEP+1))
  
  # Check for network policies affecting Tika
  print_section "Network Policies"
  run_command "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace" $STEP
  STEP=$((STEP+1))
  
  # Check Open WebUI integration (if present)
  print_section "Integration with Other Services"
  run_command "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[*].spec.containers[*].env[?(@.name==\"TIKA_SERVER_URL\")]}' 2>/dev/null || echo 'No Open WebUI pods found with Tika configuration'" "Integration with Open WebUI" $STEP
  STEP=$((STEP+1))
  
  # Analyze the results and provide a meaningful summary
  print_section "Tika Health Analysis"
  
  # Initialize status variables
  OVERALL_STATUS="Healthy"
  ISSUES_FOUND=0
  
  # Check pod status
  POD_STATUS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Issue: Tika pod is not in Running state (current state: $POD_STATUS)" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Tika pod is running correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check pod readiness
  POD_READY=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null)
  if [ "$POD_READY" != "true" ]; then
    echo "❌ Issue: Tika pod is not ready" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ Tika pod is ready and accepting connections" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check API connectivity using the API check results
  if grep -iq "apache tika server" "$OUTPUT_FILE" || grep -iq "tika version" "$OUTPUT_FILE"; then
    echo "✅ Tika API is responding correctly" | tee -a "$OUTPUT_FILE"
  else
    echo "❌ Issue: Tika API health check failed - service may be unreachable" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check for error logs
  ERROR_COUNT=$(grep -i -E "error|exception|failure" "$OUTPUT_FILE" | grep -v "No errors found" | grep -v "grep -i 'error\\|warn\\|exception\\|fail'" | wc -l)
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️ Found $ERROR_COUNT references to errors in the logs - review the log analysis section" | tee -a "$OUTPUT_FILE"
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
      echo "⚠️ CPU usage is high ($CPU_USAGE) - Tika may be under heavy load" | tee -a "$OUTPUT_FILE"
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
      if (( $(echo "$MEMORY_VALUE > 0.85 * 1" | bc -l) )); then
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
  
  # Check Java options for memory settings
  JAVA_OPTS=$(grep -i "JAVA_OPTS" "$OUTPUT_FILE" || echo "")
  if [[ "$JAVA_OPTS" == *"OutOfMemoryError"* ]]; then
    echo "✅ Java memory error handling is configured" | tee -a "$OUTPUT_FILE"
  else
    echo "⚠️ No Java OutOfMemoryError handling detected in JAVA_OPTS" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check for Xmx (max heap) settings
  if [[ "$JAVA_OPTS" == *"Xmx"* ]]; then
    XMX_VALUE=$(echo $JAVA_OPTS | grep -o "Xmx[0-9]*[mMgG]" | head -1)
    echo "✅ Java max heap size is set to $XMX_VALUE" | tee -a "$OUTPUT_FILE"
  else
    echo "⚠️ No explicit Java max heap size (Xmx) setting found - using default" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check if Tika is integrated with Open WebUI
  if grep -q "TIKA_SERVER_URL" "$OUTPUT_FILE"; then
    echo "✅ Tika integration with Open WebUI detected" | tee -a "$OUTPUT_FILE"
  else
    echo "ℹ️ No Tika integration with Open WebUI detected" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check if forking is disabled (recommended for K8s deployments)
  if [[ "$JAVA_OPTS" == *"tika.server.forking=false"* ]]; then
    echo "✅ Tika server forking is properly disabled" | tee -a "$OUTPUT_FILE"
  else
    echo "⚠️ Tika server forking might be enabled - could cause issues in Kubernetes" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check for timeout settings
  if grep -q "timeout" "$OUTPUT_FILE"; then
    echo "✅ Timeout configuration detected" | tee -a "$OUTPUT_FILE"
  else
    echo "⚠️ No timeout configuration detected - could lead to stuck tasks" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  # Check for OCR-related configuration (if Tesseract is enabled)
  if [[ "$JAVA_OPTS" == *"tesseract"* || "$JAVA_OPTS" == *"OCR"* ]]; then
    echo "✅ OCR capability appears to be configured" | tee -a "$OUTPUT_FILE"
  else
    echo "ℹ️ No OCR configuration detected - text extraction from images may not be available" | tee -a "$OUTPUT_FILE"
  fi
  
  # Final summary
  echo "" | tee -a "$OUTPUT_FILE"
  echo "Overall Tika Status: $OVERALL_STATUS" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Found $ISSUES_FOUND potential issues that may need attention." | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Unhealthy" ]; then
      echo "Critical issues detected - Tika may not be functioning correctly!" | tee -a "$OUTPUT_FILE"
    else
      echo "Non-critical issues detected - Tika is operational but may benefit from optimizations." | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No issues detected - Tika appears to be functioning correctly!" | tee -a "$OUTPUT_FILE"
  fi
  
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Only show relevant troubleshooting recommendations if issues found
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    print_section "Troubleshooting Recommendations"
    
    if grep -q "pod is not in Running state\|pod is not ready" "$OUTPUT_FILE"; then
      echo "• Check pod events: kubectl describe pod -n $NAMESPACE $TIKA_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Review pod logs: kubectl logs -n $NAMESPACE $TIKA_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod's liveness/readiness probes in the deployment" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "API health check failed" "$OUTPUT_FILE"; then
      echo "• Verify service endpoints: kubectl get endpoints -n $NAMESPACE $TIKA_SVC_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod networking: kubectl exec -n $NAMESPACE $TIKA_POD_NAME -- curl localhost:$TIKA_PORT/tika" | tee -a "$OUTPUT_FILE"
      echo "• Restart the Tika pod: kubectl delete pod -n $NAMESPACE $TIKA_POD_NAME" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "references to errors in the logs" "$OUTPUT_FILE"; then
      echo "• Examine full logs: kubectl logs -n $NAMESPACE $TIKA_POD_NAME | grep -i 'error\\|exception'" | tee -a "$OUTPUT_FILE"
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
    
    if grep -q "No Java OutOfMemoryError handling" "$OUTPUT_FILE" || grep -q "No explicit Java max heap size" "$OUTPUT_FILE"; then
      echo "• Add or modify JAVA_OPTS in your deployment:" | tee -a "$OUTPUT_FILE"
      echo "  - name: JAVA_OPTS" | tee -a "$OUTPUT_FILE"
      echo "    value: \"-Xms512m -Xmx1g -XX:+HeapDumpOnOutOfMemoryError -Dtika.server.forking=false\"" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Tika server forking might be enabled" "$OUTPUT_FILE"; then
      echo "• Disable forking by adding this to JAVA_OPTS: -Dtika.server.forking=false" | tee -a "$OUTPUT_FILE"
      echo "• Forking can cause issues in containerized environments" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "No timeout configuration detected" "$OUTPUT_FILE"; then
      echo "• Configure timeouts by adding to JAVA_OPTS: -Dtika.server.timeout=300000" | tee -a "$OUTPUT_FILE"
      echo "• This sets a 5-minute timeout for document processing" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  print_section "Debug Summary"
  echo "Tika debug information collected and saved to $OUTPUT_FILE"
  echo "Completed $((STEP-1)) diagnostic checks on your Tika installation"
  echo ""
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    echo "Overall status: $OVERALL_STATUS"
    echo "Found $ISSUES_FOUND potential issues that may need attention"
    echo "See the Tika Health Analysis section for details and specific troubleshooting steps"
  else
    echo "Overall status: Healthy"
    echo "All diagnostics passed - your Tika installation appears to be functioning correctly"
  fi
  echo ""
  echo "For more information, refer to the Apache Tika documentation at https://tika.apache.org/2.8.0/index.html"

} 2>&1