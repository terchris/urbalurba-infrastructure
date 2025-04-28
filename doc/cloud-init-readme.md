# Cloud-Init Setup Guide

This guide explains how to create cloud-init configuration files for VM provisioning. All VMs are created using cloud-init YAML files, which configure an "ansible" user with SSH key authentication.

## What Cloud-Init Does

The cloud-init configurations in this project perform several important functions:

- **Configure MicroK8s**: Installs and configures a single-node Kubernetes cluster using MicroK8s
- **Enable key Kubernetes features**: Depending on the template, enables features like DNS, dashboard, Helm, and storage
- **Configure system settings**: Sets hostname, timezone, and other essential system configurations
- **Apply security settings**: Hardens SSH configuration and sets appropriate permissions
- **Set up an ansible user**: Creates a user with sudo privileges that can access the VM via SSH
- **Connect to Tailscale network**: Installs Tailscale and connects the VM to your private mesh network

The most powerful aspect of this approach is that it ensures a consistent Kubernetes installation (MicroK8s) that works identically across all environments:

- Works the same across all cloud providers (AWS, Azure, GCP, OCI, etc.)
- Functions consistently on both x86 and ARM-based CPUs
- Provides identical functionality whether hosted in the cloud or on a local VM
- Runs the same way in virtual machines and on bare metal hardware
- Even runs on Raspberry Pi devices

This consistency allows for seamless development, testing, and deployment across different environments without worrying about infrastructure differences.

## Prerequisites

Before creating cloud-init files, you need to set up the SSH keys for the ansible user:

1. Follow the instructions in [secrets/create-secrets.md](../secrets/create-secrets.md) to create the necessary SSH keys.
2. Make sure the public key file `id_rsa_ansible.pub` exists in the `secrets` directory.

You can verify the public key with:

```bash
cat secrets/id_rsa_ansible.pub
```

## Creating Cloud-Init Files

The script `create-cloud-init.sh` generates cloud-init YAML files from templates. It replaces placeholder variables (prefixed with `URB_`) with actual values, including the SSH public key and secrets from the Kubernetes secrets file.

### Usage

1. Make sure you are in the `cloud-init` directory:

```bash
cd cloud-init
```

2. If a cloud-init file already exists with the target name, you must delete it first:

```bash
rm <template-name>-cloud-init.yml  # For example: rm azure-cloud-init.yml
```

3. Run the script with the required parameters:

```bash
./create-cloud-init.sh <hostname> <template-name>
```

Example:
```bash
./create-cloud-init.sh azure-microk8s azure
```

This command will:
- Use `azure-cloud-init-template.yml` as the template
- Create `azure-cloud-init.yml` as the output file
- Set the hostname to "azure-microk8s"
- Include the SSH public key from `secrets/id_rsa_ansible.pub`
- Include various secrets from `topsecret/kubernetes/kubernetes-secrets.yml`

### Verifying the Generated File

You can verify that the cloud-init file has been created correctly with:

```bash
cat <template-name>-cloud-init.yml  # For example: cat azure-cloud-init.yml
```

The YAML file should contain your SSH public key in the `ssh_authorized_keys` section, along with various other configurations for the VM.

### Available Templates

The script works with any template file that follows the naming convention `<template-name>-cloud-init-template.yml`. Current templates include:

- `azure-cloud-init-template.yml` - For Azure VMs
- `gcp-cloud-init-template.yml` - For Google Cloud Platform VMs
- `multipass-cloud-init-template.yml` - For Multipass VMs
- `oci-cloud-init-template.yml` - For Oracle Cloud Infrastructure VMs  
- `provision-cloud-init-template.yml` - For provisioning hosts
- `raspberry-cloud-init-template.yml` - For Raspberry Pi devices

### How It Works

The script:
1. Reads variables from the Kubernetes secrets file
2. Reads the SSH public key
3. Replaces placeholders in the template with actual values
4. Creates a new cloud-init file with the `-template` suffix removed

The template files contain variables like `URB_HOSTNAME_VARIABLE` and `URB_SSH_AUTHORIZED_KEY_VARIABLE` that get replaced with actual values.

### Key Components in Cloud-Init Templates

The cloud-init templates typically include the following sections:

1. **User Configuration**:
   ```yaml
   users:
     - name: ansible
       groups: [sudo]
       shell: /bin/bash
       sudo: ['ALL=(ALL) NOPASSWD:ALL']
       ssh_authorized_keys:
         - *ssh_key
   ```

2. **MicroK8s Setup**:
   ```yaml
   # MicroK8s installation and configuration
   - 'microk8s status --wait-ready'
   - 'microk8s enable dns'
   - 'microk8s enable dashboard'
   - 'microk8s enable helm'
   - 'microk8s enable hostpath-storage'
   ```

3. **Tailscale Configuration**:
   ```yaml
   # Tailscale installation and setup
   - ['sh', '-c', 'curl -fsSL https://tailscale.com/install.sh | sh']
   - ['tailscale', 'up', '--authkey', *tailscale_key, '--hostname', *hostname]
   ```

These configurations allow for seamless deployment of infrastructure with consistent configurations across different cloud providers.

### Important Notes about Tailscale

The Tailscale authentication key used in the cloud-init files has an expiration date. If a VM fails to connect to the Tailscale network, the key may have expired and will need to be renewed.

To set up or renew Tailscale keys, refer to the documentation in `networking/vpn-tailscale-howto.md`. This guide provides detailed instructions on:
- Generating new authentication keys
- Setting appropriate expiration periods
- Managing node access and permissions
- Troubleshooting connection issues

When a key expires, you'll need to:
1. Generate a new key following the instructions in the guide
2. Update the key in your Kubernetes secrets file
3. Regenerate the cloud-init file with the updated key