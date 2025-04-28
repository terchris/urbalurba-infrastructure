# Provision Host for Kubernetes

This document explains the automated process for provisioning and configuring software on Kubernetes clusters in the Urbalurba-infrastructure.

## Overview

The provisioning system uses a structured approach to install and configure applications on Kubernetes clusters. It follows a sequential execution pattern organized by numbered directories and scripts to ensure dependencies are properly managed.

## Directory Structure

Software installation is organized in numbered directories within the `/mnt/urbalurbadisk/provision-host/kubernetes` path. Each directory contains numbered shell scripts that perform specific installation or configuration tasks.

Current directory structure:

```plaintext
/mnt/urbalurbadisk/provision-host/kubernetes/
├── 01-core-systems/
│   ├── 020-setup-nginx.sh
│   └── not-in-use
├── 02-databases/
│   ├── 05-cloud-setup-postgres.sh
│   └── not-in-use/
│       └── 04-setup-mongodb.sh
├── 03-queues/
│   └── not-in-use/
│       ├── 06-setup-redis.sh
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
│   └── not-in-use/
│       └── 02-setup-open-webui.sh
├── 08-development/
│   ├── 02-setup-argocd.sh
│   └── not-in-use
├── 09-network/
│   ├── 01-tailscale-net-start.sh
│   └── not-in-use
├── export-cluster-status.sh
├── not-used-apps/
│   └── 04-cloud-setup-log-monitor.sh
├── provision-host-kubernetes-readme.md
└── provision-kubernetes.sh
```

## Execution Flow

The `provision-kubernetes.sh` script automates the provisioning process with the following flow:

1. Directories are processed in numerical order (e.g., `01-core-systems`, then `02-databases`, etc.)
2. Within each directory, scripts are executed in numerical order
3. All scripts receive the target host as a parameter
4. Execution continues even if individual scripts fail, but errors are tracked
5. A summary report is generated after all scripts are executed

Inside each folder there is a folder named `not-in-use`. This folder contains scripts that are not currently in use. You can descide what the initial state of the urbalurba-infrastructure should be by moving the files in and out of the `not-in-use` folder.

## Using the Provisioning System

### Prerequisites

Before using the provisioning system:

Ensure a functioning Kubernetes cluster is available (MicroK8s in most cases)

### Running the Provisioning

To provision a cluster:

```bash
cd /mnt/urbalurbadisk
./provision-kubernetes.sh [target-host]
```

Where `[target-host]` is the name of your target Kubernetes host (e.g., `azure-microk8s` or `multipass-microk8s`). If omitted, it defaults to `multipass-microk8s`.

### Adding New Applications

To add new applications to the provisioning:

1. Create a script in the appropriate numbered directory or create a new directory if needed
2. Name your script with a numeric prefix (e.g., `05-setup-new-app.sh`)
3. Ensure your script accepts a target host parameter
4. Make the script executable: `chmod +x 05-setup-new-app.sh`

### Application Dependencies

Many applications depend on others to function properly. The numerical ordering of directories and scripts helps manage these dependencies:

- **Application Stack Dependencies**:
  - `pgadmin` (in 06-management) depends on `postgres` (in 02-databases)
  - `gravitee` (in 05-apim) depends on `mongodb` (in 02-databases) and `elasticsearch` (in 04-search)
  - Web services may depend on multiple database services

The provisioning system executes scripts in numerical order to ensure dependencies are installed first. If you need to add an application with specific dependencies, ensure it runs after its dependencies by using an appropriate numeric prefix.

### Managing Inactive Applications

Each numbered directory contains a `not-in-use` folder that stores scripts that are not currently part of the active provisioning process. To activate these:

1. Move the script from the `not-in-use` folder to the parent directory
2. The script will automatically be included in the next provisioning run

For example, to activate MongoDB:

```bash
mv /mnt/urbalurbadisk/provision-host/kubernetes/02-databases/not-in-use/04-setup-mongodb.sh /mnt/urbalurbadisk/provision-host/kubernetes/02-databases/
```

To deactivate an application, simply move its script back to the `not-in-use` folder of its respective directory.

### Installed Applications

The current setup includes the following applications:

#### Core Systems (01-core-systems)
- **Nginx**: Web server and reverse proxy (active)
- **MongoDB**: NoSQL document database (not in use)

#### Databases (02-databases)
- **PostgreSQL**: Relational database (active)
- **MongoDB**: NoSQL document database (not in use)

#### Queues (03-queues)
- **Redis**: In-memory data store/cache (not in use)
- **RabbitMQ**: Message broker (not in use)

#### Search (04-search)
- **Elasticsearch**: Search and analytics engine (not in use)

#### API Management (05-apim)
- **Gravitee**: API management platform (not in use)

#### Management Tools (06-management)
- **pgAdmin**: PostgreSQL administration and management tool (not in use)

#### AI Services (07-ai)
- **Open WebUI**: AI interface platform (not in use)

#### Development Tools (08-development)
- **ArgoCD**: GitOps continuous delivery tool (active)

#### Network Services (09-network)
- **Tailscale**: Secure networking solution (active)
