# Azure AKS Deployment Strategy

**⚠️ FIRST ESTIMATE PLAN** - This document represents an initial strategic assessment for adapting the Urbalurba Infrastructure system to deploy services on Azure Kubernetes Service (AKS). Implementation details may evolve based on testing and real-world constraints.

## Executive Summary

The Urbalurba Infrastructure system is excellently positioned for Azure AKS deployment with minimal architectural changes. The existing provision-host container, numbered playbook system, and cloud-agnostic Kubernetes manifests provide a strong foundation. This enhancement will add AKS as a new deployment target alongside the existing Rancher Desktop, MicroK8s VMs, and Raspberry Pi options.

## Current System Analysis

### Strengths for AKS Migration

1. **Mature Container Architecture**
   - provision-host already contains Azure CLI, kubectl, helm, ansible
   - All tools needed for AKS management are present
   - Container-based approach ensures consistent tooling

2. **Cloud-Agnostic Manifests**
   - Existing Kubernetes manifests in `/manifests` are designed for portability
   - Services use standard Kubernetes APIs that work identically on AKS
   - Helm-based deployments translate directly to AKS

3. **Proven Azure Integration**
   - `hosts/azure-microk8s/` demonstrates successful Azure authentication patterns
   - PIM integration, resource group management already working
   - Cloud-init templates show multi-cloud deployment experience
   - Note: Tailscale approach from VM deployment cannot be used with AKS

4. **Systematic Deployment Pattern**
   - Numbered playbooks (020+) provide clear service deployment sequence
   - Infrastructure-as-Code approach through Kubernetes manifests
   - Environment separation through kubeconfig contexts

### Current Limitations

1. **Storage Dependencies**
   - Current system uses `hostpath` storage classes
   - AKS requires Azure Managed Disks or Azure Files

2. **Load Balancing**
   - Local/VM environments use NodePort or Traefik ingress
   - AKS can leverage Azure Load Balancer for better integration

3. **Networking Assumptions**
   - Current setup assumes single-node or simple networking
   - AKS requires consideration of CNI choices and network policies

## Strategic Architecture Enhancement

### Organizational Structure

Following the established pattern, AKS deployment will be contained in:

```
hosts/azure-aks/
├── 01-azure-aks-cluster-create.sh         # Main cluster creation script
├── 02-azure-aks-ansible-inventory.sh      # Ansible inventory integration
├── 03-azure-aks-kubeconfig-merge.sh       # Kubeconfig management
├── azure-aks-config.sh                    # Configuration variables
├── azure-aks-cleanup.sh                   # Cluster deletion script
├── azure-aks-readme.md                    # This document
├── manifests-azure-aks/                   # AKS-specific manifests
│   ├── 000-storage-class-azure-disk.yaml  # Azure Disk storage class
│   ├── 001-storage-class-azure-files.yaml # Azure Files storage class
│   └── 002-loadbalancer-azure.yaml        # Azure Load Balancer config
│   # Note: Keep existing Traefik ingress - no AKS-specific ingress manifests needed
└── playbooks/                             # AKS-specific infrastructure playbooks
    ├── 001-create-aks-cluster.yml         # Cluster provisioning
    ├── 002-configure-aks-storage.yml      # Storage class setup
    ├── 003-setup-aks-networking.yml       # Networking configuration
    └── 004-install-aks-addons.yml         # Azure-specific add-ons
```

### Three-Tier Enhancement Strategy

#### Tier 1: AKS Cluster Provisioning (New: 00x series)
**Purpose**: Create and configure AKS infrastructure

- **001-create-aks-cluster.yml**: 
  - Create AKS cluster with appropriate node pools
  - Configure Azure AD integration (optional)
  - Set up cluster networking (CNI choice)
  - Enable monitoring and logging

- **002-configure-aks-storage.yml**:
  - Deploy Azure Disk storage classes
  - Configure Azure Files for shared storage
  - Set up backup and snapshot policies

- **003-setup-aks-networking.yml**:
  - Configure Azure Load Balancer
  - Set up network policies
  - Integrate with existing Tailscale networking

#### Tier 2: Service Adaptation (Modify existing: 01x-09x series)
**Purpose**: Adapt infrastructure playbooks for AKS

- **Modified playbooks**:
  - `01-configure_provision-host.yml`: Add AKS context management
  - `010-move-hostpath-storage.yml`: Adapt for Azure storage classes
  - Update storage references throughout manifests

