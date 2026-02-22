# Azure AKS Host Documentation

**File**: `docs/hosts-azure-aks.md`
**Purpose**: Complete operational documentation for Urbalurba Infrastructure on Azure Kubernetes Service (AKS)
**Target Audience**: Infrastructure engineers deploying to Azure AKS
**Last Updated**: September 22, 2024

**Version 4.0** - All components tested and working in production.

## Executive Summary

✅ **Production Ready** - Urbalurba Infrastructure is fully operational on Azure AKS with **zero changes to existing manifests**. The system's context-based architecture provides seamless multi-environment support via kubectl context switching.

### Operational Status:
- ✅ **Complete AKS deployment** - All services running successfully
- ✅ **Storage compatibility** - Azure Disk CSI with transparent aliases
- ✅ **Cost management** - Comprehensive cluster and internet access control
- ✅ **Automated provisioning** - End-to-end deployment scripts
- ✅ **Multi-environment** - Seamless switching between local and cloud contexts
- ✅ **Production tested** - Validated with real workloads and cost analysis

## Deployment Guide

### Quick Start

```bash
# 1. Ensure provision-host is running
docker exec -it provision-host bash
cd /mnt/urbalurbadisk

# 2. Configure Azure settings (see Configuration section below)
cp hosts/azure-aks/azure-aks-config.sh-template hosts/azure-aks/azure-aks-config.sh
nano hosts/azure-aks/azure-aks-config.sh

# 3. Deploy AKS cluster
./hosts/install-azure-aks.sh

# 4. Deploy all services
cd /mnt/urbalurbadisk/provision-host/kubernetes
./provision-kubernetes.sh azure-aks

# 5. Manage cluster
./hosts/azure-aks/manage-aks-cluster.sh
```

## Configuration

**IMPORTANT**: Before running any deployment scripts, you must configure your Azure credentials:

1. **Copy the template file**:
   ```bash
   cd hosts/azure-aks
   cp azure-aks-config.sh-template azure-aks-config.sh
   ```

2. **Edit the configuration file** and replace placeholder values with your actual Azure information:
   ```bash
   nano azure-aks-config.sh
   ```

   Replace these placeholder values:
   - `TENANT_ID="your-tenant-id"` → Your Azure tenant ID
   - `SUBSCRIPTION_ID="your-subscription-id"` → Your Azure subscription ID
   - `your-email@organization.com` → Your actual email address
   - `your-cost-center` → Your organization's cost center

3. **Security Note**: The `azure-aks-config.sh` file contains sensitive information and is automatically excluded from git commits via `.gitignore`.

### Azure Settings

**Example configuration** (`azure-aks-config.sh`):
```bash
TENANT_ID="your-tenant-id"
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="rg-urbalurba-aks-weu"
CLUSTER_NAME="azure-aks"
LOCATION="westeurope"
NODE_COUNT=2
NODE_SIZE="Standard_B2ms"
```

**Prerequisites**:
- Azure subscription with Contributor access
- PIM role activation capability
- Provision-host container running
- **Configuration setup**: Copy template and add your Azure credentials (see Configuration section above)

## Deployment Components

### Available Scripts

1. **Core Deployment Scripts** ✅
   - ✅ `install-azure-aks.sh` - Complete automated deployment orchestrator
   - ✅ `01-azure-aks-create.sh` - AKS cluster creation with PIM handling
   - ✅ `02-azure-aks-setup.sh` - Post-creation configuration and Traefik setup
   - ✅ `03-azure-aks-cleanup.sh` - Comprehensive cluster removal

2. **Management and Support Scripts** ✅
   - ✅ `azure-aks-config.sh` - Centralized configuration management
   - ✅ `check-aks-quota.sh` - Pre-deployment quota validation
   - ✅ `manage-aks-cluster.sh` - Operations management (internet, costs, cluster control)

3. **Infrastructure Configuration** ✅
   - ✅ `manifests-overrides/000-storage-class-azure-alias.yaml` - Storage class compatibility
   - ✅ Full integration with existing Urbalurba manifests and playbooks

### Deployment Workflow ✅

1. ✅ **Prerequisites**: Provision-host container running (`./uis start`)
2. ✅ **Enter container**: `docker exec -it provision-host bash`
3. ✅ **Configure Azure**: Edit `azure-aks-config.sh` with your Azure details
4. ✅ **Deploy cluster**: `./hosts/install-azure-aks.sh` (fully automated)
5. ✅ **Deploy services**: `cd /mnt/urbalurbadisk/provision-host/kubernetes && ./provision-kubernetes.sh azure-aks`
6. ✅ **Manage cluster**: `./hosts/azure-aks/manage-aks-cluster.sh [command]`

## Cluster Management

### Management Commands

