# INVESTIGATE: Platform Provisioning Layer

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Created**: 2026-04-09
**Updated**: 2026-05-07
**Status**: ACTIVE — AKS Step 1 *drafts* merged to `main` via PR #120 (2026-04-09) but **never run end-to-end**. Production AKS deployments today still go through `hosts/azure-aks/` (the bash + `az aks create` path). Direction (per maintainer, 2026-05-07): make `platforms/aks/` the production path, with helpers.no's Microsoft nonprofit grant as the funding source and atlas-on-AKS as the load-bearing end-state. AKS-only focus; other platforms (gke, eks, microk8s-vm/metal/rpi) deferred until a concrete consumer surfaces.

---

## Background

UIS currently has a `hosts/` directory containing bash scripts and `az` CLI commands
that set up Kubernetes clusters on various targets. These scripts predate a consistent
platform model and have grown organically — each target has different conventions,
different secret handling approaches, and different levels of automation maturity.

The idea is to introduce a `platforms/` layer that replaces `hosts/` with a consistent,
OpenTofu-based approach for cloud targets and an Ansible/cloud-init approach for VM and
bare-metal targets. Every platform gets a working Kubernetes cluster that is ready to
receive UIS services.

The first concrete output of this investigation is `platforms/aks/` (Step 1),
which provisions AKS via OpenTofu with Azure Blob Storage remote state.

---

## What is the Platform Layer?

The platform layer is everything that must exist **before** `./uis deploy <service>` can run.
It is not part of UIS service management — it is the substrate that UIS runs on.

For a cloud-managed cluster (AKS, GKE, EKS), the platform layer:
- Creates cloud resources (resource group, cluster, networking)
- Writes a kubeconfig
- Applies cross-cluster compatibility shims (storage class aliases)
- Installs Traefik (ingress)

For a VM or bare-metal cluster (MicroK8s), the platform layer:
- Generates and applies cloud-init
- Creates the VM or configures the physical machine
- Bootstraps MicroK8s
- Connects via Ansible for post-boot configuration

The platform layer is intentionally separate from the UIS service layer. Once
`02-post-apply.sh` (or equivalent) finishes, the cluster is identical from UIS's
perspective regardless of what created it.

---

## Target Platforms

| Target | Type | Tooling | Status |
|--------|------|---------|--------|
| `aks` | Azure managed K8s | OpenTofu + bash | Step 1 in progress |
| `gke` | GCP managed K8s | OpenTofu + bash | Not started |
| `eks` | AWS managed K8s | OpenTofu + bash | Not started |
| `microk8s-vm` | Ubuntu VM (any cloud) | cloud-init + Ansible | Exists in `hosts/` — needs migration |
| `microk8s-metal` | Ubuntu bare metal | cloud-init + Ansible | Exists partially in `hosts/` |
| `microk8s-rpi` | Raspberry Pi | cloud-init + Ansible | Exists partially in `hosts/` |

---

## Directory Structure (Target)

```
platforms/
  aks/                    ← Azure Kubernetes Service (OpenTofu)
    azure-aks-config.sh-template
    tofu/
      main.tf
      variables.tf
      outputs.tf
      backend.tf
      terraform.tfvars.example
    manifests/
      000-storage-class-azure-alias.yaml
    scripts/
      00-bootstrap-state.sh
      01-apply.sh
      02-post-apply.sh
      03-destroy.sh
    README.md

  gke/                    ← Google Kubernetes Engine (OpenTofu)
    gke-config.sh-template
    tofu/
    scripts/
    README.md

  eks/                    ← Elastic Kubernetes Service (OpenTofu)
    eks-config.sh-template
    tofu/
    scripts/
    README.md

  microk8s-vm/            ← Ubuntu VM on any cloud (Ansible + cloud-init)
    config.sh-template
    cloud-init/
    ansible/
    scripts/
    README.md

  microk8s-metal/         ← Ubuntu bare metal (Ansible + cloud-init)
    config.sh-template
    cloud-init/
    ansible/
    scripts/
    README.md

  microk8s-rpi/           ← Raspberry Pi (Ansible + cloud-init)
    config.sh-template
    cloud-init/
    ansible/
    scripts/
    README.md
```

---

## Design Decisions

