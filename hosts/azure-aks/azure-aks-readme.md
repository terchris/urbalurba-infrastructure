# Azure AKS Implementation Guide

**Version 3.0** - Updated with practical testing results and working implementation. This guide now includes validated scripts and proven deployment workflows for Urbalurba Infrastructure on Azure Kubernetes Service (AKS).

## Executive Summary

✅ **Implementation Complete and Tested** - Urbalurba Infrastructure successfully runs on Azure AKS with **zero changes to existing files**. Through practical testing, we've validated that the system's context-based architecture works perfectly with AKS via kubectl context switching.

### Key Achievements:
- **Working AKS deployment** with all core services (nginx, whoami, Traefik)
- **Validated storage abstraction** using Azure Disk CSI with storage class aliases
- **Internet access control** via automated toggle script
- **Cost-effective setup** with proper quota validation
- **Seamless context switching** between local Rancher Desktop and cloud AKS

## Key Findings from Codebase Analysis

### No Changes Required to Existing Files ✅

1. **Context-Based Architecture**
   - All scripts use `kubectl` with context switching
   - Ansible playbook `04-merge-kubeconf.yml` already handles multiple clusters
   - Services deploy identically regardless of cluster context

2. **Storage Abstraction Works Perfectly**
   - System uses storage class aliases (e.g., `microk8s-hostpath`)
   - Only need Azure-specific alias pointing to Azure Disk provisioner
   - Manifests reference class names, not provisioners

3. **Traefik Installation Required** ⚠️
   - AKS doesn't include Traefik (unlike Rancher Desktop)
   - Must install Traefik via Helm during setup
   - IngressRoutes work identically once Traefik is installed
   - External LoadBalancer provides internet access

4. **Existing Azure Patterns**
   - `hosts/azure-microk8s/` provides excellent PIM activation flow
   - Resource group management patterns ready to reuse
   - Azure CLI integration already proven

### Implemented Files ✅

1. **Working Scripts** (Tested and Validated)
   - `azure-aks-config.sh` - Azure configuration variables
   - `check-aks-quota.sh` - Pre-deployment quota validation
   - `toggle-internet-access.sh` - Control internet accessibility
   - `steps-plan.md` - Complete manual deployment guide
   - `manifests-overrides/000-storage-class-azure-alias.yaml` - Storage compatibility

2. **Validated Integration**
   - Existing manifests work unchanged ✅
   - Kubeconfig merging via ansible playbook ✅ 
   - Context switching between rancher-desktop and azure-aks ✅
   - Storage provisioning via Azure Disk CSI ✅

## Implementation Architecture

### File Structure (New Files Only)

```
hosts/azure-aks/
├── azure-aks-config.sh                 # ✅ Azure subscription and cluster configuration
├── azure-aks-readme.md                 # ✅ This implementation guide
├── check-aks-quota.sh                  # ✅ Validates quota before cluster creation
├── steps-plan.md                       # ✅ Complete manual deployment walkthrough
├── toggle-internet-access.sh           # ✅ Control cluster internet accessibility  
└── manifests-overrides/
    └── 000-storage-class-azure-alias.yaml  # Maps local-path to Azure Disk
```

### Validated Workflow ✅

1. **Prerequisites**: Run `install-rancher.sh` (creates provision-host with all tools)
2. **Enter container**: `docker exec -it provision-host bash`
3. **Manual deployment**: Follow `steps-plan.md` for complete walkthrough
4. **Azure login**: Device code authentication with PIM activation
5. **Quota check**: Run `./check-aks-quota.sh` before cluster creation
6. **Cluster creation**: Standard AKS cluster with Azure CNI
7. **Traefik installation**: Helm install with LoadBalancer configuration
8. **Kubeconfig merge**: Ansible playbook combines rancher-desktop + azure-aks contexts
9. **Storage setup**: Apply storage class alias for compatibility
10. **Service deployment**: Existing manifests work without changes
11. **Internet control**: Use `./toggle-internet-access.sh on/off` to manage access

## Concrete Implementation Plan

### Phase 1: Core Implementation ✅ COMPLETED

**Configuration and Authentication**
- ✅ Created `azure-aks-config.sh` with Azure subscription details
- ✅ Validated PIM activation workflow manually
- ✅ Established Azure resource naming conventions

**Cluster Management**
- ✅ Manual AKS cluster creation tested and documented
- ✅ Resource group creation with proper tagging
- ✅ AKS cluster with Azure CNI networking
- ✅ Kubeconfig retrieval and context setup
- ✅ Traefik installation via Helm

**Integration and Control**
- ✅ Created storage class alias manifest (`000-storage-class-azure-alias.yaml`)
- ✅ Kubeconfig merging via ansible playbook
- ✅ Internet access control script
- ✅ Quota validation script

### Phase 2: Testing and Validation ✅ COMPLETED

**Basic Validation**
- ✅ Applied storage class alias successfully
- ✅ Tested basic pod creation with Azure Disk CSI
- ✅ Verified kubectl access from provision-host container
- ✅ Validated internet accessibility via external IP (4.245.72.239)

