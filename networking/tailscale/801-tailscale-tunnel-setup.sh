#!/bin/bash
# filename: 801-tailscale-tunnel-setup.sh
# description: Tailscale tunnel setup - let Ansible do the heavy lifting

set -e

echo "Setting up Tailscale for provision-host container..."

# Basic checks only
if ! command -v kubectl &>/dev/null; then
    echo "ERROR: kubectl not found"
    exit 1
fi

if ! kubectl get nodes &>/dev/null; then
    echo "ERROR: Cannot access Kubernetes"
    exit 1
fi

if ! kubectl get secret --namespace default urbalurba-secrets &>/dev/null; then
    echo "ERROR: Cannot access Kubernetes secrets"
    exit 1
fi

echo "Prerequisites validated - starting Ansible playbook..."

# Hand off to comprehensive Ansible playbook
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/801-setup-network-tailscale-tunnel.yml

echo "Tailscale setup completed successfully"