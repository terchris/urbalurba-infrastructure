# Hosts Documentation

## Overview

The Urbalurba infrastructure is designed to be highly flexible and can be deployed across various environments and hardware configurations:

- **Hardware Support**
  - Raspberry Pi (ARM architecture)
  - Standard x86/AMD64 servers
  - Cloud virtual machines
  - Bare metal servers

- **Deployment Options**
  - Single machine deployment
  - Multi-node clusters
  - Multi-datacenter deployments
  - Cross-cloud provider deployments

## Host Provisioning

All hosts in the Urbalurba infrastructure are provisioned using cloud-init. For detailed information about cloud-init configuration and templates, please refer to [cloud-init-readme.md](./cloud-init-readme.md).

## Host Types

The system supports several types of host configurations:

### 1. Azure MicroK8s Hosts
Located in `hosts/azure-microk8s/`:
- Deploys MicroK8s on Azure VMs
- Uses Azure-specific cloud-init configuration
- Supports automatic scaling
- Integrates with Azure services
- Includes Tailscale VPN for secure access

### 2. Rancher Kubernetes Hosts
Located in `hosts/rancher-kubernetes/`:
- Deploys Rancher-managed Kubernetes clusters
- Supports multi-node clusters
- Includes Rancher-specific configurations
- Provides cluster management interface

### 3. Multipass MicroK8s Hosts
Located in `hosts/multipass-microk8s/`:
- Deploys MicroK8s using Multipass
- Uses Multipass-specific cloud-init configuration
- Ideal for local development
- Lightweight virtualization
- Quick setup and teardown

### 4. Raspberry Pi MicroK8s Hosts
Located in `hosts/raspberry-microk8s/`:
- Uses Raspberry Pi-specific cloud-init configuration
- Optimized for ARM architecture
- Resource-efficient configuration
- Edge computing support
- Low-power operation
- Includes WiFi configuration

## Installation Scripts

The system provides installation scripts for each host type:

### 1. Azure MicroK8s Installation
`install-azure-microk8s-v2.sh`:
- Creates Azure VM with MicroK8s
- Uses cloud-init for initial configuration
- Sets up Ansible inventory
- Configures Kubernetes access
- Integrates with Tailscale VPN

### 2. Rancher Kubernetes Installation
`install-rancher-kubernetes.sh`:
- Deploys Rancher server
- Creates Kubernetes clusters
- Configures cluster access
- Sets up monitoring

### 3. Multipass MicroK8s Installation
`install-multipass-microk8s.sh`:
- Creates Multipass VMs
- Uses cloud-init for configuration
- Installs MicroK8s
- Configures networking
- Sets up local access

## Host Provisioning Process

The host provisioning follows a standardized process:

1. **Initial Setup**
   - Hardware/VM provisioning
   - Cloud-init configuration (see [cloud-init-readme.md](./cloud-init-readme.md))
   - Operating system installation
   - Network configuration
   - Security hardening

2. **Kubernetes Installation**
   - MicroK8s or Rancher installation
   - Cluster configuration
   - Network plugin setup
   - Storage configuration

3. **Ansible Integration**
   - Inventory registration
   - SSH key configuration
   - Access control setup
   - Service deployment

4. **Service Deployment**
   - Core services installation
   - Monitoring setup
   - Logging configuration
   - Backup configuration

## Configuration Management

Each host type has specific configuration files:

### 1. Azure Configuration
- VM size and type
- Network settings
- Storage configuration
- Security groups
- Cloud-init configuration (see [cloud-init-readme.md](./cloud-init-readme.md))

### 2. Rancher Configuration
- Cluster settings
- Node configuration
- Network policies
- Storage classes

### 3. Multipass Configuration
- VM specifications
- Network setup
- Storage allocation
- Resource limits
- Cloud-init configuration (see [cloud-init-readme.md](./cloud-init-readme.md))

### 4. Raspberry Pi Configuration
- Hardware-specific settings
- Resource optimization
- Network configuration
- Storage management
- WiFi configuration
- Cloud-init configuration (see [cloud-init-readme.md](./cloud-init-readme.md))

## Security Considerations

1. **Access Control**
   - SSH key management
   - User permissions
   - Service accounts
   - RBAC configuration
   - Tailscale VPN integration

2. **Network Security**
   - Firewall rules
   - Network policies
   - VPN configuration
   - TLS certificates

3. **Data Protection**
   - Encryption at rest
   - Secure backups
   - Secret management
   - Audit logging

## Maintenance

1. **Regular Updates**
   - Security patches
   - Kubernetes updates
   - System upgrades
   - Configuration updates

2. **Monitoring**
   - Resource usage
   - Performance metrics
   - Health checks
   - Alert configuration

3. **Backup and Recovery**
   - Regular backups
   - Disaster recovery
   - Configuration backup
   - State management

## Best Practices

1. **Host Configuration**
   - Use standardized configurations
   - Document custom settings
   - Version control configurations
   - Regular security audits

2. **Resource Management**
   - Monitor resource usage
   - Plan for scaling
   - Optimize performance
   - Regular cleanup

3. **Security**
   - Regular updates
   - Security scanning
   - Access control
   - Audit logging