**Service Testing**
- ✅ Deployed nginx service with PVC storage
- ✅ Deployed whoami test service
- ✅ Validated Traefik IngressRoute functionality
- ✅ Verified Azure Disk storage provisioning
- ✅ Tested seamless context switching between rancher-desktop and azure-aks

### Phase 3: Full Deployment (Ready for Implementation)

**Core Services**
- 🔄 Deploy all database services (PostgreSQL, Redis, MongoDB) - *Ready to test*
- 🔄 Deploy authentication (Authentik) - *Ready to test*
- 🔄 Deploy observability stack (Grafana, Prometheus) - *Ready to test*

**AI Services**
- 🔄 Deploy OpenWebUI - *Ready to test*
- 🔄 Test AI model connectivity - *Ready to test*
- 🔄 Verify authentication integration - *Ready to test*

**Documentation and Optimization**
- ✅ Documented AKS-specific requirements (Traefik installation)
- ✅ Created comprehensive troubleshooting guide (`steps-plan.md`)
- ✅ Validated resource allocation (2x Standard_B2ms nodes)
- ✅ Implemented cost monitoring via internet access control

## User Workflow

### Initial Setup (on host machine)

```bash
# Start by creating the provision-host container
./install-rancher.sh
```

### Inside Provision-Host Container

```bash
# Enter the provision-host container
docker exec -it provision-host bash

# Navigate to the working directory
cd /mnt/urbalurbadisk

# For Azure AKS deployment - follow the complete manual guide
less hosts/azure-aks/steps-plan.md

# Check quota before starting
hosts/azure-aks/check-aks-quota.sh

# Control internet access
hosts/azure-aks/toggle-internet-access.sh        # Show status
hosts/azure-aks/toggle-internet-access.sh off    # Disable internet
hosts/azure-aks/toggle-internet-access.sh on     # Enable internet

# Switch between environments (after kubeconfig merge)
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all
kubectl config use-context rancher-desktop  # Local
kubectl config use-context azure-aks       # Azure

# Deploy services (works on both contexts)
cd provision-host/kubernetes
./provision-kubernetes.sh

# Manual cluster cleanup (save costs)
# Follow cleanup section in steps-plan.md
```

## Technical Implementation Details

### AKS Cluster Configuration

```bash
# Based on azure-microk8s patterns
RESOURCE_GROUP="rg-sandbox-aks-weu"
CLUSTER_NAME="aks-urbalurba-sandbox"
LOCATION="westeurope"
NODE_COUNT=2
NODE_SIZE="Standard_B2ms"  # Same as microk8s VMs

# Create cluster
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --location $LOCATION \
  --network-plugin azure \
  --generate-ssh-keys
```

### Storage Class Alias (Key Innovation)

```yaml
# hosts/azure-aks/manifests-overrides/000-storage-class-azure-alias.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path  # Alias for existing manifests
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: disk.csi.azure.com
parameters:
  skuName: Standard_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: microk8s-hostpath  # Additional alias for compatibility
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: disk.csi.azure.com
parameters:
  skuName: Standard_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

✅ **Validated**: Both `local-path` and `microk8s-hostpath` aliases work with Azure Disk CSI.

### Networking Strategy

**Simple and Secure**:
- Traefik IngressRoutes work unchanged
- Azure Load Balancer for Traefik service
- Authorized IP ranges for API server access
- Azure RBAC for authentication

```bash
# Install Traefik (Required - not pre-installed on AKS)
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  -f /mnt/urbalurbadisk/manifests/003-traefik-config.yaml \
  --namespace kube-system

# Control internet access
./toggle-internet-access.sh on   # Enable (LoadBalancer)
./toggle-internet-access.sh off  # Disable (ClusterIP)
```

### Script Integration Examples

**install-azure-aks.sh structure** (runs inside provision-host):
```bash
#!/bin/bash
# This script runs INSIDE the provision-host container
# All tools (az, kubectl, ansible) are already installed

# Step 1: Create AKS Cluster
cd /mnt/urbalurbadisk/hosts/azure-aks
./01-azure-aks-create.sh

# Step 2: Update ansible inventory
./02-azure-aks-ansible-inventory.sh

# Step 3: Merge kubeconfig
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/04-merge-kubeconf.yml

# Step 4: Apply secrets
cd /mnt/urbalurbadisk/../topsecret
./update-kubernetes-secrets-aks.sh

# Step 5: Setup Azure storage classes
kubectl apply -f /mnt/urbalurbadisk/hosts/azure-aks/manifests-overrides/000-storage-class-azure-alias.yaml

# Step 6: Same verification steps as Rancher
```

## Key Implementation Files

### 1. azure-aks-config.sh
```bash
#!/bin/bash
# Based on azure-vm-config-redcross-sandbox.sh
TENANT_ID="d34df49e-8ff4-46d6-b78d-3cef3261bcd6"
SUBSCRIPTION_ID="68bf1e87-1a04-4500-ab03-cc04054b0862"
RESOURCE_GROUP="rg-sandbox-aks-weu"
CLUSTER_NAME="aks-urbalurba-sandbox"
LOCATION="westeurope"
NODE_COUNT=2
NODE_SIZE="Standard_B2ms"
```

### 2. Key Script Snippets

**PIM Activation** (from azure-microk8s):
```bash
pim_yourself() {
    echo "Checking for Contributor role..."
    if az role assignment list --scope "/subscriptions/$SUBSCRIPTION_ID" \
       --query "[?roleDefinitionName=='Contributor']"; then
        echo "Contributor role active"
    else
        echo "Please activate PIM role at:"
        echo "https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac"
        read -p "Press Enter after activation..."
    fi
}
```

**AKS Creation**:
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --network-plugin azure \
  --generate-ssh-keys

az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --file azure-aks-kubeconf
```

