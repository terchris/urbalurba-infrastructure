# INVESTIGATE: Remote Deployment Targets & Target Management

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Related**: [INVESTIGATE-topsecret-cleanup](../completed/INVESTIGATE-topsecret-cleanup.md), [STATUS-service-migration](../completed/STATUS-service-migration.md), [INVESTIGATE-provision-host-tools-and-auth.md](INVESTIGATE-provision-host-tools-and-auth.md)
**Created**: 2026-02-22 (merged with PLAN-006-target-host-management on 2026-02-26)
**Updated**: 2026-03-12
**Status**: INVESTIGATION COMPLETE

## Background

The UIS system currently targets local Rancher Desktop. However, the codebase also contains scripts for provisioning remote servers and edge devices. These scripts predate the UIS system and still reference `topsecret/` for secrets. They require separate planning and real infrastructure testing before their secrets paths can be migrated.

Additionally, users have no easy way to see which cluster they're deploying to or switch between targets.

Secrets handling is also a core part of this investigation.

Today there is a clear UIS secrets system for values that are generated into Kubernetes and deployed into the cluster via `urbalurba-secrets`. However, remote-target and VM workflows also need secrets that are used by the `uis-provision-host` container itself during provisioning, authentication, connectivity, and bootstrap.

This means the target work must define:

- how the old pre-UIS secret patterns map to the current UIS structure
- which secrets belong to the **cluster-deployed** secrets system
- which secrets belong to the **`uis-provision-host` runtime/provisioning** environment
- where those provision-host-only secrets should live in `.uis.secrets/`
- how users should create, edit, validate, and troubleshoot them

Without that definition, target management risks mixing two separate concerns:

1. secrets for workloads deployed **into Kubernetes**
2. secrets needed by **UIS itself** to create hosts, authenticate to cloud providers, join Tailscale, fetch kubeconfig, and bootstrap targets

This investigation was extended on 2026-03-12 to cover:
- A refined `target`-based UX for remote deployment destinations
- How `.uis.extend/` and `.uis.secrets/` are used by the current `uis-provision-host` container
- How secrets should be handled for `uis-provision-host` versus cluster-deployed workloads
- Whether older helper scripts for the old `provision-host` container are still active

Tool installation and provider authentication inside `uis-provision-host` are now split into:

- [INVESTIGATE-provision-host-tools-and-auth.md](INVESTIGATE-provision-host-tools-and-auth.md)

---

## Part 1: Target Management UX (from PLAN-006)

### Problem

Users have no easy way to:
1. See which Kubernetes cluster they're deploying to
2. Switch between different targets (rancher-desktop, azure-aks, etc.)
3. Understand the relationship between UIS hosts and kubectl context

Currently:
- Local development works by default on `rancher-desktop`
- `.uis.extend/cluster-config.sh` defaults to:
  - `CLUSTER_TYPE="rancher-desktop"`
  - `TARGET_HOST="rancher-desktop"`
- User must manually manage kubectl context
- `./uis host list` shows configured hosts but not the active target
- No synchronization between UIS and kubectl context

### Quick Fix Already Implemented

Added target cluster display to `./uis status`:
```
Target cluster: rancher-desktop
```

### Refined UX Decision

The user-facing concept should be **target**, not **host**.

Rationale:
- `target` matches the user's mental model: "Where will `./uis deploy` go?"
- It fits both local clusters and managed clusters like AKS
- It avoids overloading `host` for things that are not really hosts (for example, AKS)

### Proposed Target Commands

Minimum recommended command set:

1. `./uis target` - Show current active target
2. `./uis target list` - List available targets and show which one is active
3. `./uis target add <template> --name <name>` - Create a target config from a template
4. `./uis target setup <name>` - Guided setup for tools, auth, kubeconfig, and validation
5. `./uis target use <name>` - Make a configured target active

Optional follow-up commands:

1. `./uis target bootstrap <name>` - Prepare the cluster for UIS workloads (Traefik, storage aliases, secrets, validation)
2. `./uis target create <name>` - Create cloud resources for a target that does not exist yet
3. `./uis target generate <name>` - Generate cloud-init for cloud VM or physical targets
4. `./uis target verify <name>` - Validate connectivity and UIS prerequisites without switching active target

### Implementation Requirements

