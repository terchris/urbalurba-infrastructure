# Provision Host for Kubernetes

This document explains the automated process for provisioning and configuring software on Kubernetes clusters in the Urbalurba environment.

## Overview

The provisioning system uses a structured approach to install and configure applications on Kubernetes clusters. It follows a sequential execution pattern organized by numbered directories and scripts to ensure dependencies are properly managed.

## Directory Structure

Software installation is organized in numbered directories within the `/mnt/urbalurbadisk/provision-host/kubernetes` path. Each directory contains numbered shell scripts that perform specific installation or configuration tasks.

Current directory structure:

```plaintext
/mnt/urbalurbadisk/provision-host/kubernetes/
├── 01-default-apps/
│   ├── 02-setup-nginx.sh
│   ├── 04-setup-mongodb.sh
│   ├── 05-cloud-setup-postgres.sh
│   ├── 06-setup-redis.sh
│   ├── 07-setup-elasticsearch.sh
│   ├── 08-setup-rabbitmq.sh
│   └── 09-setup-gravitee.sh
├── 02-adm-apps/
│   └── 03-setup-pgadmin.sh
├── 03-user-apps/
│   └── 01-setup-web-services.sh
└── not-used-apps/
    └── 04-cloud-setup-log-monitor.sh
```

## Execution Flow

The `provision-kubernetes.sh` script automates the provisioning process with the following flow:

1. Directories are processed in numerical order (e.g., `01-default-apps`, then `02-adm-apps`, etc.)
2. Within each directory, scripts are executed in numerical order
3. All scripts receive the target host as a parameter
4. Execution continues even if individual scripts fail, but errors are tracked
5. A summary report is generated after all scripts are executed

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
  - `pgadmin` (in 02-adm-apps) depends on `postgres` (in 01-default-apps)
  - `gravitee` (in 01-default-apps) depends on `mongodb` and `elasticsearch`
  - Web services (in 03-user-apps) may depend on multiple database services

The provisioning system executes scripts in numerical order to ensure dependencies are installed first. If you need to add an application with specific dependencies, ensure it runs after its dependencies by using an appropriate numeric prefix.

### Managing Inactive Applications

The `not-used-apps` directory stores scripts that are not currently part of the active provisioning process. To activate these:

1. Move the script to the appropriate numbered directory
2. The script will automatically be included in the next provisioning run

For example, to activate log monitoring:

```bash
mv /mnt/urbalurbadisk/provision-host/kubernetes/not-used-apps/04-cloud-setup-log-monitor.sh /mnt/urbalurbadisk/provision-host/kubernetes/01-default-apps/
```

### Installed Applications

The current setup includes the following applications:

#### Core Services (01-default-apps)
- **Nginx**: Web server and reverse proxy
- **MongoDB**: NoSQL document database
- **PostgreSQL**: Relational database
- **Redis**: In-memory data store/cache
- **Elasticsearch**: Search and analytics engine
- **RabbitMQ**: Message broker
- **Gravitee**: API management platform

#### Admin Tools (02-adm-apps)
- **pgAdmin**: PostgreSQL administration and management tool

#### User Applications (03-user-apps)
- **Web Services**: Custom web applications and services
