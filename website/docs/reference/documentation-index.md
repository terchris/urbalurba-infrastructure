# Urbalurba Infrastructure Documentation

**Purpose**: Master documentation index and entry point for Urbalurba Infrastructure
**Target Audience**: All users, developers, and administrators

## Overview

Welcome to the complete documentation for **Urbalurba Infrastructure** — a zero-friction developer platform that provides a complete datacenter environment on your laptop. This documentation covers everything from installation to advanced configuration and troubleshooting.

## Quick Start

**New to Urbalurba?** Start here:

1. **[Getting Started](../getting-started/overview.md)** — 5-minute first test with your browser
2. **[Installation Guide](../getting-started/installation.md)** — Get up and running in 2 simple steps
3. **[System Architecture](../getting-started/architecture.md)** — Understand how everything fits together
4. **[Services Overview](../getting-started/services.md)** — See all available services vs Azure equivalents

## Documentation Categories

### Getting Started

*Essential guides for new users and system administrators*

| Document | Purpose |
|----------|---------|
| [Getting Started](../getting-started/overview.md) | 5-minute first test guide with browser access |
| [Installation Guide](../getting-started/installation.md) | Simple 2-step installation guide |
| [System Architecture](../getting-started/architecture.md) | Two-tier architecture overview with diagrams |
| [Infrastructure Overview](../getting-started/infrastructure.md) | Infrastructure components and relationships |
| [Services Overview](../getting-started/services.md) | Complete services comparison with Azure equivalents |

### Packages — Observability

*Metrics, logs, and distributed tracing*

| Document | Purpose |
|----------|---------|
| [Observability Overview](../packages/observability/index.md) | Stack overview and architecture |
| [Prometheus](../packages/observability/prometheus.md) | Metrics collection and alerting |
| [Grafana](../packages/observability/grafana.md) | Visualization and dashboards |
| [Loki](../packages/observability/loki.md) | Log aggregation |
| [Tempo](../packages/observability/tempo.md) | Distributed tracing |
| [OpenTelemetry Collector](../packages/observability/otel-collector.md) | Telemetry pipeline |
| [OTLP Collector](../packages/observability/otel.md) | OTLP ingestion configuration |
| [sovdev-logger](../packages/observability/sovdev-logger.md) | Multi-language OTLP integration library |

### Packages — AI & ML

*AI services, LLM integration, and model management*

| Document | Purpose |
|----------|---------|
| [AI & ML Overview](../packages/ai/index.md) | AI platform overview |
| [Open WebUI](../packages/ai/openwebui.md) | ChatGPT-like interface |
| [LiteLLM](../packages/ai/litellm.md) | LLM proxy configuration |
| [LiteLLM Client Keys](../packages/ai/litellm-client-keys.md) | API key setup for Claude Code integration |
| [OpenWebUI Model Access](../packages/ai/openwebui-model-access.md) | Model access configuration |
| [Environment Management](../packages/ai/environment-management.md) | AI environment and model management |

### Packages — Analytics

*Data science, notebooks, and distributed computing*

| Document | Purpose |
|----------|---------|
| [Analytics Overview](../packages/analytics/index.md) | Analytics platform overview |
| [Apache Spark](../packages/analytics/spark.md) | Distributed computing |
| [JupyterHub](../packages/analytics/jupyterhub.md) | Collaborative notebooks |
| [Unity Catalog](../packages/analytics/unity-catalog.md) | Data governance |

### Packages — Identity

*SSO, authentication, and access control*

| Document | Purpose |
|----------|---------|
| [Identity Overview](../packages/identity/index.md) | Identity and access management overview |
| [Authentik](../packages/identity/authentik.md) | Authentik SSO service |
| [Auth10 Blueprints](../packages/identity/auth10.md) | Dynamic blueprint creation and management |
| [Blueprints Syntax](../packages/identity/blueprints-syntax.md) | Authentik blueprint configuration reference |
| [Developer Guide](../packages/identity/developer-guide.md) | Auth10 developer guide |
| [Technical Implementation](../packages/identity/technical-implementation.md) | Authentik technical implementation details |
| [Test Users](../packages/identity/test-users.md) | Test user configuration |

### Packages — Databases

*Data storage and caching services*