### OpenTofu for cloud targets, Ansible/cloud-init for VM/bare-metal

Cloud-managed clusters (AKS, GKE, EKS) are a natural fit for OpenTofu:
- Declarative resource definitions
- Remote state (Azure Blob, GCS, S3)
- Plan/apply/destroy lifecycle
- Managed identity and role assignments are first-class

VM and bare-metal targets are not a good fit for OpenTofu because:
- The "resource" is a physical machine or a VM that already exists
- Configuration is imperative (run these commands in this order)
- Ansible and cloud-init are already proven for this use case
- The existing `hosts/` scripts for MicroK8s are largely correct and just need migration

### Single config file per platform

Each platform has one `*-config.sh` file (git-ignored) that is sourced by all scripts.
This mirrors the existing `azure-aks-config.sh` pattern and means there is one place
to change values — no separate tfvars editing, no env file juggling.

### State backend from day one

All OpenTofu platforms use remote state (Azure Blob, GCS bucket, S3 bucket).
Local state is never used in production. State storage is created by a one-time
`00-bootstrap-state.sh` script and survives cluster destroy/recreate cycles.

### Script numbering convention

```
00-bootstrap-state.sh   ← one-time pre-requisite
01-apply.sh             ← create / update
02-post-apply.sh        ← configure (storage, ingress)
03-destroy.sh           ← tear down
```

This makes the execution order self-documenting and consistent across all cloud platforms.

### Relationship to hosts/

`hosts/` is not deleted. It is kept as a reference and fallback while `platforms/` is built
out. Migration happens platform by platform:

1. `platforms/aks/` replaces `hosts/azure-aks/` and `hosts/install-azure-aks.sh`
2. `platforms/microk8s-vm/` replaces `hosts/azure-microk8s/`, `hosts/multipass-microk8s/`
3. `platforms/microk8s-rpi/` replaces `hosts/raspberry-microk8s/`
4. `hosts/` is archived or deleted after all platforms are migrated

---

## AKS — Step-by-Step Plan

AKS is the first platform. The current scope is deliberately minimal: get an AKS cluster up that behaves like the Rancher Desktop substrate UIS already targets, so atlas-on-AKS can run with no Azure-specific add-ons. Anything that doesn't have a Rancher-Desktop equivalent is deferred until there's a concrete need (see *Future hardening* below).

### Step 1: Minimal working cluster — drafts merged 2026-04-09, **not yet verified end-to-end**

Scope:

- Resource group
- AKS cluster (matches original `az aks create` flags)
- Azure Blob remote state
- Storage class aliases
- Traefik via Helm in `02-post-apply.sh`
- **`kubernetes-secrets.yml` applied in `02-post-apply.sh`** — same flow as Rancher Desktop and `hosts/azure-aks/02-azure-aks-setup.sh`. No Key Vault, no Azure-specific secret integration. (Currently *missing* from the tofu draft; the Step 1 PLAN must add it.)

Other gap-analysis findings vs `hosts/azure-aks/` (2026-05-07):

- Quota pre-flight check (`hosts/azure-aks/check-aks-quota.sh`) is not ported. Acceptable to let `tofu apply` fail loudly on first run and address the gap only if it bites.
- PIM check is weaker (single-shot prompt vs 3-attempt loop). Cosmetic; defer unless first-run friction surfaces.
- External-IP curl reachability test is missing from `02-post-apply.sh`. The nginx in-cluster connectivity test (verification bar below) covers the load-bearing case; the curl test is optional polish.
- `--generate-ssh-keys` is intentionally absent from the tofu — `azurerm_kubernetes_cluster` generates them for Linux node pools by default.

Code lives in `platforms/aks/`. The `feature/platform-aks-opentofu` branch was merged and the stale remote was deleted.

**Verification bar for "Step 1 done":** a tester runs the four scripts (`00-bootstrap-state.sh` → `01-apply.sh` → `02-post-apply.sh`) end-to-end against a real Azure subscription, then runs `./uis deploy nginx` and the deploy completes successfully — including the built-in connectivity tests in `020-setup-nginx.yml` (steps 13 and 15) which spin up a curl-test pod and fetch the test file + index page via cluster-internal DNS. That single command exercises networking, pod scheduling, storage class aliases, service DNS, and IngressRoute application, so it's a sufficient end-to-end signal without needing additional services for the verification.