## Cost Management (Tested)

### Actual Deployment Cost

**Validated with 2x Standard_B2ms nodes**:
- **AKS Control Plane**: $0 (Free tier)
- **2x Standard_B2ms nodes**: ~$120/month total  
- **Storage (Azure managed disks)**: ~$20-40/month
- **Load Balancer**: ~$20/month (only when internet enabled)
- **Total**: **~$160-180/month when active**

### Cost Management

```bash
# Disable internet access to save LoadBalancer costs
./toggle-internet-access.sh off

# Manual cluster cleanup (follow steps-plan.md)
az aks delete --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --yes

# Start/stop entire cluster
az aks stop --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
az aks start --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Success Criteria ✅ ACHIEVED

### Initial Deployment ✅ COMPLETED
- ✅ AKS cluster created and accessible from provision-host
- ✅ Storage class aliases working with Azure Disk CSI
- ✅ Basic services (nginx, whoami) deployed successfully
- ✅ Context switching functional between rancher-desktop and azure-aks
- ✅ Internet access control implemented

### Production Readiness 🔄 IN PROGRESS
- ✅ No changes required to existing manifests
- ✅ Cost tracking via internet access control
- ✅ Comprehensive documentation complete
- 🔄 Full service stack deployment ready for testing

### Key Validations ✅ CONFIRMED
- ✅ Existing manifests work unchanged
- ✅ Ansible playbooks work with context parameter
- ✅ Storage abstraction via aliases successful
- ✅ Traefik IngressRoutes functional (after Helm installation)
- ✅ External IP assignment and internet accessibility
- ✅ Seamless kubectl context switching

## Implementation Checklist

### Prerequisites
- [ ] Run `install-rancher.sh` to create provision-host container
- [ ] Azure subscription with Contributor role (PIM)
- [ ] Access to topsecret repository for secrets
- [ ] Note: Azure CLI, kubectl, ansible are pre-installed in provision-host

### Implementation Tasks ✅ COMPLETED
- ✅ Created azure-aks-config.sh with subscription details
- ✅ Validated PIM activation flow manually
- ✅ Documented complete manual deployment process
- ✅ Created internet access control orchestrator
- ✅ Tested basic deployment from provision-host
- ✅ Validated core services (nginx, whoami, Traefik)

### Full Deployment Tasks 🔄 READY
- 🔄 Deploy all database and auth services (infrastructure ready)
- 🔄 Deploy AI services (infrastructure ready)
- ✅ Documented AKS-specific requirements (Traefik installation)
- ✅ Set up cost monitoring via internet access control

### Deliverables ✅
1. ✅ Complete manual deployment guide (`steps-plan.md`) 
2. ✅ Working AKS cluster with validated core services
3. ✅ Comprehensive documentation with troubleshooting
4. ✅ Internet access control for cost management
5. ✅ Quota validation tools
6. ✅ Storage compatibility solutions

## Summary

The Azure AKS implementation is straightforward thanks to Urbalurba's excellent architecture:

### Key Advantages
- **Zero changes to existing files** - Everything works through context switching
- **Storage abstraction works perfectly** - Just need Azure-specific aliases
- **Traefik IngressRoutes need no changes** - Work identically on AKS
- **Proven patterns from azure-microk8s** - PIM, resource management ready to reuse
- **All tools pre-installed** - provision-host container has az, kubectl, ansible ready
- **Simple workflow** - Run scripts from inside provision-host, same as other operations

### Validated Implementation Approach ✅
- ✅ Manual deployment process documented and tested
- ✅ Storage class aliases provide full compatibility 
- ✅ Context switching enables multi-environment support
- ✅ Internet access control reduces operational costs
- ✅ Quota validation prevents deployment failures

### Next Steps for Full Production
1. ✅ Enter provision-host container
2. ✅ Follow `steps-plan.md` for complete AKS setup
3. ✅ Deploy and validate basic services  
4. 🔄 Deploy full service stack using existing provision scripts
5. 🔄 Optimize resource allocation based on workload requirements

---

## Key Files Reference

- **`steps-plan.md`** - Complete manual deployment walkthrough
- **`azure-aks-config.sh`** - Cluster configuration variables
- **`check-aks-quota.sh`** - Pre-deployment quota validation  
- **`toggle-internet-access.sh`** - Control internet accessibility
- **`manifests-overrides/000-storage-class-azure-alias.yaml`** - Storage compatibility

---

*Version 3.0 - Updated with practical testing results and validated implementation. This guide reflects the actual working deployment process with all scripts tested and proven functional.*