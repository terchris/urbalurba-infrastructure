# Cloud-Init Documentation

**File**: `docs/hosts-cloud-init-readme.md`
**Purpose**: Cloud-init configuration and templates for automated host provisioning
**Target Audience**: Infrastructure engineers working with cloud-init deployments
**Last Updated**: September 22, 2024

## 📋 Overview

Cloud-init is a critical component for automated host provisioning across different environments in the Urbalurba infrastructure. It provides a standardized way to configure hosts during their initial boot process, ensuring consistent setup across various deployment scenarios. In addition to basic system configuration, cloud-init also handles:

- Connection to the Tailscale network for secure remote management
- Standardized Kubernetes (MicroK8s) installation and configuration
- Consistent security hardening across all environments

This ensures that all hosts, regardless of their deployment environment, are:
- Securely accessible for management
- Properly configured for their intended role
- Integrated into the infrastructure's network
- Ready for service deployment

## 🔑 Prerequisites

**IMPORTANT**: Before using cloud-init templates, you must set up SSH keys for Ansible authentication:

👉 **[SSH Key Setup Guide](./secrets.md)** - Create the required SSH keys for cloud-init deployments

The SSH keys created in this prerequisite step are essential for:
- Ansible automation and host management
- Secure SSH access to provisioned hosts
- Cloud-init user authentication setup

## Cloud-Init Templates

Located in `cloud-init/`:
- `azure-cloud-init-template.yml` - Azure VM configuration
- `gcp-cloud-init-template.yml` - Google Cloud Platform configuration
- `oci-cloud-init-template.yml` - Oracle Cloud Infrastructure configuration
- `multipass-cloud-init-template.yml` - Multipass VM configuration
- `raspberry-cloud-init-template.yml` - Raspberry Pi configuration
- `provision-cloud-init-template.yml` - Generic provisioning configuration

## Cloud-Init Generation

The `create-cloud-init.sh` script generates cloud-init configurations by:
1. Reading template files
2. Extracting secrets from Kubernetes secrets file
3. Replacing placeholders with actual values
4. Generating environment-specific cloud-init files

### Usage
```bash
./create-cloud-init.sh <hostname> <template-name>
```

Where:
- `hostname`: The name of the host to be configured
- `template-name`: The name of the cloud-init template to use (e.g., azure, gcp, multipass)

## Common Cloud-Init Features

All cloud-init configurations include:

### 1. System Configuration
- Hostname setting
- Timezone configuration
- System updates
- Package management

### 2. User Management
- Ansible user creation
- SSH key configuration
- Sudo privileges
- User groups

### 3. Security Setup
- SSH hardening
- Firewall configuration
- Security updates
- Access control

### 4. Kubernetes Setup
- MicroK8s installation
- Cluster configuration
- Network plugin setup
- Storage configuration

### 5. Network Configuration
- Tailscale VPN setup
- Network interface configuration
- DNS settings
- Proxy configuration (if needed)

### 6. Environment Setup
- Path configuration
- Environment variables
- System limits
- Resource allocation

## Template Structure

Each cloud-init template follows a standard structure:

```yaml
#cloud-config
users:
  - name: ansible
    # User configuration

write_files:
  # System configuration files

package_update: true
package_upgrade: true
packages:
  # Required packages

runcmd:
  # Post-installation commands
```
