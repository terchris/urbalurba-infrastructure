# Ansible Documentation

## Overview

Ansible is used as the primary automation tool for provisioning and managing the Urbalurba infrastructure. It handles everything from initial host setup to service deployment and configuration management.

## Directory Structure

```
ansible/
├── ansible.cfg           # Global Ansible configuration
├── inventory.yml         # Main inventory file
├── inventory/           # Inventory files for different environments
│   └── rancher-desktop.yml
└── playbooks/          # Ansible playbooks
    ├── utility/        # Utility playbooks
    └── *.yml          # Main playbooks
```

## Configuration

### ansible.cfg

The global Ansible configuration file (`ansible.cfg`) contains:
- Inventory file location
- Private key configuration
- SSH connection settings
- Roles path configuration

### Inventory Management

The system uses dynamic inventory management:
- Main inventory file: `inventory.yml`
- Environment-specific inventories in `inventory/` directory
- Supports multiple environments (local, cloud, etc.)

## Playbook Categories

Playbooks are organized by their purpose and numbered for execution order:

### 1. Initial Setup (0xx)
- `01-configure_provision-host.yml`: Configures the provision host
- `02-update-ansible-inventory.yml`: Updates inventory configuration
- `03-copy-microk8s-config.yml`: Configures MicroK8s
- `04-merge-kubeconf.yml`: Merges Kubernetes configurations
- `05-install-helm-repos.yml`: Sets up Helm repositories

### 2. Storage and Files (01x-02x)
- `010-move-hostpath-storage.yml`: Configures host path storage
- `020-setup-nginx.yml`: Sets up Nginx
- `020-setup-web-files.yml`: Configures web files
- `020-setup-tstweb-nginx.yml`: Sets up test web Nginx

### 3. Database Services (03x-04x)
- `040-setup-mongodb.yml`: MongoDB setup
- `040-database-postgresql.yml`: PostgreSQL setup
- `050-setup-redis.yml`: Redis setup

### 4. Message Queues and Search (05x-08x)
- `060-setup-elasticsearch.yml`: Elasticsearch setup
- `080-setup-rabbitmq.yml`: RabbitMQ setup

### 5. API Management and UI (09x-20x)
- `090-setup-gravitee.yml`: Gravitee API Management
- `200-setup-open-webui.yml`: Open WebUI setup

### 6. Network Configuration (7xx)
- `750-setup-network-cloudflare-tunnel.yml`: Cloudflare tunnel setup
- `751-deploy-network-cloudflare-tunnel.yml`: Cloudflare tunnel deployment
- `net2-setup-tailscale-cluster.yml`: Tailscale cluster setup
- `net2-expose-tailscale-service.yml`: Tailscale service exposure

### 7. ArgoCD Management (22x)
- `220-setup-argocd.yml`: ArgoCD setup
- `argocd-register-app.yml`: Register ArgoCD applications
- `argocd-remove-app.yml`: Remove ArgoCD applications

### 8. Administration (64x)
- `640-adm-pgadmin.yml`: pgAdmin setup
- `641-adm-pgadmin.yml`: pgAdmin configuration

## Usage

The Ansible playbooks are not meant to be run manually. Instead, they are automatically executed by the provision host scripts in the following order:

1. **Initial Setup**
   - Called by `provision-host-provision.sh`
   - Sets up the basic infrastructure
   - Configures the provision host environment

2. **Service Deployment**
   - Called by `provision-host-01-cloudproviders.sh`
   - Deploys cloud provider tools
   - Configures cloud provider access

3. **Kubernetes Setup**
   - Called by `provision-host-02-kubetools.sh`
   - Sets up Kubernetes tools
   - Configures cluster access

4. **Infrastructure Deployment**
   - Called by `provision-host-03-net.sh`
   - Deploys network components
   - Configures services

5. **Helm Repository Setup**
   - Called by `provision-host-04-helmrepo.sh`
   - Configures Helm repositories
   - Sets up package management

The scripts ensure that playbooks are executed in the correct order and with the proper environment variables and configurations. This automation ensures consistent deployment and reduces the risk of manual errors.

