---
title: Azure AKS
sidebar_label: Azure AKS
sidebar_position: 2
---

# Azure AKS

Run UIS on Azure Kubernetes Service — Microsoft's managed Kubernetes offering. AKS is the production target for UIS in the cloud. Local development still uses Rancher Desktop; AKS is what you switch to when you need a real cloud cluster with public IPs, scaled storage, and autoscaling.

The whole novice path — from a fresh provision-host container to a running cluster with a deployed service — is **six commands** and takes about 7 minutes (5 of which is Azure provisioning the cluster).

## Prerequisites

| Local | Azure |
|---|---|
| Rancher Desktop running, Kubernetes enabled | A subscription you have **Contributor or Owner** on |
| The UIS provision-host container running (`./uis start`) | A Microsoft work/school account that can sign in interactively (device-code flow) |
| | If your role is just-in-time, **PIM activated** before running `uis platform up` (1–2 min to propagate) |
| | **vCPU quota** in the chosen region for the chosen VM size |

For the helpers.no nonprofit grant subscription specifically, the Contributor role is granted via group membership and active by default — no PIM step needed.

## Quick start — six commands

```bash
./uis pull                        # 1. get the latest provision-host image
./uis tools install azure-aks     # 2. installs azure-cli + opentofu
./uis platform init azure-aks     # 3. interactive wizard writes the config file
./uis platform up azure-aks       # 4. provisions the cluster end-to-end (~5 min)
./uis deploy nginx                # 5. verify with a real service
./uis platform down azure-aks     # 6. tear down when finished (cluster cost stops)
```

The sections below walk through what each command does, what output to expect, and the load-bearing checks at each step.

### 1. Pull the image, recycle the container

```bash
./uis pull
docker stop uis-provision-host 2>/dev/null; docker rm uis-provision-host 2>/dev/null
./uis start
```

The provision-host image carries the latest `uis platform ...` surface. After pull + recycle, `uis platform list` should report rancher-desktop as `✓ running (active)` (assuming Rancher Desktop is up on your host) — that's UIS auto-seeding the merged kubeconfig from your host's kubeconfig so you can use platform commands before any cloud provisioning runs.

```
$ ./uis platform list
Active: rancher-desktop

PLATFORM          STATUS
rancher-desktop   ✓ running  (active)    local k3s
azure-aks         · not initialized          (run './uis platform init azure-aks' to set up)
```

### 2. Install the cloud CLIs

`azure-cli` and `opentofu` aren't in the base image — they're optional tools. The `azure-aks` bundle installs both:

```bash
./uis tools install azure-aks
```

About 2 minutes the first time (most of it is the azure-cli install).

### 3. Set up the config file

```bash
./uis platform init azure-aks
```

The interactive wizard:
- Detects whether you're logged into Azure; runs `az login --use-device-code` if not.
- Lists the Azure subscriptions your account can see and asks you to pick one.
- Picks a default region (West Europe) and lets you override.
- Generates a globally-unique storage account name from your subscription ID.
- Writes the config to `.uis.secrets/cloud-accounts/azure-default.env` (gitignored).

Expected closing banner:

```
═══════════════════════════════════════════════════════════
 ✓ AKS setup ready
═══════════════════════════════════════════════════════════
  Subscription: Azure subscription 1
                (077d4d11-24e1-4fdc-a5f8-051eb6408208)
  Tenant:       780144c7-ffef-4e8f-93f2-18d3058eab0f
  Region:       westeurope
  Config:       .uis.secrets/cloud-accounts/azure-default.env

Next: ./uis platform up azure-aks
```

The path on the `Config:` line is shown host-relative — that's the file on your local disk, not a path inside the container. You can edit it directly to tweak any default. See the **Configuration reference** below for all the optional variables.

### 4. Provision the cluster

```bash
./uis platform up azure-aks
```

This chains three scripts: bootstrap the OpenTofu state backend → `tofu apply` → post-apply cluster configuration. About 7 minutes total (5 of which is Azure creating the AKS cluster).

The flow you'll see:

```
═══════════════════════════════════════════════════════════
 AKS cluster provisioning
 (uis platform up azure-aks)
 Subscription: 077d4d11-24e1-4fdc-a5f8-051eb6408208
 Region:       westeurope
═══════════════════════════════════════════════════════════

⚠  This will create or update Azure resources and may incur cost (~€1/day).
   Run './uis platform down azure-aks' to tear down when finished.

▶ 1/3 Bootstrap remote tofu state (Azure storage account + container)...
```

**Step 1/3** — bootstrap. Creates the state resource group + storage account + blob container. Idempotent on re-run. About 25 seconds the first time, 2 seconds when the state backend already exists.

If you're not logged into Azure (the container's `~/.azure` gets wiped by the recycle in step 1), bootstrap auto-triggers device-code login:

```
[INFO] Checking Azure login...
[WARNING] Not logged in — starting device code login...
To sign in, use a web browser to open the page https://login.microsoft.com/device and enter the code XXXXXXXXX to authenticate.
```

You don't need to run `az login` first — `up` handles it.

**Step 2/3** — `tofu apply`. Three resources: the AKS resource group, a Log Analytics workspace, and the cluster itself. The cluster create is the slow part (4–6 minutes depending on region).

**Step 3/3** — post-apply. Six sub-steps:

1. **Merge kubeconfig** — runs `ansible/playbooks/04-merge-kubeconf.yml`. The merged kubeconfig at `/mnt/urbalurbadisk/kubeconfig/kubeconf-all` ends up with both `azure-aks` and `rancher-desktop` contexts.
2. **Switch kubectl context** to azure-aks.
3. **Switch UIS target** — flips `cluster-config.sh` (`CLUSTER_TYPE=azure-aks`, `TARGET_HOST=azure-aks`) and the kubectl current-context together. Single shared writer — they can't silently diverge.
4. **Storage class aliases** — applies `platforms/azure-aks/manifests/000-storage-class-azure-alias.yaml`. Maps `local-path` and `microk8s-hostpath` to Azure Disk CSI so UIS service manifests work unchanged across rancher-desktop and AKS.
5. **Install Traefik** — via the shared `ansible/playbooks/003-setup-traefik.yml` playbook. Pinned chart v39.0.7 + proxy v3.6.13, matching the bundled k3s on Rancher Desktop.
6. **External IP** — waits up to 2 min for the Azure LoadBalancer to assign a public IP, prints it in the closing banner.

Expected closing banner:

```
========================================
POST-APPLY COMPLETE — CLUSTER READY
========================================

Cluster:        azure-aks
Nodes:          1
External IP:    20.126.163.208

Manage cluster:
  ./uis platform status azure-aks                   # state, external IP, cost
  ./uis platform down   azure-aks                   # tear down

═══════════════════════════════════════════════════════════
 ✓ AKS cluster is up
═══════════════════════════════════════════════════════════
  Try: kubectl get nodes
       ./uis deploy nginx

  Tear down: ./uis platform down azure-aks
```

After `up` completes, the active platform is `azure-aks`. The banner on every cluster-touching UIS command (`uis deploy`, `uis list`, `uis status`, etc.) will reflect that:

```
$ ./uis list 2>&1 | head -1
ℹ  Platform: azure-aks (reachable)
```

And `uis platform list` shows both contexts with `(active)` on azure-aks:

```
$ ./uis platform list
Active: azure-aks

PLATFORM          STATUS
rancher-desktop   ✓ running    local k3s
azure-aks         ✓ running  (active)    Azure AKS, k8s 1.32
```

### 5. Verify with `./uis deploy nginx`

```bash
./uis deploy nginx
```

This deploys a small nginx stack with a PVC, an IngressRoute (catch-all priority 1), and a public IP exposure via Traefik. First line you'll see is the banner:

```
ℹ  Platform: azure-aks (reachable)
```

(Banner on stderr.) The playbook explicitly resolves its target context from the merged kubeconfig, so the deploy lands in azure-aks — verified by the task message:

```
"msg": "Setting up Nginx on Kubernetes context: azure-aks"
```

