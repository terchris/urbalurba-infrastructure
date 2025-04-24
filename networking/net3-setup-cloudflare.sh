#!/bin/bash
# filename: net3-setup-cloudflare.sh
# description: Set Cloudflare tunnel and DNS for the test cluster
# usage: ./net3-setup-cloudflare.sh <cloudflare_prefix_variable>
# <cloudflare_prefix_variable> is the prefix variablename for the variables in the kubernetes-secrets.yml file eg CLOUDFLARE_TEST

# relative path to the kubernetes-secrets.yml file where all variables are stored
KUBERNETES_SECRETS_FILE="../topsecret/kubernetes/kubernetes-secrets.yml"

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Check if the cloudflare_prefix_variable is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_prefix_variable>"
    exit 1
fi

CLOUDFLARE_PREFIX_VARIABLE=$1

# Variables
PROVISION_HOST="provision-host"
PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL="/mnt/urbalurbadisk/ansible/playbooks/750-setup-network-cloudflare-tunnel.yml"
STATUS=()
ERROR=0

# Function to check the success of the last command
check_command_success() {
    if [ $? -ne 0 ]; then
        STATUS+=("$1: Fail")
        ERROR=1
    else
        STATUS+=("$1: OK")
    fi
}

# Ensure the script is run from the correct directory
CURRENT_DIR=${PWD##*/}
if [ "$CURRENT_DIR" != "networking" ]; then
    echo "This script must be run from the folder networking"
    STATUS+=("Current directory check: Fail")
    ERROR=1
else
    STATUS+=("Current directory check: OK")
fi

# Ensure that the kubernetes-secrets.yml file exists
if [ ! -f $KUBERNETES_SECRETS_FILE ]; then
    echo "The file $KUBERNETES_SECRETS_FILE does not exist"
    STATUS+=("kubernetes-secrets.yml check: Fail")
    ERROR=1
else
    STATUS+=("kubernetes-secrets.yml check: OK")
fi

# Function to get variable from kubernetes-secrets.yml
get_variable() {
    local var_name="$1"
    local var_value=$(grep "${var_name}:" $KUBERNETES_SECRETS_FILE | cut -d ':' -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -z "$var_value" ]; then
        echo "Failed to retrieve $var_name from $KUBERNETES_SECRETS_FILE"
        STATUS+=("Get $var_name: Fail")
        ERROR=1
    fi
    echo "$var_value"
}

# Get the Cloudflare variables from the kubernetes-secrets.yml file
TUNNELNAME=$(get_variable "${CLOUDFLARE_PREFIX_VARIABLE}_TUNNELNAME")
DOMAINNAME=$(get_variable "${CLOUDFLARE_PREFIX_VARIABLE}_DOMAINNAME")
SUBDOMAINS=$(get_variable "${CLOUDFLARE_PREFIX_VARIABLE}_SUBDOMAINS")

# Add variable values to STATUS
STATUS+=("${CLOUDFLARE_PREFIX_VARIABLE}_TUNNELNAME= $TUNNELNAME")
STATUS+=("${CLOUDFLARE_PREFIX_VARIABLE}_DOMAINNAME= $DOMAINNAME")
STATUS+=("${CLOUDFLARE_PREFIX_VARIABLE}_SUBDOMAINS= $SUBDOMAINS")

# Convert comma-separated SUBDOMAINS to JSON array format
SUBDOMAINS_JSON=$(echo $SUBDOMAINS | awk -v RS=',' -v ORS=',' '{print "\""$1"\""}' | sed 's/,$//')
SUBDOMAINS_JSON="[$SUBDOMAINS_JSON]"

if [ $ERROR -eq 0 ]; then
    echo "Setting up Cloudflare tunnel and DNS for prefix: $CLOUDFLARE_PREFIX_VARIABLE ... using the playbook $PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL"
    multipass exec $PROVISION_HOST -- bash -c "cd /mnt/urbalurbadisk/ansible && sudo -u ansible ansible-playbook $PLAYBOOK_PATH_SETUP_CLOUDFLARETUNNEL -e tunnel_name=\"$TUNNELNAME\" -e domain=\"$DOMAINNAME\" -e '{\"subdomains\": $SUBDOMAINS_JSON}'"
    check_command_success "Setting up Cloudflare tunnel and DNS"
fi

echo "------ Summary of installation statuses for: $0 ------"
for status in "${STATUS[@]}"; do
    echo "$status"
done

if [ $ERROR -ne 0 ]; then
    echo "---------------- E R R O R --------------------"
    echo "Check the error messages above"
else
    echo "--------------- All OK ------------------------"
fi

exit $ERROR