#!/bin/bash
# debug-ai-ollama-host.sh - Script to test host Ollama instance from within Kubernetes
# This script tests Ollama connectivity both from the host and from within the cluster

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-ollama-host-${TIMESTAMP}.txt"
NAMESPACE="ai"
HOST_OLLAMA_URL="http://host.docker.internal:11434"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-ollama-host-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..."
    ls -1t "$OUTPUT_DIR"/debug-ollama-host-*.txt | tail -n +"$((files_to_keep + 1))" | xargs rm -f
  fi
}

# Function to write section headers
write_section() {
  local section=$1
  echo -e "\n=== $section ===\n" | tee -a "$OUTPUT_FILE"
}

# Function to write command output
write_command_output() {
  local cmd=$1
  local explanation=$2
  
  echo "Step: $explanation..." | tee -a "$OUTPUT_FILE"
  echo "\$ $cmd" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  eval "$cmd" 2>&1 | tee -a "$OUTPUT_FILE"
  
  local result=$?
  echo "" | tee -a "$OUTPUT_FILE"
  if [ $result -eq 0 ]; then
    echo "  Result: Success" | tee -a "$OUTPUT_FILE"
  else
    echo "  Result: Failed (Exit Code: $result)" | tee -a "$OUTPUT_FILE"
  fi
}

# Function to calculate tokens per second
calculate_tps() {
  local duration_ns=$1
  local tokens=$2
  # Convert duration from nanoseconds to seconds and calculate TPS
  duration_sec=$(echo "scale=6; $duration_ns / 1000000000" | bc)
  echo "scale=2; $tokens / $duration_sec" | bc
}

# Start debug information collection
{
  echo "Ollama Connectivity Debug Information"
  echo "==================================="
  echo ""
  echo "Date: $(date)"
  echo "Context: $(kubectl config current-context)"
  echo "Namespace: $NAMESPACE"
  echo "Host Ollama URL: $HOST_OLLAMA_URL"
  echo ""
  echo "This script performs two sets of tests:"
  echo "1. Host-side tests: Testing Ollama directly on the host machine"
  echo "2. Cluster-side tests: Testing Ollama from within the Kubernetes cluster"
  echo ""
} | tee "$OUTPUT_FILE"

# PART 1: Host-side Tests
write_section "PART 1: Host-side Tests (Testing Ollama on localhost)"

write_section "1.1 Host Ollama Models"
write_command_output "curl -s http://localhost:11434/api/tags | jq -r '\"Available Models on Host:\n\" + (.models[] | \"- \" + .name + \"\n  Size: \" + (.size|tostring|.[:-6]) + \"MB\n  Family: \" + .details.family + \"\n  Parameters: \" + .details.parameter_size + \"\n  Quantization: \" + .details.quantization_level)'" "Listing available models on host"

write_section "1.2 Host Model Inference"
write_command_output "curl -s -X POST http://localhost:11434/api/generate -d '{\"model\":\"deepseek-r1\",\"prompt\":\"Hi, please respond with a short greeting to test if you are working properly.\",\"stream\":false}' > /tmp/host_response.json && echo \"Response Analysis:\" && cat /tmp/host_response.json | jq -r '.response' && DURATION=\$(cat /tmp/host_response.json | jq -r '.total_duration') && TOKENS=\$(cat /tmp/host_response.json | jq -r '.eval_count') && echo \"Duration: \$DURATION ns (\$(echo \"scale=3; \$DURATION/1000000000\" | bc) seconds)\" && echo \"Tokens: \$TOKENS\" && echo \"Tokens per second: \$(calculate_tps \$DURATION \$TOKENS)\"" "Testing model inference on host"

# PART 2: Cluster-side Tests
write_section "PART 2: Cluster-side Tests (Testing Ollama from within Kubernetes)"

write_section "2.1 Creating Test Pod"
cat <<EOF | kubectl apply -f - | tee -a "$OUTPUT_FILE"
apiVersion: v1
kind: Pod
metadata:
  name: ollama-host-test
  namespace: $NAMESPACE
spec:
  containers:
  - name: debug
    image: nicolaka/netshoot:latest
    command:
      - sleep
      - "300"
    env:
      - name: HOST_OLLAMA_URL
        value: "$HOST_OLLAMA_URL"
EOF

echo "Waiting for test pod to be ready..." | tee -a "$OUTPUT_FILE"
kubectl wait --for=condition=ready pod/ollama-host-test -n "$NAMESPACE" --timeout=60s | tee -a "$OUTPUT_FILE"