| Document | Purpose |
|----------|---------|
| [Databases Overview](../packages/databases/index.md) | Database services overview |
| [PostgreSQL](../packages/databases/postgresql.md) | Primary relational database |
| [PostgreSQL Container](../packages/databases/postgresql-container.md) | Custom PostgreSQL image with AI/ML extensions |
| [MySQL](../packages/databases/mysql.md) | Alternative SQL database |
| [MongoDB](../packages/databases/mongodb.md) | NoSQL document database |
| [Redis](../packages/databases/redis.md) | In-memory cache and message broker |
| [Elasticsearch](../packages/databases/elasticsearch.md) | Search and analytics engine |
| [Qdrant](../packages/databases/qdrant.md) | Vector database |

### Packages — Management

*Admin tools, GitOps, and test services*

| Document | Purpose |
|----------|---------|
| [Management Overview](../packages/management/index.md) | Management tools overview |
| [ArgoCD](../packages/management/argocd.md) | GitOps continuous deployment |
| [pgAdmin](../packages/management/pgadmin.md) | PostgreSQL administration UI |
| [RedisInsight](../packages/management/redisinsight.md) | Redis administration UI |
| [Nginx](../packages/management/nginx.md) | Web server |
| [Whoami](../packages/management/whoami.md) | Test/debug service |
| [Dev and Test Templates](../packages/management/templates.md) | Development and testing tools |

### Packages — Integration

*Messaging and API gateways*

| Document | Purpose |
|----------|---------|
| [Integration Overview](../packages/integration/index.md) | Integration services overview |
| [RabbitMQ](../packages/integration/rabbitmq.md) | Message broker |
| [Gravitee](../packages/integration/gravitee.md) | API management platform |

### Packages — Networking

*VPN tunnels and network access services*

| Document | Purpose |
|----------|---------|
| [Networking Packages Overview](../packages/networking/index.md) | Network service packages |
| [Cloudflare Tunnel](../packages/networking/cloudflare-tunnel.md) | Cloudflare tunnel service |
| [Tailscale Tunnel](../packages/networking/tailscale-tunnel.md) | Tailscale tunnel service |

### Networking

*Network architecture, ingress, and external connectivity setup guides*

| Document | Purpose |
|----------|---------|
| [Networking Overview](../networking/index.md) | Dual-tunnel internet access architecture |
| [Cloudflare Setup](../networking/cloudflare-setup.md) | Cloudflare tunnel configuration guide |
| [Tailscale Setup](../networking/tailscale-setup.md) | Tailscale tunnel configuration guide |
| [Tailscale Internal Ingress](../networking/tailscale-internal-ingress.md) | Tailscale internal access setup |
| [Tailscale Network Isolation](../networking/tailscale-network-isolation.md) | Tailscale funnel security setup |

### Hosts & Platforms

*Multi-environment deployment strategies and cloud platform integration*

| Document | Purpose |
|----------|---------|
| [Hosts Overview](../hosts/index.md) | Host types and deployment strategies |
| [Rancher Kubernetes](../hosts/rancher-kubernetes.md) | Default local development environment |
| [Azure AKS](../hosts/azure-aks.md) | Production Azure Kubernetes Service |
| [Azure MicroK8s](../hosts/azure-microk8s.md) | Azure VM with MicroK8s |
| [Multipass MicroK8s](../hosts/multipass-microk8s.md) | Legacy Multipass deployment (superseded by Rancher) |
| [Raspberry Pi MicroK8s](../hosts/raspberry-microk8s.md) | Edge computing on Raspberry Pi |
| [Cloud-Init Guide](../hosts/cloud-init/index.md) | Cloud-init automation for Ubuntu-based hosts |
| [Cloud-Init Secrets](../hosts/cloud-init/secrets.md) | SSH key setup for cloud-init and Ansible |

### Provision Host

*Central management container documentation*

| Document | Purpose |
|----------|---------|
| [Provision Host Overview](../provision-host/index.md) | Central management container guide |
| [Kubernetes Management](../provision-host/kubernetes.md) | Kubernetes-specific management tools |
| [Rancher Desktop](../provision-host/rancher.md) | Rancher Desktop configuration |
| [Tools Reference](../provision-host/tools.md) | Command reference and usage patterns |

### Rules & Standards

*Development guidelines, workflows, and architectural standards*