```bash
# Check cluster status and costs
./manage-aks-cluster.sh

# Control internet access
./manage-aks-cluster.sh internet on   # Enable external access
./manage-aks-cluster.sh internet off  # Disable (save costs)

# Control cluster state
./manage-aks-cluster.sh cluster stop  # Stop cluster (save ~$120/month)
./manage-aks-cluster.sh cluster start # Restart cluster

# View cost analysis
./manage-aks-cluster.sh costs         # Detailed cost breakdown
```

### Context Switching

```bash
# Switch between environments
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all
kubectl config use-context rancher-desktop  # Local development
kubectl config use-context azure-aks       # Cloud production

# Verify current context
kubectl config current-context
kubectl get nodes
```

### Service Deployment

```bash
# Deploy all Urbalurba services to AKS
cd /mnt/urbalurbadisk/provision-host/kubernetes
./provision-kubernetes.sh azure-aks

# Verify deployment
kubectl get pods --all-namespaces
kubectl get pvc --all-namespaces
kubectl get ingressroute --all-namespaces
```

## Cost Management

### Cost Analysis

**Typical costs for 2x Standard_B2ms configuration**:
- **AKS Control Plane**: $0 (Free tier)
- **Compute (2x Standard_B2ms)**: ~$120/month
- **Storage (Azure managed disks)**: ~$30/month
- **Load Balancer**: ~$20/month (when internet enabled)
- **Total**: **~$170/month active** | **~$30/month when stopped**

**Real cost tracking**: Use `./manage-aks-cluster.sh costs` or check Azure Portal Cost Management

### Cost Optimization

```bash
# Immediate savings
./manage-aks-cluster.sh internet off     # Save ~$20/month (LoadBalancer)
./manage-aks-cluster.sh cluster stop     # Save ~$120/month (compute)

# Restart when needed
./manage-aks-cluster.sh cluster start
./manage-aks-cluster.sh internet on

# Complete cleanup (default behavior)
./hosts/azure-aks/03-azure-aks-cleanup.sh         # Remove everything
# OR keep resource group
./hosts/azure-aks/03-azure-aks-cleanup.sh --keep-rg  # Keep RG, delete cluster only
```

## Architecture Details

### Storage Integration
- **Storage Classes**: `local-path` and `microk8s-hostpath` aliases map to Azure Disk CSI
- **Persistent Volumes**: Automatic provisioning via Azure managed disks
- **Compatibility**: All existing PVC manifests work unchanged

### Networking
- **CNI**: Azure CNI with network policies
- **Ingress**: Traefik with Azure LoadBalancer service
- **Internet Access**: Controllable via service type switching
- **Internal Services**: ClusterIP services for internal communication

### Security
- **RBAC**: Azure AD integration with Kubernetes RBAC
- **PIM**: Privileged Identity Management for Azure access
- **Network Policies**: Azure CNI network policy enforcement
- **Secrets**: Kubernetes secrets management for sensitive data

## Troubleshooting

### Common Issues

**PIM Role Activation**:
```bash
# If you get permission errors:
# 1. Go to https://portal.azure.com PIM
# 2. Activate Contributor role
# 3. Wait 2 minutes
# 4. Retry operation
```

**Context Switching**:
```bash
# If contexts are missing:
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/04-merge-kubeconf.yml
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all
```

**Storage Issues**:
```bash
# If PVCs are pending:
kubectl get storageclass  # Verify aliases exist
kubectl describe pvc <name>  # Check events
```

### Performance Monitoring

```bash
# Check cluster resources
kubectl top nodes
kubectl top pods --all-namespaces

# Monitor costs
./manage-aks-cluster.sh costs

# Check service status
kubectl get pods --all-namespaces
kubectl get pvc --all-namespaces
kubectl get ingressroute --all-namespaces
```

## Production Operations

### Daily Operations
- **Monitor costs**: Check Azure Portal or run cost analysis
- **Control internet access**: Enable only when needed
- **Context switching**: Seamless development ↔ production
- **Service deployment**: Standard Kubernetes workflows

### Backup and Recovery
- **Persistent data**: Stored in Azure managed disks
- **Configuration**: All infrastructure as code in git
- **Cluster recreation**: Fully automated via scripts
- **Service restoration**: Standard manifest redeployment


## Summary

Urbalurba Infrastructure on Azure AKS provides a complete, production-ready Kubernetes platform with:

✅ **Zero-modification deployment** - All existing manifests work unchanged  
✅ **Cost-effective operations** - Granular control over compute and networking costs  
✅ **Multi-environment support** - Seamless local ↔ cloud development workflow  
✅ **Enterprise security** - Azure AD, PIM, network policies, and RBAC  
✅ **Operational simplicity** - Automated deployment, management, and cleanup  

The system is battle-tested and ready for production workloads.

---

*Version 4.0 - Complete operational documentation. All components tested and validated in production deployment.*