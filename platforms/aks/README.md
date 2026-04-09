# platforms/aks

OpenTofu-based provisioning for Azure Kubernetes Service (AKS).

This is the **platform layer** — it creates everything needed before services
(PostgreSQL, Redis, etc.) are deployed via UIS. It replaces the old `hosts/azure-aks/` scripts.

## What this provisions (Step 1)

- Azure Resource Group
- AKS cluster with:
  - System-assigned managed identity
  - Azure CNI + Azure network policy
  - Cluster autoscaler (min/max nodes)
  - Log Analytics monitoring addon
- Storage class aliases (`local-path`, `microk8s-hostpath` → Azure Disk)
- Traefik ingress controller

ACR, Key Vault, Workload Identity, and VNet come in later steps.

## Prerequisites

- Running inside the `provision-host` container
- `tofu` (OpenTofu) installed in the container
- `helm` installed in the container
- Azure CLI logged in: `az login --tenant <tenant-id> --use-device-code`

## First-time setup

```bash
# 1. Copy and fill in your config
cp platforms/aks/azure-aks-config.sh-template platforms/aks/azure-aks-config.sh
# Edit platforms/aks/azure-aks-config.sh

# 2. Bootstrap the state storage (one-time, survives cluster destroy/recreate)
./platforms/aks/scripts/00-bootstrap-state.sh

# 3. Create the cluster
./platforms/aks/scripts/01-apply.sh

# 4. Configure the cluster (storage classes, Traefik)
./platforms/aks/scripts/02-post-apply.sh
```

## Daily operations

```bash
# Switch kubectl context to AKS
kubectl config use-context azure-aks

# Deploy services
./uis deploy <service>
./uis stack install <stack>

# Tear down cluster (saves ~$5/day)
./platforms/aks/scripts/03-destroy.sh

# Recreate from state
./platforms/aks/scripts/01-apply.sh
```

## File structure

```
platforms/aks/
├── azure-aks-config.sh-template   # Copy → azure-aks-config.sh, fill in values
├── azure-aks-config.sh            # Your config (git-ignored)
├── tofu/
│   ├── backend.tf                 # Remote state in Azure Blob Storage
│   ├── main.tf                    # Resource group + AKS cluster
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example   # Documents what 01-apply.sh generates
├── manifests/
│   └── 000-storage-class-azure-alias.yaml
└── scripts/
    ├── 00-bootstrap-state.sh      # One-time: create state storage account
    ├── 01-apply.sh                # tofu init → plan → apply → write kubeconfig
    ├── 02-post-apply.sh           # Storage classes + Traefik
    └── 03-destroy.sh              # tofu destroy + kubeconfig cleanup
```

## State backend

OpenTofu state is stored in Azure Blob Storage (`rg-urbalurba-tfstate`).
This resource group is **not** managed by OpenTofu and survives cluster destroy/recreate.
Blob versioning is enabled — previous state versions are recoverable.

## Adding to .gitignore

```
platforms/aks/azure-aks-config.sh
platforms/aks/tofu/terraform.tfvars
platforms/aks/tofu/tfplan
platforms/aks/tofu/.terraform/
```
