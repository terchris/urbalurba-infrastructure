# Provision Host Documentation Guide

**File**: `doc/provision-host-readme.md`
**Purpose**: Central entry point for all provision host documentation and guides
**Target Audience**: Developers, DevOps engineers, and infrastructure administrators
**Last Updated**: September 21, 2024

## 📋 **Overview**

This is the central starting point for understanding the provision host system - a comprehensive Docker container that serves as the management hub for Urbalurba infrastructure. The provision host contains all necessary tools for managing multi-cloud environments, Kubernetes clusters, and infrastructure automation.

## 🔧 **What is the Provision Host?**

The provision host is a self-contained Docker container that serves as your **complete infrastructure management environment**. All cluster and cloud operations are performed from within this container - no need to install any tools on your local machine.

### **Container-First Approach**
- **No Local Tool Installation**: AWS CLI, kubectl, Terraform, etc. all run in the container
- **Consistent Environment**: Same container works identically on Windows, Linux, and macOS
- **Version Controlled**: All tool versions are pinned and tested together
- **Isolation**: No conflicts with locally installed tools or different versions

### **Fully Automated Setup**
- **One-Command Deployment**: Run `./install-rancher.sh` to set up everything
- **Two-Stage Process**: First creates and provisions the container, then deploys all cluster services
- **Zero Manual Steps**: Complete infrastructure from container to running services automatically

## 📚 **Documentation Guides**

### **Container Tools Reference**
**📖 [Provision Host Tools Guide](provision-host-tools.md)**

Complete reference for all tools and software available in the provision host container - pre-configured with all major cloud providers, Kubernetes tools, automation frameworks, and networking capabilities. Includes detailed capabilities, usage examples, and authentication setup.

**When to use**: Understanding available tools, troubleshooting tool issues, cloud authentication setup

---


### **Kubernetes Service Deployment**
**☸️ [Provision Host Kubernetes Guide](provision-host-kubernetes.md)**

User guide for deploying and managing applications on Kubernetes clusters using the automated provisioning system:

- **Declarative Configuration**: Repository file organization determines what gets deployed automatically
- **One-Command Deployment**: `./install-rancher.sh` builds complete, reproducible clusters
- **Service Management**: Activate/deactivate services by moving scripts in/out of `not-in-use/` folders
- **Available Services**: AI services, databases, authentication, monitoring, and more
- **Manual Operations**: Deploy/test individual services without changing automatic configuration

**When to use**: Setting up your cluster configuration, understanding available services, managing what gets deployed automatically

---

### **Rancher Desktop Integration**
**🖥️ [Provision Host Rancher Guide](provision-host-rancher.md)**

Specific setup and compatibility for Rancher Desktop environments:

- **Rancher Desktop Setup**: Container creation and Kubernetes integration
- **MicroK8s Compatibility**: Context aliasing, storage class mapping
- **Installation Workflow**: Complete setup process and verification
- **Troubleshooting**: Common issues and solutions

**When to use**: Using Rancher Desktop as Kubernetes provider, migrating from MicroK8s, troubleshooting Rancher-specific issues

---

## 🚀 **Quick Start Paths**

### **New Developer Getting Started:**
1. Run `./install-rancher.sh` - One command sets up everything automatically
2. **[Tools Guide](provision-host-tools.md)** - Understand what's available
3. **[Kubernetes Guide](provision-host-kubernetes.md)** - Deploy your first services

### **DevOps Engineer Doing Multi-Cloud:**
1. **[Tools Guide](provision-host-tools.md)** - Cloud provider capabilities
2. Jump to specific cloud authentication sections

### **Using Rancher Desktop:**
1. **[Rancher Guide](provision-host-rancher.md)** - Platform-specific setup
2. **[Kubernetes Guide](provision-host-kubernetes.md)** - Service deployment

### **Troubleshooting:**
- Container issues? → **[Tools Guide](provision-host-tools.md)**
- Installation problems? → **[Setup Guide](provision-host-setup.md)**
- Service deployment failures? → **[Kubernetes Guide](provision-host-kubernetes.md)**
- Rancher Desktop issues? → **[Rancher Guide](provision-host-rancher.md)**

## 🏗️ **Architecture Overview**

```
Host Machine (Windows/Linux/macOS)
└── Docker + Rancher Desktop
    │
    │ ./install-rancher.sh (One Command Setup)
    │
    ├─► 1. Creates & Provisions Container
    │   ┌─────────────────────────────────────────────────────────────┐
    │   │                  Provision Host Container                   │
    │   ├─────────────────────────────────────────────────────────────┤
    │   │  Cloud Tools: AWS CLI, Azure CLI, GCP SDK, OCI CLI, Terraform │
    │   │  K8s Tools: kubectl, Helm, k9s, Ansible                   │
    │   │  Network: Cloudflared, Tailscale                          │
    │   │  Dev Tools: GitHub CLI, Python, yq/jq                     │
    │   └─────────────────────────────────────────────────────────────┘
    │                             │
    └─► 2. Deploys All Services   ▼
        ┌─────────────────────────────────────────────────────────────┐
        │                    Kubernetes Cluster                        │
        │              (Rancher Desktop / MicroK8s)                    │
        ├─────────────────────────────────────────────────────────────┤
        │  Services: Authentik, PostgreSQL, Redis, OpenWebUI, etc.    │
        │  Storage: PVCs, ConfigMaps, Secrets                         │
        │  Networking: Traefik, Ingress, Services                     │
        └─────────────────────────────────────────────────────────────┘
```

## 🎯 **Key Concepts**

- **Zero Local Installation**: Only Docker required on your machine - all tools run in the container
- **OS Agnostic**: Identical experience on Windows, Linux, and macOS
- **Container-First**: All management tools run in a consistent Docker environment
- **Multi-Cloud Ready**: Support for all major cloud providers out of the box
- **Kubernetes Native**: Designed for Kubernetes-first infrastructure patterns
- **Automation Focused**: Ansible playbooks and Infrastructure as Code
- **Developer Friendly**: Pre-configured tools and streamlined workflows

## 📞 **Getting Help**

- **Tool not working?** Check the [Tools Guide](provision-host-tools.md)
- **Setup failing?** Follow the [Setup Guide](provision-host-setup.md) step by step
- **Service won't deploy?** Review the [Kubernetes Guide](provision-host-kubernetes.md)
- **Rancher issues?** See the [Rancher Guide](provision-host-rancher.md)

---

**Related Documentation:**
- [Rules Documentation](rules-readme.md) - Infrastructure rules and standards
- [Secrets Management](rules-secrets-management.md) - Security and secrets handling
- [Ingress Configuration](rules-ingress-traefik.md) - Networking and routing