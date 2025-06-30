#!/bin/bash
# filename: 06-remove-mysql.sh
# description: Remove MySQL from the cluster using Ansible playbook.
# usage: ./06-remove-mysql.sh [target-host]
# If no target host is provided, the script will default to rancher-desktop.

if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

ANSIBLE_DIR="/mnt/urbalurbadisk/ansible"
PLAYBOOK_PATH_REMOVE_MYSQL="$ANSIBLE_DIR/playbooks/040-remove-database-mysql.yml"

TARGET_HOST=${1:-"rancher-desktop"}

cd "$ANSIBLE_DIR" && ansible-playbook "$PLAYBOOK_PATH_REMOVE_MYSQL" -e "target_host=$TARGET_HOST" 