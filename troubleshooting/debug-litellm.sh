#!/bin/bash
# debug-litellm.sh - Enhanced script to collect debugging information for LiteLLM in a Kubernetes cluster

# ------------------------------
# Constants and Global Variables
# ------------------------------
OUTPUT_FILE="debug-litellm.txt"
FIX_SCRIPT="debug-litellm-fix-issues.sh"
DEFAULT_NS="default"
HIDE_PASSWORD_FROM_PRINT=false
EXIT_CODE=0
OVERALL_STATUS="Healthy"
ISSUES_FOUND=0
STEP=1

# Arrays to store data
OLLAMA_ENDPOINTS=()
CLOUD_ENDPOINTS=()
ALL_ENDPOINTS=()
MODEL_NAMES=()
REQUIRED_ENV_VARS=()
MISSING_ENV_VARS=()

# -----------------
# Helper Functions
# -----------------
print_section() {
  echo "=== $1 ===" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
}

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
  
  return $status
}

redact_sensitive_info() {
  local input="$1"
  
  # Define patterns to redact (add more as needed)
  local patterns=("master_key:" "api_key:" "password:" "secret:" "_KEY=" "_PASSWORD=")
  
  # Apply redaction for each pattern
  for pattern in "${patterns[@]}"; do
    input=$(echo "$input" | sed -E "s/($pattern)[[:space:]]*[\"']*[^[:space:]\"']*[\"']*/\1 ***REDACTED***/g")
  done
  
  echo "$input"
}

# -------------------------
# Resource Detection Functions
# -------------------------
find_litellm_pod_name() {
  # Try with label app=litellm
  local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  # If not found, try with app.kubernetes.io/name=litellm
  if [ -z "$pod_name" ]; then
    pod_name=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  
  # If still not found, try by looking for pod names starting with litellm and not being migration jobs
  if [ -z "$pod_name" ]; then
    pod_name=$(kubectl get pods -n "$NAMESPACE" | grep "^litellm" | grep -v "migrations" | head -1 | awk '{print $1}')
  fi
  
  echo "$pod_name"
}

