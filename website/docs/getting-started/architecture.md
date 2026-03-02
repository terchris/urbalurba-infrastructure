# Urbalurba Infrastructure System Architecture

**File**: `docs/overview-system-architecture.md`
**Purpose**: High-level overview of the two-tier architecture: provision-host + cluster
**Target Audience**: Developers, architects, and anyone needing to understand the overall system design
**Last Updated**: September 20, 2024

## 🏗️ **Overview**

The Urbalurba Infrastructure follows a **two-tier architecture** that separates cluster management from cluster workloads. This design provides a clean separation of concerns, ensuring all management tooling is centralized and the cluster remains focused on running applications.

```mermaid
graph TB
    subgraph "Host Machine"
        HOST[Host Operating System<br/>macOS / Linux / Windows]

        subgraph "Provision Host Container"
            PH[provision-host<br/>Management Environment]
            TOOLS[All Management Tools<br/>kubectl, helm, ansible<br/>cloud CLIs, etc.]
            SCRIPTS[Orchestration Scripts<br/>provision-kubernetes.sh<br/>category-based automation]
            CONFIG[Configuration<br/>playbooks, manifests<br/>secrets, kubeconfig]
        end

        subgraph "Kubernetes Cluster"
            STORAGE[Storage Systems<br/>PostgreSQL, Redis]
            NETWORK[Networking<br/>Traefik Ingress]
            AUTH[Authentication<br/>Authentik SSO]
            AI[AI Platform<br/>OpenWebUI, LiteLLM]
            APPS[Other Applications<br/>Custom Services]
            MGMT[Management Tools<br/>pgAdmin, ArgoCD]
        end
    end

    HOST --> PH
    PH -.->|"Manages & Deploys"| STORAGE
    PH -.->|"Manages & Deploys"| NETWORK
    PH -.->|"Manages & Deploys"| AUTH
    PH -.->|"Manages & Deploys"| AI
    PH -.->|"Manages & Deploys"| APPS
    PH -.->|"Manages & Deploys"| MGMT
```

## 🎯 **Core Architecture Principles**

### **1. Separation of Management and Runtime**
- **Provision Host**: Contains ALL tools needed to manage the cluster
- **Cluster**: Runs ONLY application workloads and services
- **Clean Interface**: Management happens through standard Kubernetes APIs

### **2. Self-Contained Management Environment**
- **Containerized Tooling**: All management tools isolated in provision-host container
- **Version Consistency**: Same tool versions across all environments
- **Portable**: Works identically on any host machine

### **3. Declarative Configuration**
- **Infrastructure as Code**: All cluster state defined in manifests
- **Reproducible Deployments**: Same configuration produces identical results
- **Version Controlled**: All configuration tracked in Git

## 🏗️ **Tier 1: Provision Host (Management Layer)**

The **provision-host** is a containerized management environment that contains ALL tools and scripts needed to manage the Kubernetes cluster.

### **What's Inside the Provision Host**

```
/mnt/urbalurbadisk/               # Mounted working directory
├── provision-host/               # Container setup scripts
│   ├── provision-host-00-coresw.sh      # Core software installation
│   ├── provision-host-01-cloudproviders.sh  # Cloud provider CLIs
│   ├── provision-host-02-kubetools.sh   # Kubernetes tooling
│   ├── provision-host-03-net.sh         # Network configuration
│   ├── provision-host-04-helmrepo.sh    # Helm repository setup
│   └── kubernetes/               # Orchestration scripts
│       ├── provision-kubernetes.sh      # Main orchestration engine
│       ├── 01-core/                    # Core infrastructure scripts
│       ├── 02-databases/               # Data service scripts
│       ├── 07-ai/                      # AI platform scripts
│       └── [nn]-[category]/            # Other service categories
├── ansible/                      # Automation engine
│   ├── playbooks/                # Service deployment logic
│   └── inventory/                # Environment configurations
├── manifests/                    # Kubernetes manifests
├── troubleshooting/              # Debug scripts and tools
├── kubeconfig/                   # Kubernetes configuration files
│   ├── kubeconf-all              # Merged kubeconfig for all clusters
│   └── rancher-desktop-kubeconf  # Rancher Desktop specific config
├── .uis.secrets/                 # Secrets management
│   ├── generated/kubernetes/     # Generated Kubernetes secrets
│   ├── config/                   # User configuration (your values)
│   └── scripts/                  # Secret generation scripts
├── scripts/                      # Additional utility scripts
├── networking/                   # Network configurations
├── hosts/                        # Host-specific configurations
└── cloud-init/                   # Cloud-init templates
```

**Pre-installed Tools** (via setup scripts):
- **kubectl, helm** - Kubernetes management
- **ansible** - Infrastructure automation
- **az, aws, gcloud** - Cloud provider CLIs
- **tailscale** - VPN tunnel for traffic in to the cluster
- **cloudlare** - VPN tunnel for traffic in to the cluster
- **jq, yq** - JSON/YAML processing
- **git, curl, wget** - Development utilities