1. **Keep Rancher Desktop as the zero-config default**
2. **Track active target** in `.uis.extend/active-target`
3. **Keep target configuration separate from activation**
4. **Sync kubectl context** when target changes
5. **Validate target exists** before switching
6. **Show target in commands** that deploy or interact with the cluster
7. **Handle multiple kubeconfigs** in `.uis.secrets/generated/kubeconfig/`
8. **Use the provision-host tools/auth system** to satisfy target-specific tool and provider prerequisites during `target setup`
9. **Do not silently switch targets**

### User Flow

```bash
# Fresh user on local machine
./uis target
# Output: Current target: rancher-desktop

# Add a remote target
./uis target add azure-aks --name aks-dev
# Output: Created .uis.extend/targets/managed/aks-dev.conf

# Fill in resource group / cluster / credentials reference
$EDITOR .uis.extend/targets/managed/aks-dev.conf

# Guided setup
./uis target setup aks-dev
# Checks:
# - required target tools detected
# - missing tools can be installed in uis-provision-host
# - az login
# - subscription selected
# - kubeconfig fetched/refreshed
# - cluster reachable

# Activate it
./uis target use aks-dev
# Output: Current target set to aks-dev

# Prepare cluster for UIS
./uis target bootstrap aks-dev

# Deploy a service there
./uis deploy whoami
```

### UX Rule: Configure First, Activate Second

Target commands should follow this lifecycle:

1. `target add` - create config only
2. `target setup` - install tools, authenticate, fetch kubeconfig, validate
3. `target use` - switch active deployment target
4. `target bootstrap` - prepare the cluster for UIS services
5. `deploy` - deploy services to the active target

This avoids accidental switching and keeps failure modes easy to understand.

### Files to Modify

- `provision-host/uis/manage/uis-cli.sh` - Add target commands
- `provision-host/uis/lib/uis-hosts.sh` - Current host-template logic to adapt or wrap
- `uis` wrapper - Pass target commands through
- `.uis.extend/cluster-config.sh` - Default target handling today

### Dependencies

- Requires kubeconfig files for each target in `.uis.secrets/generated/kubeconfig/`
- Target or host templates should generate appropriate kubeconfig entries
- Requires a clear mapping between:
  - target config in `.uis.extend/`
  - credentials in `.uis.secrets/`
  - active target state in `.uis.extend/active-target`
- Depends on [INVESTIGATE-provision-host-tools-and-auth.md](INVESTIGATE-provision-host-tools-and-auth.md) for provider-tool installation and authentication behavior

---

## Part 1b: Config and Secrets Model for Targets

The current `uis-provision-host` container already uses the right folder split for target management:

- `.uis.extend/` = safe project configuration
- `.uis.secrets/` = sensitive values and generated artifacts

The canonical description of `.uis.secrets/` now lives in:

- `website/docs/contributors/architecture/secrets.md`

This investigation should therefore focus on the **target-management implications** of that secrets model rather than trying to redefine the full `.uis.secrets/` structure here.

### `.uis.extend/` should store

- Active target marker (`active-target`)
- Cluster config (`cluster-config.sh`)
- Enabled services (`enabled-services.conf`)
- Target definitions (new `targets/` folder recommended)

### `.uis.secrets/` should store

- Cloud account credentials (`cloud-accounts/`)
- Service keys like Tailscale / Cloudflare (`service-keys/`)
- SSH keys for VM and edge provisioning (`ssh/`)
- Local network credentials where relevant (`network/`)
- Generated kubeconfigs (`generated/kubeconfig/`)
- Generated cloud-init output (`generated/ubuntu-cloud-init/`)
- Generated Kubernetes secrets (`generated/kubernetes/`)

`api-keys/` exists in the current structure, but based on the architecture documentation it should be treated as legacy/unclear and not as the primary basis for new target-management design.

### Important current behavior

- The current `./uis` wrapper mounts `.uis.extend/` to `/mnt/urbalurbadisk/.uis.extend`
- The current `./uis` wrapper mounts `.uis.secrets/` to `/mnt/urbalurbadisk/.uis.secrets`
- `paths.sh` resolves these locations consistently for both host-side and container-side code
- Many playbooks already use `.uis.secrets/generated/kubeconfig/kubeconf-all`
- The current `./uis` wrapper starts the container with host networking, which may allow the container to reach tailnet IPs through the host machine's Tailscale connection

This means the target-management work should build on the existing `.uis.extend/` / `.uis.secrets/` model rather than invent a new configuration system.