find_litellm_svc_name() {
  # Try with label app=litellm
  local svc_name=$(kubectl get svc -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  # If not found, try with app.kubernetes.io/name=litellm
  if [ -z "$svc_name" ]; then
    svc_name=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  
  # If still not found, try by looking for service names starting with litellm
  if [ -z "$svc_name" ]; then
    svc_name=$(kubectl get svc -n "$NAMESPACE" | grep "^litellm" | head -1 | awk '{print $1}')
  fi
  
  echo "$svc_name"
}

find_litellm_configmap_name() {
  # Try with label app=litellm
  local cm_name=$(kubectl get configmap -n "$NAMESPACE" -l app=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  # If not found, try with app.kubernetes.io/name=litellm
  if [ -z "$cm_name" ]; then
    cm_name=$(kubectl get configmap -n "$NAMESPACE" -l app.kubernetes.io/name=litellm -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  
  # If still not found, try by looking for configmap names containing litellm
  if [ -z "$cm_name" ]; then
    cm_name=$(kubectl get configmap -n "$NAMESPACE" | grep litellm | head -1 | awk '{print $1}')
  fi
  
  echo "$cm_name"
}

check_kubectl_installed() {
  if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl command not found. Please install kubectl first." | tee -a "$OUTPUT_FILE"
    return 1
  fi
  return 0
}

check_jq_installed() {
  if ! command -v jq &> /dev/null; then
    echo "Warning: jq command not found. Some JSON parsing features may not work correctly." | tee -a "$OUTPUT_FILE"
    return 1
  fi
  return 0
}

collect_basic_information() {
  print_section "LiteLLM Basic Information"
  
  # Find all resources related to LiteLLM
  run_command "kubectl get all -n $NAMESPACE | grep -i litellm" "LiteLLM Resources" $STEP
  STEP=$((STEP+1))
  
  # Get version of LiteLLM
  run_command "kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.spec.containers[0].image}'" "LiteLLM Version" $STEP
  STEP=$((STEP+1))
  
  return 0
}

# -------------------------
# Status Checking Functions
# -------------------------
check_pod_status() {
  print_section "LiteLLM Pod Status"
  
  # Get LiteLLM pod list
  run_command "kubectl get pods -n $NAMESPACE | grep -i litellm | grep -v migrations" "LiteLLM Pod List" $STEP
  STEP=$((STEP+1))
  
  if [ -n "$LITELLM_POD_NAME" ]; then
    # Get detailed pod description
    run_command "kubectl describe pods -n $NAMESPACE $LITELLM_POD_NAME" "LiteLLM Pod Details" $STEP
    STEP=$((STEP+1))
    
    # Get restart count
    run_command "kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}'" "Pod Restart Count" $STEP
    STEP=$((STEP+1))
    
    # Check resource usage
    check_resource_usage
  else
    echo "No LiteLLM pod found to check status" | tee -a "$OUTPUT_FILE"
  fi
  
  return 0
}

check_service_status() {
  print_section "LiteLLM Service Details"
  run_command "kubectl get svc -n $NAMESPACE | grep -i litellm" "LiteLLM Service List" $STEP
  STEP=$((STEP+1))
  
  return 0
}

check_configmap() {
  print_section "LiteLLM Configuration"
  run_command "kubectl get configmap -n $NAMESPACE | grep -i litellm" "LiteLLM ConfigMaps" $STEP
  STEP=$((STEP+1))
  
  if [ -n "$LITELLM_CONFIG_NAME" ]; then
    if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
      # Get ConfigMap and redact sensitive values
      run_command "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data}' | sed -E 's/(master_key|api_key|password|secret)[[:space:]]*:[[:space:]]*\"?[^\"[:space:]]*\"?/\\1: \"***REDACTED**\"/g'" "LiteLLM Config Content (redacted)" $STEP
    else
      run_command "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data}'" "LiteLLM Config Content" $STEP
    fi
    STEP=$((STEP+1))
    
    # Check model list configuration
    run_command "kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml | grep -A 50 'model_list:' | grep -v '^ *#'" "LiteLLM Model Configuration" $STEP
    STEP=$((STEP+1))
  fi
  
  return 0
}

check_storage() {
  print_section "LiteLLM Database Storage"
  run_command "kubectl get pvc -n $NAMESPACE | grep -i litellm" "LiteLLM PVC List" $STEP
  STEP=$((STEP+1))
  
  # Check PVC details if they exist
  if kubectl get pvc -n $NAMESPACE | grep -q -i litellm; then
    PVC_NAME=$(kubectl get pvc -n $NAMESPACE | grep -i litellm | head -1 | awk '{print $1}')
    run_command "kubectl describe pvc -n $NAMESPACE $PVC_NAME" "LiteLLM PVC Details" $STEP
    STEP=$((STEP+1))
  fi
  
  return 0
}

check_ingress() {
  print_section "LiteLLM Ingress"
  run_command "kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/name=litellm 2>/dev/null || kubectl get ingress -n $NAMESPACE -l app=litellm 2>/dev/null || kubectl get ingress -n $NAMESPACE | grep -i litellm 2>/dev/null || echo 'No ingress resources found'" "LiteLLM Ingress Resources" $STEP
  STEP=$((STEP+1))
  
  # Check ingress details if they exist
  LITELLM_INGRESS=$(kubectl get ingress -n $NAMESPACE -l app.kubernetes.io/name=litellm 2>/dev/null || kubectl get ingress -n $NAMESPACE -l app=litellm 2>/dev/null || kubectl get ingress -n $NAMESPACE | grep -i litellm 2>/dev/null)
  if [ -n "$LITELLM_INGRESS" ]; then
    INGRESS_NAME=$(echo "$LITELLM_INGRESS" | head -1 | awk '{print $1}')
    run_command "kubectl describe ingress -n $NAMESPACE $INGRESS_NAME" "LiteLLM Ingress Details" $STEP
    STEP=$((STEP+1))
  else
    echo "No LiteLLM ingress found to describe" | tee -a "$OUTPUT_FILE"
  fi
  
  return 0
}

check_resource_usage() {
  print_section "LiteLLM Resource Usage"
  if [ -n "$LITELLM_POD_NAME" ]; then
    run_command "kubectl top pod -n $NAMESPACE $LITELLM_POD_NAME 2>/dev/null || echo 'Metrics server not available'" "LiteLLM Pod Resource Usage" $STEP
    STEP=$((STEP+1))
  
    # Check resource limits and requests
    run_command "kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.spec.containers[0].resources}'" "Resource Limits and Requests" $STEP
    STEP=$((STEP+1))
  else
    echo "No LiteLLM pod found to retrieve resource usage" | tee -a "$OUTPUT_FILE"
  fi
  
  return 0
}

# ---------------------------
# Configuration Analysis Functions
# ---------------------------
analyze_environment_variables() {
  print_section "LiteLLM Environment Variables"
  if [ -n "$LITELLM_POD_NAME" ]; then
    # Check for critical environment variables
    if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
      # Redact passwords from environment variables
      run_command "kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env | grep -E 'LITELLM|OPENAI|AZURE|ANTHROPIC|OLLAMA|AWS|DATABASE|PROXY|REDIS' | sed -E 's/(_KEY|PASSWORD|MASTER_KEY)=.*/\\1=***REDACTED***/g'" "Configuration Environment Variables (passwords redacted)" $STEP
    else
      run_command "kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env | grep -E 'LITELLM|OPENAI|AZURE|ANTHROPIC|OLLAMA|AWS|DATABASE|PROXY|REDIS'" "Configuration Environment Variables" $STEP
    fi
    STEP=$((STEP+1))
    
    # Analyze required environment variables
    if [ -n "$LITELLM_CONFIG_NAME" ]; then
      # Get all environment variables referenced in the config
      CONFIG_CONTENT=$(kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml)
      ENV_VARS_REFERENCED=$(echo "$CONFIG_CONTENT" | grep -o '\${[^}]*}' | sort | uniq | sed 's/\${//g' | sed 's/:.*/}/g' | sed 's/}//g')
      
      # Base required variables
      REQUIRED_ENV_VARS+=("LITELLM_PROXY_MASTER_KEY" "PROXY_MASTER_KEY")
      
      # Add variables based on config content
      if echo "$CONFIG_CONTENT" | grep -q "azure"; then
        REQUIRED_ENV_VARS+=("AZURE_API_KEY" "AZURE_API_BASE")
      fi
      
      if echo "$CONFIG_CONTENT" | grep -q "openai"; then
        REQUIRED_ENV_VARS+=("OPENAI_API_KEY")
      fi
      
      if echo "$CONFIG_CONTENT" | grep -q "anthropic"; then
        REQUIRED_ENV_VARS+=("ANTHROPIC_API_KEY")
      fi
      
      # Add any specifically referenced env vars from the config
      if [ -n "$ENV_VARS_REFERENCED" ]; then
        while read -r var; do
          # Skip variables with default values: ${VAR:-default}
          if [[ "$var" != *":-"* ]]; then
            REQUIRED_ENV_VARS+=("$var")
          fi
        done <<< "$ENV_VARS_REFERENCED"
      fi
      
      # Get unique list
      REQUIRED_ENV_VARS=($(echo "${REQUIRED_ENV_VARS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
      
      # Get current environment variables in the pod
      ENV_OUTPUT=$(kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env 2>/dev/null)
      
      # Check each required environment variable
      for var in "${REQUIRED_ENV_VARS[@]}"; do
        VAR_VALUE=$(echo "$ENV_OUTPUT" | grep -E "^$var=" | wc -l)
        if [ "$VAR_VALUE" -eq 0 ]; then
          # Special case: LITELLM_PROXY_MASTER_KEY can be PROXY_MASTER_KEY
          if [ "$var" == "LITELLM_PROXY_MASTER_KEY" ] && echo "$ENV_OUTPUT" | grep -q "PROXY_MASTER_KEY"; then
            echo "✅ Found PROXY_MASTER_KEY instead of LITELLM_PROXY_MASTER_KEY (this is fine)" | tee -a "$OUTPUT_FILE"
          elif [ "$var" == "PROXY_MASTER_KEY" ] && echo "$ENV_OUTPUT" | grep -q "LITELLM_PROXY_MASTER_KEY"; then
            echo "✅ Found LITELLM_PROXY_MASTER_KEY instead of PROXY_MASTER_KEY (this is fine)" | tee -a "$OUTPUT_FILE"
          else
            MISSING_ENV_VARS+=("$var")
          fi
        fi
      done
      
      if [ ${#MISSING_ENV_VARS[@]} -gt 0 ]; then
        # Check if these variables are actually used in the config
        REFERENCED_AND_MISSING=0
        for missing_var in "${MISSING_ENV_VARS[@]}"; do
          if echo "$ENV_VARS_REFERENCED" | grep -q "^$missing_var$"; then
            REFERENCED_AND_MISSING=$((REFERENCED_AND_MISSING+1))
          fi
        done
        
        if [ "$REFERENCED_AND_MISSING" -gt 0 ]; then
          echo "❌ CRITICAL ERROR: Missing environment variables that are referenced in config:" | tee -a "$OUTPUT_FILE"
          for missing_var in "${MISSING_ENV_VARS[@]}"; do
            if echo "$ENV_VARS_REFERENCED" | grep -q "^$missing_var$"; then
              echo "  - $missing_var (REFERENCED IN CONFIG)" | tee -a "$OUTPUT_FILE"
            else
              echo "  - $missing_var" | tee -a "$OUTPUT_FILE"
            fi
          done
          OVERALL_STATUS="Unhealthy"
          ISSUES_FOUND=$((ISSUES_FOUND+1))
        else
          echo "⚠️ Warning: Some environment variables are missing but may not be required:" | tee -a "$OUTPUT_FILE"
          for missing_var in "${MISSING_ENV_VARS[@]}"; do
            echo "  - $missing_var" | tee -a "$OUTPUT_FILE"
          done
        fi
      else
        echo "✅ All required environment variables are set" | tee -a "$OUTPUT_FILE"
      fi
    fi
  fi
  
  return 0
}

extract_model_configuration() {
  print_section "LiteLLM API Endpoints"
  
  if [ -n "$LITELLM_CONFIG_NAME" ]; then
    # Get the direct YAML content from the ConfigMap
    echo "Extracting model configuration from ConfigMap..." | tee -a "$OUTPUT_FILE"
    
    # Get the actual config.yaml content directly
    CONFIG_YAML=$(kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data.config\.yaml}' 2>/dev/null)
    
    if [ -z "$CONFIG_YAML" ]; then
      echo "❌ Error: Could not extract config.yaml content from ConfigMap" | tee -a "$OUTPUT_FILE"
      OVERALL_STATUS="Unhealthy"
      ISSUES_FOUND=$((ISSUES_FOUND+1))
      return 1
    fi
    
    # Output the raw model list section for debugging
    MODEL_LIST_SECTION=$(echo "$CONFIG_YAML" | sed -n '/model_list:/,/router_settings:/p' | grep -v "router_settings:")
    echo "Raw model list configuration:" >> "$OUTPUT_FILE"
    echo "$MODEL_LIST_SECTION" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Process model configurations
    echo "Configured Models:" | tee -a "$OUTPUT_FILE"
    
    # Initialize for model counting
    model_count=0
    MODEL_NAMES=()  # Clear the array
    
    # Use grep to extract model entries - one model at a time
    while read -r line; do
      # If we find a model_name line, it's the start of a new model definition
      if [[ "$line" =~ model_name:[[:space:]]*([-_a-zA-Z0-9]+) ]]; then
        model_name="${BASH_REMATCH[1]}"
        MODEL_NAMES+=("$model_name")
        model_count=$((model_count + 1))
        
        # Get model_params for this model (lines after model_name until next model_name or end)
        model_params=$(echo "$MODEL_LIST_SECTION" | grep -A 20 "model_name: $model_name" | sed -n "2,/model_name:/p" | grep -v "model_name:")
        
        # Extract model path, api_base and api_key
        model_path=$(echo "$model_params" | grep "model:" | head -1 | sed -E 's/[[:space:]]*model:[[:space:]]*([-_\/a-zA-Z0-9$.{}:]+).*/\1/')
        api_base=$(echo "$model_params" | grep "api_base:" | head -1 | sed -E 's/[[:space:]]*api_base:[[:space:]]*([-_\/a-zA-Z0-9$.{}:]+).*/\1/')
        api_key=$(echo "$model_params" | grep "api_key:" | head -1 | sed -E 's/[[:space:]]*api_key:[[:space:]]*([-_\/a-zA-Z0-9$.{}:]+).*/\1/')
        
        # Output model information
        echo "  - model_name: $model_name" | tee -a "$OUTPUT_FILE"
        echo "    model: $model_path" | tee -a "$OUTPUT_FILE"
        
        if [ -n "$api_base" ]; then
          echo "    api_base: $api_base" | tee -a "$OUTPUT_FILE"
          
          # Extract environment variable if present
          if [[ "$api_base" == *"\${"* ]]; then
            ENV_VAR=$(echo "$api_base" | sed -E 's/.*\$\{([^}:]*)[^}]*\}.*/\1/')
            echo "      (Uses environment variable: $ENV_VAR)" | tee -a "$OUTPUT_FILE"
          else
            # Add to appropriate endpoint arrays
            ALL_ENDPOINTS+=("$api_base")
            if [[ "$api_base" == *"ollama"* ]]; then
              OLLAMA_ENDPOINTS+=("$api_base")
            elif [[ "$api_base" == *"openai"* ]] || [[ "$api_base" == *"azure"* ]] || [[ "$api_base" == *"anthropic"* ]]; then
              CLOUD_ENDPOINTS+=("$api_base")
            fi
          fi
        fi
        
        if [ -n "$api_key" ]; then
          if [[ "$api_key" == *"\${"* ]]; then
            ENV_VAR=$(echo "$api_key" | sed -E 's/.*\$\{([^}:]*)[^}]*\}.*/\1/')
            echo "    api_key: Uses environment variable $ENV_VAR" | tee -a "$OUTPUT_FILE"
          else
            echo "    api_key: [Set directly in config]" | tee -a "$OUTPUT_FILE"
          fi
        fi
        
        echo "" | tee -a "$OUTPUT_FILE"
      fi
    done < <(echo "$MODEL_LIST_SECTION" | grep "model_name:")
    
    # Check if we found any models
    if [ "$model_count" -eq 0 ]; then
      echo "❌ Error: No models found in ConfigMap" | tee -a "$OUTPUT_FILE"
      OVERALL_STATUS="Unhealthy"
      ISSUES_FOUND=$((ISSUES_FOUND+1))
    else
      echo "Found $model_count models in ConfigMap" | tee -a "$OUTPUT_FILE"
    fi
    
    # Collect environment variables referenced in the configuration
    ENV_VARS_REFERENCED=$(echo "$CONFIG_YAML" | grep -o '\${[^}]*}' | sed 's/\${//g' | sed 's/:.*/}/g' | sed 's/}//g' | sort | uniq)
    if [ -n "$ENV_VARS_REFERENCED" ]; then
      echo "Environment variables referenced in configuration:" | tee -a "$OUTPUT_FILE"
      while read -r var; do
        echo "  - $var" | tee -a "$OUTPUT_FILE"
      done <<< "$ENV_VARS_REFERENCED"
      echo "" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  return 0
}

check_auth_keys() {
  print_section "LiteLLM Authentication"
  
  # Get the secrets first
  LITELLM_MASTER_SECRET=$(kubectl get secret -n $NAMESPACE | grep -i "masterkey\|master-key" | head -1 | awk '{print $1}')
  SECRETS_KEY=""
  if [ -n "$LITELLM_MASTER_SECRET" ]; then
    # Get the key from the masterkey secret
    run_command "kubectl get secret $LITELLM_MASTER_SECRET -n $NAMESPACE -o jsonpath='{.metadata}'" "LiteLLM Secret Metadata" $STEP
    STEP=$((STEP+1))
    
    # Find the key in the secret that might have the master key
    SECRET_KEYS=$(kubectl get secret $LITELLM_MASTER_SECRET -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys[]' 2>/dev/null)
    if [ -n "$SECRET_KEYS" ]; then
      for key in $SECRET_KEYS; do
        clean_key=$(echo $key | tr -d '"')
        if [[ "$clean_key" == *"master"* ]] || [[ "$clean_key" == *"key"* ]]; then
          # Found a likely key for master key
          if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
            echo "Found potential master key in secret at key: $clean_key (value hidden)" | tee -a "$OUTPUT_FILE"
          else
            value=$(kubectl get secret $LITELLM_MASTER_SECRET -n $NAMESPACE -o jsonpath="{.data.$clean_key}" | base64 --decode 2>/dev/null)
            echo "Found potential master key in secret at key: $clean_key = $value" | tee -a "$OUTPUT_FILE"
          fi
          SECRETS_KEY=$(kubectl get secret $LITELLM_MASTER_SECRET -n $NAMESPACE -o jsonpath="{.data.$clean_key}" | base64 --decode 2>/dev/null)
          break
        fi
      done
    fi
  else
    echo "No LiteLLM master key secret found" | tee -a "$OUTPUT_FILE"
  fi
  
  # Try additional approaches to find a key for testing
  
  # 1. Check for a central urbalurba-secrets with LITELLM_PROXY_MASTER_KEY
  if [ -z "$SECRETS_KEY" ]; then
    SECRETS_KEY=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.LITELLM_PROXY_MASTER_KEY}' 2>/dev/null | base64 --decode 2>/dev/null)
    if [ -n "$SECRETS_KEY" ]; then
      if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
        echo "Found LITELLM_PROXY_MASTER_KEY in urbalurba-secrets (value hidden)" | tee -a "$OUTPUT_FILE"
      else
        echo "Found LITELLM_PROXY_MASTER_KEY in urbalurba-secrets: $SECRETS_KEY" | tee -a "$OUTPUT_FILE"
      fi
    fi
  fi
  
  # 2. Check the environment variables in the pod
  LITELLM_ENV_KEY=""
  if [ -n "$LITELLM_POD_NAME" ]; then
    ENV_CMD_OUTPUT=$(kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env 2>/dev/null | grep -E 'PROXY_MASTER_KEY|LITELLM_PROXY_MASTER_KEY')
    if [ -n "$ENV_CMD_OUTPUT" ]; then
      LITELLM_ENV_KEY=$(echo "$ENV_CMD_OUTPUT" | grep -E 'PROXY_MASTER_KEY|LITELLM_PROXY_MASTER_KEY' | head -1 | cut -d= -f2)
      ENV_VAR_NAME=$(echo "$ENV_CMD_OUTPUT" | grep -E 'PROXY_MASTER_KEY|LITELLM_PROXY_MASTER_KEY' | head -1 | cut -d= -f1)
      if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
        echo "Found $ENV_VAR_NAME in pod environment (value hidden)" | tee -a "$OUTPUT_FILE"
      else
        echo "Found $ENV_VAR_NAME in pod environment: $LITELLM_ENV_KEY" | tee -a "$OUTPUT_FILE"
      fi
    else
      echo "No master key environment variable found in pod" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  # 3. Look for master_key in ConfigMap
  CONFIG_MASTER_KEY=""
  if [ -n "$LITELLM_CONFIG_NAME" ]; then
    CONFIG_MASTER_KEY=$(kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml | grep "master_key:" | head -1 | sed -E 's/.*master_key:[[:space:]]*(.*)/\1/g' | tr -d ' "' 2>/dev/null)
    if [ -n "$CONFIG_MASTER_KEY" ]; then
      if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
        echo "Found master_key in config.yaml (value hidden)" | tee -a "$OUTPUT_FILE"
      else
        echo "Found master_key in config.yaml: $CONFIG_MASTER_KEY" | tee -a "$OUTPUT_FILE"
      fi
    else
      echo "No master_key found in config.yaml" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  # Choose the key to use for testing based on priority
  LITELLM_KEY=""
  KEY_SOURCE=""
  
  # First priority: environment variable (this is what's actually in use)
  if [ -n "$LITELLM_ENV_KEY" ]; then
    LITELLM_KEY="$LITELLM_ENV_KEY"
    KEY_SOURCE="environment variable"
  # Second priority: config.yaml master_key (this is the configuration source)
  elif [ -n "$CONFIG_MASTER_KEY" ]; then
    LITELLM_KEY="$CONFIG_MASTER_KEY"
    KEY_SOURCE="config.yaml master_key"
  # Third priority: secrets (this is what should be used)
  elif [ -n "$SECRETS_KEY" ]; then
    LITELLM_KEY="$SECRETS_KEY"
    KEY_SOURCE="secret"
  # Last resort: we couldn't find any key
  else
    echo "❌ ERROR: Could not find any authentication key in environment, config, or secrets" | tee -a "$OUTPUT_FILE"
    echo "Model testing will likely fail due to authentication issues" | tee -a "$OUTPUT_FILE"
    # Try without a key for testing, it might work if auth is disabled
    LITELLM_KEY=""
    EXIT_CODE=1
  fi
  
  # Show which key is being used
  if [ -n "$LITELLM_KEY" ]; then
    echo "Using authentication key from $KEY_SOURCE for testing" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check for key mismatches (which would indicate configuration issues)
  if [ -n "$LITELLM_ENV_KEY" ] && [ -n "$CONFIG_MASTER_KEY" ] && [ "$LITELLM_ENV_KEY" != "$CONFIG_MASTER_KEY" ]; then
    echo "❌ CRITICAL ERROR: Key mismatch between environment and config.yaml" | tee -a "$OUTPUT_FILE"
    echo "  Environment key: ${HIDE_PASSWORD_FROM_PRINT:-true} ? \"***REDACTED***\" : \"$LITELLM_ENV_KEY\"" | tee -a "$OUTPUT_FILE"
    echo "  Config.yaml key: ${HIDE_PASSWORD_FROM_PRINT:-true} ? \"***REDACTED***\" : \"$CONFIG_MASTER_KEY\"" | tee -a "$OUTPUT_FILE"
    echo "  This will cause authentication failures!" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  if [ -n "$LITELLM_ENV_KEY" ] && [ -n "$SECRETS_KEY" ] && [ "$LITELLM_ENV_KEY" != "$SECRETS_KEY" ]; then
    echo "❌ CRITICAL ERROR: Key mismatch between environment and secrets" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  if [ -n "$CONFIG_MASTER_KEY" ] && [ -n "$SECRETS_KEY" ] && [ "$CONFIG_MASTER_KEY" != "$SECRETS_KEY" ]; then
    echo "❌ CRITICAL ERROR: Key mismatch between config.yaml and secrets" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  fi
  
  return 0
}

test_api_connectivity() {
  print_section "LiteLLM API Connectivity Tests"
  if [ -n "$LITELLM_SVC_NAME" ]; then
    LITELLM_PORT=$(kubectl get svc -n $NAMESPACE $LITELLM_SVC_NAME -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -n "$LITELLM_PORT" ]; then
      # Health check
      run_command "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/health/liveliness" "LiteLLM Liveliness Check" $STEP
      STEP=$((STEP+1))
      
      # Readiness check
      run_command "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/health/readiness" "LiteLLM Readiness Check" $STEP
      STEP=$((STEP+1))
      
      # Check available models - important for LiteLLM functionality (with authentication)
      if [ -n "$LITELLM_KEY" ]; then
        AUTH_HEADER="Authorization: Bearer $LITELLM_KEY"
        run_command "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s -H \"$AUTH_HEADER\" http://$LITELLM_SVC_NAME:$LITELLM_PORT/v1/models" "LiteLLM Available Models" $STEP
      else
        # Try without authentication in case it's disabled
        run_command "kubectl run curl-test-litellm --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$LITELLM_SVC_NAME:$LITELLM_PORT/v1/models" "LiteLLM Available Models (no auth)" $STEP
      fi
      STEP=$((STEP+1))
      
      # Test individual models if configured
      test_individual_models "$LITELLM_SVC_NAME" "$LITELLM_PORT" "$LITELLM_KEY"
    else
      echo "Could not determine LiteLLM service port" | tee -a "$OUTPUT_FILE"
    fi
  else
    echo "No LiteLLM service found to test API" | tee -a "$OUTPUT_FILE"
  fi
  
  return 0
}

test_individual_models() {
  local svc_name=$1
  local port=$2
  local auth_key=$3
  
  print_section "Individual Model Tests"
  
  if [ ${#MODEL_NAMES[@]} -eq 0 ]; then
    echo "No models were found to test individually" | tee -a "$OUTPUT_FILE"
    return 0
  fi
  
  echo "Testing connectivity for individual models..." | tee -a "$OUTPUT_FILE"
  
  # Get the models from logs as a more reliable source if available
  LOG_MODELS=()
  LOG_OUTPUT=$(kubectl logs -n $NAMESPACE $LITELLM_POD_NAME | grep -A 10 "Proxy initialized with Config, Set models:" | sed 's/\x1b\[[0-9;]*m//g' | grep -v "^INFO" | grep -v "Proxy")
  if [ -n "$LOG_OUTPUT" ]; then
    while read -r line; do
      # Remove leading/trailing whitespace and check if not empty
      trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$trimmed_line" ] && [ "$trimmed_line" != "Set models:" ]; then
        LOG_MODELS+=("$trimmed_line")
      fi
    done < <(echo "$LOG_OUTPUT")
  fi
  
  # Use log models if available, otherwise use models from config
  TEST_MODELS=("${MODEL_NAMES[@]}")
  if [ ${#LOG_MODELS[@]} -gt 0 ]; then
    echo "Using models found in logs rather than config for testing..." | tee -a "$OUTPUT_FILE"
    TEST_MODELS=("${LOG_MODELS[@]}")
  fi
  
  for model_name in "${TEST_MODELS[@]}"; do
    echo "Testing model: $model_name" | tee -a "$OUTPUT_FILE"
    
    # Only proceed with testing if we have an authentication key
    if [ -n "$auth_key" ]; then
      # Test if the model is available
      run_command "kubectl run curl-test-model-$STEP --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s -X GET -H \"Authorization: Bearer $auth_key\" http://$svc_name:$port/v1/models | grep -q \"$model_name\" && echo \"✅ Model $model_name is available\" || echo \"❌ Model $model_name is not found\"" "Model Availability Test for $model_name" $STEP
      STEP=$((STEP+1))
    else
      echo "⚠️ Skipping model test for $model_name - no authentication key available" | tee -a "$OUTPUT_FILE"
    fi
    
    echo "" | tee -a "$OUTPUT_FILE"
  done
  
  return 0
}

# ---------------------------
# Integration Testing Functions
# ---------------------------
test_ollama_integration() {
  print_section "Ollama Integration"
  
  # Look for Ollama pods using multiple approaches
  run_command "kubectl get pods -n $NAMESPACE -l app=ollama 2>/dev/null || kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=ollama 2>/dev/null || kubectl get pods -n $NAMESPACE | grep -i ollama | grep -v Completed 2>/dev/null || echo 'No Ollama pods found'" "Ollama Pods" $STEP
  STEP=$((STEP+1))
  
  # Test Ollama connectivity from LiteLLM
  if [ ${#OLLAMA_ENDPOINTS[@]} -gt 0 ]; then
    echo "Testing Ollama connectivity for endpoints found in ConfigMap..." | tee -a "$OUTPUT_FILE"
    
    # Test each Ollama endpoint
    for endpoint in "${OLLAMA_ENDPOINTS[@]}"; do
      # Extract hostname and port from URL
      OLLAMA_HOST=$(echo "$endpoint" | sed -E 's|^http://([^:/]+)(:[0-9]+)?.*|\1|')
      OLLAMA_PORT=$(echo "$endpoint" | grep -o ':[0-9]\+' | tr -d ':')
      
      # If no port specified, use default
      if [ -z "$OLLAMA_PORT" ]; then
        OLLAMA_PORT="11434"
      fi
      
      echo "Testing Ollama endpoint: $endpoint (Host: $OLLAMA_HOST, Port: $OLLAMA_PORT)" | tee -a "$OUTPUT_FILE"
      
      if [ "$OLLAMA_HOST" = "host.docker.internal" ]; then
        # For host.docker.internal, test from inside the LiteLLM pod
        if [ -n "$LITELLM_POD_NAME" ]; then
          run_command "kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- sh -c 'wget -qO- http://$OLLAMA_HOST:$OLLAMA_PORT/api/version 2>/dev/null || echo Cannot connect to host Ollama'" "Host Ollama ($OLLAMA_HOST) Connection Test" $STEP
          STEP=$((STEP+1))
        fi
      else
        # For other endpoints, use a test pod
        run_command "kubectl run curl-test-ollama-$STEP --image=curlimages/curl --rm -it --restart=Never -n $NAMESPACE -- curl -s http://$OLLAMA_HOST:$OLLAMA_PORT/api/version" "Ollama API Test ($OLLAMA_HOST)" $STEP
        STEP=$((STEP+1))
      fi
    done
  else
    echo "No Ollama endpoints found in the ConfigMap" | tee -a "$OUTPUT_FILE"
  
    # Test connectivity to host machine Ollama if configured
    if kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml 2>/dev/null | grep -q "host.docker.internal"; then
      echo "Host machine Ollama configuration detected" | tee -a "$OUTPUT_FILE"
      
      if [ -n "$LITELLM_POD_NAME" ]; then
        # Test host Ollama connectivity with a better approach
        run_command "kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- sh -c 'wget -qO- http://host.docker.internal:11434/api/version 2>/dev/null || echo Cannot connect to host Ollama'" "Host Ollama Connection Test" $STEP
        STEP=$((STEP+1))
      fi
    fi
  fi
  
  return 0
}

test_cloud_provider_integration() {
  print_section "Cloud LLM Provider Integration"
  
  # Check if any cloud providers are configured from env vars
  CLOUD_PROVIDERS=("openai" "azure" "anthropic" "aws")
  for provider in "${CLOUD_PROVIDERS[@]}"; do
    # Check if provider is configured in environment or config
    PROVIDER_CONFIGURED=0
    
    # Check environment vars first
    if [ -n "$LITELLM_POD_NAME" ] && kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env 2>/dev/null | grep -q -i "$provider"; then
      PROVIDER_CONFIGURED=1
      echo "Found $provider configuration in environment variables" | tee -a "$OUTPUT_FILE"
    fi
    
    # Also check the ConfigMap for this provider
    if [ -n "$LITELLM_CONFIG_NAME" ] && kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml 2>/dev/null | grep -q -i "$provider"; then
      PROVIDER_CONFIGURED=1
      echo "Found $provider configuration in ConfigMap" | tee -a "$OUTPUT_FILE"
    fi
    
    # If provider is configured, check for endpoint and connectivity if possible
    if [ "$PROVIDER_CONFIGURED" -eq 1 ]; then
      # Special handling for Azure with testable endpoint
      if [ "$provider" == "azure" ]; then
        # Try to extract the Azure endpoint from config and environment
        AZURE_ENDPOINT=""
        
        # Check environment vars first
        if [ -n "$LITELLM_POD_NAME" ]; then
          AZURE_ENDPOINT=$(kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- env 2>/dev/null | grep -i "AZURE_API_BASE" | cut -d= -f2 2>/dev/null)
        fi
        
        # If not found, try to extract from ConfigMap
        if [ -z "$AZURE_ENDPOINT" ] && [ -n "$LITELLM_CONFIG_NAME" ]; then
          AZURE_ENDPOINT=$(kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml 2>/dev/null | grep -i "api_base.*azure" | sed -E 's/.*api_base:[[:space:]]*(http[^[:space:]]*).*/\1/g' | head -1)
        fi
        
        if [ -n "$AZURE_ENDPOINT" ]; then
          echo "Azure endpoint found: $AZURE_ENDPOINT" | tee -a "$OUTPUT_FILE"
          
          # We can't directly test Azure connection due to auth, but we can check if endpoint is reachable
          if [ -n "$LITELLM_POD_NAME" ]; then
            run_command "kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- sh -c 'curl -s -I $AZURE_ENDPOINT -o /dev/null -w %{http_code} 2>/dev/null || echo Connection failed'" "Azure Endpoint Connectivity" $STEP
            STEP=$((STEP+1))
          fi
        else
          echo "Azure is configured but no endpoint found" | tee -a "$OUTPUT_FILE"
        fi
      fi
    fi
  done
  
  return 0
}

check_database_integration() {
  print_section "LiteLLM Database Configuration"
  run_command "kubectl get statefulset,pods -n $NAMESPACE | grep -E 'postgres|postgresql|litellm.*sql'" "PostgreSQL Resources" $STEP
  STEP=$((STEP+1))
  
  if kubectl get pods -n $NAMESPACE | grep -E 'postgres|postgresql' &>/dev/null; then
    POSTGRES_POD=$(kubectl get pods -n $NAMESPACE | grep -E 'postgres|postgresql' | head -1 | awk '{print $1}')
    if [ -n "$POSTGRES_POD" ]; then
      run_command "kubectl describe pod -n $NAMESPACE $POSTGRES_POD" "PostgreSQL Pod Details" $STEP
      STEP=$((STEP+1))
    fi
  fi
  
  return 0
}

# ---------------------------
# Analysis Functions
# ---------------------------
analyze_logs() {
  print_section "LiteLLM Logs Analysis"
  if [ -n "$LITELLM_POD_NAME" ]; then
    # Get initialization messages and configured models
    run_command "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME | grep -A 10 'Proxy initialized with Config, Set models:'" "Model Initialization" $STEP
    STEP=$((STEP+1))
    
    # Check for error patterns in logs
    run_command "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'error\\|warn\\|exception\\|fail' | tail -20" "Recent Errors and Warnings" $STEP
    STEP=$((STEP+1))
    
    # Check startup logs for critical information
    run_command "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'starting\\|initialized\\|proxy\\|config\\|router'" "Startup Information" $STEP
    STEP=$((STEP+1))
    
    # Check logs for model loading patterns
    run_command "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --tail=100 | grep -i 'model\\|router\\|proxy initialized'" "Model Initialization Logs" $STEP
    STEP=$((STEP+1))
    
    # Check previous container logs if restarts detected
    RESTART_COUNT=$(kubectl get pods -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
    if [ "$RESTART_COUNT" -gt 0 ]; then
      run_command "kubectl logs -n $NAMESPACE $LITELLM_POD_NAME --previous --tail=50 | grep -i 'error\\|exception\\|fatal'" "Previous Container Crash Logs" $STEP
      STEP=$((STEP+1))
    fi
  else
    echo "No LiteLLM pod found to retrieve logs" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check events related to LiteLLM
  print_section "LiteLLM-Related Events"
  run_command "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | grep -i 'litellm\\|proxy' | tail -15" "Recent LiteLLM Events" $STEP
  STEP=$((STEP+1))
  
  return 0
}

check_migration_status() {
  print_section "Database Migration Status"
  run_command "kubectl get job -n $NAMESPACE -l 'app=litellm' 2>/dev/null || kubectl get job -n $NAMESPACE -l 'app.kubernetes.io/name=litellm' 2>/dev/null || kubectl get job -n $NAMESPACE | grep -i 'litellm.*migra' 2>/dev/null || echo 'No migration jobs found'" "Database Migration Jobs" $STEP 
  STEP=$((STEP+1))
  
  # Check if migrations were successful
  MIGRATION_JOBS=$(kubectl get job -n $NAMESPACE | grep -i 'litellm.*migra' 2>/dev/null)
  if [ -n "$MIGRATION_JOBS" ]; then
    COMPLETE_COUNT=$(echo "$MIGRATION_JOBS" | grep "1/1" | wc -l)
    TOTAL_COUNT=$(echo "$MIGRATION_JOBS" | wc -l)
    
    if [ "$COMPLETE_COUNT" -eq "$TOTAL_COUNT" ]; then
      echo "✅ All database migration jobs completed successfully" | tee -a "$OUTPUT_FILE"
    else
      echo "❌ Some database migration jobs failed to complete" | tee -a "$OUTPUT_FILE"
      echo "Completed: $COMPLETE_COUNT / $TOTAL_COUNT" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  return 0
}

generate_health_summary() {
  print_section "LiteLLM Health Analysis"
  
  # Check pod status
  POD_STATUS=$(kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$POD_STATUS" != "Running" ]; then
    echo "❌ Issue: LiteLLM pod is not in Running state (current state: $POD_STATUS)" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ LiteLLM pod is running correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check pod ready status
  POD_READY=$(kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
  if [ "$POD_READY" != "true" ]; then
    echo "❌ Issue: LiteLLM container is not ready" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ LiteLLM container is ready and accepting connections" | tee -a "$OUTPUT_FILE"
  fi
  
  # Get pod restart count directly from pod name
  RESTART_COUNT=$(kubectl get pod -n $NAMESPACE $LITELLM_POD_NAME -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
  if [ "$RESTART_COUNT" -gt 5 ]; then
    echo "❌ Issue: LiteLLM pod has restarted $RESTART_COUNT times - indicates stability problems" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif [ "$RESTART_COUNT" -gt 1 ]; then
    echo "⚠️ Warning: LiteLLM pod has restarted $RESTART_COUNT times" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ LiteLLM pod restart count is low ($RESTART_COUNT)" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check PVC status if using database
  PVC_STATUS=$(kubectl get pvc -n $NAMESPACE | grep -i litellm | grep -v "Bound" | wc -l)
  if [ "$PVC_STATUS" -gt 0 ]; then
    echo "❌ Issue: One or more LiteLLM database PVCs are not properly bound" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  elif kubectl get pvc -n $NAMESPACE | grep -q -i litellm; then
    echo "✅ LiteLLM database persistent storage is correctly configured" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check API connectivity using the health check results
  HEALTH_CHECK_RESULT=$(grep -i "health" "$OUTPUT_FILE" | grep -i -v "No" | grep -i "200\|OK\|true" | wc -l)
  if [ "$HEALTH_CHECK_RESULT" -lt 1 ]; then
    echo "❌ Issue: LiteLLM API health check failed - service may be unreachable" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ LiteLLM API is responding correctly" | tee -a "$OUTPUT_FILE"
  fi
  
  # Check models list from API response and configuration
  MODELS_CHECK=$(grep -i "models" "$OUTPUT_FILE" | grep -i "\[\|\{" | wc -l)
  
  # Get expected models from config file
  EXPECTED_MODELS=()
  if [ -n "$LITELLM_CONFIG_NAME" ]; then
    # Extract model names from config
    EXPECTED_MODELS=($(kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o yaml | grep "model_name:" | awk '{print $2}'))
  fi
  
  # Get initialized models from logs, properly cleaning up ANSI color codes
  INITIALIZED_MODELS=()
  LOG_OUTPUT=$(kubectl logs -n $NAMESPACE $LITELLM_POD_NAME | grep -A 10 "Proxy initialized with Config, Set models:" | grep -v "^INFO" | sed 's/\x1b\[[0-9;]*m//g' 2>/dev/null)
  if [ -n "$LOG_OUTPUT" ]; then
    # Extract just the model names, skipping headers and whitespace
    while read -r line; do
      if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*$ ]]; then
        model="${BASH_REMATCH[1]}"
        if [ "$model" != "Proxy" ] && [ "$model" != "initialized" ] && [ "$model" != "with" ] && [ "$model" != "Config," ] && [ "$model" != "Set" ] && [ "$model" != "models:" ]; then
          INITIALIZED_MODELS+=("$model")
        fi
      fi
    done < <(echo "$LOG_OUTPUT")
  fi
  
  if [ "$MODELS_CHECK" -lt 1 ]; then
    echo "❌ Issue: No models found in LiteLLM API response" | tee -a "$OUTPUT_FILE"
    OVERALL_STATUS="Unhealthy"
    ISSUES_FOUND=$((ISSUES_FOUND+1))
  else
    echo "✅ LiteLLM models available through API" | tee -a "$OUTPUT_FILE"
  fi
  
  # Compare expected vs. initialized models
  if [ ${#EXPECTED_MODELS[@]} -gt 0 ]; then
    echo "Expected models from config:" | tee -a "$OUTPUT_FILE"
    for model in "${EXPECTED_MODELS[@]}"; do
      echo "  - $model" | tee -a "$OUTPUT_FILE"
    done
  fi
  
  if [ ${#INITIALIZED_MODELS[@]} -gt 0 ]; then
    echo "Initialized models from logs:" | tee -a "$OUTPUT_FILE"
    for model in "${INITIALIZED_MODELS[@]}"; do
      echo "  - $model" | tee -a "$OUTPUT_FILE"
    done
    
    # Check if initialized models match expected models
    if [ ${#EXPECTED_MODELS[@]} -gt 0 ] && [ ${#INITIALIZED_MODELS[@]} -gt 0 ]; then
      EXPECTED_COUNT=${#EXPECTED_MODELS[@]}
      INITIALIZED_COUNT=${#INITIALIZED_MODELS[@]}
      # Simple count comparison (not perfect but gives an indication)
      if [ "$EXPECTED_COUNT" -ne "$INITIALIZED_COUNT" ]; then
        echo "⚠️ Warning: Number of initialized models ($INITIALIZED_COUNT) doesn't match configuration ($EXPECTED_COUNT)" | tee -a "$OUTPUT_FILE"
        if [ "$OVERALL_STATUS" = "Healthy" ]; then
          OVERALL_STATUS="Warning"
        fi
        ISSUES_FOUND=$((ISSUES_FOUND+1))
      else
        echo "✅ Model count in configuration matches initialized models" | tee -a "$OUTPUT_FILE"
      fi
    fi
  else
    echo "⚠️ Warning: Could not find initialized models in logs" | tee -a "$OUTPUT_FILE"
    if [ "$OVERALL_STATUS" = "Healthy" ]; then
      OVERALL_STATUS="Warning"
    fi
    ISSUES_FOUND=$((ISSUES_FOUND+1))
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
  
  # Add a specific debug message to help users understand how the pod was identified
  echo "" | tee -a "$OUTPUT_FILE"
  echo "Debug Info - Selected LiteLLM pod: $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE"
  echo "Debug Info - Selected LiteLLM service: $LITELLM_SVC_NAME" | tee -a "$OUTPUT_FILE"
  echo "Debug Info - Selected ConfigMap: $LITELLM_CONFIG_NAME" | tee -a "$OUTPUT_FILE"
  
  # Final summary
  print_section "Final Summary"
  echo "Overall Status: $OVERALL_STATUS" | tee -a "$OUTPUT_FILE"
  echo "Total Issues Found: $ISSUES_FOUND" | tee -a "$OUTPUT_FILE"
  
  if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo "✅ LiteLLM appears to be functioning normally" | tee -a "$OUTPUT_FILE"
  elif [ "$OVERALL_STATUS" = "Warning" ]; then
    echo "⚠️ LiteLLM has some minor issues that should be investigated" | tee -a "$OUTPUT_FILE"
  else
    echo "❌ LiteLLM has critical issues that need immediate attention" | tee -a "$OUTPUT_FILE"
  fi
  
  return 0
}

generate_troubleshooting_recommendations() {
  # Only show relevant troubleshooting recommendations if issues found
  if [ "$ISSUES_FOUND" -gt 0 ]; then
    print_section "Troubleshooting Recommendations"
    
    if grep -q "pod is not in Running state\|pod is not ready" "$OUTPUT_FILE"; then
      echo "• Check pod events: kubectl describe pod -n $NAMESPACE $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Review pod logs: kubectl logs -n $NAMESPACE $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod's liveness/readiness probes in the deployment" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "API health check failed" "$OUTPUT_FILE"; then
      echo "• Verify service endpoints: kubectl get endpoints -n $NAMESPACE $LITELLM_SVC_NAME" | tee -a "$OUTPUT_FILE"
      echo "• Check pod networking: kubectl exec -n $NAMESPACE $LITELLM_POD_NAME -- curl localhost:$LITELLM_PORT/health/liveliness" | tee -a "$OUTPUT_FILE"
      echo "• Restart the LiteLLM pod: kubectl delete pod -n $NAMESPACE $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "No models found in LiteLLM\|models doesn't match configuration" "$OUTPUT_FILE"; then
      echo "• Check config.yaml in ConfigMap for proper model configuration" | tee -a "$OUTPUT_FILE"
      echo "• Ensure environment variables for API keys are properly set" | tee -a "$OUTPUT_FILE"
      echo "• Verify model names and formats in the configuration" | tee -a "$OUTPUT_FILE"
      echo "• Compare model list in logs with configuration:" | tee -a "$OUTPUT_FILE"
      echo "  - kubectl logs -n $NAMESPACE $LITELLM_POD_NAME | grep -A 10 'Proxy initialized with Config'" | tee -a "$OUTPUT_FILE"
      echo "  - kubectl get configmap -l app=litellm -n $NAMESPACE -o yaml | grep -A 50 'model_list:'" | tee -a "$OUTPUT_FILE"
    fi
    
    if grep -q "Key mismatch" "$OUTPUT_FILE"; then
      echo "• Authentication key mismatches detected:" | tee -a "$OUTPUT_FILE"
      echo "  - Verify that the secret 'litellm-masterkey' contains the same key as config.yaml" | tee -a "$OUTPUT_FILE"
      echo "  - Check that urbalurba-secrets LITELLM_PROXY_MASTER_KEY matches litellm-masterkey and config.yaml" | tee -a "$OUTPUT_FILE"
      echo "  - Command to check secrets: kubectl get secret litellm-masterkey -o jsonpath='{.data.masterkey}' | base64 --decode" | tee -a "$OUTPUT_FILE"
      echo "  - Command to check config: kubectl get configmap litellm-config -o yaml | grep master_key" | tee -a "$OUTPUT_FILE"
    fi
  fi
  
  return 0
}

check_secrets() {
  print_section "Secrets"
  run_command "kubectl get secret -n $NAMESPACE | grep -i litellm" "LiteLLM Secrets" $STEP
  STEP=$((STEP+1))
  
  # If we found a litellm secret, examine it (without exposing values)
  LITELLM_SECRET=$(kubectl get secret -n $NAMESPACE | grep -i litellm | head -1 | awk '{print $1}')
  if [ -n "$LITELLM_SECRET" ]; then
    run_command "kubectl get secret $LITELLM_SECRET -n $NAMESPACE -o jsonpath='{.metadata}'" "LiteLLM Secret Metadata" $STEP
    STEP=$((STEP+1))
    
    # Check what keys exist in the secret (without showing values)
    run_command "kubectl get secret $LITELLM_SECRET -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys'" "LiteLLM Secret Keys" $STEP
    STEP=$((STEP+1))
  fi
  
  # Check unified secrets for API keys but don't display sensitive information
  URBALURBA_SECRET_EXISTS=$(kubectl get secret -n $NAMESPACE urbalurba-secrets &>/dev/null && echo "yes" || echo "no")
  if [ "$URBALURBA_SECRET_EXISTS" == "yes" ]; then
    run_command "kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.metadata}'" "Unified Secrets Metadata" $STEP
    STEP=$((STEP+1))
    
    # Check for required API keys without revealing their values
    if [ "$HIDE_PASSWORD_FROM_PRINT" = "true" ]; then
      AZURE_API_KEY_EXISTS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.AZURE_API_KEY}' &>/dev/null && echo "yes" || echo "no")
      AZURE_API_BASE_EXISTS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.AZURE_API_BASE}' &>/dev/null && echo "yes" || echo "no") 
      OPENAI_API_KEY_EXISTS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.OPENAI_API_KEY}' &>/dev/null && echo "yes" || echo "no")
      ANTHROPIC_API_KEY_EXISTS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.ANTHROPIC_API_KEY}' &>/dev/null && echo "yes" || echo "no")
      LITELLM_PROXY_MASTER_KEY_EXISTS=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data.LITELLM_PROXY_MASTER_KEY}' &>/dev/null && echo "yes" || echo "no")
      
      echo "Checking for necessary API keys in urbalurba-secrets:" | tee -a "$OUTPUT_FILE"
      echo "  - AZURE_API_KEY: $AZURE_API_KEY_EXISTS" | tee -a "$OUTPUT_FILE"
      echo "  - AZURE_API_BASE: $AZURE_API_BASE_EXISTS" | tee -a "$OUTPUT_FILE"
      echo "  - OPENAI_API_KEY: $OPENAI_API_KEY_EXISTS" | tee -a "$OUTPUT_FILE"
      echo "  - ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY_EXISTS" | tee -a "$OUTPUT_FILE"
      echo "  - LITELLM_PROXY_MASTER_KEY: $LITELLM_PROXY_MASTER_KEY_EXISTS" | tee -a "$OUTPUT_FILE"
      
      API_KEYS_PRESENT=$(($(echo "$AZURE_API_KEY_EXISTS $AZURE_API_BASE_EXISTS $OPENAI_API_KEY_EXISTS $ANTHROPIC_API_KEY_EXISTS $LITELLM_PROXY_MASTER_KEY_EXISTS" | grep -o "yes" | wc -l)))
      
      if [ "$API_KEYS_PRESENT" -gt 3 ]; then
        echo "✅ Found API keys in the unified secrets" | tee -a "$OUTPUT_FILE"
      else
        echo "⚠️ Some API keys are missing in the unified secrets" | tee -a "$OUTPUT_FILE"
      fi
    else
      # For debugging purposes only, if hiding passwords is disabled
      # Check keys by name only, without revealing values
      run_command "kubectl get secret urbalurba-secrets -n $NAMESPACE -o jsonpath='{.data}' | jq 'keys | sort'" "Unified Secret Keys" $STEP
      STEP=$((STEP+1))
      
      API_KEYS_PRESENT=$(kubectl get secret urbalurba-secrets -n $NAMESPACE -o yaml | grep -i -E "AZURE_API|OPENAI_API|LITELLM_MASTER|ANTHROPIC" | wc -l)
      if [ "$API_KEYS_PRESENT" -gt 3 ]; then
        echo "✅ Found API keys in the unified secrets" | tee -a "$OUTPUT_FILE"
      else
        echo "⚠️ Some API keys are missing in the unified secrets" | tee -a "$OUTPUT_FILE"
      fi
    fi
  fi
  
  return 0
}

check_network_policies() {
  print_section "Network Policies"
  run_command "kubectl get networkpolicies -n $NAMESPACE | grep -v 'NAME'" "Network Policies in Namespace" $STEP
  STEP=$((STEP+1))
  
  return 0
}

# ---------------------------
# Main Execution Function
# ---------------------------
run_debug_litellm() {
  # 1. Initial setup
  print_section "LiteLLM Debug Information"
  echo "Date: $(date)" | tee -a "$OUTPUT_FILE"
  echo "Context: $(kubectl config current-context 2>/dev/null || echo "Unable to determine context")" | tee -a "$OUTPUT_FILE"
  echo "Namespace: $NAMESPACE" | tee -a "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"
  
  # Check if kubectl is installed
  check_kubectl_installed || return 1
  
  # Check if jq is installed
  check_jq_installed
  
  # Find key resources
  LITELLM_POD_NAME=$(find_litellm_pod_name)
  LITELLM_SVC_NAME=$(find_litellm_svc_name)
  LITELLM_CONFIG_NAME=$(find_litellm_configmap_name)
  
  # Check if LiteLLM is found
  if [ -z "$LITELLM_POD_NAME" ]; then
    echo "Error: No LiteLLM pods found in namespace $NAMESPACE" | tee -a "$OUTPUT_FILE"
    echo "Please check if LiteLLM is deployed in this namespace or try another namespace." | tee -a "$OUTPUT_FILE"
    echo "You can specify a namespace as an argument: ./debug-litellm.sh <namespace>" | tee -a "$OUTPUT_FILE"
    return 1
  fi
  
  # Log the key resources that we found
  echo "Found LiteLLM resources:" | tee -a "$OUTPUT_FILE"
  echo "- Pod: $LITELLM_POD_NAME" | tee -a "$OUTPUT_FILE" 
  echo "- Service: $LITELLM_SVC_NAME" | tee -a "$OUTPUT_FILE"
  echo "- ConfigMap: $LITELLM_CONFIG_NAME" | tee -a "$OUTPUT_FILE"
  echo "" | tee -a "$OUTPUT_FILE"
  
  # 2. Collect information about LiteLLM deployment
  collect_basic_information
  
  # 3. Check resources status
  check_pod_status
  check_service_status
  
  # 4. Analyze configuration - order matters here, we need to extract model configuration
  # before testing API connectivity and integrations
  check_configmap
  extract_model_configuration
  analyze_environment_variables
  check_auth_keys
  check_secrets
  
  # 5. Check storage
  check_storage
  check_ingress
  
  # 6. Test API connectivity and integrations
  test_api_connectivity
  test_ollama_integration
  test_cloud_provider_integration
  check_database_integration
  check_migration_status
  check_network_policies
  
  # 7. Analyze logs and events
  analyze_logs
  
  # 8. Generate summary and recommendations
  generate_health_summary
  generate_troubleshooting_recommendations
  
  return 0
}

# ---------------------------
# ---------------------------
# Additional Utility Functions
# ---------------------------
print_usage() {
  echo "Usage: $0 [namespace] [--hide-passwords/--show-passwords]"
  echo ""
  echo "Options:"
  echo "  namespace             Kubernetes namespace to debug LiteLLM (default: default)"
  echo "  --hide-passwords      Hide sensitive values in the output (default)"
  echo "  --show-passwords      Show sensitive values in the output (useful for troubleshooting)"
  echo ""
  echo "Examples:"
  echo "  $0                    Debug LiteLLM in the default namespace"
  echo "  $0 litellm-ns         Debug LiteLLM in the litellm-ns namespace"
  echo "  $0 --show-passwords   Debug in default namespace and show passwords"
}

generate_fix_script() {
  # If issues were found, generate a helper script to fix them
  if [ "$ISSUES_FOUND" -gt 0 ]; then

    echo "#!/bin/bash" > $FIX_SCRIPT
    echo "# Generated by debug-litellm.sh on $(date)" >> $FIX_SCRIPT
    echo "# Run this script to fix issues identified with your LiteLLM deployment" >> $FIX_SCRIPT
    echo "" >> $FIX_SCRIPT
    
    # If master key mismatch found - this is a common issue
    if grep -q "Key mismatch between" "$OUTPUT_FILE"; then
      echo "echo 'Fixing master key mismatch...'" >> $FIX_SCRIPT
      
      # Generate commands to fix the key mismatch
      if [ -n "$CONFIG_MASTER_KEY" ]; then
        echo "# Fix the LiteLLM master key in the ConfigMap to match the secret" >> $FIX_SCRIPT
        echo "CONFIG_PATCH=\"{\\\"data\\\":{\\\"config.yaml\\\":\\\"`kubectl get configmap $LITELLM_CONFIG_NAME -n $NAMESPACE -o jsonpath='{.data.config\\.yaml}' | sed \"s/master_key: $CONFIG_MASTER_KEY/master_key: \\$LITELLM_KEY/\"`\\\"}}\"" >> $FIX_SCRIPT
        echo "kubectl patch configmap $LITELLM_CONFIG_NAME -n $NAMESPACE --type=merge -p \"\$CONFIG_PATCH\"" >> $FIX_SCRIPT
        echo "echo 'ConfigMap patched with correct master key'" >> $FIX_SCRIPT
      fi
      
      echo "" >> $FIX_SCRIPT
      echo "# Restart the LiteLLM pod to apply changes" >> $FIX_SCRIPT
      echo "kubectl rollout restart deployment -n $NAMESPACE \$(kubectl get deployment -n $NAMESPACE | grep litellm | awk '{print \$1}')" >> $FIX_SCRIPT
      echo "echo 'LiteLLM pod restarted'" >> $FIX_SCRIPT
    fi
    
    # If missing environment variables are found
    if grep -q "Missing environment variables" "$OUTPUT_FILE"; then
      echo "" >> $FIX_SCRIPT
      echo "echo 'Adding missing environment variables...'" >> $FIX_SCRIPT
      echo "# Create a patch for the deployment to add missing environment variables" >> $FIX_SCRIPT
      
      # Generate an environment variable patch
      echo "ENV_PATCH='{" >> $FIX_SCRIPT
      echo "  \"spec\": {" >> $FIX_SCRIPT
      echo "    \"template\": {" >> $FIX_SCRIPT
      echo "      \"spec\": {" >> $FIX_SCRIPT
      echo "        \"containers\": [" >> $FIX_SCRIPT
      echo "          {" >> $FIX_SCRIPT
      echo "            \"name\": \"litellm\"," >> $FIX_SCRIPT
      echo "            \"env\": [" >> $FIX_SCRIPT
      
      for missing_var in "${MISSING_ENV_VARS[@]}"; do
        if [ -n "$missing_var" ]; then
          echo "              {" >> $FIX_SCRIPT
          echo "                \"name\": \"$missing_var\"," >> $FIX_SCRIPT
          echo "                \"valueFrom\": {" >> $FIX_SCRIPT
          echo "                  \"secretKeyRef\": {" >> $FIX_SCRIPT
          echo "                    \"name\": \"urbalurba-secrets\"," >> $FIX_SCRIPT
          echo "                    \"key\": \"$missing_var\"" >> $FIX_SCRIPT
          echo "                  }" >> $FIX_SCRIPT
          echo "                }" >> $FIX_SCRIPT
          echo "              }," >> $FIX_SCRIPT
        fi
      done
      
      # Remove trailing comma
      sed -i '' -e '$ s/,$//' $FIX_SCRIPT
      
      echo "            ]" >> $FIX_SCRIPT
      echo "          }" >> $FIX_SCRIPT
      echo "        ]" >> $FIX_SCRIPT
      echo "      }" >> $FIX_SCRIPT
      echo "    }" >> $FIX_SCRIPT
      echo "  }" >> $FIX_SCRIPT
      echo "}'" >> $FIX_SCRIPT
      
      echo "" >> $FIX_SCRIPT
      echo "kubectl patch deployment \$(kubectl get deployment -n $NAMESPACE | grep litellm | awk '{print \$1}') -n $NAMESPACE --type=strategic --patch \"\$ENV_PATCH\"" >> $FIX_SCRIPT
      echo "echo 'Deployment patched with missing environment variables'" >> $FIX_SCRIPT
    fi
    
    # Make the script executable
    chmod +x $FIX_SCRIPT
    echo "A helper script has been generated to fix issues: $FIX_SCRIPT"
  fi
}

# ---------------------------
# Script Entry Point
# ---------------------------
main() {
  # Set default values
  NAMESPACE="default"
  HIDE_PASSWORD_FROM_PRINT=true
  
  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --hide-passwords)
        HIDE_PASSWORD_FROM_PRINT=true
        shift
        ;;
      --show-passwords)
        HIDE_PASSWORD_FROM_PRINT=false
        shift
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1"
        print_usage
        exit 1
        ;;
      *)
        NAMESPACE="$1"
        shift
        ;;
    esac
  done
  
  # Remove previous debug file if it exists
  if [ -f "$OUTPUT_FILE" ]; then
    rm "$OUTPUT_FILE"
  fi
  
  echo "Collecting LiteLLM debugging information in namespace $NAMESPACE..."
  echo "Output will be saved to $OUTPUT_FILE"
  
  # Run the debug process
  run_debug_litellm
  
  # Generate fix script if issues were found
  generate_fix_script
  
  # Output final message
  echo ""
  echo "Debug information has been collected and saved to $OUTPUT_FILE"
  
  return $EXIT_CODE
}

# Execute main function
main "$@"