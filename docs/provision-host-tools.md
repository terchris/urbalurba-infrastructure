# Provision Host Container Documentation

## Overview

The provision host container is a comprehensive Docker container that serves as the central management environment for the Urbalurba infrastructure. It contains all necessary tools for managing Kubernetes clusters, cloud providers, and infrastructure automation.

## Key Features

- **Multi-Cloud Management**: Full support for AWS, Azure, Google Cloud, Oracle Cloud, and Terraform
- **Kubernetes Tools**: kubectl, Helm, k9s, and Ansible with Kubernetes modules
- **Networking**: Cloudflare tunnels and Tailscale VPN capabilities
- **Automation**: Ansible playbooks and infrastructure as code with Terraform
- **Cross-Platform**: Supports both x86_64 and ARM64 architectures
- **Developer Tools**: GitHub CLI, Python, yq/jq for YAML/JSON processing
- **Pre-configured**: Ansible inventory, Helm repositories, and kubeconfig management

## Container Architecture

### Base Image
- **Ubuntu 22.04 LTS**: Provides a stable, long-term support base
- **User**: Runs as `ansible` user with sudo privileges
- **Working Directory**: `/mnt/urbalurbadisk`

### Pre-installed Base Tools
The container comes with essential tools pre-installed:
- Git, Python3, pip
- curl, wget, jq, yq
- Network utilities (ping, netcat, dnsutils, traceroute)
- vim, bash-completion

## Provisioned Tools and Software

After the container is created, it's provisioned with additional tools through a series of scripts:

### 1. Core Software (`provision-host-00-coresw.sh`)
- **GitHub CLI (gh)**: GitHub repository management and automation
- Supports both x86_64 and aarch64 architectures

### 2. Cloud Provider Tools (`provision-host-01-cloudproviders.sh`)

The container supports ALL major cloud providers with their official CLIs:

#### Azure CLI
- **Resource Management**: VMs, Storage, Networking, AKS
- **Authentication**: Service principals, managed identities, interactive login
- **DevOps Integration**: Azure DevOps, pipelines, artifacts
- **Database Services**: CosmosDB, SQL Database, PostgreSQL
- **AI/ML Services**: Azure ML, Cognitive Services
- **Monitoring**: Application Insights, Log Analytics
- **Bicep**: Can be installed with `az bicep install` for Infrastructure as Code (alternative to ARM templates)

#### AWS CLI (v2)
- **Compute**: EC2, Lambda, ECS, EKS
- **Storage**: S3, EBS, EFS
- **Database**: RDS, DynamoDB, Aurora
- **Networking**: VPC, Route53, CloudFront
- **IAM**: Users, roles, policies, MFA
- **Infrastructure**: CloudFormation, CDK support
- **Monitoring**: CloudWatch, X-Ray

#### Google Cloud SDK (gcloud)
- **Compute**: Compute Engine, GKE, Cloud Run, Functions
- **Storage**: Cloud Storage, Filestore
- **Database**: Cloud SQL, Spanner, Firestore
- **BigData**: BigQuery (bq command), Dataflow, Pub/Sub
- **AI/ML**: Vertex AI, AutoML
- **Operations**: Cloud Monitoring, Logging
- **IAM**: Service accounts, roles, permissions

#### Oracle Cloud Infrastructure (OCI) CLI
- **Compute**: Instances, container instances
- **Database**: Autonomous DB, MySQL, NoSQL
- **Networking**: VCN, load balancers, FastConnect
- **Storage**: Block volumes, object storage, file storage
- **Identity**: Compartments, policies, groups
- **Kubernetes**: OKE (Oracle Kubernetes Engine)
- **Installed in isolated Python venv for compatibility**

#### Terraform
- **Multi-Cloud Support**: Works with 300+ providers
- **Infrastructure as Code**: Declarative configuration
- **State Management**: Remote state, locking, versioning
- **Module Support**: Reusable infrastructure components
- **Plan & Apply**: Preview changes before applying
- **Import Existing**: Bring existing infrastructure under management
- **Supports**: AWS, Azure, GCP, OCI, Kubernetes, and more

### 3. Kubernetes Tools (`provision-host-02-kubetools.sh`)

#### Ansible
- Configuration management and automation
- Kubernetes module support
- Custom playbooks for service deployment
- Pre-configured with:
  - Inventory at `/mnt/urbalurbadisk/ansible/inventory/hosts`
  - Roles path at `/mnt/urbalurbadisk/ansible/roles`
  - Host key checking disabled for automation

#### kubectl
- Kubernetes cluster management
- Multi-context support
- Rancher Desktop and MicroK8s compatibility

#### Helm
- Kubernetes package management
- Chart repository management
- Values file templating

#### k9s
- Terminal-based Kubernetes UI
- Real-time cluster monitoring
- Resource management interface