---

## Part 1b.1: Secrets Handling Findings

### Current UIS Secret Model

The architecture documentation now makes the current UIS split explicit:

1. **Generated cluster/application secrets**
   - Source of truth: `.uis.secrets/secrets-config/00-common-values.env.template`
   - Rendered to: `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`
   - Applied to cluster as `urbalurba-secrets`
   - Used by Kubernetes workloads and by scripts that read values back from `urbalurba-secrets`

2. **Local provisioning secrets**
   - Stored as dedicated files under `.uis.secrets/`
   - Examples:
     - `.uis.secrets/cloud-accounts/azure-default.env`
     - `.uis.secrets/service-keys/tailscale.env`
     - `.uis.secrets/ssh/id_rsa_ansible`
   - Intended for UIS itself rather than for direct Kubernetes secret generation

The architecture doc also clarifies the operational rule:

- edit `secrets-config/` for cluster-secret source values
- never edit `generated/` directly
- treat other folders under `.uis.secrets/` as dedicated runtime/provisioning inputs when that pattern is established

For target-management work, that means the question is no longer "should `.uis.secrets/` contain both cluster and provision-host secrets?" The answer is yes. The real design question is which specific values belong in:

- the cluster-secret pipeline under `secrets-config/`
- dedicated runtime folders such as `cloud-accounts/`, `ssh/`, `service-keys/`, and `network/`
- generated output folders such as `generated/kubeconfig/` and `generated/ubuntu-cloud-init/`

### Important Finding: Tailscale Secret Handling Is Currently Inconsistent

There are currently **two** apparent places for Tailscale bootstrap secrets:

1. `.uis.secrets/service-keys/tailscale.env`
   - Created automatically by `provision-host/uis/lib/uis-hosts.sh` for targets that require Tailscale
   - Exposed by `get_tailscale_key_path()` in `paths.sh`

2. `TAILSCALE_SECRET` and related values in `.uis.secrets/secrets-config/00-common-values.env.template`
   - Generated into `urbalurba-secrets`
   - Read back by cloud-init generation and Tailscale networking scripts

### Who Uses `.uis.secrets/service-keys/tailscale.env`?

Current code review found:

- The file is **created/scaffolded** by `uis-hosts.sh`
- A path helper exists for it in `paths.sh`
- Documentation and previous plans mention it
- But no active runtime consumer was found that actually reads `TAILSCALE_AUTH_KEY` from this file during target or networking operations

In other words:

- `service-keys/tailscale.env` appears to be a **prepared local secret file**
- but the currently active Tailscale workflows appear to use `TAILSCALE_SECRET` from the generated Kubernetes secret pipeline instead

### Evidence of Actual Current Consumption

- `cloud-init/create-cloud-init.sh` injects `URB_TAILSCALE_SECRET_VARIABLE` using `extract_kubernetes_secret "TAILSCALE_SECRET"`
- `networking/tailscale/802-tailscale-tunnel-deploy.sh` reads `TAILSCALE_SECRET` from `urbalurba-secrets` in the cluster
- Tailscale OAuth/API flows also read `TAILSCALE_CLIENTID`, `TAILSCALE_CLIENTSECRET`, `TAILSCALE_TAILNET`, and `TAILSCALE_DOMAIN` from `urbalurba-secrets`

### Assessment

The result is a split model:

| Secret location | Current role | Assessment |
|-----------------|--------------|------------|
| `.uis.secrets/secrets-config/00-common-values.env.template` | Active source for generated Tailscale values used by cluster-side and cloud-init-related flows | Actively used |
| `.uis.secrets/service-keys/tailscale.env` | Template/scaffolding created for host/target workflows | Present but appears not wired into active runtime flow |

### Recommendation

The target work should explicitly decide on **one primary source of truth** for VM-bootstrap Tailscale secrets.

Recommended rule:

1. **Cluster-side Tailscale secrets** (operator/Funnel/API values consumed through `urbalurba-secrets`) should remain in `secrets-config/00-common-values.env.template`
2. **Provisioning-only secrets** used exclusively by `uis-provision-host` should live in dedicated files under `.uis.secrets/`
3. If `service-keys/tailscale.env` is kept, it must either:
   - be wired into the real VM-target workflow, or
   - be removed to avoid duplicate/confusing configuration

