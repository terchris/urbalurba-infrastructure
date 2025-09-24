# Infrastructure Overview

**File**: `doc/overview-infrastructure.md`
**Purpose**: Simple overview of the two-component infrastructure
**Target Audience**: All users and developers
**Last Updated**: September 22, 2024

## 🏗️ Core Architecture

Urbalurba Infrastructure has a simple two-component design that runs entirely on your local development machine:

```
┌─────────────────────────────────────────────┐
│           Your Computer                     │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐  │
│  │ Provision Host   │  │ Kubernetes      │  │
│  │ Container        │─►│ Cluster         │  │
│  │                  │  │                 │  │
│  │ • kubectl        │  │ • Services      │  │
│  │ • ansible        │  │ • Storage       │  │
│  │ • scripts        │  │ • Networking    │  │
│  └──────────────────┘  └─────────────────┘  │
│                            ▲                │
│  ┌─────────────────────────┴──────────────┐ │
│  │        Web Browser                     │ │
│  │  http://service.localhost              │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 1. Provision Host Container
Purpose of the provision-host is to manage the kubernetes cluster. All sw for doing this is installed in the container so that there is no need to install anything on your computer.

A Docker container containing all management tools and scripts:
- **kubectl, helm, ansible** - Infrastructure management tools
- **Cloud CLIs** (az, aws, gcloud) - Cloud provider tools
- **Orchestration scripts** - Automated service deployment
- **Configuration management** - Secrets, manifests, playbooks

### 2. Kubernetes Cluster
Purpose is to set up the same services as your cloud provider (Azure) so that you can develop locally.

A local Kubernetes cluster running on your machine:
- **Rancher Desktop** (default) - Easy setup with GUI
- **Services** - All applications run as Kubernetes workloads
See [overview-services.md](./overview-services.md) for list of services and their Azure equivalents


## 🔄 How They Work Together

1. **Management**: All cluster operations happen from inside the provision-host container
2. **Deployment**: Scripts in provision-host deploy services to the local Kubernetes cluster
3. **Access**: Services are accessible via `http://service-name.localhost` URLs
4. **Development**: Same environment works identically on any developer machine

## 🌐 Beyond Local Development

For production or remote development, the same provision-host can manage:
- **Azure AKS clusters** - Production Kubernetes in the cloud
- **Azure VMs with MicroK8s** - Dedicated remote environments
- **Multi-cluster setups** - Development, staging, production environments

The key advantage: **same tools, same scripts, same processes** whether running locally or in the cloud.

## 📚 Related Documentation

- **[System Architecture](./overview-system-architecture.md)** - Detailed architectural diagrams
- **[Installation Guide](./overview-installation.md)** - Get started in 2 steps
- **[Services Overview](./overview-services.md)** - List of services and their Azure equivalents
- **[Host Types](./hosts-readme.md)** - All deployment options 