Once `PLAY RECAP: ok=45 changed=13 failed=0 skipped=4` lands, smoke test from your host (replace with the External IP from step 4):

```bash
curl -sS http://<external-ip>/ | grep -E '<title|<h1'
```

Expected:

```
  <title>Welcome to UIS</title>
    <h1>Welcome to UIS</h1>
```

End-to-end: your laptop → public internet → Azure LoadBalancer → kube-system/traefik → default/nginx → PVC.

### 6. Tear down

```bash
./uis platform down azure-aks
```

You'll be prompted to type the cluster name to confirm (irreversible destroys aren't piped — F9 safety). About 3–4 minutes total: the AKS cluster, its Log Analytics workspace, and its resource group are destroyed; the state resource group is preserved by design (~€0.10/month, holds blob versions for re-creates).

Expected closing banner:

```
========================================
DESTROY COMPLETE
========================================

✅ Deleted cluster:        azure-aks
✅ Deleted resource group: rg-urbalurba-aks-weu
✅ Removed kubectl context

💾 State preserved in:     sa077d4d1124e14fdctf

💰 Estimated savings: ~€1/day (Standard_B2s_v2 x 1)

To recreate the cluster:
  ./uis platform up azure-aks

═══════════════════════════════════════════════════════════
 ✓ AKS cluster destroyed
═══════════════════════════════════════════════════════════
  Cluster cost stopped. The config file is preserved:
    .uis.secrets/cloud-accounts/azure-default.env

  To recreate the cluster with the same subscription + region:
    ./uis platform up azure-aks

  To fully reset (e.g. before switching tenants), delete the file:
    rm .uis.secrets/cloud-accounts/azure-default.env
```

The `[SUCCESS] cluster-config.sh + kubectl context reset to: rancher-desktop` line during teardown confirms that UIS has switched your active platform back to local — `uis platform list` after the destroy shows:

```
$ ./uis platform list
Active: rancher-desktop

PLATFORM          STATUS
rancher-desktop   ✓ running  (active)    local k3s
azure-aks         · configured, not running  (run './uis platform up azure-aks' to start it)
```

The env file `.uis.secrets/cloud-accounts/azure-default.env` is **preserved** — you can `uis platform up azure-aks` again later without re-running `init`. To fully reset (e.g. before switching tenants), delete the file.

## Configuration reference

All variables live in `.uis.secrets/cloud-accounts/azure-default.env`. The file is gitignored. `uis platform init azure-aks` writes the three required variables for you — the rest are optional overrides.

### Required

| Variable | What it is | How to find it |
|---|---|---|
| `AZURE_TENANT_ID` | GUID of your Microsoft Entra (Azure AD) tenant. | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | GUID of the subscription that pays for the cluster. | `az account show --query id -o tsv` |
| `AZURE_STATE_STORAGE_ACCOUNT` | Globally-unique storage account name for the OpenTofu state blob. Lowercase letters + digits, 3–24 chars. `init` derives this from the subscription ID. | `az storage account check-name --name <candidate> --query nameAvailable -o tsv` |

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
| `AZURE_AKS_STATE_RESOURCE_GROUP` | `rg-urbalurba-tfstate` | Holds the state storage account. Created once by bootstrap. Must not collide with `AZURE_AKS_RESOURCE_GROUP`. |
| `AZURE_AKS_STATE_CONTAINER` | `tfstate` | Blob container name inside the storage account. |
| `AZURE_AKS_STATE_KEY` | `aks/terraform.tfstate` | Blob name. The path-like syntax keeps room for future state files (e.g. `gke/terraform.tfstate`) in the same container. |

> **No password or service principal stored anywhere.** Bootstrap calls `az login --use-device-code` interactively if not already logged in; the token caches in `~/.azure/` inside the container. There is *nothing* in `kubernetes-secrets.yml` related to Azure infrastructure auth — that file is for cluster workloads.

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

`uis platform down azure-aks` deletes everything except the state resource group (`rg-urbalurba-tfstate` by default). That RG is intentionally preserved — it holds blob versions and ~€0.10/month of metadata. To wipe completely (e.g. between verification runs), `az group delete --name rg-urbalurba-tfstate --yes`.

