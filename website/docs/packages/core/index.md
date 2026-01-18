# Core Infrastructure Package

**File**: `docs/package-core-readme.md`
**Purpose**: Overview of core infrastructure services and deployment patterns
**Target Audience**: Infrastructure engineers, developers deploying core services
**Last Updated**: September 22, 2024

## 📋 Overview

The **Core Infrastructure Package** provides essential foundation services required for any Kubernetes cluster deployment. These services are deployed first during cluster provisioning to establish the basic infrastructure layer that all other services depend on.

**Core Services Include**:
- **Web Servers**: Nginx for reverse proxy and static content
- **Storage Systems**: Persistent volumes and storage classes
- **Network Services**: DNS, load balancing, and ingress
- **Basic Monitoring**: Health checks and readiness probes

## 🗂️ Service Organization

### **Directory Structure**
```
provision-host/kubernetes/01-core/
├── 020-setup-nginx.sh          # Nginx web server deployment
└── not-in-use/                 # Inactive core services
    └── 020-remove-nginx.sh     # Nginx removal script
```

## 🚀 Deployment Workflow

### **Automatic Deployment**
Core services deploy automatically during cluster provisioning:

```bash
# Full cluster provisioning (includes core services)
./provision-kubernetes.sh rancher-desktop
```

### **Manual Core Service Management**
```bash
# Deploy specific core service
cd provision-host/kubernetes/01-core/
./020-setup-nginx.sh rancher-desktop

# Remove specific core service (from not-in-use folder)
cd provision-host/kubernetes/01-core/not-in-use/
./020-remove-nginx.sh rancher-desktop
```


---

**💡 Remember**: Core services are the foundation of your cluster. Ensure they're stable and well-tested before deploying other services that depend on them.