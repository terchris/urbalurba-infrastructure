#!/bin/bash
# debug-nginx.sh - Script to collect debugging information for NGINX in Kubernetes
# This script runs commands to gather information about NGINX pods, configurations, and logs

# Set variables
MAX_DEBUG_FILES=3
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="$(dirname "$0")/output"
OUTPUT_FILE="${OUTPUT_DIR}/debug-nginx-${TIMESTAMP}.txt"
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Clean up old debug files, keeping only the MAX_DEBUG_FILES most recent ones
cleanup_old_files() {
  local files_to_keep=$1
  local files_count
  files_count=$(ls -1 "$OUTPUT_DIR"/debug-nginx-*.txt 2>/dev/null | wc -l)
  
  if [ "$files_count" -gt "$files_to_keep" ]; then
    echo "Cleaning up old debug files, keeping the $files_to_keep most recent ones..." | tee -a "$OUTPUT_FILE"
    ls -t "$OUTPUT_DIR"/debug-nginx-*.txt | tail -n +$((files_to_keep + 1)) | while read -r file; do
      echo "Removing old file: $file" | tee -a "$OUTPUT_FILE"
      rm -f "$file"
    done
  fi
}

echo "Collecting NGINX debugging information..."
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

# Main output collection
{
  print_section "NGINX Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # Find NGINX pods
  print_section "NGINX Pods"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get pods --all-namespaces -o wide | grep -i nginx" "NGINX Pods (All Namespaces)"
  else
    run_kubectl "kubectl get pods -n $NAMESPACE -o wide | grep -i nginx" "NGINX Pods (Namespace: $NAMESPACE)"
  fi
  
  # NGINX Configurations
  print_section "NGINX Configurations"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    nginx_pods=$(kubectl get pods --all-namespaces -o wide | grep -i nginx | awk '{print $1 " " $2}')
  else
    nginx_pods=$(kubectl get pods -n $NAMESPACE -o wide | grep -i nginx | awk '{print $1 " " $2}')
  fi
  
  if [ -n "$nginx_pods" ]; then
    echo "$nginx_pods" | while read -r ns pod; do
      if [ -n "$ns" ] && [ -n "$pod" ]; then
        echo "--- NGINX Configuration for pod: $pod in namespace: $ns ---" | tee -a "$OUTPUT_FILE"
        run_kubectl "kubectl exec -n $ns $pod -- nginx -T 2>/dev/null || echo 'Unable to get NGINX configuration'" "NGINX Configuration"
      fi
    done
  else
    echo "No NGINX pods found." | tee -a "$OUTPUT_FILE"
  fi
  
  # NGINX Logs
  print_section "NGINX Logs"
  if [ -n "$nginx_pods" ]; then
    echo "$nginx_pods" | while read -r ns pod; do
      if [ -n "$ns" ] && [ -n "$pod" ]; then
        echo "--- Logs for pod: $pod in namespace: $ns ---" | tee -a "$OUTPUT_FILE"
        run_kubectl "kubectl logs --tail=100 -n $ns $pod" "NGINX Logs"
        run_kubectl "kubectl logs --tail=100 -n $ns $pod --previous 2>/dev/null || echo 'No previous logs available'" "Previous NGINX Logs"
      fi
    done
  fi
  
  # NGINX Ingress Resources
  print_section "NGINX Ingress Resources"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get ingress --all-namespaces | grep -i nginx" "NGINX Ingress Resources (All Namespaces)"
  else
    run_kubectl "kubectl get ingress -n $NAMESPACE | grep -i nginx" "NGINX Ingress Resources (Namespace: $NAMESPACE)"
  fi
  
  # NGINX Ingress Controller
  print_section "NGINX Ingress Controller"
  run_kubectl "kubectl get pods -n ingress-nginx -o wide 2>/dev/null || echo 'No ingress-nginx namespace found'" "NGINX Ingress Controller Pods"
  run_kubectl "kubectl get svc -n ingress-nginx 2>/dev/null || echo 'No ingress-nginx services found'" "NGINX Ingress Controller Services"
  
  # NGINX ConfigMaps
  print_section "NGINX ConfigMaps"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get configmaps --all-namespaces | grep -i nginx" "NGINX ConfigMaps (All Namespaces)"
  else
    run_kubectl "kubectl get configmaps -n $NAMESPACE | grep -i nginx" "NGINX ConfigMaps (Namespace: $NAMESPACE)"
  fi
  
  # NGINX Network Policies
  print_section "NGINX Network Policies"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get networkpolicies --all-namespaces | grep -i nginx" "NGINX Network Policies (All Namespaces)"
  else
    run_kubectl "kubectl get networkpolicies -n $NAMESPACE | grep -i nginx" "NGINX Network Policies (Namespace: $NAMESPACE)"
  fi
  
  # NGINX Resource Usage
  print_section "NGINX Resource Usage"
  if [ -n "$nginx_pods" ]; then
    echo "$nginx_pods" | while read -r ns pod; do
      if [ -n "$ns" ] && [ -n "$pod" ]; then
        echo "--- Resource Usage for pod: $pod in namespace: $ns ---" | tee -a "$OUTPUT_FILE"
        run_kubectl "kubectl top pod -n $ns $pod 2>/dev/null || echo 'Metrics server not available'" "Pod Resource Usage"
      fi
    done
  fi
  
  # NGINX Events
  print_section "NGINX Events"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get events --sort-by='.lastTimestamp' --all-namespaces | grep -i nginx | tail -50" "Recent NGINX Events (All Namespaces)"
  else
    run_kubectl "kubectl get events --sort-by='.lastTimestamp' -n $NAMESPACE | grep -i nginx | tail -50" "Recent NGINX Events (Namespace: $NAMESPACE)"
  fi

  # Add summary section
  print_section "Summary and Recommendations"
  echo "1. Check NGINX configuration for any syntax errors or misconfigurations" | tee -a "$OUTPUT_FILE"
  echo "2. Review NGINX logs for error messages and warnings" | tee -a "$OUTPUT_FILE"
  echo "3. Verify NGINX ingress controller is running and properly configured" | tee -a "$OUTPUT_FILE"
  echo "4. Check network policies and connectivity for NGINX pods" | tee -a "$OUTPUT_FILE"
  echo "5. Monitor NGINX resource usage for potential bottlenecks" | tee -a "$OUTPUT_FILE"
  echo "6. Verify SSL/TLS configurations if HTTPS is being used" | tee -a "$OUTPUT_FILE"
  echo "7. Check for any recent events or errors related to NGINX" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"

} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot NGINX issues."

# Clean up old files after the new one is created
cleanup_old_files "$MAX_DEBUG_FILES"