| Document | Purpose |
|----------|---------|
| [Rules Overview](../rules/index.md) | Rules guide and index |
| [UIS Deployment System](../rules/kubernetes-deployment.md) | UIS CLI, service metadata, stacks, and deploy flow |
| [Provisioning](../rules/provisioning.md) | Ansible playbook patterns and testing standards |
| [Naming Conventions](../rules/naming-conventions.md) | File, resource, and identifier naming patterns |
| [Ingress & Traefik](../rules/ingress-traefik.md) | Traefik IngressRoute standards |
| [Git Workflow](../rules/git-workflow.md) | Git branching, commits, and PR standards |
| [Secrets Management](../rules/secrets-management.md) | Secrets management rules |
| [Development Workflow](../rules/development-workflow.md) | Development workflow and command execution |
| [Documentation Guide](../rules/documentation.md) | Documentation standards |
| [Documentation Legacy](../rules/documentation-legacy.md) | Legacy documentation standards (historical reference) |

### Reference

*Configuration, troubleshooting, and operational reference*

| Document | Purpose |
|----------|---------|
| [UIS CLI Reference](./uis-cli-reference.md) | Complete UIS command-line reference |
| [Service Dependencies](./service-dependencies.md) | Service dependency graph |
| [Kubernetes Manifests](./manifests.md) | Manifest file reference |
| [Secrets Management System](./secrets-management.md) | Secrets management system documentation |
| [Factory Reset](./factory-reset.md) | Factory reset and full verification guide |
| [Troubleshooting](./troubleshooting.md) | Troubleshooting guide for common issues |

### AI Development

*Guides for contributors using AI-assisted development*

| Document | Purpose |
|----------|---------|
| [Developing with AI](../ai-development/index.md) | AI-assisted development overview |
| [AI Development Workflow](../ai-development/workflow.md) | Workflow for AI-assisted contributions |
| [Creating Plans](../ai-development/creating-plans.md) | How to create implementation plans |

## Finding What You Need

### By Role

**Developers:**
- Start: [Installation](../getting-started/installation.md) → [Architecture](../getting-started/architecture.md) → [Provision Host](../provision-host/index.md)
- AI Development: [AI & ML Overview](../packages/ai/index.md)
- Authentication: [Identity Overview](../packages/identity/index.md)

**Infrastructure Engineers:**
- Start: [Architecture](../getting-started/architecture.md) → [Hosts](../hosts/index.md)
- Production: [Azure AKS](../hosts/azure-aks.md)
- Networking: [Traefik Rules](../rules/ingress-traefik.md)

**Architects:**
- Start: [Architecture](../getting-started/architecture.md) → [UIS Deployment System](../rules/kubernetes-deployment.md)
- Security: [Identity](../packages/identity/index.md) → [Secrets Management](./secrets-management.md)

**Data Scientists:**
- Start: [Analytics Overview](../packages/analytics/index.md)
- AI/ML: [AI Overview](../packages/ai/index.md) → [LiteLLM](../packages/ai/litellm.md)

### By Use Case

**Getting Started:**
1. [Installation Guide](../getting-started/installation.md) — Install and setup
2. [System Architecture](../getting-started/architecture.md) — Understand the system
3. [Provision Host](../provision-host/index.md) — Learn management tools

**Setting Up Authentication:**
1. [Identity Overview](../packages/identity/index.md) — Core SSO setup
2. [Auth10 Blueprints](../packages/identity/auth10.md) — Blueprint management
3. [Technical Implementation](../packages/identity/technical-implementation.md) — Integration details

**AI Development:**
1. [AI & ML Overview](../packages/ai/index.md) — Platform overview
2. [LiteLLM](../packages/ai/litellm.md) — LLM proxy setup
3. [Open WebUI](../packages/ai/openwebui.md) — Chat interface

**Production Deployment:**
1. [Hosts Overview](../hosts/index.md) — Deployment strategies
2. [Azure AKS](../hosts/azure-aks.md) — Azure production
3. [Networking Overview](../networking/index.md) — External access

**External Access:**
1. [Cloudflare Setup](../networking/cloudflare-setup.md) — Cloudflare tunnels
2. [Tailscale Setup](../networking/tailscale-setup.md) — VPN access
3. [Networking Overview](../networking/index.md) — Network architecture

## Getting Help

- **Technical Issues**: See [Troubleshooting Guide](./troubleshooting.md)
- **Architecture Questions**: Review [System Architecture](../getting-started/architecture.md)
- **Bug Reports**: Use GitHub issues in the main repository
- **Contributions**: Follow [Git Workflow Rules](../rules/git-workflow.md)

## Documentation Standards

All documentation follows the standards defined in:
- [Documentation Guide](../rules/documentation.md) — Documentation writing standards
- [Git Workflow Rules](../rules/git-workflow.md) — Git workflow and contribution standards

---

**Total Documentation**: 92 pages (excluding internal plans) | **Last Updated**: March 2026