For now, the investigation should treat `.uis.secrets/service-keys/tailscale.env` as **currently scaffolded but not clearly consumed**.

This is consistent with the architecture documentation, which now documents `service-keys/` as active but inconsistent in places rather than fully authoritative for current Tailscale runtime behavior.

---

## Part 1c: Tailscale Requirement for VM Targets

For VM-based targets, Tailscale is not just an optional public-ingress feature. It is also part of the **bootstrap transport** used to reach the VM after first boot.

### Important Distinction

There are two different Tailscale use cases in this codebase:

1. **VM bootstrap connectivity**
   - Used so UIS can reach a newly created VM after cloud-init finishes
   - Needed for cloud VM and some physical-device target workflows
   - Depends on the VM joining the tailnet at boot

2. **Cluster service exposure**
   - Used by `./uis tailscale expose ...` and the Tailscale operator / Funnel flow
   - Used to expose Kubernetes services to the internet or to the tailnet
   - This is a different concern from VM bootstrap

These should be treated as separate UX and implementation concerns.

### Current Evidence

- Cloud-init templates for VM and provision-host style targets already include Tailscale installation and `tailscale up` during first boot
- `.uis.secrets/service-keys/tailscale.env` already exists as a user-editable secret file, but current active flows do not clearly consume it
- Current cloud-init and networking flows read `TAILSCALE_SECRET` from generated Kubernetes secrets instead
- Operational requirement: we use Tailscale inside `uis-provision-host` for VM-target workflows
- Tailscale is **not installed by default** in the current `uis-provision-host` container

### Requirement for Target Setup

For any `cloud-vm` or `physical` target, `./uis target setup <name>` should validate Tailscale prerequisites before proceeding:

1. The required Tailscale bootstrap credentials exist in the chosen source of truth for that workflow
2. The target config indicates whether Tailscale is required
3. Tailscale is installed in `uis-provision-host`
4. `uis-provision-host` is configured to participate in Tailscale for VM-target workflows
5. After VM creation, UIS can detect the Tailscale hostname or IP and use that for follow-up SSH / Ansible steps

**Note:** Before implementation, the source of truth for the VM-bootstrap Tailscale auth key must be clarified. Today the codebase contains both:
- local file scaffolding in `.uis.secrets/service-keys/tailscale.env`
- active use of `TAILSCALE_SECRET` via generated Kubernetes secrets

If the secret is missing, `target setup` should tell the user exactly which file to inspect based on the chosen model. The current architecture docs already distinguish:

- shipped defaults in `provision-host/uis/templates/default-secrets.env`
- current machine-local active values in `.uis.secrets/secrets-config/00-common-values.env.template`

### Recommended New Commands

Because VM provisioning should not start until provision-host Tailscale is working, UIS should expose an explicit command for this.

Recommended command set:

1. `./uis tailscale setup`
   - Install Tailscale inside `uis-provision-host` if it is missing
   - Configure or authenticate Tailscale inside `uis-provision-host`
   - Read required secrets from `.uis.secrets/`
   - Join the correct tailnet
   - Persist whatever state is required for later target operations

2. `./uis tailscale verify`
   - Check that the Tailscale CLI and daemon are installed and available inside `uis-provision-host`
   - Check that Tailscale is healthy inside `uis-provision-host`
   - Verify the provision-host is connected to the expected tailnet
   - Verify required secrets are present and not placeholder values
   - Verify that VM-target workflows can safely proceed

### UX Recommendation

`./uis target setup <name>` should fail fast for VM-based targets unless provision-host Tailscale is already healthy.

Expected flow:

```bash
./uis tailscale setup
./uis tailscale verify
./uis target setup my-azure-microk8s
./uis target create my-azure-microk8s
```

Or, if the user skips Tailscale setup:

```bash
./uis target setup my-azure-microk8s
# Output:
# Tailscale is required for VM targets but is not installed/configured in uis-provision-host.
# Run:
#   ./uis tailscale setup
#   ./uis tailscale verify
```

### Design Direction

Treat Tailscale in `uis-provision-host` as a first-class requirement for VM-based targets.

Implications:

1. `./uis target setup <name>` should verify that Tailscale is configured and healthy inside the provision-host environment
2. `./uis tailscale setup` must handle installation as well as authentication/configuration
3. Tailscale bootstrap secrets must be available before VM creation
4. VM target workflows should not rely solely on the host machine's own Tailscale client state
5. Diagnostics should clearly separate:
   - provision-host Tailscale readiness
   - VM joined to tailnet
   - cluster kubeconfig retrieval and merge

