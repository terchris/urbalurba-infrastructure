# Secrets Management System

This document is the source of truth for the `.uis.secrets/` folder.

It covers both:

1. **Cluster-deployed secrets** that are rendered into Kubernetes and applied as `urbalurba-secrets`
2. **Provision-host/runtime secrets** used by `uis-provision-host` itself for provisioning, connectivity, authentication, kubeconfig management, and cloud-init generation

## The Core Split

UIS stores all sensitive local data under `.uis.secrets/`, but not all subfolders serve the same purpose.

### Cluster-deployed secrets

These are values that flow through the standard UIS secrets pipeline:

```text
Container image templates -> .uis.secrets/secrets-config/ -> .uis.secrets/generated/kubernetes/kubernetes-secrets.yml -> kubectl apply -> urbalurba-secrets
```

These values are consumed by workloads running in Kubernetes.

### Provision-host/runtime secrets

These are values used by `uis-provision-host` itself, not directly by cluster workloads.

Examples:
- cloud provider credentials
- SSH keys for VM provisioning
- local network access credentials
- generated kubeconfigs
- generated cloud-init output

The target-management work depends on this distinction being explicit.

## The Golden Rule

```text
EDIT HERE:        .uis.secrets/secrets-config/           (machine-specific source values)
NEVER EDIT:       .uis.secrets/generated/                (auto-generated output)
```

This rule applies to the cluster-secret pipeline.

Other folders under `.uis.secrets/` may also be user-edited, but they should be treated as dedicated runtime/provisioning inputs, not as generated Kubernetes secret sources.

## Directory Map

```text
.uis.secrets/
├── secrets-config/                 # Cluster secret source files (user-edited)
│   ├── 00-common-values.env.template
│   ├── 00-master-secrets.yml.template
│   └── configmaps/
├── generated/                      # Generated outputs (never edit directly)
│   ├── kubernetes/
│   │   └── kubernetes-secrets.yml
│   ├── kubeconfig/
│   │   └── kubeconf-all
│   └── ubuntu-cloud-init/
├── ssh/                            # SSH keys for VM / device provisioning
├── cloud-accounts/                 # Cloud provider credentials
├── service-keys/                   # Service-specific runtime credentials
├── network/                        # Local network access credentials
├── api-keys/                       # Misc external API keys (legacy/unclear use)
└── README.md
```

## Folder Reference

| Folder | Scope | User edits? | Generated? | Used by | Status |
|--------|-------|-------------|------------|---------|--------|
| `secrets-config/` | Cluster secrets | Yes | No | `./uis secrets generate`, service deployments | Active |
| `generated/kubernetes/` | Cluster secrets | No | Yes | `./uis secrets apply`, workloads via `urbalurba-secrets` | Active |
| `generated/kubeconfig/` | Provision-host runtime | No | Yes | Ansible playbooks, kubectl, target management | Active |
| `generated/ubuntu-cloud-init/` | Provision-host runtime | No | Yes | VM and edge-device provisioning | Active |
| `ssh/` | Provision-host runtime | Usually no | Often generated once | VM bootstrap, Ansible SSH access | Active |
| `cloud-accounts/` | Provision-host runtime | Yes | No | Cloud auth for Azure/GCP/AWS-style targets | Active |
| `service-keys/` | Provision-host runtime | Yes | No | Service-specific provisioning/runtime integrations | Active but inconsistent in places |
| `network/` | Provision-host runtime | Yes | No | Network credentials such as WiFi | Active/optional |
| `api-keys/` | Provision-host runtime | Possibly | No | Not clearly documented in current runtime | Legacy or unclear |

## Cluster Secret Workflow

### Source files

The standard cluster secret pipeline uses three important files:

| File | Location | Purpose |
|------|----------|---------|
| `default-secrets.env` | `provision-host/uis/templates/` | Built-in development defaults shipped in the image |
| `00-common-values.env.template` | `.uis.secrets/secrets-config/` | User-edited secret values |
| `00-master-secrets.yml.template` | `.uis.secrets/secrets-config/` | Kubernetes YAML with `${VARIABLE}` placeholders |

### Flow

