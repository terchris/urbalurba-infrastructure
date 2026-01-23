# Host Configuration Templates

Templates for Kubernetes cluster configurations. These are copied to the user's `.uis.extend/hosts/` folder.

## Host Types

| Type | Description | Creates VM? | Needs SSH? | Needs Tailscale? |
|------|-------------|-------------|------------|------------------|
| `managed/` | Cloud-managed Kubernetes (AKS, GKE, EKS) | No | No | No |
| `cloud-vm/` | VM in cloud running K8s | Yes | Yes | Yes |
| `physical/` | Physical device running K8s | No | Yes | Yes |
| `local/` | Local development environment | No | No | No |

## Available Templates

### managed/
- `azure-aks.conf.template` - Azure Kubernetes Service
- `gcp-gke.conf.template` - Google Kubernetes Engine (future)
- `aws-eks.conf.template` - Amazon EKS (future)

### cloud-vm/
- `azure-microk8s.conf.template` - Azure VM with MicroK8s

### physical/
- `raspberry-pi.conf.template` - Raspberry Pi with MicroK8s

### local/
- `rancher-desktop.conf.template` - Rancher Desktop (default)

## Usage

```bash
# List available templates
./uis host add

# Add a host from template
./uis host add azure-aks

# List configured hosts
./uis host list
```

## File Structure

Host configs are copied to user's `.uis.extend/hosts/<type>/`:

```
.uis.extend/
└── hosts/
    ├── managed/
    │   └── my-azure-aks.conf
    ├── cloud-vm/
    │   └── my-dev-vm.conf
    └── local/
        └── rancher-desktop.conf
```

## Configuration Format

Each `.conf` file is a bash-sourceable file with:
- `CREDENTIALS` - Reference to secrets file (for cloud providers)
- Provider-specific settings (resource group, cluster name, etc.)

Example:
```bash
# Which credentials to use (from .uis.secrets/cloud-accounts/)
CREDENTIALS="azure-default"

# Cluster settings
CLUSTER_NAME="my-cluster"
LOCATION="westeurope"
```
