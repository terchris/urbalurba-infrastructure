# Provision Host for Kubernetes

**Purpose**: User guide for managing and deploying applications on Kubernetes clusters using the Urbalurba automated provisioning system.

**Target Audience**: Users who want to deploy, activate, or manage services on their Kubernetes cluster.

## Overview

The provision-host container provides a complete automated deployment system for Kubernetes applications. Simply run `./uis start && ./uis provision` and all active services deploy automatically in the correct order.


See also [overview-system-architecture.md](../getting-started/architecture.md) 

**Key Benefits**:
- ✅ **Fully Automated**: One command deploys entire cluster
- ✅ **Dependency Management**: Services deploy in correct order automatically
- ✅ **Easy Service Management**: Move scripts in/out of `not-in-use/` folders to control what gets deployed when the cluster is built
- ✅ **Safe Removal**: Removal scripts are protected from accidental execution

**For Technical Details**: See [Rules for Automated Kubernetes Deployment](../rules/kubernetes-deployment.md)

## Service Categories

Services are organized by category to ensure proper deployment order. Each category contains setup and removal scripts for different applications.

**Current Service Categories**:

```plaintext
/mnt/urbalurbadisk/provision-host/kubernetes/
├── 01-core/
│   ├── 020-setup-nginx.sh
│   └── not-in-use
├── 02-databases/
│   ├── 05-setup-postgres.sh
│   └── not-in-use/
│       ├── 04-setup-mongodb.sh
│       └── 08-setup-mssql.sh
├── 03-queues/
│   ├── 06-setup-redis.sh
│   └── not-in-use/
│       └── 08-setup-rabbitmq.sh
├── 04-search/
│   └── not-in-use/
│       └── 07-setup-elasticsearch.sh
├── 05-apim/
│   └── not-in-use/
│       └── 09-setup-gravitee.sh
├── 06-management/
│   └── not-in-use/
│       └── 03-setup-pgadmin.sh
├── 07-ai/
│   ├── 01-setup-litellm-openwebui.sh
│   └── not-in-use/
│       └── 02-setup-open-webui.sh
├── 08-development/
│   ├── 02-setup-argocd.sh
│   └── not-in-use
├── 09-network/
│   ├── 01-tailscale-net-start.sh
│   └── not-in-use
├── 10-datascience/
│   └── not-in-use/
│       ├── unity-catalog setup scripts
│       └── jupyter setup scripts
├── 11-monitoring/
│   └── not-in-use/
│       └── monitoring setup scripts
├── 12-auth/
│   ├── 01-setup-authentik.sh
│   └── not-in-use/
├── not-used-apps/
│   └── 04-cloud-setup-log-monitor.sh
└── provision-kubernetes.sh
```

## How Automated Deployment Works

When you run `./uis start && ./uis provision`, it automatically calls the deployment system which:

1. **Deploys Core Systems First**: Networking, storage, DNS infrastructure
2. **Then Databases**: PostgreSQL, Redis, and other data services
3. **Then Applications**: AI services, authentication, monitoring, etc.
4. **Provides Progress Updates**: Shows what's being deployed and any issues
5. **Generates Summary Report**: Complete status of all deployments

## Managing Active Services

**🎛️ Control What Gets Deployed**:

Each category has a `not-in-use/` folder containing optional services. You control your cluster configuration by moving scripts:

- **📁 Active Services**: Scripts in the category folder (e.g., `07-ai/01-setup-litellm-openwebui.sh`)
- **📁 Inactive Services**: Scripts in `not-in-use/` folder (e.g., `07-ai/not-in-use/02-setup-open-webui.sh`)

