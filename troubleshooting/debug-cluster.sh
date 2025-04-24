#!/bin/bash
# debug-cluster.sh - Script to collect debugging information for a Kubernetes cluster
# This script runs commands to gather information about the cluster and its components

# Set variables
OUTPUT_FILE="debug-cluster.txt"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
DEFAULT_NS="default"
NAMESPACE=${1:-$DEFAULT_NS}

echo "Collecting Kubernetes cluster debugging information..."
echo "This may take a few minutes, please be patient..."

# Function to print section headers
print_section() {
  echo "=== $1 ===" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

# Function to run kubectl commands and append output to the debug file
run_kubectl() {
  local cmd=$1
  local description=$2
  
  echo "Step: Collecting $description..." | tee -a "$OUTPUT_FILE"
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
  print_section "Kubernetes Cluster Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Cluster information
  print_section "Cluster Information"
  run_kubectl "kubectl cluster-info" "Cluster Info"
  
  # Nodes information
  print_section "Node Information"
  run_kubectl "kubectl get nodes -o wide" "Node List"
  run_kubectl "kubectl describe nodes" "Node Details"
  run_kubectl "kubectl top nodes 2>/dev/null || echo 'Metrics server not available'" "Node Resource Usage"

  # Namespaces
  print_section "Namespaces"
  run_kubectl "kubectl get namespaces" "Namespace List"
  
  # Pods across all namespaces or specified namespace
  print_section "Pods"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get pods --all-namespaces -o wide" "Pod List (All Namespaces)"
  else
    run_kubectl "kubectl get pods -n $NAMESPACE -o wide" "Pod List (Namespace: $NAMESPACE)"
  fi
  
  # Check for unhealthy pods
  print_section "Unhealthy Pods"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get pods --all-namespaces -o wide | grep -v 'Running\|Completed' || echo 'No unhealthy pods found'" "Unhealthy Pods (All Namespaces)"
  else
    run_kubectl "kubectl get pods -n $NAMESPACE -o wide | grep -v 'Running\|Completed' || echo 'No unhealthy pods found'" "Unhealthy Pods (Namespace: $NAMESPACE)"
  fi
  
  # Services
  print_section "Services"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get svc --all-namespaces -o wide" "Service List (All Namespaces)"
  else
    run_kubectl "kubectl get svc -n $NAMESPACE -o wide" "Service List (Namespace: $NAMESPACE)"
  fi
  
  # Deployments
  print_section "Deployments"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get deployments --all-namespaces" "Deployment List (All Namespaces)"
  else
    run_kubectl "kubectl get deployments -n $NAMESPACE" "Deployment List (Namespace: $NAMESPACE)"
  fi
  
  # StatefulSets
  print_section "StatefulSets"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get statefulsets --all-namespaces" "StatefulSet List (All Namespaces)"
  else
    run_kubectl "kubectl get statefulsets -n $NAMESPACE" "StatefulSet List (Namespace: $NAMESPACE)"
  fi
  
  # DaemonSets
  print_section "DaemonSets"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get daemonsets --all-namespaces" "DaemonSet List (All Namespaces)"
  else
    run_kubectl "kubectl get daemonsets -n $NAMESPACE" "DaemonSet List (Namespace: $NAMESPACE)"
  fi
  
  # ConfigMaps
  print_section "ConfigMaps"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get configmaps --all-namespaces" "ConfigMap List (All Namespaces)"
  else
    run_kubectl "kubectl get configmaps -n $NAMESPACE" "ConfigMap List (Namespace: $NAMESPACE)"
  fi
  
  # Secrets (only count, not content for security)
  print_section "Secrets"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get secrets --all-namespaces | wc -l | xargs -I{} echo 'Total secrets: {}'" "Secret Count (All Namespaces)"
  else
    run_kubectl "kubectl get secrets -n $NAMESPACE | wc -l | xargs -I{} echo 'Total secrets: {}'" "Secret Count (Namespace: $NAMESPACE)"
  fi
  
  # PersistentVolumes and PersistentVolumeClaims
  print_section "Storage"
  run_kubectl "kubectl get pv" "PersistentVolumes"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get pvc --all-namespaces" "PersistentVolumeClaims (All Namespaces)"
  else
    run_kubectl "kubectl get pvc -n $NAMESPACE" "PersistentVolumeClaims (Namespace: $NAMESPACE)"
  fi
  
  # StorageClasses
  run_kubectl "kubectl get sc" "StorageClasses"
  
  # Ingress resources
  print_section "Ingress Resources"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get ingress --all-namespaces 2>/dev/null || echo 'No ingress resources found'" "Ingress Resources (All Namespaces)"
  else
    run_kubectl "kubectl get ingress -n $NAMESPACE 2>/dev/null || echo 'No ingress resources found'" "Ingress Resources (Namespace: $NAMESPACE)"
  fi
  
  # IngressClasses
  run_kubectl "kubectl get ingressclass 2>/dev/null || echo 'No ingress classes found'" "Ingress Classes"
  
  # Custom Resources - just check existence
  print_section "Custom Resources"
  run_kubectl "kubectl api-resources --namespaced=true -o name | grep -v '^[^.]*$' | sort" "Available Custom Resource Definitions"
  
  # Recent events
  print_section "Recent Events"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get events --sort-by='.lastTimestamp' --all-namespaces | tail -50" "Recent Events (All Namespaces, Last 50)"
  else
    run_kubectl "kubectl get events --sort-by='.lastTimestamp' -n $NAMESPACE | tail -50" "Recent Events (Namespace: $NAMESPACE, Last 50)"
  fi

  # Collect resource usage
  print_section "Resource Usage"
  run_kubectl "kubectl top pods --all-namespaces 2>/dev/null || echo 'Metrics server not available'" "Pod Resource Usage"
  
  # Network policies
  print_section "Network Policies"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    run_kubectl "kubectl get networkpolicies --all-namespaces 2>/dev/null || echo 'No network policies found'" "Network Policies (All Namespaces)"
  else
    run_kubectl "kubectl get networkpolicies -n $NAMESPACE 2>/dev/null || echo 'No network policies found'" "Network Policies (Namespace: $NAMESPACE)"
  fi
  
  # Collect logs from problematic pods
  print_section "Logs from Unhealthy Pods"
  if [ "$NAMESPACE" = "$DEFAULT_NS" ]; then
    unhealthy_pods=$(kubectl get pods --all-namespaces -o wide | grep -v 'Running\|Completed' | grep -v "NAME" | awk '{print $1 " " $2}')
  else
    unhealthy_pods=$(kubectl get pods -n $NAMESPACE -o wide | grep -v 'Running\|Completed' | grep -v "NAME" | awk '{print $1 " " $2}')
  fi
  
  if [ -n "$unhealthy_pods" ]; then
    echo "Found unhealthy pods, collecting logs..." | tee -a "$OUTPUT_FILE"
    echo "Unhealthy pods:" | tee -a "$OUTPUT_FILE"
    echo "$unhealthy_pods" | tee -a "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "$unhealthy_pods" | while read -r ns pod; do
      if [ -n "$ns" ] && [ -n "$pod" ]; then
        echo "Collecting logs for pod: $pod in namespace: $ns..." | tee -a "$OUTPUT_FILE"
        echo "--- Logs for pod: $pod in namespace: $ns ---" >> "$OUTPUT_FILE"
        kubectl logs --tail=100 -n "$ns" "$pod" --all-containers=true >> "$OUTPUT_FILE" 2>&1 || 
          echo "Failed to get logs for $pod" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
      fi
    done
  else
    echo "No unhealthy pods found." | tee -a "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
  fi

  # Dynamically detect cluster components
  print_section "Detected Cluster Components"
  echo "Discovering components running in the cluster..." | tee -a "$OUTPUT_FILE"
  
  # Extract container images to identify components
  component_images=$(kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" 2>/dev/null)
  
  # Extract deployment/statefulset names for component identification
  component_resources=$(kubectl get deployments,statefulsets,daemonsets --all-namespaces -o name 2>/dev/null)
  
  # Combine and format the component information
  echo "Component images found in the cluster:" | tee -a "$OUTPUT_FILE"
  echo "$component_images" | tr ' ' '\n' | sort | uniq | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  echo "Component resources found in the cluster:" | tee -a "$OUTPUT_FILE"
  echo "$component_resources" | sort | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Pod distributions by namespace
  print_section "Pod Distribution by Namespace"
  run_kubectl "kubectl get pods --all-namespaces | awk '{print \$1}' | sort | uniq -c | sort -nr" "Pods per Namespace"

  # Check for cluster operators and controllers
  print_section "Cluster Operators and Controllers"
  run_kubectl "kubectl get pods -n kube-system" "Kube-System Pods"
  
  # Add summary section
  print_section "Summary and Recommendations"
  echo "1. Check for pods not in 'Running' or 'Completed' state" | tee -a "$OUTPUT_FILE"
  echo "2. Review recent events for warnings and errors" | tee -a "$OUTPUT_FILE"
  echo "3. Check resource usage for any pods nearing their limits" | tee -a "$OUTPUT_FILE"
  echo "4. Verify network connectivity between components" | tee -a "$OUTPUT_FILE"
  echo "5. Check logs of problematic pods for specific error messages" | tee -a "$OUTPUT_FILE"
  echo "6. Verify ingress configuration is correct" | tee -a "$OUTPUT_FILE"
  echo "7. For detailed component debugging, look for component-specific debug scripts" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

} 2>&1

print_section "Debug Complete"
echo "Debug information collected and saved to $OUTPUT_FILE"
echo "You can now examine this file to troubleshoot cluster issues."