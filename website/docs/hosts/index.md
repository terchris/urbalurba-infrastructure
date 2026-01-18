# Hosts Documentation

**File**: `docs/hosts-readme.md`
**Purpose**: Comprehensive guide to Urbalurba infrastructure host types and deployment strategies
**Target Audience**: Infrastructure engineers and developers deploying Urbalurba
**Last Updated**: September 22, 2024

## 📋 Overview

The Urbalurba infrastructure is designed to be highly flexible and can be deployed across various environments and hardware configurations. This document provides a standardized overview of all supported host types and their deployment strategies.

### **Hardware Support**
- **Raspberry Pi (ARM architecture)** - Edge computing and development
- **Standard x86/AMD64 servers** - On-premises and bare metal
- **Cloud virtual machines** - Azure, AWS, GCP
- **Local virtualization** - Multipass, Rancher Desktop


The software and programs in the system work consistently across all host types.

## 🚀 Host Provisioning Strategy

Ubuntu-based hosts (Azure MicroK8s, Multipass, Raspberry Pi) use **cloud-init** for automated provisioning, while managed services (Azure AKS, Rancher Desktop) use their own provisioning mechanisms. For detailed information about cloud-init configuration and templates, see [hosts-cloud-init-readme.md](./hosts-cloud-init-readme.md).

## 🏗️ Host Types

The system supports several types of host configurations:

### 1. Rancher Kubernetes Hosts
**Documentation**: [hosts-rancher-kubernetes.md](./hosts-rancher-kubernetes.md) | **Scripts**: `hosts/rancher-kubernetes/`
- Deploys Rancher-managed Kubernetes clusters
- Default local development environment
- Supports multi-node clusters
- Includes Rancher-specific configurations
- Provides cluster management interface
- No cloud-init required (uses Rancher Desktop)

### 2. Azure AKS Hosts
**Documentation**: [hosts-azure-aks.md](./hosts-azure-aks.md) | **Scripts**: `hosts/azure-aks/`
- Managed Kubernetes service on Azure
- Production-ready with Azure integration
- Cost management and scaling features
- No cloud-init required (managed service)

### 3. Azure MicroK8s Hosts
**Documentation**: [hosts-azure-microk8s.md](./hosts-azure-microk8s.md) | **Scripts**: `hosts/azure-microk8s/`
- Deploys MicroK8s on Azure VMs
- Uses Azure-specific cloud-init configuration ✅
- Supports automatic scaling
- Integrates with Azure services
- Includes Tailscale VPN for secure access

### 4. Raspberry Pi MicroK8s Hosts
**Documentation**: [hosts-raspberry-microk8s.md](./hosts-raspberry-microk8s.md) | **Scripts**: `hosts/raspberry-microk8s/`
- Uses Raspberry Pi-specific cloud-init configuration ✅
- Optimized for ARM architecture
- Resource-efficient configuration
- Edge computing support
- Low-power operation
- Includes WiFi configuration

### 5. Multipass MicroK8s Hosts (LEGACY)
**Documentation**: [hosts-multipass-microk8s.md](./hosts-multipass-microk8s.md) | **Scripts**: `hosts/multipass-microk8s/`
- **REPLACED BY RANCHER DESKTOP** - Kept for historical reference
- Deploys MicroK8s using Multipass
- Uses Multipass-specific cloud-init configuration ✅
- Previously used for local development
- Lightweight virtualization


## 🚀 Host Setup Commands

Each host type provides Kubernetes cluster setup commands. These are run **from the provision-host container** to prepare different types of Kubernetes clusters.

To set up clusters (and machines that run clusters) log in to `provision-host` container. Then change working directory to 

```bash 
cd /mnt/urbalurbadisk/hosts
```


### To set up Azure AKS

Read documentation: [hosts-azure-aks.md](./hosts-azure-aks.md)

```bash
./install-azure-aks.sh
```

### To set up a VM in Azure and then prepare microk8s kubernetes on it

Read documentation: [hosts-azure-microk8s.md](./hosts-azure-microk8s.md)

```bash
./install-azure-microk8s-v2.sh
```

### To set up Ubuntu on a Raspberry Pi and then prepare microk8s kubernetes on it

Raspberry Pi (manual setup required)

See documentation: [hosts-raspberry-microk8s.md](./hosts-raspberry-microk8s.md)

### Multipass MicroK8s (LEGACY - replaced by Rancher Desktop)

See documentation: [hosts-multipass-microk8s.md](./hosts-multipass-microk8s.md)




## **After Cluster Setup: Deploy All Services**

The benefit of Kubernetes is that once you have a cluster running, the application deployment process is identical across all cluster types.

Once your Kubernetes cluster is ready, deploy all Urbalurba services:

```bash
# From inside provision-host container:
cd /mnt/urbalurbadisk/provision-host/kubernetes
./provision-kubernetes.sh <cluster-context>

# Examples:
./provision-kubernetes.sh rancher-desktop    # For Rancher Desktop
./provision-kubernetes.sh azure-aks          # For Azure AKS
./provision-kubernetes.sh multipass-microk8s # For Multipass (legacy)
```

This script automatically installs all services in the correct order (core systems, databases, AI services, monitoring, etc.).

## 🔄 Multi-Cluster Management

When you set up multiple Kubernetes clusters, Urbalurba automatically merges their kubeconfig files for seamless context switching:

### **Automatic Kubeconfig Merging**

Each time a new cluster is added, the system runs:
```bash
# From inside provision-host container:
ansible-playbook ansible/playbooks/04-merge-kubeconf.yml
```

This merges all `*-kubeconfig` files from `/mnt/urbalurbadisk/kubeconfig/` into a single file: `/mnt/urbalurbadisk/kubeconfig/kubeconf-all`

### **Context Switching Between Clusters**

Once merged, you can easily switch between different Kubernetes environments:

```bash
# Set the merged kubeconfig
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all

# Switch between clusters
kubectl config use-context rancher-desktop  # Local development
kubectl config use-context azure-aks       # Cloud production
kubectl config use-context azure-microk8s  # Azure VM
kubectl config use-context multipass-microk8s # Legacy multipass

# Check current context
kubectl config current-context

# List all available contexts
kubectl config get-contexts
```

### **Benefits of Multi-Cluster Setup**
- **Development → Production workflow** - Test locally, deploy to cloud
- **Cross-cloud redundancy** - Multiple cloud providers
- **Environment isolation** - Separate dev/staging/prod clusters
- **Unified management** - One kubectl interface for all clusters

## 📚 Detailed Documentation

For comprehensive setup guides, troubleshooting, and configuration details:

- **[hosts-cloud-init-readme.md](./hosts-cloud-init-readme.md)** - Cloud-init configuration and templates
- **[hosts-azure-microk8s.md](./hosts-azure-microk8s.md)** - Azure MicroK8s deployment guide
- **[hosts-azure-aks.md](./hosts-azure-aks.md)** - Azure AKS deployment guide
- **[hosts-multipass-microk8s.md](./hosts-multipass-microk8s.md)** - Multipass MicroK8s deployment guide
- **[hosts-raspberry-microk8s.md](./hosts-raspberry-microk8s.md)** - Raspberry Pi MicroK8s deployment guide
- **[hosts-rancher-kubernetes.md](./hosts-rancher-kubernetes.md)** - Rancher Kubernetes deployment guide