---

## Part 2: Deployment Targets Inventory

### 1. Rancher Desktop (local development) — DEFAULT

- **Scripts**: `hosts/install-rancher-kubernetes.sh`
- **Purpose**: Local Kubernetes via Rancher Desktop — the standard UIS development environment
- **Secrets**: Uses `paths.sh` with `topsecret/` fallback
- **Status**: Actively maintained (Jan 2026)
- **Cloud-init**: No

### 2. Azure AKS (managed Kubernetes)

- **Scripts**: `hosts/install-azure-aks.sh`, `hosts/azure-aks/01-azure-aks-create.sh`, `02-azure-aks-setup.sh`, `03-azure-aks-cleanup.sh`, `manage-aks-cluster.sh`, `check-aks-quota.sh`
- **Purpose**: Production-grade managed Kubernetes on Azure
- **Secrets**: Git-ignored `azure-aks-config.sh` with Azure tenant/subscription IDs. Uses `paths.sh` for kubernetes secrets path (with `topsecret/` fallback in `02-azure-aks-setup.sh`)
- **Status**: Production ready — documented as "Version 4.0 - All components tested and working"
- **Cloud-init**: No
- **Docs**: `website/docs/hosts/azure-aks.md`
- **Cloud tools**: Requires Azure CLI (`az`)

### 3. Azure MicroK8s (VMs on Azure)

