#!/bin/bash
# debug-ai-ollama-cluster.sh - Script to collect debugging information for Ollama deployment
# This script focuses on debugging Ollama-specific components in the AI namespace

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ai-ollama-cluster-${TIMESTAMP}.txt"
NAMESPACE="ai"  # Fixed to 'ai' namespace where Ollama runs

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ai-ollama-cluster-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    ls -t "$OUTPUT_DIR"/debug-ai-ollama-cluster-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

echo "Collecting Ollama deployment debugging information..."
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
  
  local output
  output=$(eval "$cmd" 2>&1)
  local status=$?
  
  echo "$output" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
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

# Function to run Ollama-specific commands inside the pod
run_ollama_cmd() {
  local cmd=$1
  local description=$2
  local pod_name
  
  pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=ollama -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  if [ -z "$pod_name" ]; then
    echo "Error: No Ollama pod found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    return 1
  fi
  
  echo "Step: $description..." | tee -a "$OUTPUT_FILE"
  echo "$ kubectl exec -n $NAMESPACE $pod_name -- $cmd" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  local output
  output=$(kubectl exec -n "$NAMESPACE" "$pod_name" -- $cmd 2>&1)
  local status=$?
  
  echo "$output" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  if [ $status -eq 0 ]; then
    echo "  Result: Success" | tee -a "$OUTPUT_FILE"
  else
    echo "  Result: Command failed with status $status" | tee -a "$OUTPUT_FILE"
  fi
  echo "" | tee -a "$OUTPUT_FILE"
}

# Function to test model inference using a temporary test pod
run_model_test() {
  local model=$1
  local prompt=$2
  local test_pod_name="ollama-test-$(date +%s)"
  local service_name="ollama"
  
  echo "Step: Testing model inference with prompt: '$prompt'..." | tee -a "$OUTPUT_FILE"
  echo "Creating temporary test pod to simulate client access..." | tee -a "$OUTPUT_FILE"
  
  # Create a temporary pod yaml
  cat <<EOF | kubectl apply -f - 2>&1 | tee -a "$OUTPUT_FILE"
apiVersion: v1
kind: Pod
metadata:
  name: $test_pod_name
  namespace: $NAMESPACE
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: 
      - sleep
      - "300"
EOF
  
  # Wait for pod to be ready
  echo "Waiting for test pod to be ready..." | tee -a "$OUTPUT_FILE"
  kubectl wait --for=condition=ready pod/$test_pod_name -n $NAMESPACE --timeout=30s 2>&1 | tee -a "$OUTPUT_FILE"
  
  if [ $? -ne 0 ]; then
    echo "Error: Test pod failed to start" | tee -a "$OUTPUT_FILE"
    kubectl delete pod $test_pod_name -n $NAMESPACE 2>/dev/null
    return 1
  fi
  
  echo "" | tee -a "$OUTPUT_FILE"
  echo "Testing Ollama API through service endpoint..." | tee -a "$OUTPUT_FILE"
  echo "$ kubectl exec -n $NAMESPACE $test_pod_name -- curl -s -X POST http://$service_name:11434/api/generate -d '{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}'" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Record start time
  local start_time=$(date +%s.%N)
  
  # Use a subshell with timeout
  output=$( (kubectl exec -n "$NAMESPACE" "$test_pod_name" -- \
    curl -s -X POST "http://$service_name:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}" 2>&1 & 
    pid=$!
    (sleep 30; kill $pid 2>/dev/null) & 
    wait $pid
  ) )
  local status=$?
  
  # Record end time and calculate duration
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)
  
  # Format the JSON output and extract metrics
  if [ $status -eq 0 ] && [ -n "$output" ]; then
    echo "Response from model:" | tee -a "$OUTPUT_FILE"
    echo "$output" | grep -o '"response":"[^"]*"' | cut -d'"' -f4 | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
    # Extract total_duration and eval_count from response
    local eval_count=$(echo "$output" | grep -o '"eval_count":[0-9]*' | cut -d':' -f2)
    local total_duration=$(echo "$output" | grep -o '"total_duration":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$eval_count" ] && [ -n "$total_duration" ]; then
      local tokens_per_second=$(echo "scale=2; $eval_count / ($total_duration / 1000000000)" | bc)
      echo "Performance Metrics:" | tee -a "$OUTPUT_FILE"
      echo "- Total tokens generated: $eval_count" | tee -a "$OUTPUT_FILE"
      echo "- Generation time: $(printf "%.2f" $duration) seconds" | tee -a "$OUTPUT_FILE"
      echo "- Tokens per second: $tokens_per_second" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "$output" | tee -a "$OUTPUT_FILE"
  fi
  echo "" | tee -a "$OUTPUT_FILE"
  
  if [ $status -eq 0 ]; then
    echo "  Result: Model responded successfully" | tee -a "$OUTPUT_FILE"
  elif [ $status -eq 143 ] || [ $status -eq 137 ]; then
    echo "  Result: Command timed out after 30 seconds" | tee -a "$OUTPUT_FILE"
  else
    echo "  Result: Command failed with status $status" | tee -a "$OUTPUT_FILE"
  fi
  
  # Clean up the test pod
  echo "Cleaning up test pod..." | tee -a "$OUTPUT_FILE"
  kubectl delete pod $test_pod_name -n $NAMESPACE --wait=false 2>&1 | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
}