**Technical Details**: See [Active vs Inactive Management](../rules/kubernetes-deployment.md#active-vs-inactive-management) in the rules documentation.

## Quick Start Guide

### 🚀 Deploy Everything (Recommended)

The easiest way to get a complete cluster:

```bash
# From your host machine in the repository root:
./uis start && ./uis provision
```

This automatically:
1. Sets up the provision-host container
2. Deploys all active services in dependency order
3. Provides a complete working cluster

### 🎯 Deploy Individual Services

If you only want to deploy specific services manually:

```bash
# Access the provision-host container:
docker exec -it provision-host bash

# Deploy a specific service:
cd /mnt/urbalurbadisk/provision-host/kubernetes/07-ai
./01-setup-litellm-openwebui.sh rancher-desktop
```

## Declarative Cluster Configuration

The system is designed to build a **complete, reproducible cluster** every time. Your repository configuration determines exactly what services get deployed automatically.

### 🎯 How It Works

**The repository is your cluster blueprint**:
- Services in category folders → Deploy automatically during cluster build
- Services in `not-in-use/` folders → Available but not deployed
- Every `./uis start && ./uis provision` creates the exact same cluster based on your current configuration

### ⚙️ Configure Your Cluster

**To include a service in automatic deployment**:
```bash
# Move setup script to category folder (from your host machine):
cd provision-host/kubernetes/02-databases
mv not-in-use/04-setup-mongodb.sh ./

# Now MongoDB deploys automatically on every cluster rebuild
./uis start && ./uis provision
```

**To exclude a service from automatic deployment**:
```bash
# Move setup script to not-in-use folder:
cd provision-host/kubernetes/02-databases
mv 04-setup-mongodb.sh not-in-use/

# Now MongoDB won't deploy automatically
./uis start && ./uis provision
```

### 🚀 Manual Service Deployment

**Deploy a service without changing automatic configuration**:
```bash
# Run script directly from not-in-use folder:
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/02-databases/not-in-use
./04-setup-mongodb.sh rancher-desktop
```

**Remove a deployed service**:
```bash
# Run removal script (always kept in not-in-use for safety):
docker exec -it provision-host bash
cd /mnt/urbalurbadisk/provision-host/kubernetes/02-databases/not-in-use
./04-remove-mongodb.sh rancher-desktop
```

### 🔄 Benefits of This Approach

- ✅ **Reproducible**: Same cluster configuration every rebuild
- ✅ **Version Controlled**: Your cluster config is in git
- ✅ **Flexible**: Test services manually before adding to automatic deployment
- ✅ **Safe**: Removal scripts never run automatically

## Available Services

The platform includes a comprehensive set of services organized by category:

| Category | Active Services | Available (Inactive) Services |
|----------|----------------|------------------------------|
| **🔧 Core Systems** | Nginx | |
| **🗄️ Databases** | PostgreSQL, Redis | MongoDB, MySQL, MSSQL |
| **🔍 Search & Queues** | | Elasticsearch, RabbitMQ |
| **🚪 API Management** | | Gravitee |
| **⚡ Management Tools** | | pgAdmin, phpMyAdmin |
| **🤖 AI Services** | LiteLLM + OpenWebUI | OpenWebUI (standalone) |
| **🔄 Development** | ArgoCD | |
| **🌐 Network** | Tailscale | |
| **🔐 Authentication** | Authentik | Keycloak |

**Legend**:
- **Active Services**: Deploy automatically with `./uis start && ./uis provision`
- **Available Services**: In `not-in-use/` folders, can be activated by moving to parent directory

## Access Your Services

After deployment, access services via:

- **Local Development**: `http://service-name.localhost` (e.g., `http://authentik.localhost`)
- **External Access**: Configure via Cloudflare tunnels or Tailscale
- **Port Forward**: `kubectl port-forward svc/service-name local-port:service-port -n namespace`

## Technical Reference

For developers and advanced users:
- **📋 [Automated Deployment Rules](../rules/kubernetes-deployment.md)** - How the orchestration system works
- **🔧 [Provisioning Rules](../rules/provisioning.md)** - How to write deployment scripts
- **📖 [Provision Host Overview](./index.md)** - Complete platform documentation
