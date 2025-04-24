#!/bin/bash
# filename: create-secrets.sh
# description: Script that creates the secrets id_rsa_ansible.pub and id_rsa_ansible
# the script must be run in the folder named secrets

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
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
if [ "$CURRENT_DIR" != "secrets" ]; then
    echo "This script must be run from the folder named secrets"
    exit 1
fi

echo "Creating the ssh keys id_rsa_ansible.pub and id_rsa_ansible"
ssh-keygen -t rsa -b 4096 -f ./id_rsa_ansible -N ""
check_command_success "Creating ssh keys"

# Verify the keys were created
if [ -f id_rsa_ansible.pub ] && [ -f id_rsa_ansible ]; then
    STATUS+=("Verification of keys: OK")
else
    STATUS+=("Verification of keys: Fail")
    ERROR=1
fi

echo "------ Summary of operation statuses: ------"
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