---
title: Azure AKS
sidebar_label: Azure AKS
sidebar_position: 2
---

# Azure AKS

Run UIS on Azure Kubernetes Service — Microsoft's managed Kubernetes offering. AKS is the production target for UIS in cloud (helpers.no's Microsoft nonprofit grant subscription, plus any other AKS subscription you have). Local development still uses Rancher Desktop; AKS is what you switch to when you need a real cloud cluster with public IPs, scaled storage, and autoscaling.

## What's in this directory tree

UIS provisions AKS via [OpenTofu](https://opentofu.org/) (the open-source Terraform fork). The shape that ships:

- **`platforms/azure-aks/scripts/`** — the four scripts you run, in order: `00-bootstrap-state.sh`, `01-apply.sh`, `02-post-apply.sh`, `03-destroy.sh`.
- **`platforms/azure-aks/tofu/`** — the IaC module (~92 lines). One Resource Group, one Log Analytics workspace, one AKS cluster with autoscaler enabled.
- **`manifests/003-traefik-config.yaml`** — Helm values for the Traefik ingress controller, pinned to chart v39.0.7 + proxy v3.6.13 (matches Rancher Desktop's bundled k3s — local-dev ↔ cloud parity).
- **`platforms/azure-aks/manifests/000-storage-class-azure-alias.yaml`** — aliases `local-path` and `microk8s-hostpath` (which UIS service manifests reference) to Azure Disk CSI, so service manifests work unchanged across rancher-desktop and AKS.

State (the OpenTofu `terraform.tfstate` blob) lives in an Azure Storage Account, separate Resource Group from the cluster. State persists across destroy/recreate cycles by design.

## Prerequisites

| Local | Azure |
|---|---|
| Rancher Desktop running, Kubernetes enabled | A subscription you have **Contributor or Owner** on |
| The UIS provision-host container running (`./uis start`) | A Microsoft work/school account that can sign in interactively (device-code flow) |
| `azure-cli` and `opentofu` installed in the container — see step 1 below | If your role is just-in-time, **PIM activated** before running `01-apply.sh` (1–2 min to propagate) |
| | **vCPU quota** in the chosen region for the chosen VM size |

For the helpers.no nonprofit grant subscription specifically, the Contributor role is granted via group membership and active by default — no PIM step needed.

## Quick start

Five steps from a fresh provision-host to a working cluster + verification.

### 1. Install the cloud CLIs in the provision-host

`azure-cli` and `opentofu` aren't in the base image — they're optional tools. See [Tools](../reference/tools.md) for the full catalogue.

```bash
./uis tools install azure-cli
./uis tools install opentofu
./uis tools list   # confirm both flip to ✅ Installed
```

### 2. Create your config file

Copy the gitignored template into `.uis.secrets/cloud-accounts/`:

```bash
cp provision-host/uis/templates/uis.secrets/cloud-accounts/azure.env.template \
   .uis.secrets/cloud-accounts/azure-default.env
```

Edit the new file. Only **three values are required** (everything else is commented and uses sensible defaults):

```bash
AZURE_TENANT_ID="<your-tenant-guid>"
AZURE_SUBSCRIPTION_ID="<your-subscription-guid>"
AZURE_STATE_STORAGE_ACCOUNT="<a-globally-unique-name>"   # 3–24 lowercase chars + digits
```

The full variable reference is below.

### 3. Bootstrap the OpenTofu state backend (one time per subscription)

Creates the state Resource Group + storage account + blob container. Idempotent — skips on re-run if already present:

```bash
./uis shell
cd /mnt/urbalurbadisk
az login --use-device-code
./platforms/azure-aks/scripts/00-bootstrap-state.sh
```

~30–60 seconds. Storage costs a few cents per month; survives cluster destroys.

### 4. Provision the cluster

```bash
./platforms/azure-aks/scripts/01-apply.sh
```

The script generates `terraform.tfvars` from your `.uis.secrets/cloud-accounts/azure-default.env`, runs `tofu init -upgrade -reconfigure` against the remote backend, prints the plan for review, and applies on `y`. Cluster comes up in 5–10 minutes.

### 5. Configure the cluster + verify

```bash
./platforms/azure-aks/scripts/02-post-apply.sh    # merges kubeconfig, flips UIS target, applies storage-class aliases, installs Traefik
./uis deploy nginx                           # the verification bar — in-cluster curl tests pass on a real AKS cluster
```

When done:

```bash
./platforms/azure-aks/scripts/03-destroy.sh
```

`03-destroy.sh` removes the cluster, its Resource Group, the Log Analytics workspace, and the LoadBalancer's public IP. The state Resource Group survives by design.

> **Cost gate**: AKS bills while running. Always run `03-destroy.sh` before walking away from the keyboard. Default cluster shape (`Standard_B2s_v2` × 1 with autoscaler max 3) is roughly €1–4/day depending on autoscaler activity. See *Cost* below.

For the detailed first-time walkthrough — variable-by-variable explanation, how to find every Azure GUID, what each script does and why — see **[PLAN-001b — AKS Manual Setup](../ai-developer/plans/backlog/PLAN-001b-aks-manual-setup.md)**.

## Configuration reference

All variables live in `.uis.secrets/cloud-accounts/azure-default.env`. The file is gitignored.

### Required

| Variable | What it is | How to find it |
|---|---|---|
| `AZURE_TENANT_ID` | GUID of your Microsoft Entra (Azure AD) tenant. | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | GUID of the subscription that pays for the cluster. | `az account show --query id -o tsv` |
| `AZURE_STATE_STORAGE_ACCOUNT` | Globally-unique storage account name for the OpenTofu state blob. Lowercase letters + digits, 3–24 chars. | `az storage account check-name --name <candidate> --query nameAvailable -o tsv` |

### Optional — cluster shape

All have sensible defaults; uncomment in your env file only to override.

| Variable | Default | What changes if you change it |
|---|---|---|
| `AZURE_AKS_LOCATION` | `westeurope` | Azure region. Pick what's nearest you geographically. |
| `AZURE_AKS_RESOURCE_GROUP` | `rg-urbalurba-aks-weu` | The RG holding the cluster + Log Analytics workspace. |
| `AZURE_AKS_CLUSTER_NAME` | `azure-aks` | Becomes both the cluster name AND the kubectl context name. Change to run multiple clusters side by side. |
| `AZURE_AKS_NODE_SIZE` | `Standard_B2s_v2` | VM SKU for the node pool. *(B2ms is gone in many regions/subscriptions; B2s_v2 is broadly allowed and similarly priced.)* |
| `AZURE_AKS_NODE_COUNT` | `1` | Initial node count; the autoscaler moves from this baseline. |
| `AZURE_AKS_MIN_COUNT` | `1` | Cluster autoscaler minimum. |
| `AZURE_AKS_MAX_COUNT` | `3` | Cluster autoscaler maximum. Caps the bill at 3× node cost. |
| `AZURE_AKS_OS_DISK_SIZE` | `30` | Per-node OS disk size in GB. |

### Optional — Azure tags for cost tracking

| Variable | Default |
|---|---|
| `AZURE_TAG_BUSINESS_OWNER` | Your `az ad signed-in-user` email |
| `AZURE_TAG_IT_OWNER` | Your `az ad signed-in-user` email |
| `AZURE_TAG_COST_CENTER` | `helpers-no` |

`tag_project` (`urbalurba-infrastructure`) and `tag_environment` (`Sandbox`) are baked into the scripts as constants.

### Optional — OpenTofu state backend layout

| Variable | Default | Notes |
|---|---|---|
| `AZURE_AKS_STATE_RESOURCE_GROUP` | `rg-urbalurba-tfstate` | Holds the state storage account. Created once by `00-bootstrap-state.sh`. Must not collide with `AZURE_AKS_RESOURCE_GROUP`. |
| `AZURE_AKS_STATE_CONTAINER` | `tfstate` | Blob container name inside the storage account. |
| `AZURE_AKS_STATE_KEY` | `aks/terraform.tfstate` | Blob name. The path-like syntax keeps room for future state files (e.g. `gke/terraform.tfstate`) in the same container. |

> **No password or service principal stored anywhere.** `01-apply.sh` calls `az login --use-device-code` interactively on first run; the token caches in `~/.azure/` inside the container. There is *nothing* in `kubernetes-secrets.yml` related to Azure infrastructure auth — that file is for cluster workloads.

## Cost

AKS itself (the control plane) is free on the Standard tier. You pay for:

| Resource | Approx cost (West Europe, 2026) |
|---|---|
| 1× `Standard_B2s_v2` node, 24/7 | ≈ €30/month / ≈ €1/day |
| 3× `Standard_B2s_v2` nodes (autoscaler max) | ≈ €100/month / ≈ €3/day |
| Public LoadBalancer + outbound IP | ≈ €5/month |
| Log Analytics workspace (first 5 GB free, then ~€2/GB) | typically negligible for a single test cluster |
| OS disk (30 GB managed disk per node) | ≈ €2/month per node |
| State storage account | ≈ €0.10/month |

`03-destroy.sh` deletes everything except the state RG. The state RG (`rg-urbalurba-tfstate` by default) is intentionally preserved — it holds blob versions and ~€0.10/month of metadata. To wipe completely (e.g. between verification runs), `az group delete --name rg-urbalurba-tfstate --yes`.

For finer control, set `AZURE_AKS_NODE_SIZE="Standard_B1ms"` (1 vCPU, ~€15/month per node) for cheap testing, or override `AZURE_AKS_MAX_COUNT=1` to disable autoscaling.

## What `02-post-apply.sh` does

After `01-apply.sh` provisions the cluster, post-apply gets it ready for UIS service deployments. Six steps:

1. **Merge kubeconfig** via `ansible/playbooks/04-merge-kubeconf.yml` — adds the new AKS context to the merged `kubeconf-all` so `kubectl config get-contexts` shows it alongside `rancher-desktop`. The merge writes to `/mnt/urbalurbadisk/kubeconfig/` (in-container, kubectl-flock-safe) and copies to the bind-mounted legacy path that ~100 consumer playbooks read from.
2. **Switch kubectl context** to the new AKS cluster.
3. **Switch UIS target** — sed-flips `cluster-config.sh` to `CLUSTER_TYPE=azure-aks`, `TARGET_HOST=$AZURE_AKS_CLUSTER_NAME` so subsequent `./uis deploy <service>` targets the AKS cluster instead of rancher-desktop.
4. **Apply storage-class aliases** from `platforms/azure-aks/manifests/000-storage-class-azure-alias.yaml`. Maps `local-path` and `microk8s-hostpath` to Azure Disk CSI. Without this, every UIS service that requests a `local-path` PVC would fail on AKS.
5. **Install Traefik** via the shared playbook `ansible/playbooks/003-setup-traefik.yml`. Pinned chart v39.0.7 + proxy v3.6.13 (matches the bundled k3s on Rancher Desktop, so local-dev tests map directly to cloud tests). The same playbook detects k3s-managed Traefik on rancher-desktop and skips the helm install — single source of truth across all UIS platforms.
6. **Wait for the LoadBalancer external IP** (up to 2 min).

`03-destroy.sh` reverses 1–3: removes the kubectl context, deletes the per-cluster kubeconfig file, cleans the merged `kubeconf-all`'s `azure-aks` entries (so bare `kubectl …` doesn't dial a dead API), and resets `cluster-config.sh` back to rancher-desktop.

## Troubleshooting

### "Storage account name already in use" during `00-bootstrap-state.sh`

Storage account names are *globally unique across all of Azure*. Pick a different `AZURE_STATE_STORAGE_ACCOUNT` and re-run. The script is idempotent.

### "QuotaExceeded" during `01-apply.sh`

Not enough vCPU quota in the chosen region for the chosen VM size. Two fixes:

- **Increase quota**: Azure portal → Subscription → Usage + quotas → request increase. Usually instant for small bumps.
- **Pick a smaller VM**: set `AZURE_AKS_NODE_SIZE="Standard_B1ms"` (1 vCPU, ~€15/month per node) in your env file and re-run.

### `tofu plan` rejects `auto_scaling_enabled` or similar attribute

Provider version mismatch. The module pins `azurerm = "~> 4.0"`; a stale `.terraform.lock.hcl` from an older run may still be pinning 3.x. The script's `tofu init` already passes `-upgrade` to refresh the lock — re-run `01-apply.sh` and the lock updates on the next init.

### Traefik external IP stuck `<pending>` for >5 min

AKS LoadBalancer provisioning failed. `kubectl describe svc traefik -n kube-system` shows events. Common causes: regional Azure issue (rare), or quota exhausted on public IPs in the subscription. If unrecoverable, `03-destroy.sh` and re-create — usually faster than debugging Azure networking.

### `tofu destroy` leaves the RG behind

AKS auto-creates a `Microsoft.OperationsManagement/solutions` resource (ContainerInsights) in the cluster RG that's not in the OpenTofu state. The provider's `prevent_deletion_if_contains_resources = false` flag in `tofu/main.tf` should handle the orphan; if you still see RG-not-empty errors, force-delete:

```bash
az group delete --name "$AZURE_AKS_RESOURCE_GROUP" --yes
```

### Bare `kubectl …` after destroy fails with DNS-lookup errors

The merged `kubeconf-all` may still have the destroyed cluster's `current-context`. The destroy script tries to clean this up; if it's still pointing at `azure-aks`, run:

```bash
kubectl --kubeconfig /mnt/urbalurbadisk/kubeconfig/kubeconf-all config use-context rancher-desktop
```

### "Can I use a service principal instead of device-code?"

Yes — `azure-cli` accepts `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` (commented in the template). Useful for CI; not required for first-time interactive work.

## Multi-cluster context switching

After `02-post-apply.sh`'s kubeconfig merge, you have `rancher-desktop` and `azure-aks` (or whatever you named it) side by side in `kubectl`:

```bash
kubectl config get-contexts                 # list both
kubectl config use-context rancher-desktop  # local
kubectl config use-context azure-aks        # cloud
```

`./uis deploy <service>` targets whichever cluster `cluster-config.sh` currently names — `02-post-apply.sh` flips it on apply; `03-destroy.sh` flips it back.

## See also

- **[PLAN-001b — AKS Manual Setup](../ai-developer/plans/backlog/PLAN-001b-aks-manual-setup.md)** — detailed first-time walkthrough; explains every variable, every script, and every Azure-side step (PIM, region picking, vCPU quota check, resource provider registration).
- **[Traefik](../services/networking/traefik.md)** — the cluster ingress controller installed by `02-post-apply.sh`; chart and proxy version pinning rationale.
- **[Tools](../reference/tools.md)** — `./uis tools install azure-cli` / `./uis tools install opentofu`.
- **[Rancher Desktop](./rancher-kubernetes.md)** — the local cluster you switch back to with the kubeconfig context.