#### Tier 3: Service Deployment (Unchanged: 020+ series)
**Purpose**: Deploy services to AKS using existing playbooks

- Services deploy identically to AKS as other targets
- Context switching enables multi-environment deployment
- Existing service manifests work without modification

## Implementation Phases

### Phase 1: Minimal Viable AKS
**Goal**: Establish basic AKS cluster with core functionality

**Deliverables**:
- Working AKS cluster creation scripts
- Azure storage class integration
- 2-3 core services running (nginx, whoami, basic observability)
- Documentation and troubleshooting guides

**Tasks**:
1. Create cluster provisioning scripts based on existing Azure patterns
2. Adapt storage class manifests for Azure Disk
3. Test basic service deployment
4. Establish kubeconfig integration
5. Document lessons learned and gotchas

**Success Criteria**:
- Can deploy AKS cluster from provision-host
- Can deploy nginx service accessible via Azure Load Balancer
- Can switch contexts between Rancher Desktop and AKS
- All operations follow existing patterns and conventions

### Phase 2: Full Service Migration
**Goal**: Systematically adapt all services for AKS deployment

**Deliverables**:
- All numbered playbooks (020+) tested on AKS
- AKS-specific optimizations implemented
- Performance and cost baseline established
- Migration runbooks for each service

**Tasks**:
1. Systematically test each service playbook on AKS
2. Identify and resolve AKS-specific issues
3. Implement Azure-native optimizations where beneficial
4. Establish monitoring and alerting
5. Document service-specific considerations

**Success Criteria**:
- All services from local deployment work on AKS
- Performance meets or exceeds local deployment
- Cost model is understood and acceptable
- Rollback procedures are tested and documented

### Phase 3: Production Hardening
**Goal**: Prepare AKS deployment for production workloads

**Deliverables**:
- Security hardening implementation
- Cost optimization strategies
- CI/CD pipeline integration
- Disaster recovery procedures

**Tasks**:
1. Implement Azure security best practices
2. Set up comprehensive monitoring and logging
3. Establish backup and disaster recovery procedures
4. Optimize resource allocation and costs
5. Create production deployment procedures

**Success Criteria**:
- Security posture meets organizational requirements
- Monitoring provides comprehensive observability
- Costs are optimized and predictable
- Production deployment procedures are validated

## Technical Implementation Details

### Cluster Configuration Strategy

**AKS Cluster Specifications** (Initial recommendation):
- **Node Pool**: Standard_B4ms (4 vCPUs, 16GB RAM)
- **Node Count**: 2-3 nodes (auto-scaling enabled)
- **Kubernetes Version**: Latest stable
- **CNI**: Azure CNI (for better Azure integration)
- **Authentication**: Azure AD integration (recommended for enterprise)

**Storage Strategy**:
```yaml
# Azure Managed Disk - Primary storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingmode: ReadOnly
  diskIopsReadWrite: "500"
volumeBindingMode: WaitForFirstConsumer

# Azure Files - Shared storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-files-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
  storageAccount: ""  # Auto-generated
mountOptions:
  - dir_mode=0755
  - file_mode=0644
```

**Networking Strategy**:
- **Load Balancer**: Azure Load Balancer for service exposure
- **Ingress**: Keep existing Traefik ingress controller (no manifest changes needed)
- **Security**: Cannot use Tailscale (no VM to install on) - requires alternative secure access strategy
- **Network Policies**: Implement for pod-to-pod communication control

**Secure Access Strategy** (Tailscale Alternative):
Since AKS nodes are managed by Azure and Tailscale cannot be installed, secure access requires:
- **Option 1**: Azure Private AKS cluster + Azure Bastion for management access
- **Option 2**: Public AKS cluster with authorized IP ranges (provision-host IP)
- **Option 3**: Azure VPN Gateway for secure network connectivity
- **Option 4**: Direct kubectl access through Azure RBAC and firewall rules
- **Recommendation**: Option 2 for development, Option 1 for production

### Integration Patterns

**Kubeconfig Management**:
```bash
# AKS context integration
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --context azure-aks
kubectl config use-context azure-aks

# Merge with existing kubeconfig
KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all:~/.kube/config kubectl config view --merge --flatten > /tmp/merged
mv /tmp/merged /mnt/urbalurbadisk/kubeconfig/kubeconf-all
```

**Service Deployment Pattern**:
```bash
# Existing pattern works unchanged
ansible-playbook 020-setup-nginx.yml -e kube_context=azure-aks
ansible-playbook 200-setup-open-webui.yml -e kube_context=azure-aks
```