```text
default-secrets.env
        |
        v  [first run: copy + apply defaults]
.uis.secrets/secrets-config/
  00-common-values.env.template
  00-master-secrets.yml.template
        |
        v  [source + envsubst]
.uis.secrets/generated/kubernetes/
  kubernetes-secrets.yml
        |
        v  [kubectl apply]
Kubernetes cluster
  Secret: urbalurba-secrets
```

### On first run

When the user runs `./uis` for the first time:

1. The wrapper creates `.uis.secrets/`
2. UIS copies templates into `.uis.secrets/secrets-config/`
3. Development defaults are applied
4. `./uis secrets generate` logic produces `generated/kubernetes/kubernetes-secrets.yml`
5. `./uis secrets apply` logic applies it to the cluster

### Normal commands

```bash
# Edit source values
nano .uis.secrets/secrets-config/00-common-values.env.template

# Render generated Kubernetes secrets
./uis secrets generate

# Apply to cluster
./uis secrets apply
```

### Safety

- Edit files in `secrets-config/`
- Never edit files in `generated/`
- Never commit `.uis.secrets/`

## Provision-Host / Runtime Secrets

These are secrets or artifacts used by `uis-provision-host` itself.

They do **not** all flow through the `secrets generate` / `secrets apply` pipeline.

### `cloud-accounts/`

Purpose:
- store cloud login details or account references for target provisioning

Examples:
- `azure-default.env`
- future `gcp-default.env`, `aws-default.env`

Used by:
- target or host creation/setup flows
- cloud CLI login/bootstrap logic

### `ssh/`

Purpose:
- store SSH keys used for VM provisioning and follow-up access

Typical files:
- `id_rsa_ansible`
- `id_rsa_ansible.pub`

Used by:
- Ansible-based VM bootstrap flows
- cloud VM or edge-device target management

### `network/`

Purpose:
- store network-access values that are local/provisioning oriented rather than cluster application secrets

Examples:
- WiFi credentials for Raspberry Pi style provisioning

### `generated/kubeconfig/`

Purpose:
- store kubeconfig artifacts used by provision-host tooling and playbooks

Important file:
- `kubeconf-all`

Used by:
- Ansible playbooks
- kubectl commands in `uis-provision-host`
- future target switching / merging logic

### TODO: Current vs Intended `kubeconf-all` Behavior

The intended model is:

- one `*-kubeconf` file per target
- `ansible/playbooks/04-merge-kubeconf.yml` merges them into `generated/kubeconfig/kubeconf-all`
- `kubeconf-all` is the real merged multi-target kubeconfig used by playbooks and tooling

The current wrapper behavior does not fully match that model. In the primary `./uis` flow, `kubeconf-all` may currently be created as a symlink to the mounted host kubeconfig instead of being regenerated from multiple `*-kubeconf` files.

This needs to be reinstated for proper multi-cluster target management so that what this document describes is fully true in practice.

### `generated/ubuntu-cloud-init/`

Purpose:
- store rendered cloud-init output for VMs and devices

Used by:
- VM creation and first-boot automation

### `service-keys/`

Purpose:
- store service-specific runtime/provisioning secrets that do not clearly belong in the cluster-secret template flow

Examples currently scaffolded:
- `tailscale.env`
- `cloudflare.env`
- `openai.env`

#### Important current inconsistency

Tailscale is currently split across two models:

1. `service-keys/tailscale.env` exists and is scaffolded by host/target helpers
2. Active Tailscale networking and cloud-init-related flows currently read `TAILSCALE_SECRET`, `TAILSCALE_CLIENTID`, `TAILSCALE_CLIENTSECRET`, `TAILSCALE_TAILNET`, and `TAILSCALE_DOMAIN` from the generated Kubernetes secret system

So today:
- `service-keys/tailscale.env` appears to be **prepared for use**
- but the active runtime path appears to rely on `TAILSCALE_SECRET` in `secrets-config/00-common-values.env.template`

This ambiguity should be resolved by the target-management work.

### `api-keys/`

This folder exists in the current `.uis.secrets` structure but is not clearly documented in the active runtime flow.

Treat it as:
- not the primary path for new design work
- subject to clarification or cleanup

## Multi-Machine Behavior

`.uis.secrets/` is machine-specific and gitignored.