- **Scripts**: `hosts/install-azure-microk8s-v2.sh`, `hosts/azure-microk8s/01-azure-vm-create-redcross-v2.sh`, `02-azure-ansible-inventory-v2.sh`, `azure-vm-cleanup-redcross-v2.sh`, `hosts/03-setup-microk8s-v2.sh`
- **Purpose**: Self-managed Kubernetes on Azure VMs via MicroK8s + cloud-init
- **Secrets**: Uses `paths.sh` with `topsecret/` fallback. SSH keys from `get_ssh_key_path()`
- **Status**: Actively maintained (Jan 2026)
- **Cloud-init**: Yes (`azure-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/azure-microk8s.md`
- **Cloud tools**: Requires Azure CLI (`az`)

### 4. Multipass MicroK8s (local VMs)

- **Scripts**: `hosts/install-multipass-microk8s.sh`, `hosts/multipass-microk8s/01-create-multipass-microk8s.sh`, `02-inventory-multipass-microk8s.sh`
- **Purpose**: Local development alternative to Rancher Desktop, closer to production MicroK8s
- **Secrets**: Still references `topsecret/` directly — NOT migrated to `paths.sh`
- **Status**: Last updated Sep 2025 — moderate activity
- **Cloud-init**: Yes (`multipass-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/multipass-microk8s.md`

### 5. Raspberry Pi MicroK8s (edge/IoT)

- **Scripts**: `hosts/raspberry-microk8s/install-raspberry.sh`, `02-raspberry-ansible-inventory.sh`, `03-raspberry-setup-microk8s.sh`
- **Purpose**: Edge computing on Raspberry Pi 4 (ARM)
- **Secrets**: Commented-out topsecret references. Note in script: "secrets are pushed from the local mac-- fix this"
- **Status**: Experimental — manual setup only, automation TODO
- **Cloud-init**: Yes (`raspberry-cloud-init-template.yml`)
- **Docs**: `website/docs/hosts/raspberry-microk8s.md` (limited)

### 6. GCP (Google Cloud) — DORMANT

- **Scripts**: None (cloud-init template only)
- **Purpose**: Google Cloud VMs with MicroK8s
- **Status**: Template exists (`gcp-cloud-init-template.yml`) but no active scripts
- **Cloud-init**: Yes (template only)
- **Cloud tools**: Current UIS has Google Cloud CLI installer, but no active target workflow

### 7. Oracle Cloud (OCI) — DORMANT

- **Scripts**: None (cloud-init template only)
- **Purpose**: Oracle Cloud VMs with MicroK8s
- **Status**: Template exists (`oci-cloud-init-template.yml`) but no active scripts
- **Cloud-init**: Yes (template only)
- **Cloud tools**: Old pre-UIS tooling supported OCI CLI, but current `uis tools` does not expose it

---

## Part 2b: Provision-Host Tools and Provider Authentication

The detailed investigation for:

- optional tool installation inside `uis-provision-host`
- persistence via `.uis.extend/enabled-tools.conf`
- provider credential files in `.uis.secrets/`
- provider login/auth workflows
- reuse of the `devcontainer-toolbox` pattern

has been split into:

- [INVESTIGATE-provision-host-tools-and-auth.md](INVESTIGATE-provision-host-tools-and-auth.md)

For the target-management investigation, the main dependency is:

- `./uis target setup <name>` should consume that system rather than redefining its own provider-tool installation and auth logic

---

## Part 2c: Kubeconfig Merge System (`kubeconf-all`)

### Original Design

The pre-UIS system had a multi-cluster kubeconfig workflow:

1. Each cluster produced its own `*-kubeconf` file
2. `ansible/playbooks/04-merge-kubeconf.yml` merged them into `kubeconf-all`
3. The merged file became the main kubeconfig for tooling and playbooks
4. The most recently updated kubeconfig became the active context

### What Survived the Migration

The merge playbook still exists and is functionally intact:

- It still scans for `*-kubeconf` files
- It still rewrites names to avoid collisions
- It still runs `kubectl config view --flatten`
- It still produces `kubeconf-all`
- It still selects the most recently modified context as current

The main migration change was the path:

- Old path: `/mnt/urbalurbadisk/kubeconfig/kubeconf-all`
- New path: `/mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all`

Most current playbooks now use the new `.uis.secrets/generated/kubeconfig/kubeconf-all` path.

### Current UIS Wrapper Behavior

The current `./uis` wrapper does **not** appear to run the merge playbook during normal startup.

Instead, it creates `kubeconf-all` as a symlink to the mounted host kubeconfig:

```bash
mkdir -p /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig
ln -sf /home/ansible/.kube/config /mnt/urbalurbadisk/.uis.secrets/generated/kubeconfig/kubeconf-all
```

This preserves the expected file path but does **not** guarantee that the file is a merged artifact built from multiple target-specific kubeconfigs.

### Legacy Flows Still Using Real Merge Behavior

Older host/bootstrap flows still explicitly use the merge playbook:

- `provision-host-rancher/prepare-rancher-environment.sh`
- `hosts/azure-aks/02-azure-aks-setup.sh`
- `hosts/03-setup-microk8s-v2.sh`
- `hosts/raspberry-microk8s/03-raspberry-setup-microk8s.sh`

These flows still reflect the original "individual kubeconf files + merge into kubeconf-all" model.

### Current Assessment

| Aspect | Status |
|--------|--------|
| Merge playbook logic | Intact |
| New migrated path in playbooks | Mostly intact |
| Default `./uis` startup integration | Weakened / bypassed |
| Guaranteed multi-cluster merge in current wrapper | No |

### Implication for `target` Design

The `target` implementation should reinstate first-class multi-target kubeconfig management. UIS should:

1. Restore first-class multi-target kubeconfig management
2. Create one `*-kubeconf` per configured target in `.uis.secrets/generated/kubeconfig/`
3. Re-run `04-merge-kubeconf.yml` whenever targets are added or refreshed
4. Treat `kubeconf-all` as a real merged file again, not just a compatibility symlink

This is required if UIS is going to manage several Kubernetes targets cleanly. Without restoring merge behavior, UIS will continue to expose the historical `kubeconf-all` path while silently depending on a single mounted kubeconfig instead of a real merged multi-target config.

### Docs Drift

Some older docs and scripts still reference the old pre-migration path `/mnt/urbalurbadisk/kubeconfig/kubeconf-all`. These should be updated as part of the target-management work.

---

## Cloud-Init System

**Script**: `cloud-init/create-cloud-init.sh`

Generates cloud-init YAML files from templates by substituting `URB_*` placeholders with actual values (SSH keys, hostnames, Tailscale keys, etc.).

**Supported targets**: Azure, Multipass, Raspberry Pi, Provision Host, GCP, OCI

**Secrets path**: Uses `paths.sh` with fallback to `../topsecret/kubernetes/kubernetes-secrets.yml`

---

## VM Provisioning

**Script**: `provision-host/provision-host-vm-create.sh`

Creates the provision-host VM in Multipass and copies repo files to it. Currently only syncs `.uis.secrets/` (topsecret rsync already removed in PLAN-004).

---

## Migration Status

| Target | paths.sh integrated | topsecret fallback | Needs testing on real infra |
|--------|:-------------------:|:------------------:|:---------------------------:|
| Rancher Desktop | Yes | Yes | No (local) |
| Azure AKS | Yes | Yes | Yes (Azure subscription) |
| Azure MicroK8s | Yes | Yes | Yes (Azure subscription) |
| Multipass MicroK8s | No | Hardcoded | Yes (local VM) |
| Raspberry Pi | No | Commented out | Yes (physical device) |
| cloud-init/create-cloud-init.sh | Yes | Yes | Tested via targets above |

---

## Files Referencing `topsecret/`

| File | Line(s) | Reference Type |
|------|:-------:|----------------|
| `hosts/install-rancher-kubernetes.sh` | 110-134 | Fallback path check and script call |
| `hosts/azure-aks/02-azure-aks-setup.sh` | 132 | Hardcoded secrets file path |
| `hosts/install-azure-microk8s-v2.sh` | 216 | Topsecret directory reference |
| `hosts/install-azure-aks.sh` | 12 | Comment only |
| `hosts/install-multipass-microk8s.sh` | 83, 89 | Direct topsecret script calls |
| `hosts/raspberry-microk8s/install-raspberry.sh` | 97-102 | Commented-out topsecret calls |
| `cloud-init/create-cloud-init.sh` | 27 | Fallback secrets file path |

---

## Legacy Container Helper Scripts

Two older scripts were reviewed during this investigation and appear to be legacy:

| File | Current status | Reason |
|------|----------------|--------|
| `login-provision-host.sh` | Legacy | Replaced by `./uis shell`; still hardcodes old container name `provision-host` |
| `provision-host-rancher/provision-host-container-create.sh` | Legacy | Older container bootstrap path using `docker compose` and manual copy into container; replaced by `./uis start` / `./uis` wrapper behavior |

### Recommendation

Add a follow-up cleanup task to delete both files after:

1. Any remaining docs are updated to point to `./uis shell` / `./uis start`
2. Any remaining scripts that depend on the old `provision-host` container name are updated

---

## Open Questions

1. Are the Azure targets (AKS, MicroK8s) still actively used for Red Cross deployments?
2. Is the Multipass target worth maintaining, or is Rancher Desktop the preferred local option?
3. Should the Raspberry Pi target be kept as experimental or removed?
4. Should the dormant GCP and OCI cloud-init templates be removed?
5. What testing infrastructure is available for validating changes to Azure scripts?
6. Should target configs live under a new `.uis.extend/targets/` folder, or should existing `.uis.extend/hosts/` templates be reused internally and surfaced as `target` commands?
7. Should `target bootstrap` be a first-class command, or should its behavior be folded into `target setup` for existing clusters?
8. What is the cleanest implementation path for reinstating real `kubeconf-all` merge behavior in the primary UIS flow?
9. How should `uis-provision-host` authenticate to Tailscale, verify connectivity, and report failures during VM-target setup?

## Proposed Approach

This investigation documents the current state. A separate implementation plan should be created when there is time and infrastructure to test these changes. The work involves:

1. Implement `./uis target` commands using the target-based UX described above
2. Store active target state in `.uis.extend/active-target`
3. Reuse `.uis.extend/` for safe target config and `.uis.secrets/` for credentials and generated kubeconfig/cloud-init
4. Make `target setup` responsible for guided target validation and kubeconfig fetch, while depending on the separate provision-host tools/auth system for provider prerequisites
5. Decide whether to add `target bootstrap` as a separate cluster-preparation step
6. Remove `topsecret/` fallback paths — use `.uis.secrets/` only
7. Ensure `paths.sh` is sourced in scripts that don't yet use it (Multipass, Raspberry Pi)
8. Reinstate first-class kubeconfig merging in the primary UIS wrapper and `target` workflow
9. Make `target setup` validate Tailscale readiness inside `uis-provision-host` for VM-based targets
10. Mark `login-provision-host.sh` and `provision-host-rancher/provision-host-container-create.sh` as legacy and delete them in a cleanup follow-up
11. Test the full deployment cycle on each target platform
12. Keep `website/docs/contributors/architecture/secrets.md` as the canonical `.uis.secrets/` reference and update target docs to point to it
13. Update documentation in `website/docs/hosts/` and any remaining references to the old `provision-host` container workflow