**Cost Optimization Patterns**:
- Use Azure Dev/Test pricing for development clusters
- Implement cluster auto-scaling
- Set up automatic cluster shutdown for non-production environments
- Monitor costs through Azure Cost Management integration

## Risk Assessment and Mitigation

### Technical Risks

**Risk**: Storage performance differences between local and Azure
- **Impact**: Medium - May affect service startup times
- **Mitigation**: Performance testing during Phase 1, storage class optimization

**Risk**: Networking complexity with Azure CNI and loss of Tailscale simplicity
- **Impact**: Medium - May complicate troubleshooting and secure access
- **Mitigation**: Implement Azure-native security, maintain documentation, implement network monitoring

**Risk**: Azure service dependencies
- **Impact**: High - Could affect service reliability
- **Mitigation**: Implement proper health checks, establish SLAs

### Operational Risks

**Risk**: Cost overruns during development
- **Impact**: Medium - Could affect project budget
- **Mitigation**: Implement cost monitoring, automatic shutdowns, resource quotas

**Risk**: Security configuration complexity
- **Impact**: High - Could expose sensitive data
- **Mitigation**: Follow Azure security best practices, implement least-privilege access

**Risk**: Knowledge gap on AKS-specific operations
- **Impact**: Medium - Could slow troubleshooting
- **Mitigation**: Training plan, comprehensive documentation

### Business Risks

**Risk**: Migration timeline extends beyond estimate
- **Impact**: Medium - Could delay other projects
- **Mitigation**: Phased approach allows early value delivery

**Risk**: Performance doesn't meet expectations
- **Impact**: High - Could require architecture changes
- **Mitigation**: Performance testing in Phase 1, rollback plans

## Cost Considerations

### Estimated Monthly Costs (Development Environment)

**AKS Control Plane**: $0 (Free tier)
**Compute Nodes**: ~$200-300/month (2-3 Standard_B4ms nodes)
**Storage**: ~$50-100/month (depends on data volume)
**Networking**: ~$20-50/month (load balancer, data transfer)
**Monitoring**: ~$30-50/month (Azure Monitor, Log Analytics)

**Total Estimated**: $300-500/month for development environment

### Cost Optimization Strategies

1. **Auto-scaling**: Scale nodes down during off-hours
2. **Spot Instances**: Use Azure Spot VMs for non-critical workloads
3. **Reserved Instances**: Commit to reserved capacity for production
4. **Resource Quotas**: Prevent resource waste through enforcement
5. **Regular Reviews**: Monthly cost analysis and optimization

## Success Metrics

### Technical Metrics
- **Deployment Success Rate**: >95% successful service deployments
- **Performance**: Service startup time within 20% of local deployment
- **Availability**: >99.5% uptime for deployed services
- **Security**: Zero security incidents during implementation

### Operational Metrics
- **Cost Efficiency**: Stay within estimated budget ranges
- **Time to Deploy**: New services deploy in <30 minutes
- **Recovery Time**: Service recovery in <15 minutes
- **Documentation Quality**: All procedures documented and tested

### Business Metrics
- **Team Productivity**: No reduction in development velocity
- **Knowledge Transfer**: All team members can deploy to AKS
- **Flexibility**: Can switch between local and cloud environments seamlessly

## Next Steps

### Immediate Actions
1. **Create cluster creation scripts** based on existing azure-microk8s patterns
2. **Set up development AKS cluster** for testing
3. **Test basic service deployment** (nginx, whoami)
4. **Document initial findings** and update this plan

### Short Term
1. **Systematically test all services** on AKS
2. **Implement storage class adaptations**
3. **Establish monitoring and logging**
4. **Create troubleshooting documentation**

### Medium Term
1. **Implement security hardening**
2. **Optimize for production workloads**
3. **Establish CI/CD integration**
4. **Create disaster recovery procedures**

## Conclusion

The Urbalurba Infrastructure system's architecture provides an excellent foundation for Azure AKS deployment. The systematic approach, cloud-agnostic design, and proven Azure integration patterns minimize migration risks while maximizing the value of existing investments.

This enhancement will provide:
- **Production-ready cloud deployment** option
- **Scalability** for larger workloads
- **Enterprise features** through Azure integration
- **Maintained flexibility** across deployment targets

The phased implementation approach ensures early value delivery while managing risks through systematic validation and documentation.

---

*This document represents initial strategic planning and will be updated based on implementation experience and changing requirements.*