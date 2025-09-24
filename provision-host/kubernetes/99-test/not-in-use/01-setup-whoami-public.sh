#!/bin/bash
# filename: 01-setup-whoami-public.sh
# description: Setup whoami-public test service using existing Ansible playbook. Simple first service for testing.
# usage: ./01-setup-whoami-public.sh [target-host]
# example: ./01-setup-whoami-public.sh rancher-desktop
# If no target host is provided, the script will default to rancher-desktop.

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# Variables
ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH="$ANSIBLE_DIR/playbooks/025-setup-whoami-testpod.yml"
TARGET_HOST=${1:-"rancher-desktop"}

# Function to run Ansible playbook
run_playbook() {
    echo "$(basename "$0"): Running Ansible playbook for whoami setup..."
    cd "$ANSIBLE_DIR" && ansible-playbook "$PLAYBOOK_PATH" -e "kube_context=$TARGET_HOST"
    local result=$?
    if [ $result -ne 0 ]; then
        echo "❌ Playbook failed with exit code $result"
        return 1
    else
        echo "✅ whoami deployment complete"
        echo "🎉 Open your browser to: http://whoami.localhost"
        return 0
    fi
}

# Main execution
main() {
    echo "🚀 Deploying whoami test service..."

    run_playbook

    return $?
}

# Run the main function and exit with its return code
main
exit $?