#!/bin/bash
# debug-ai-litellm.sh - Script to collect debugging information for LiteLLM in a Kubernetes cluster
# This script runs commands to gather information about LiteLLM and its components

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ai-litellm-${TIMESTAMP}.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}
HIDE_PASSWORD_FROM_PRINT=true

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ai-litellm-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    # Get list of files sorted by time (newest first), skip the first $files_to_keep files, and remove the rest
    ls -t "$OUTPUT_DIR"/debug-ai-litellm-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

echo "Collecting LiteLLM debugging information..."
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

# Function to find LiteLLM resources
find_litellm_resources() {
  print_section "Finding LiteLLM Resources"
  
  # Find LiteLLM pod
  LITELLM_POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$LITELLM_POD_NAME" ]; then
    LITELLM_POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  if [ -z "$LITELLM_POD_NAME" ]; then
    LITELLM_POD_NAME=$(kubectl get pods -n "$NAMESPACE" | grep "^litellm" | grep -v "migrations" | head -1 | awk '{print $1}')
  fi
  
  # Find LiteLLM service
  LITELLM_SVC_NAME=$(kubectl get svc -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$LITELLM_SVC_NAME" ]; then
    LITELLM_SVC_NAME=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  if [ -z "$LITELLM_SVC_NAME" ]; then
    LITELLM_SVC_NAME=$(kubectl get svc -n "$NAMESPACE" | grep "^litellm" | head -1 | awk '{print $1}')
  fi
  
  # Find LiteLLM configmap
  LITELLM_CONFIG_NAME=$(kubectl get configmap -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ -z "$LITELLM_CONFIG_NAME" ]; then
    LITELLM_CONFIG_NAME=$(kubectl get configmap -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  if [ -z "$LITELLM_CONFIG_NAME" ]; then
    LITELLM_CONFIG_NAME=$(kubectl get configmap -n "$NAMESPACE" | grep litellm | head -1 | awk '{print $1}')
  fi
  
  # Output found resources
  echo "Found LiteLLM resources:" | tee -a "$OUTPUT_FILE"
  echo "- Pod: $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE"
  echo "- Service: $LITELLM_SVC_NAME" | tee -a "$OUTPUT_FILE"
  echo "- ConfigMap: $LITELLM_CONFIG_NAME" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
}

# Function to check pod status
check_pod_status() {
  print_section "LiteLLM Pod Status"
  
  if [ -n "$LITELLM_POD_NAME" ]; then
    run_kubectl "kubectl get pods -n $NAMESPACE $LITELLM_POD_NAME" "LiteLLM Pod Status"
    run_kubectl "kubectl describe pods -n $NAMESPACE $LITELLM_POD_NAME" "LiteLLM Pod Details"
    run_kubectl "kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}'" "Pod Restart Count"
  else
    echo "No LiteLLM pod found to check status" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to check service status
check_service_status() {
  print_section "LiteLLM Service Status"
  
  if [ -n "$LITELLM_SVC_NAME" ]; then
    run_kubectl "kubectl get svc -n $NAMESPACE $LITELLM_SVC_NAME" "LiteLLM Service Status"
    run_kubectl "kubectl describe svc -n $NAMESPACE $LITELLM_SVC_NAME" "LiteLLM Service Details"
  else
    echo "No LiteLLM service found to check status" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to check configmap
check_configmap() {
  print_section "LiteLLM Configuration"
  
  if [ -n "$LITELLM_CONFIG_NAME" ]; then
    run_kubectl "kubectl get configmap -n $NAMESPACE $LITELLM_CONFIG_NAME" "LiteLLM ConfigMap Status"
    
    if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
      run_kubectl "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data}' | sed -E 's/(master_key|api_key|password|secret)[[:space:]]*:[[:space:]]*\"?[^\"[:space:]]*\"?/\\1: \"***REDACTED**\"/g'" "LiteLLM Config Content (redacted)"
    else
      run_kubectl "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data}'" "LiteLLM Config Content"
    fi
    
    run_kubectl "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml | grep -A 50 'model_list:' | grep -v '^ *#'" "LiteLLM Model Configuration"
  else
    echo "No LiteLLM configmap found to check" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to check secrets
check_secrets() {
  print_section "LiteLLM Secrets"
  
  run_kubectl "kubectl get secret -n $NAMESPACE | grep -i litellm" "LiteLLM Secrets"
  
  # Check for unified secrets
  run_kubectl "kubectl get secret urbalurba-secrets -n $NAMESPACE 2>/dev/null" "Unified Secrets"
  
  if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
    echo "Checking for necessary API keys in secrets (values hidden):" | tee -a "$OUTPUT_FILE"
    run_kubectl "kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys | sort'" "Available Secret Keys"
  fi
}

# Function to check API connectivity
check_api_connectivity() {
  print_section "LiteLLM API Connectivity"
  
  if [ -n "$LITELLM_SVC_NAME" ]; then
    LITELLM_PORT=$(kubectl get svc -n $NAMESPACE $LITELLM_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -n "$LITELLM_PORT" ]; then
      run_kubectl "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/health/liveliness" "LiteLLM Liveliness Check"
      run_kubectl "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/health/readiness" "LiteLLM Readiness Check"
      run_kubectl "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/v1/models" "LiteLLM Available Models"
    fi
  else
    echo "No LiteLLM service found to test API" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to check logs
check_logs() {
  print_section "LiteLLM Logs"
  
  if [ -n "$LITELLM_POD_NAME" ]; then
    run_kubectl "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'error\\|warn\\|exception\\|fail'" "Recent Errors and Warnings"
    run_kubectl "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'starting\\|initialized\\|proxy\\|config\\|router'" "Startup Information"
    run_kubectl "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'model\\|router\\|proxy initialized'" "Model Initialization Logs"
  else
    echo "No LiteLLM pod found to retrieve logs" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to check events
check_events() {
  print_section "LiteLLM Events"
  
  run_kubectl "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'litellm\\|proxy' | tail -15" "Recent LiteLLM Events"
}

# Main output collection
{
  print_section "LiteLLM Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Find LiteLLM resources
  find_litellm_resources
  
  # Check pod status
  check_pod_status
  
  # Check service status
  check_service_status
  
  # Check configmap
  check_configmap
  
  # Check secrets
  check_secrets
  
  # Check API connectivity
  check_api_connectivity
  
  # Check logs
  check_logs
  
  # Check events
  check_events
  
  # Add summary section
  print_section "Summary and Recommendations"
  echo "1. Check pod status and restart count" | tee -a "$OUTPUT_FILE"
  echo "2. Verify service endpoints and connectivity" | tee -a "$OUTPUT_FILE"
  echo "3. Review configuration and secrets" | tee -a "$OUTPUT_FILE"
  echo "4. Check logs for errors and warnings" | tee -a "$OUTPUT_FILE"
  echo "5. Verify API connectivity and model availability" | tee -a "$OUTPUT_FILE"
  echo "6. Review recent events for any issues" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot LiteLLM issues."

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES"