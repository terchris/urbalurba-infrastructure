#!/bin/bash
# filename: create-kubernetes-secrets.sh
# description: Creates a new kubernetes-secrets.yml file from template and guides user through configuration

# Exit codes:
# 0 - Success
# 1 - Error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
URB_PATH="$(dirname "$SCRIPT_DIR")"  # Get the parent directory of topsecret
TEMPLATE_FILE="kubernetes/kubernetes-secrets-template.yml"
SECRETS_FILE="kubernetes/kubernetes-secrets.yml"
FULL_TEMPLATE_PATH="$SCRIPT_DIR/$TEMPLATE_FILE"
FULL_SECRETS_PATH="$SCRIPT_DIR/$SECRETS_FILE"

# Function to check if a file exists
check_file_exists() {
    if [ -f "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get description and value from template file
get_variable_info() {
    local key="$1"
    local file="$2"
    
    # Get the line with the variable and its comment
    local line=$(grep -A 1 "^  $key:" "$file" | head -n 2)
    
    # Extract the comment (everything after #)
    local description=$(echo "$line" | grep "#" | sed 's/^.*# //')
    
    # Extract the value
    local value=$(echo "$line" | grep -v "#" | sed -E 's/^  '"$key"':[[:space:]]*["]?([^"#]*[^"#[:space:]])["]?.*$/\1/')
    
    echo "$description|$value"
}

# Function to prompt user for input with default value
prompt_with_default() {
    local key="$1"
    local var_name="$2"
    local info=$(get_variable_info "$key" "$FULL_TEMPLATE_PATH")
    local description=$(echo "$info" | cut -d'|' -f1)
    local default_value=$(echo "$info" | cut -d'|' -f2)
    local input

    echo "$description"
    echo "Current value: $default_value"
    read -p "Press Enter to keep current value or enter new value: " input
    if [ -z "$input" ]; then
        input="$default_value"
    fi
    eval "$var_name='$input'"
}

# Function to update a value in the secrets file
update_secret_value() {
    local key="$1"
    local value="$2"
    local file="$3"
    
    # Escape special characters in the value
    value=$(echo "$value" | sed 's/[\/&]/\\&/g')
    
    # Update the value in the file
    sed -i '' "s/^  $key: .*$/  $key: $value/" "$file"
}

# Function to get all variable names from template file
get_all_variables() {
    local file="$1"
    grep -E "^  [A-Z_]+:" "$file" | sed -E 's/^  ([A-Z_]+):.*$/\1/'
}

# Main execution
main() {
    # Check if template exists
    if ! check_file_exists "$FULL_TEMPLATE_PATH"; then
        echo "Error: Template file not found at: $FULL_TEMPLATE_PATH"
        exit 1
    fi

    # Check if secrets file exists
    if ! check_file_exists "$FULL_SECRETS_PATH"; then
        echo "Error: Kubernetes secrets file not found at: $FULL_SECRETS_PATH"
        echo ""
        echo "You have two options:"
        echo "1. Copy the template manually and edit it:"
        echo "   cp $TEMPLATE_FILE $SECRETS_FILE"
        echo "   # Then edit $SECRETS_FILE with your values"
        echo "2. Use this script to create a new file:"
        echo "   ./topsecret/create-kubernetes-secrets.sh new"
        echo ""
        echo "For detailed information about the secrets and their default values,"
        echo "please read doc/kubernetes-secrets-readme.md"
        exit 1
    fi

    # If we get here, the secrets file exists
    echo "Kubernetes secrets file exists at: $FULL_SECRETS_PATH"
    echo "If you want to create a new one, please delete the existing file first."
    exit 0
}

# Check if script was called with 'new' parameter
if [ "$1" = "new" ]; then
    # Check if template exists
    if ! check_file_exists "$FULL_TEMPLATE_PATH"; then
        echo "Error: Template file not found at: $FULL_TEMPLATE_PATH"
        exit 1
    fi

    # Check if secrets file exists
    if check_file_exists "$FULL_SECRETS_PATH"; then
        echo "Kubernetes secrets file already exists at: $FULL_SECRETS_PATH"
        echo "If you want to create a new one, please delete the existing file first."
        exit 1
    fi

    echo "Creating new Kubernetes secrets file from template..."
    cp "$FULL_TEMPLATE_PATH" "$FULL_SECRETS_PATH"
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create secrets file"
        exit 1
    fi

    echo "Created new secrets file at: $FULL_SECRETS_PATH"
    echo ""
    echo "Please configure the following variables:"
    echo "-----------------------------------------------"

    # Get all variables from template and process them
    while read -r key; do
        # Skip empty lines
        if [ -z "$key" ]; then
            continue
        fi
        
        # Convert key to lowercase for variable name
        var_name=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        
        # Special handling for ArgoCD admin password
        if [ "$key" = "admin.password" ]; then
            echo ""
            echo "ArgoCD Configuration:"
            echo "You need to create a bcrypt hashed password for ArgoCD admin"
        fi
        
        # Special handling for Tailscale configuration
        if [ "$key" = "TAILSCALE_SECRET" ]; then
            echo ""
            echo "Tailscale Configuration:"
            echo "You need to create Tailscale keys at https://login.tailscale.com/admin/settings/keys"
        fi
        
        # Special handling for Cloudflare configuration
        if [ "$key" = "CLOUDFLARE_DNS_TOKEN" ]; then
            echo ""
            echo "Cloudflare Configuration:"
            echo "You need to create a Cloudflare API token at https://dash.cloudflare.com/profile/api-tokens"
        fi
        
        # Special handling for GitHub configuration
        if [ "$key" = "GITHUB_ACCESS_TOKEN" ]; then
            echo ""
            echo "GitHub Configuration:"
            echo "You need to create a GitHub Personal Access Token at https://github.com/settings/tokens"
        fi
        
        prompt_with_default "$key" "$var_name"
        update_secret_value "$key" "${!var_name}" "$FULL_SECRETS_PATH"
    done < <(get_all_variables "$FULL_TEMPLATE_PATH")

    echo ""
    echo "Kubernetes secrets file has been created and configured."
    echo "You can now run the installation script."
    
    exit 0
else
    # Run the main function which checks for file existence
    main
fi 