### 4. Networking Tools (`provision-host-03-net.sh`)

#### Cloudflared
- Cloudflare Tunnel client
- Zero-trust networking
- Secure tunnel creation and management

#### Tailscale
- Mesh VPN solution
- Peer-to-peer secure networking
- MagicDNS support
- Note: Installed but requires separate configuration

### 5. Helm Repositories (`provision-host-04-helmrepo.sh`)
Pre-configured repositories:
- **Bitnami**: Production-ready charts for databases, web apps, and more
- **Runix**: pgAdmin and other administrative tools
- **Gravitee**: API management platform charts

## Directory Structure

```
/mnt/urbalurbadisk/
├── ansible/                 # Ansible playbooks and roles
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── manifests/               # Kubernetes manifests
├── provision-host/          # Provisioning scripts
│   └── kubernetes/         # Kubernetes setup scripts
├── secrets/                # Secure storage (gitignored)
├── kubeconfig/             # Kubernetes configurations
└── topsecret/              # Sensitive configurations
```

## Usage

### Accessing the Container

```bash
# Access interactive shell
docker exec -it provision-host bash

# Run commands directly
docker exec provision-host kubectl get pods -A
```

### Cloud Provider Authentication

#### Azure
```bash
az login
az account set --subscription "subscription-name"
```

#### AWS
```bash
aws configure
# Or use environment variables
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
```

#### Google Cloud
```bash
gcloud auth login
gcloud config set project PROJECT_ID
```

#### Oracle Cloud
```bash
oci setup config
```

### Kubernetes Management

```bash
# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context rancher-desktop

# Deploy with Helm
helm install myapp bitnami/postgresql

# Run Ansible playbook
ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/setup.yml
```

## Container Lifecycle

### Building the Container
```bash
cd provision-host-rancher/
docker build -t provision-host:latest .
```

### Running the Container
```bash
docker run -d \
  --name provision-host \
  -v ${HOME}/.kube:/home/ansible/.kube \
  -v ${PWD}:/mnt/urbalurbadisk \
  provision-host:latest
```

### Provisioning After Creation
```bash
# Inside the container or via docker exec
cd /mnt/urbalurbadisk/provision-host/
./provision-host-00-coresw.sh
./provision-host-01-cloudproviders.sh all
./provision-host-02-kubetools.sh
./provision-host-03-net.sh
./provision-host-04-helmrepo.sh
```

## Environment Variables

- `RUNNING_IN_CONTAINER=true`: Set automatically, used by scripts to detect container environment
- `KUBECONFIG`: Points to merged kubeconfig file
- `PATH`: Includes user's local bin directory

## Security Considerations

### Credentials Management
- Cloud credentials should be mounted as volumes or set via environment variables
- Use Kubernetes secrets for sensitive data
- Never commit credentials to git

### Network Security
- Container runs with limited privileges
- Use Tailscale or Cloudflare tunnels for secure access
- SSH keys should be mounted from host when needed

## Troubleshooting

### Common Issues

#### 1. Permission Denied
```bash
# Switch to root temporarily if needed
docker exec -u root provision-host bash
```

#### 2. Kubernetes Context Issues
```bash
# Verify kubeconfig
kubectl config view
# Check current context
kubectl config current-context
```

#### 3. Cloud CLI Authentication
- Ensure credentials are properly mounted or configured
- Check token expiration and refresh as needed

#### 4. Tool Not Found
- Verify provisioning scripts have been run
- Check PATH includes `/home/ansible/.local/bin`

## Maintenance

### Updating Tools
```bash
# Update cloud CLIs
az upgrade
aws --version  # Check for updates
gcloud components update

# Update Kubernetes tools
helm repo update
# kubectl is typically updated via snap or direct download
```

### Container Updates
1. Update Dockerfile if base image changes needed
2. Rebuild container with new tag
3. Re-run provisioning scripts for tool updates

## Best Practices

1. **Version Control**: Keep provisioning scripts in git
2. **Idempotency**: Ensure scripts can be run multiple times safely
3. **Documentation**: Document any custom configurations
4. **Backup**: Backup important configurations and secrets
5. **Security**: Regularly update tools and base image for security patches

## Architecture Support

The container and all provisioned tools support:
- x86_64 (AMD64)
- aarch64 (ARM64)

This ensures compatibility with both Intel/AMD and Apple Silicon machines.

## Integration with CI/CD

The provision host container can be used in CI/CD pipelines:
- GitLab CI: Use as a base image for jobs
- Jenkins: Run as a Jenkins agent
- GitHub Actions: Use in self-hosted runners

## Related Documentation

- [Provision Host Setup](./provision-host-readme.md)
- [Kubernetes Provisioning](./provision-host-kubernetes-readme.md)
- [Rancher Desktop Integration](./provision-host-rancher-readme.md)