That means:
- each machine may have different cloud credentials
- each machine may have different Tailscale settings
- each machine may have a different `kubeconf-all`
- each machine may have different generated cloud-init output

Example:

```bash
# Laptop
.uis.secrets/cloud-accounts/azure-default.env
.uis.secrets/generated/kubeconfig/kubeconf-all

# iMac
.uis.secrets/cloud-accounts/azure-default.env
.uis.secrets/generated/kubeconfig/kubeconf-all
```

The filenames may match, but the values are local to that machine.

## Common Tasks

### Change a cluster password or secret

```bash
nano .uis.secrets/secrets-config/00-common-values.env.template
./uis secrets generate
./uis secrets apply
```

### Check current secret status

```bash
./uis secrets status
```

### Reset cluster secret templates to defaults

```bash
rm .uis.secrets/secrets-config/00-common-values.env.template
./uis stop
./uis start
```

### Configure a cloud account

Edit the relevant file in:

```text
.uis.secrets/cloud-accounts/
```

For example:

```bash
nano .uis.secrets/cloud-accounts/azure-default.env
```

### Inspect generated kubeconfig artifacts

```bash
ls .uis.secrets/generated/kubeconfig/
```

Do not manually edit generated kubeconfig artifacts unless you are debugging a specific workflow.

## Development Defaults

On first run, UIS sets development-friendly defaults so services can run immediately for local development.

To avoid drift, this document does not duplicate the literal default values.

Use these files instead:

- Shipped built-in development defaults: `provision-host/uis/templates/default-secrets.env`
- Current machine-local active values after initialization: `.uis.secrets/secrets-config/00-common-values.env.template`

Practical rule:

- If you want to know what UIS ships with by default, check `default-secrets.env`
- If you want to know what credentials your current machine is actually using, check `.uis.secrets/secrets-config/00-common-values.env.template`

The second file is the more useful one for a user who has already installed and initialized UIS.

If a user starts UIS and has not changed any usernames, emails, or passwords yet, they should be told:

- you can start UIS and play around using the development defaults
- the shipped defaults are documented in `provision-host/uis/templates/default-secrets.env`
- after initialization, the most important file is `.uis.secrets/secrets-config/00-common-values.env.template`
- if that machine-local file has been edited, it overrides the original defaults for that machine

So the guidance should always be:

- first check `.uis.secrets/secrets-config/00-common-values.env.template`
- if you have never customized secrets yet, compare with `provision-host/uis/templates/default-secrets.env`

> Password restriction: Do not use `!`, `$`, `` ` ``, `\`, or `"` in passwords.
> Some charts pass passwords through shell initialization, which can corrupt these characters.

## Troubleshooting

| Problem | Likely Cause | Suggested Fix |
|---------|--------------|---------------|
| Changes not appearing in cluster | Secrets not regenerated/applied | Run `./uis secrets generate` then `./uis secrets apply` |
| Service still uses old password | Deployment still using previous secret values | Redeploy affected service |
| `kubeconf-all` missing or stale | Kubeconfig generation/merge path not refreshed | Re-run the relevant target/bootstrap flow |
| Cloud provisioning cannot authenticate | Missing or wrong file in `cloud-accounts/` | Check the relevant provider file |
| VM bootstrap cannot reach target over Tailscale | Provision-host/runtime secret path unclear or Tailscale not ready | Validate Tailscale setup and source-of-truth secret location |
| Folder exists but usage is unclear | Legacy or partially migrated design | Check investigation docs before extending it |

## Safety Rules

**Do:**
- edit files in `secrets-config/` for cluster secret values
- use dedicated files in `cloud-accounts/`, `service-keys/`, and `network/` for provision-host/runtime inputs where that pattern is established
- treat `.uis.secrets/` as machine-local, not shareable configuration
- document new folders or files in this architecture page when adding them

**Do not:**
- edit files in `generated/`
- put real secrets in image templates under `provision-host/uis/templates/`
- assume every `.uis.secrets/` subfolder participates in the Kubernetes secret generation pipeline
- duplicate the same secret in multiple places without explicitly defining the source of truth
- commit `.uis.secrets/` to git

## Related Docs

- [Secrets Management Rules](../rules/secrets-management.md) - Rules and guardrails

