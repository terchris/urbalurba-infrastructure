#!/bin/bash
# debug-ai-tika.sh - Script to collect debugging information for Apache Tika in a Kubernetes cluster
# This script gathers detailed information about Tika deployment, configuration, and performance
# Usage: ./debug-ai-tika.sh [namespace]
#   namespace: Optional Kubernetes namespace (defaults to 'default')

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ai-tika-${TIMESTAMP}.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ai-tika-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    # Get list of files sorted by time (newest first), skip the first $files_to_keep files, and remove the rest
    ls -t "$OUTPUT_DIR"/debug-ai-tika-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

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
  print_section "Apache Tika Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Check if Tika is found
  TIKA_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tika -o name 2>/dev/null | head -1)
  TIKA_SVC=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=tika -o name 2>/dev/null | head -1)
  
  if [ -z "$TIKA_POD" ]; then
    echo "No Apache Tika pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if Tika is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-ai-tika.sh <namespace>" | tee -a "$OUTPUT_FILE"
    exit 1
  fi
  
  # Basic Tika information
  print_section "Tika Basic Information"
  run_kubectl "kubectl get all -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika Resources"
  
  # Pod information
  print_section "Tika Pod Status"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o wide" "Tika Pod List"
  run_kubectl "kubectl describe pods -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika Pod Details"
  
  # Service information
  print_section "Tika Service Details"
  run_kubectl "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=tika -o wide" "Tika Service List"
  run_kubectl "kubectl describe svc -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika Service Details"
  
  # Configuration information
  print_section "Tika Configuration"
  run_kubectl "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=tika" "Tika ConfigMap List"
  run_kubectl "kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].data.tikaConfig}'" "Tika XML Configuration"
  
  # Resource usage
  print_section "Tika Resource Usage"
  TIKA_POD_NAME=$(echo "$TIKA_POD" | sed 's/^pod\///')
  if [ -n "$TIKA_POD_NAME" ]; then
    run_kubectl "kubectl top pod -n $NAMESPACE $TIKA_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "Tika Pod Resource Usage"
  fi
  
  # Environment variables
  print_section "Tika Environment Variables"
  if [ -n "$TIKA_POD_NAME" ]; then
    run_kubectl "kubectl exec -n $NAMESPACE $TIKA_POD_NAME -- env | grep -i 'java\\|tika'" "Tika Java Environment Variables"
  fi
  
  # API connectivity tests
  print_section "Tika API Connectivity Tests"
  if [ -n "$TIKA_SVC" ]; then
    TIKA_SVC_NAME=$(echo "$TIKA_SVC" | sed 's/^service\///')
    TIKA_PORT=$(kubectl get svc -n $NAMESPACE $TIKA_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -n "$TIKA_PORT" ]; then
      run_kubectl "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/tika" "Tika Server Status"
      run_kubectl "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/version" "Tika Version Info"
      run_kubectl "kubectl run curl-test-tika --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$TIKA_SVC_NAME:$TIKA_PORT/parsers" "Tika Available Parsers"
    fi
  fi
  
  # Logs analysis
  print_section "Tika Logs Analysis"
  if [ -n "$TIKA_POD_NAME" ]; then
    run_kubectl "kubectl logs -n $NAMESPACE $TIKA_POD_NAME --tail=100 | grep -i 'error\\|warn\\|exception\\|fail' | tail -20" "Recent Errors and Warnings"
  fi
  
  # Java memory usage
  print_section "Java Memory Usage"
  if [ -n "$TIKA_POD_NAME" ]; then
    run_kubectl "kubectl exec -n $NAMESPACE $TIKA_POD_NAME -- ps -o pid,rss,command | grep -i java || echo 'Unable to check memory usage'" "Java Process Memory Usage"
  fi
  
  # Events
  print_section "Tika-Related Events"
  run_kubectl "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'tika' | tail -15" "Recent Tika Events"
  
  # Network policies
  print_section "Network Policies"
  run_kubectl "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace"
  
  # Integration with other services
  print_section "Integration with Other Services"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=open-webui -o jsonpath='{.items[*].spec.containers[*].env[?(@.name==\"TIKA_SERVER_URL\")]}' 2>/dev/null || echo 'No Open WebUI pods found with Tika configuration'" "Integration with Open WebUI"
  
  # Health analysis
  print_section "Tika Health Analysis"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].status.phase}'" "Pod Status"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=tika -o jsonpath='{.items[0].status.containerStatuses[0].ready}'" "Pod Readiness"
  
  # Add summary section
  print_section "Summary and Recommendations"
  echo "1. Check Tika pod status and readiness" | tee -a "$OUTPUT_FILE"
  echo "2. Review Tika logs for errors and warnings" | tee -a "$OUTPUT_FILE"
  echo "3. Verify Tika API connectivity and responses" | tee -a "$OUTPUT_FILE"
  echo "4. Monitor resource usage (CPU and memory)" | tee -a "$OUTPUT_FILE"
  echo "5. Check integration with other services" | tee -a "$OUTPUT_FILE"
  echo "6. Review network policies and connectivity" | tee -a "$OUTPUT_FILE"
  echo "7. Verify configuration settings" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Tika issues."

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES" 