### Step 2: Operational tooling (cost control)

The bash path includes two operational scripts that have no `platforms/aks/` equivalent:

- `hosts/azure-aks/manage-aks-cluster.sh` (682 lines) — start / stop / scale operations so the cluster only costs money while in use
- `hosts/azure-aks/toggle-internet-access.sh` — gate the external IP

These are not provisioning correctness, but they are the difference between "cluster burns the Microsoft grant 24/7" and "cluster only costs while atlas is being worked on." Out of scope for Step 1; lands as a follow-up plan once Step 1 verifies.

### Future hardening (deferred until concrete need)

The original roadmap had Steps 2–4 (ACR + Key Vault, Workload Identity, Networking). These are all deferred — the goal for now is parity with the Rancher Desktop developer substrate, not Azure-grade hardening. Each item below moves out of "deferred" only when a concrete consumer pulls on it.

| Capability | What it would add | Why deferred |
|---|---|---|
| Azure Key Vault | Centralised secret storage outside the cluster | UIS already has a working secrets workflow (`kubernetes-secrets.yml`); adding Key Vault is Azure-specific complexity with no current consumer |
| Azure Container Registry (ACR) | Private container registry with managed-identity pull | UIS images come from public registries (GHCR / Docker Hub); no current need for a private registry |
| Workload Identity | OIDC-federated identity for pods to access Azure services | The original motivation was Key Vault access; without Key Vault, no consumer remains |
| Networking hardening | Dedicated VNet, private cluster, NSG rules | The default AKS networking works for getting atlas running; private cluster + NSG matter only when a security review demands it |

> **Other platforms (gke, eks, microk8s-vm/metal/rpi) are also deferred.** The Target Platforms table and Directory Structure sketch above keep the multi-platform vision visible, but no per-platform question lists are maintained here until a concrete consumer surfaces. AKS is the focus.

---

## Shared Concerns Across All Platforms

### kubeconfig merge

All platforms write a `*-kubeconf` file. The `04-merge-kubeconf.yml` Ansible playbook
merges these into `kubeconf-all`. This must keep working as platforms are added.

The current `./uis` wrapper bypasses this by symlinking `kubeconf-all` to the host
kubeconfig. This should be restored to a real merge as part of the target management
work (see INVESTIGATE-remote-deployment-targets.md).

### .gitignore

All platform config files and generated tofu files must be git-ignored:

```gitignore
# Platform configs (contain secrets)
platforms/*/azure-aks-config.sh
platforms/*/gke-config.sh
platforms/*/eks-config.sh
platforms/*/config.sh

# OpenTofu generated files
platforms/*/tofu/terraform.tfvars
platforms/*/tofu/tfplan
platforms/*/tofu/.terraform/
platforms/*/tofu/.terraform.lock.hcl
```

### Traefik values

`02-post-apply.sh` references `/mnt/urbalurbadisk/manifests/003-traefik-config.yaml`.
This is shared across all cluster types. It should remain in `manifests/` and be
referenced from all platform post-apply scripts.

---

## Open Questions

1. Should `platforms/` have its own `README.md` at the top level explaining the concept?
2. Should OpenTofu modules be shared across `aks/`, `gke/`, `eks/` (e.g., a shared `modules/traefik-helm/`) or kept separate for simplicity?
3. What is the right home for the Ansible merge playbook — should each platform call it, or should there be a shared `platforms/common/` area?
4. Should `hosts/` be deleted immediately after a platform is migrated, or kept until all platforms are done?
5. How does this interact with the `./uis target` command work described in INVESTIGATE-remote-deployment-targets.md? The `platforms/` scripts are the implementation behind `./uis target create` and `./uis target bootstrap`.

---

## Related

- [INVESTIGATE-remote-deployment-targets.md](INVESTIGATE-remote-deployment-targets.md) — target management UX (`./uis target` commands)
- [INVESTIGATE-provision-host-tools-and-auth.md](INVESTIGATE-provision-host-tools-and-auth.md) — tool installation and cloud auth inside provision-host
- `platforms/aks/README.md` — AKS platform documentation
- `hosts/azure-aks/` — original bash scripts being replaced
