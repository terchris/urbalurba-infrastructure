# Rancher Kubernetes Host Documentation

**File**: `doc/hosts-rancher-kubernetes.md`
**Purpose**: Deployment guide for Rancher Desktop Kubernetes cluster setup
**Target Audience**: Developers setting up local Kubernetes development environment
**Last Updated**: September 22, 2024

## 📋 Overview

Rancher Desktop is the **default Kubernetes environment** for Urbalurba infrastructure. When you run `./install-rancher.sh`, it automatically starts both the provision-host container and a Rancher Desktop Kubernetes cluster, providing a complete local development environment.

Unlike other host types, Rancher Desktop comes with Kubernetes (k3s) pre-installed, so the setup process focuses on configuration and integration with the Urbalurba infrastructure.

### **Default Setup**
- **Automatic provisioning** - Started automatically with `./install-rancher.sh`
- **Provision-host integration** - Container and cluster work together seamlessly
- **Default context** - All scripts use `rancher-desktop` context by default
- **Zero configuration** - Works out of the box for development

### **Key Features**
- **Pre-installed Kubernetes** - No manual cluster setup required
- **Local development** - Ideal for testing and development workflows
- **Docker integration** - Built-in container runtime
- **GUI management** - Easy cluster management through Rancher Desktop UI
- **No cloud-init required** - Uses Rancher Desktop's built-in provisioning

## 🚀 Quick Start

The Rancher Desktop cluster is automatically set up when you start Urbalurba:

```bash
# This single command sets up everything:
# 1. Provision-host container
# 2. Rancher Desktop Kubernetes cluster
# 3. All Urbalurba services
./install-rancher.sh
```

**That's it!** The provision-host container and Rancher cluster start together, and all services deploy automatically.

## 📖 Prerequisites

1. **Rancher Desktop Installation**
   - Download and install Rancher Desktop from [rancherdesktop.io](https://rancherdesktop.io)
   - Start Rancher Desktop and enable Kubernetes
   - The `./install-rancher.sh` script will automatically configure everything else

2. **What's Included Automatically**
   - kubectl (included with Rancher Desktop)
   - Helm (for package management)
   - Docker (included with Rancher Desktop)
   - Provision-host container with all tools
   - Kubernetes cluster configuration
   - All Urbalurba services

## 🔧 Installation Process

The installation script (`install-rancher-kubernetes.sh`) **runs automatically inside the provision-host container** when you execute `./install-rancher.sh`. This script performs these steps:

1. **Verify Kubernetes Cluster** - Ensures Rancher Desktop Kubernetes is running
2. **Apply Secrets** - Configures necessary Kubernetes secrets
3. **Setup Storage** - Configures local storage classes
4. **Configure Networking** - Sets up ingress and networking components

> ℹ️ **Automatic Execution**: This script is called automatically by the main installation process. You typically don't need to run it manually unless troubleshooting specific issues.


## 🏗️ Architecture

### **Cluster Configuration**
- **Single-node cluster** - All components run on local machine
- **Storage** - Local path provisioner for persistent volumes
- **Networking** - Traefik ingress controller with localhost access
- **Container Runtime** - Docker (default) or containerd
- **Browser Access** - All services accessible via `http://localhost` URLs

### **Integration Points**
- **Local development** - Seamless integration with local IDE and tools
- **Port forwarding** - Easy access to services via localhost
- **Volume mounts** - Direct access to local filesystem
- **Resource management** - Configurable CPU and memory limits

## 🛠️ Configuration

### **Rancher Desktop Settings**
```yaml
# Recommended Rancher Desktop configuration
kubernetes:
  enabled: true
  version: "v1.28.x"  # Latest stable

container:
  runtime: docker  # or containerd

resources:
  memory: 8GB      # Adjust based on your system
  cpus: 4          # Adjust based on your system
```

### **Storage Configuration**
- **Default storage class** - `local-path` (compatible with Urbalurba manifests)
- **Persistent volumes** - Stored in local directories
- **Volume size** - Limited by available disk space


### **Service Access**

**Browser Access (Primary Method)**
All Urbalurba services are automatically configured for browser access:

```bash
# Services are accessible directly in your browser at:
http://<service>.localhost

# Examples of common services:
http://whoami.localhost          # Whoami test service
http://grafana.localhost         # Grafana monitoring
http://pgadmin.localhost         # PostgreSQL admin
http://openwebui.localhost       # OpenWebUI AI interface
```


### **Complete Reset (Factory Reset)**

If you need to completely reset the Urbalurba infrastructure, you can perform a factory reset in Rancher Desktop:

⚠️ **Warning**: All data, configurations, and certificates will be permanently lost. If you have multiple clusters configured, the kubeconfig file that provides access to them will be deleted. Use `kubeconf-copy2local.sh` to backup this file before proceeding if you have multiple clusters.

1. **Open Rancher Desktop application**
2. **Go to Troubleshooting → Factory Reset**
3. **Confirm the reset** - This will delete all data and configurations
4. **Restart Rancher Desktop** and enable Kubernetes
5. **Redeploy** by running `./install-rancher.sh`

**Warning**: Factory reset will permanently delete all deployed services, persistent volumes, and configurations. Make sure to backup any important data before proceeding.

## 📈 Performance Optimization

### **Resource Allocation**
- **Memory** - Allocate at least 8GB for full Urbalurba stack
- **CPU** - 4+ cores recommended for good performance
- **Disk** - Ensure sufficient space for persistent volumes

### **Development Workflow**
- **Hot reloading** - Use volume mounts for development
- **Service mesh** - Optional for advanced testing scenarios
- **Monitoring** - Use kubectl top or Rancher Desktop metrics

## 🔗 Integration with Urbalurba

### **Service Deployment**
```bash
# Deploy all Urbalurba services
cd /mnt/urbalurbadisk/provision-host/kubernetes
./provision-kubernetes.sh rancher-desktop

# Deploy specific services
kubectl apply -f manifests/<service-manifest>.yaml
```

### **Context Switching**
```bash
# Switch between different Kubernetes contexts
kubectl config use-context rancher-desktop  # Local development
kubectl config use-context azure-aks       # Cloud production

# Verify current context
kubectl config current-context
```

## 📖 Related Documentation

- **[hosts-readme.md](./hosts-readme.md)** - Main hosts overview
- **[CLAUDE.md](../CLAUDE.md)** - Repository instructions
- **[install-rancher-desktop-mac.md](./install-rancher-desktop-mac.md)** - Rancher Desktop installation guide
- **[rules-git-workflow.md](./rules-git-workflow.md)** - Development workflow standards

## 📝 Notes

- **No cloud-init required** - Rancher Desktop handles all provisioning
- **GUI management** - Use Rancher Desktop application for cluster management
- **Local only** - This setup is for development and testing, not production
- **Resource limits** - Performance depends on your local machine specifications