### **Management Capabilities**

- **🚀 Cluster Provisioning**: Automated setup of entire infrastructure
- **📦 Service Deployment**: Deploy services using Ansible + Helm
- **🔧 Configuration Management**: Manage secrets, configs, manifests
- **🔍 Monitoring & Debugging**: Access logs, metrics, troubleshooting tools
- **☁️ Cloud Integration**: Deploy to AWS, Azure, GCP from same environment

### **Key Benefits**

- ✅ **Tool Consistency**: Same versions across all environments
- ✅ **Reproducible**: Identical setup process everywhere
- ✅ **Isolated**: Management tools don't interfere with cluster workloads
- ✅ **Portable**: Works on any machine with Rancher Desktop
- ✅ **Auditable**: All management actions tracked and scripted

## 🎪 **Tier 2: Kubernetes Cluster (Runtime Layer)**

The **provision-host** runs on the host machine and manages the Kubernetes cluster which provides container orchestration for all application services.

### **Cluster Runtime Options**

| **Option** | **Use Case** | **Benefits** |
|------------|--------------|--------------|
| **Rancher Desktop** | Development, local testing | Easy setup, GUI management |
| **MicroK8s** | Production-like local env | Lightweight, production features |
| **Cloud K8s** | Production deployment | Managed services, high availability |


## 🔄 **Deployment Flow**

Two ways to start the services in the cluster.

### **Automated Provisioning Process**

This is run when the cluster is built. 
For detailed description see [provision-host-kubernetes.md](../provision-host/kubernetes.md)
```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PH as Provision Host
    participant K8s as Kubernetes Cluster

    Dev->>PH: Execute provision-kubernetes.sh
    PH->>PH: Discovery: Find numbered directories (01, 02, 07...)
    PH->>PH: Discovery: Find numbered scripts in each directory

    loop For each category (01-core, 02-databases, 07-ai...)
        PH->>PH: Execute category scripts in sequence
        PH->>K8s: Deploy services via Ansible + Helm
        K8s-->>PH: Report deployment status
        PH->>PH: Verify service health
    end

    PH-->>Dev: Complete provisioning report
```

### **Manual Service Management**

This is when you log in to the `provision-host`container and start a service. See the section Starting services in the [overview-getting-started.md](./overview.md) for an example on how to start a service.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant PH as Provision Host
    participant K8s as Kubernetes Cluster

    Dev->>PH: Run specific service script
    PH->>PH: Execute Ansible playbook
    PH->>K8s: Deploy/update service
    PH->>K8s: Apply manifests
    PH->>K8s: Verify deployment
    K8s-->>PH: Service status
    PH-->>Dev: Deployment results
```


### **Multi-Cluster Management**

The provision-host can manage multiple Kubernetes clusters simultaneously using merged kubeconfig files:

```mermaid
graph TB
    subgraph "Host Machine"
        PH[provision-host<br/>Management Container]
        CONFIG[kubeconfig/kubeconf-all<br/>Merged Configuration]
    end

    subgraph "Development"
        RD[rancher-desktop<br/>Local Development]
    end

    subgraph "On-Premise"
        UMICROK8S[ubuntu-microk8s<br/>Dedicated Hardware]
    end

    subgraph "Azure Cloud"
        AKS[azure-aks<br/>Production Cluster]
        AMICROK8S[azure-microk8s<br/>Staging Cluster]
    end

    subgraph "Google Cloud"
        GKE[google-gke<br/>GKE Cluster]
    end

    subgraph "AWS Cloud"
        EKS[aws-eks<br/>EKS Cluster]
    end

    subgraph "Edge Computing"
        RMICROK8S[raspberry-microk8s<br/>IoT/Edge Cluster]
    end

    PH --> CONFIG
    CONFIG -.-> RD
    CONFIG -.-> UMICROK8S
    CONFIG -.-> AKS
    CONFIG -.-> AMICROK8S
    CONFIG -.-> GKE
    CONFIG -.-> EKS
    CONFIG -.-> RMICROK8S

    PH -.->|"Same tools & scripts"| RD
    PH -.->|"Same tools & scripts"| UMICROK8S
    PH -.->|"Same tools & scripts"| AKS
    PH -.->|"Same tools & scripts"| AMICROK8S
    PH -.->|"Same tools & scripts"| GKE
    PH -.->|"Same tools & scripts"| EKS
    PH -.->|"Same tools & scripts"| RMICROK8S
```

**Key Benefits:**
- **🎯 Single Management Point**: One provision-host manages all clusters
- **🔧 Consistent Tooling**: Same kubectl, helm, ansible across all environments
- **📋 Unified Configuration**: Merged kubeconfig enables cluster switching with `kubectl config use-context`
- **🚀 Identical Deployments**: Same manifests and playbooks work everywhere

---

**💡 Key Takeaway**: The Urbalurba Infrastructure is fundamentally about **separation of concerns** - the provision-host handles ALL management complexity, while the cluster focuses purely on running applications reliably and efficiently.