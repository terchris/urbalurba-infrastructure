#!/bin/bash
# filename: provision-host-sshconf.sh
# description: Set up SSH configuration for a Multipass VM and run a verification script
# NB! it also copies the ssh key to the provision-host so you can login without password to all VMs
# usage: ./provision-host-sshconf.sh [vm-name] [ssh-user]
# example: ./provision-host-sshconf.sh provision-host ansible

set -e  # Exit immediately if a command exits with a non-zero status.

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run with Bash"
    exit 1
fi

# Ensure we're in the correct directory
if [[ $(basename "$PWD") != "provision-host" ]]; then
    echo "Error: This script must be run from the 'provision-host' directory"
    exit 1
fi

# Variables
VM_NAME=${1:-"provision-host"}
SSH_USER=${2:-"ansible"}
SSH_KEY_PATH="$(cd .. && pwd)/secrets/id_rsa_ansible"
REMOTE_SCRIPT="/tmp/verify_user.sh"
SSH_CONFIG="$HOME/.ssh/config"

# Arrays to store status and errors
STEPS=()
STATUS=()
ERRORS=()

# Function to add status
add_status() {
    STEPS+=("$1")
    STATUS+=("$2")
    echo "Status: $1 - $2"
}

# Function to add error
add_error() {
    ERRORS+=("$1: $2")
    echo "Error: $1 - $2"
}

# Function to get VM IP
get_vm_ip() {
    local step="Get VM IP"
    echo "Getting VM IP address..."
    VM_IP=$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}')
    if [ -z "$VM_IP" ]; then
        add_status "$step" "Fail"
        add_error "$step" "Could not get IP address for VM $VM_NAME"
        return 1
    else
        echo "VM IP: $VM_IP"
        add_status "$step" "OK"
        return 0
    fi
}

# Function to update SSH config
update_ssh_config() {
    local step="Update SSH config"
    echo "Updating SSH configuration..."
    local config_entry="Host $VM_NAME
    HostName $VM_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null"

    if [ ! -f "$SSH_CONFIG" ]; then
        echo "$config_entry" > "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        echo "Created new SSH config file"
    else
        # Remove existing entry if it exists
        sed -i.bak "/^Host $VM_NAME/,/^$/d" "$SSH_CONFIG"
        # Append new entry
        echo "$config_entry" >> "$SSH_CONFIG"
        echo "Updated SSH config entry"
    fi
    add_status "$step" "OK"
}

# New function to copy SSH key to provision-host
copy_ssh_key_to_provision_host() {
    local step="Copy SSH key to provision-host"
    echo "Copying SSH key to provision-host..."
    
    # Create .ssh directory if it doesn't exist
    ssh "$VM_NAME" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    
    # Copy the public key
    scp "${SSH_KEY_PATH}.pub" "${VM_NAME}:~/.ssh/id_rsa.pub"
    
    # Copy the private key
    scp "${SSH_KEY_PATH}" "${VM_NAME}:~/.ssh/id_rsa"
    
    # Set correct permissions
    ssh "$VM_NAME" "chmod 600 ~/.ssh/id_rsa ~/.ssh/id_rsa.pub"
    
    # Add public key to authorized_keys
    ssh "$VM_NAME" "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    
    add_status "$step" "OK"
}

# Function to create and copy verification script
create_copy_verification_script() {
    local step="Create and copy verification script"
    echo "Creating and copying verification script..."
    cat << EOF > /tmp/verify_user.sh
#!/bin/bash
# Source the user's profile to set up the environment
if [ -f ~/.profile ]; then
    . ~/.profile
fi
if [ -f ~/.bash_profile ]; then
    . ~/.bash_profile
elif [ -f ~/.bash_login ]; then
    . ~/.bash_login
elif [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

echo "This script is running as user: \$(whoami)"
echo "Current working directory: \$(pwd)"
echo "Home directory: \$HOME"
echo "Hostname: \$(hostname)"
echo "PATH: \$PATH"
echo "Environment variables:"
env | sort
EOF
    scp /tmp/verify_user.sh "$VM_NAME:$REMOTE_SCRIPT"
    ssh "$VM_NAME" "chmod +x $REMOTE_SCRIPT"
    add_status "$step" "OK"
}

# Function to run remote script
run_remote_script() {
    local step="Run remote script"
    echo "Running remote script..."
    if ssh "$VM_NAME" "bash $REMOTE_SCRIPT"; then
        add_status "$step" "OK"
    else
        add_status "$step" "Fail"
        add_error "$step" "Failed to execute remote script"
    fi
}

# Function to print summary
print_summary() {
    echo "---------- Configuration Summary ----------"
    for i in "${!STEPS[@]}"; do
        echo "${STEPS[$i]}: ${STATUS[$i]}"
    done

    if [ ${#ERRORS[@]} -eq 0 ]; then
        echo "All steps completed successfully."
    else
        echo "Errors occurred during configuration:"
        for error in "${ERRORS[@]}"; do
            echo "  $error"
        done
    fi
}

# Function to print SSH usage instructions
print_ssh_instructions() {
    echo
    echo "SSH Connection Instructions:"
    echo "----------------------------"
    echo "To log in to the VM:"
    echo "  ssh $VM_NAME"
    echo
    echo "To run a command on the VM:"
    echo "  ssh $VM_NAME 'your_command_here'"
    echo
    echo "To copy a file to the VM:"
    echo "  scp /path/to/local/file $VM_NAME:/path/on/remote/machine"
    echo
    echo "To copy a file from the VM:"
    echo "  scp $VM_NAME:/path/on/remote/machine /path/to/local/destination"
    echo
    echo "Note: These commands use the SSH config we've just set up, so you don't need to specify the IP address or username."
}

# Main execution
main() {
    echo "Starting SSH configuration for $VM_NAME"
    echo "---------------------------------------------------"

    get_vm_ip || return 1
    update_ssh_config || return 1
    copy_ssh_key_to_provision_host || return 1
    create_copy_verification_script || return 1
    run_remote_script || return 1

    # Clean up the local temporary script
    rm /tmp/verify_user.sh

    print_summary
    print_ssh_instructions
    
    # Return 0 if no errors, 1 otherwise
    return ${#ERRORS[@]}
}

# Run the main function and exit with its return code
main
exit $?