For finer control, set `AZURE_AKS_NODE_SIZE="Standard_B1ms"` (1 vCPU, ~€15/month per node) for cheap testing, or override `AZURE_AKS_MAX_COUNT=1` to disable autoscaling.

> **Cost gate**: AKS bills while running. Always run `./uis platform down azure-aks` before walking away from the keyboard. Or use `./uis platform status azure-aks` to confirm whether the cluster is up.

## Troubleshooting

### `up` reports "Storage account name already in use"

Storage account names are *globally unique across all of Azure*. Pick a different `AZURE_STATE_STORAGE_ACCOUNT` in your env file and re-run `uis platform up azure-aks`. The bootstrap step is idempotent.

### `up` fails on `tofu plan` / `tofu apply` with "QuotaExceeded"

Not enough vCPU quota in the chosen region for the chosen VM size. Two fixes:

- **Increase quota**: Azure portal → Subscription → Usage + quotas → request increase. Usually instant for small bumps.
- **Pick a smaller VM**: set `AZURE_AKS_NODE_SIZE="Standard_B1ms"` (1 vCPU, ~€15/month per node) in your env file and re-run.

### `tofu plan` rejects `auto_scaling_enabled` or similar attribute

Provider version mismatch. The module pins `azurerm = "~> 4.0"`; a stale `.terraform.lock.hcl` from an older run may still be pinning 3.x. The script's `tofu init` already passes `-upgrade` to refresh the lock — re-run `uis platform up azure-aks` and the lock updates on the next init.

### Traefik external IP stuck `<pending>` for >5 min

AKS LoadBalancer provisioning failed. `kubectl describe svc traefik -n kube-system` shows events. Common causes: regional Azure issue (rare), or quota exhausted on public IPs in the subscription. If unrecoverable, `./uis platform down azure-aks` and re-create — usually faster than debugging Azure networking.

### `tofu destroy` leaves the RG behind

AKS auto-creates a `Microsoft.OperationsManagement/solutions` resource (ContainerInsights) in the cluster RG that's not in the OpenTofu state. The provider's `prevent_deletion_if_contains_resources = false` flag in `tofu/main.tf` should handle the orphan; if you still see RG-not-empty errors, force-delete:

```bash
az group delete --name rg-urbalurba-aks-weu --yes
```

### "Can I use a service principal instead of device-code?"

Yes — `azure-cli` accepts `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` (commented in the template). Useful for CI; not required for first-time interactive work.

## Direct script access (advanced)

The `uis platform <verb> azure-aks` flow chains the per-script files under `platforms/azure-aks/scripts/`:

| Script | What it does | Called by |
|---|---|---|
| `00-bootstrap-state.sh` | Creates the state RG + storage account + blob container. Idempotent. | Step 1/3 of `uis platform up` |
| `01-apply.sh` | `tofu init` + `tofu plan` + `tofu apply`. | Step 2/3 of `uis platform up` |
| `02-post-apply.sh` | Merge kubeconfig, flip UIS target, install Traefik, capture external IP. | Step 3/3 of `uis platform up` |
| `03-destroy.sh` | `tofu destroy` + cleanup of kubectl context + reset of `cluster-config.sh`. | `uis platform down` |

You can run them directly if you need to debug a specific step (e.g. re-run just the post-apply after fixing a Traefik issue without re-provisioning the cluster). Each script is self-contained and re-runnable. For day-to-day use, the `uis platform <verb>` wrappers are the right surface — they handle the chaining and the platform-list/use lockstep automatically.

## See also

- **[Platforms overview](./index.md)** — `uis platform list / use` mechanics, cluster targeting, the banner.
- **[CLI Reference — Platform](../reference/uis-cli-reference.md)** — full `uis platform` command reference.
- **[Tools](../reference/tools.md)** — `uis tools install azure-aks` and the underlying CLIs.
- **[Traefik](../services/networking/traefik.md)** — the cluster ingress controller installed during post-apply; chart and proxy version pinning rationale.
