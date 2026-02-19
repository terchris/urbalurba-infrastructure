#!/bin/bash
# File: provision-host-rancher/prepare-rancher-environment.sh
# Description: Prepares the Rancher Desktop environment for Kubernetes provisioning

set -e

echo "Setting up Rancher Desktop environment..."

#TODO: this is not needed as we can copied the kubeconfig from the host to the container in the entrypoint script
# Create the kubeconfig directory
#mkdir -p /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig

# Copy the Rancher Desktop kubeconfig to the expected location
echo "Copying Rancher Desktop kubeconfig so that it can be merged with the other kubeconfigs..."
# The line below seems crazy. But what we do is to copy the kubeconfig that came from the host to the place where we normally woul put kubekonf files that are going to be merged
cp /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/rancher-desktop-kubeconf

# Create Ansible inventory for Rancher Desktop
echo "Setting up Ansible inventory for Rancher Desktop..."
mkdir -p /mnt/urbalurbadisk/ansible/inventory
cat > /mnt/urbalurbadisk/ansible/inventory/rancher-desktop.yml << EOF
---
all:
  children:
    rancher-desktop:
      hosts:
        localhost:
          ansible_connection: local
EOF

# Run the existing merge playbook
echo "Running kubeconfig merge playbook..."
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/04-merge-kubeconf.yml

echo "Environment setup complete."

# Test the configuration
echo "Testing Kubernetes configuration..."
KUBECONFIG=/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all kubectl get nodes
if [ $? -eq 0 ]; then
    echo "Kubernetes configuration test successful!"
else
    echo "Kubernetes configuration test failed!"
    exit 1
fi

echo "Testing Ansible inventory..."
cd /mnt/urbalurbadisk/ansible
ansible -i inventory/rancher-desktop.yml rancher-desktop -m ping
if [ $? -eq 0 ]; then
    echo "Ansible inventory test successful!"
else
    echo "Ansible inventory test failed!"
    exit 1
fi

echo "Rancher Desktop environment is ready for Kubernetes provisioning." 