# Main output collection
{
  print_section "Ollama Deployment Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Helm release information
  print_section "Helm Release Information"
  run_kubectl "helm list -n $NAMESPACE" "Helm Releases in AI Namespace"
  run_kubectl "helm status ollama -n $NAMESPACE" "Ollama Helm Release Status"
  
  # Ollama Pod Status
  print_section "Ollama Pod Status"
  run_kubectl "kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama -o wide" "Ollama Pod Details"
  run_kubectl "kubectl describe pods -n $NAMESPACE -l app.kubernetes.io/name=ollama" "Ollama Pod Description"
  
  # Ollama Service Status
  print_section "Ollama Service Status"
  run_kubectl "kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=ollama" "Ollama Service"
  run_kubectl "kubectl describe svc -n $NAMESPACE -l app.kubernetes.io/name=ollama" "Ollama Service Details"
  
  # Ollama ConfigMap and Secrets
  print_section "Ollama Configuration"
  run_kubectl "kubectl get configmaps -n $NAMESPACE -l app.kubernetes.io/name=ollama" "Ollama ConfigMaps"
  run_kubectl "kubectl get secrets -n $NAMESPACE -l app.kubernetes.io/name=ollama" "Ollama Secrets"
  
  # PVC Status
  print_section "Persistent Volume Status"
  run_kubectl "kubectl get pvc ollama-models -n $NAMESPACE" "Ollama PVC Status"
  run_kubectl "kubectl describe pvc ollama-models -n $NAMESPACE" "Ollama PVC Details"
  
  # Resource Usage
  print_section "Resource Usage"
  run_kubectl "kubectl top pods -n $NAMESPACE -l app.kubernetes.io/name=ollama 2>/dev/null || echo 'Metrics server not available'" "Ollama Resource Usage"
  
  # Ollama-specific Information
  print_section "Ollama Model Information"
  run_ollama_cmd "ollama list" "Available Models"
  run_ollama_cmd "ollama show qwen2:0.5b" "Qwen2 Model Details"
  
  # Add Model Inference Test
  print_section "Model Inference Test"
  run_model_test "qwen2:0.5b" "Hi, please respond with a short greeting to test if you're working properly."
  
  # Recent Events
  print_section "Recent Events"
  run_kubectl "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i ollama" "Recent Ollama-related Events"
  
  # Logs
  print_section "Ollama Logs"
  run_kubectl "kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=ollama --tail=200 | grep -v 'GET      \"/\"'" "Recent Ollama Logs (excluding health checks)"
  
  # Network Policy
  print_section "Network Policies"
  run_kubectl "kubectl get networkpolicies -n $NAMESPACE" "Network Policies in AI Namespace"
  
  # Add summary section
  print_section "Summary and Recommendations"
  echo "1. Check if Ollama pod is in 'Running' state" | tee -a "$OUTPUT_FILE"
  echo "2. Verify model 'qwen2:0.5b' is properly loaded" | tee -a "$OUTPUT_FILE"
  echo "3. Check resource usage against limits (CPU: 1000m, Memory: 3Gi)" | tee -a "$OUTPUT_FILE"
  echo "4. Verify persistent volume 'ollama-models' is properly mounted" | tee -a "$OUTPUT_FILE"
  echo "5. Check for any recent error events" | tee -a "$OUTPUT_FILE"
  echo "6. Verify service is accessible within the cluster on port 11434" | tee -a "$OUTPUT_FILE"
  echo "7. Check logs for any model loading or API errors" | tee -a "$OUTPUT_FILE"
  echo "8. Verify model inference is working properly" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot Ollama deployment issues."

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES"

# Make the script executable
chmod +x "$0" 