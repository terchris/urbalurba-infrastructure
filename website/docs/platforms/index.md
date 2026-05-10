---
title: Platforms
sidebar_label: Overview
sidebar_position: 1
---

# Platforms

Where you run UIS. The provision-host container is the same everywhere; the cluster underneath swaps. Local development on a laptop, a real cloud cluster on Azure for production, or one of the legacy paths (multipass, Raspberry Pi, Azure VM) for older deployments.

## Supported (UIS CLI flow)

These platforms work end-to-end through the standard `./uis` command line. Cluster setup is automated by `platforms/<provider>/scripts/`; service deployment is identical to local-dev (`./uis deploy <service>`).

| Platform | Use case | Cluster setup | Status |
|---|---|---|---|
| [Rancher Desktop](./rancher-kubernetes.md) | Local development. Single-node k3s on your laptop. | Install [Rancher Desktop](https://rancherdesktop.io/) → enable Kubernetes → `./uis start`. No platform script. | ✅ Default |
| [Azure AKS](./azure-aks.md) | Production cloud cluster. | `platforms/aks/scripts/00-bootstrap-state.sh` → `01-apply.sh` → `02-post-apply.sh`. OpenTofu-driven. | ✅ Verified end-to-end (PR #149) |

After cluster setup, deployment is identical:

```bash
./uis deploy postgresql           # any single service
./uis stack install observability # a coordinated stack
./uis list                        # what's deployed where
```

## Legacy (not yet migrated)

These platforms have working code under `hosts/<provider>/` from earlier UIS iterations, but they haven't been migrated to the `platforms/` + UIS CLI shape yet. Their docs still describe the legacy `hosts/` script flow and carry a "not migrated" caution banner. Use at your own risk; expect rough edges.

| Platform | Use case | Code path | Notes |
|---|---|---|---|
| [Azure VM (MicroK8s)](./azure-microk8s.md) | Azure VM with MicroK8s instead of managed AKS. | `hosts/azure-microk8s/` | Pre-UIS-CLI deployment scripts. |
| [Multipass MicroK8s](./multipass-microk8s.md) | Local virtualised cluster. **Replaced by Rancher Desktop.** | `hosts/multipass-microk8s/` | Kept for historical reference. |
| [Raspberry Pi MicroK8s](./raspberry-microk8s.md) | Edge / ARM-based deployments. | `hosts/raspberry-microk8s/` | Manual provisioning, requires Tailscale for remote access. |

The migration of these to first-class `platforms/` + UIS CLI support is tracked under [INVESTIGATE-migrate-hosts-to-platforms.md](../ai-developer/plans/backlog/INVESTIGATE-migrate-hosts-to-platforms.md).

## How the UIS provision-host stays the same across platforms

Every platform target — local k3s, AKS, Azure VM, RPi — runs the same `uis-provision-host` container. The container holds:

- **`kubectl` + `helm` + `ansible`** built into the image — these don't change between targets.
- **A merged kubeconfig** at `/mnt/urbalurbadisk/kubeconfig/kubeconf-all` containing every cluster you've connected. Built by `ansible/playbooks/04-merge-kubeconf.yml` whenever you bring up a new cluster; consumed by every `./uis deploy <service>` invocation. The kubeconfig file lives in-container (not on the bind-mounted `.uis.secrets/` path) so `kubectl config use-context` writes are flock-safe on Rancher Desktop's lima VM.
- **Cluster-target indirection** via `.uis.extend/cluster-config.sh`. `TARGET_HOST` names the kubectl context that `./uis deploy <service>` will deploy to; AKS's `02-post-apply.sh` flips it to `azure-aks` on apply and back to `rancher-desktop` on destroy.
- **Optional cloud CLIs** (`azure-cli`, `aws-cli`, `gcp-cli`, `opentofu`) installed on demand via `./uis tools install <id>`. See [Tools](../reference/tools.md).

This is why a UIS service manifest written for Rancher Desktop deploys unchanged on AKS — the cluster differences are absorbed by the storage-class aliases and the merged kubeconfig, not by per-platform service definitions.

## Switching between clusters

Once you have multiple cluster contexts in your merged kubeconfig:

```bash
kubectl config get-contexts                 # list every cluster you've connected
kubectl config use-context rancher-desktop  # switch to local
kubectl config use-context azure-aks        # switch to cloud
kubectl config current-context              # show what kubectl is targeting
```

For UIS commands specifically (`./uis deploy <service>`, `./uis configure <service>`), the target is also gated by `cluster-config.sh`'s `TARGET_HOST`. The supported-platform scripts (`02-post-apply.sh`, `03-destroy.sh`) keep this in sync with `kubectl config current-context` automatically. If you need to flip manually:

```bash
sed -i \
  -e 's|^CLUSTER_TYPE=.*|CLUSTER_TYPE="azure-aks"|' \
  -e 's|^TARGET_HOST=.*|TARGET_HOST="azure-aks"|' \
  /mnt/urbalurbadisk/.uis.extend/cluster-config.sh
```

## See also

- **[Provision Host Overview](../advanced/provision-host/index.md)** — the management container that's identical across all platforms.
- **[Tools](../reference/tools.md)** — built-in vs installable CLIs (`azure-cli`, `opentofu`, etc.).
- **[How Deployment Works](../advanced/how-deployment-works.md)** — what `./uis deploy <service>` does under the hood.