write_section "2.2 Cluster Ollama Models"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- curl -s $HOST_OLLAMA_URL/api/tags | jq -r '\"Available Models from Cluster:\n\" + (.models[] | \"- \" + .name + \"\n  Size: \" + (.size|tostring|.[:-6]) + \"MB\n  Family: \" + .details.family + \"\n  Parameters: \" + .details.parameter_size + \"\n  Quantization: \" + .details.quantization_level)'" "Listing available models from cluster"

write_section "2.3 DNS Resolution"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- nslookup host.docker.internal" "Checking if pod can resolve host.docker.internal"

write_section "2.4 Network Connectivity"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- curl -v $HOST_OLLAMA_URL/api/tags" "Testing HTTP connectivity to host Ollama"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- nc -zv host.docker.internal 11434" "Testing TCP connectivity to Ollama port"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- ping -c 3 host.docker.internal" "Testing ICMP connectivity to host"

write_section "2.5 Model Inference from Cluster"
INFERENCE_CMD="curl -s -X POST \$HOST_OLLAMA_URL/api/generate -d '{\\\"model\\\":\\\"deepseek-r1\\\",\\\"prompt\\\":\\\"Hi, please respond with a short greeting to test if you are working properly.\\\",\\\"stream\\\":false}'"
write_command_output "kubectl exec -n $NAMESPACE ollama-host-test -- sh -c \"$INFERENCE_CMD > /tmp/response.json && echo \\\"\\nResponse Analysis:\\\" && cat /tmp/response.json | jq -r '.response' && DURATION=\\\$(cat /tmp/response.json | jq -r '.total_duration') && TOKENS=\\\$(cat /tmp/response.json | jq -r '.eval_count') && echo \\\"Duration: \\\$DURATION ns (\\\$(echo \\\"scale=3; \\\$DURATION/1000000000\\\" | bc) seconds)\\\" && echo \\\"Tokens: \\\$TOKENS\\\" && echo \\\"Tokens per second: \\\$(echo \\\"scale=2; \\\$TOKENS / (\\\$DURATION/1000000000)\\\" | bc)\\\"\"" "Testing model inference from cluster"

# Write completion message with performance comparison
{
  echo -e "\n=== Performance Summary ===\n"
  echo "Host Direct Test:"
  if [ -f /tmp/host_response.json ]; then
    DURATION=$(jq -r '.total_duration' /tmp/host_response.json)
    TOKENS=$(jq -r '.eval_count' /tmp/host_response.json)
    DURATION_SEC=$(echo "scale=3; $DURATION/1000000000" | bc)
    TPS=$(calculate_tps $DURATION $TOKENS)
    echo "- Duration: $DURATION ns ($DURATION_SEC seconds)"
    echo "- Tokens: $TOKENS"
    echo "- Tokens per second: $TPS"
  else
    echo "- No data available"
  fi
  
  echo -e "\nKubernetes Pod Test:"
  # Try to get the pod test results before pod deletion
  if kubectl exec -n $NAMESPACE ollama-host-test -- test -f /tmp/response.json 2>/dev/null; then
    POD_DURATION=$(kubectl exec -n $NAMESPACE ollama-host-test -- sh -c "cat /tmp/response.json | jq -r '.total_duration'" 2>/dev/null)
    POD_TOKENS=$(kubectl exec -n $NAMESPACE ollama-host-test -- sh -c "cat /tmp/response.json | jq -r '.eval_count'" 2>/dev/null)
    if [ ! -z "$POD_DURATION" ] && [ ! -z "$POD_TOKENS" ]; then
      POD_DURATION_SEC=$(echo "scale=3; $POD_DURATION/1000000000" | bc)
      POD_TPS=$(calculate_tps $POD_DURATION $POD_TOKENS)
      echo "- Duration: $POD_DURATION ns ($POD_DURATION_SEC seconds)"
      echo "- Tokens: $POD_TOKENS"
      echo "- Tokens per second: $POD_TPS"
    else
      echo "- Error retrieving pod test results"
    fi
  else
    echo "- No data available"
  fi
  
  echo ""
  echo "Debug information has been collected and saved to: $OUTPUT_FILE"
  echo "Review this file to understand the connectivity between:"
  echo "1. Host machine -> Local Ollama"
  echo "2. Kubernetes cluster -> Host Ollama"
  echo ""
} | tee -a "$OUTPUT_FILE"

# Clean up test pod
echo "Cleaning up test pod..." | tee -a "$OUTPUT_FILE"
kubectl delete pod ollama-host-test -n "$NAMESPACE" | tee -a "$OUTPUT_FILE"

# Clean up old files
cleanup_old_files "$MAX_DEBUG_FILES" 