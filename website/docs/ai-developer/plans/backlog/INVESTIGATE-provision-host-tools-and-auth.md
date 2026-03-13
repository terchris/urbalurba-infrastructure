# INVESTIGATE: Provision-Host Tools and Provider Authentication

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Related**:
- [INVESTIGATE-remote-deployment-targets.md](INVESTIGATE-remote-deployment-targets.md)
- [Secrets Management System](../../../contributors/architecture/secrets.md)

**Created**: 2026-03-13
**Updated**: 2026-03-13
**Status**: BACKLOG

## Goal

Investigate how UIS should install optional software inside `uis-provision-host`, persist those choices across container rebuilds, and manage the provider credentials and auth state those tools depend on.

This includes tools such as:

- Azure CLI
- AWS CLI
- Google Cloud CLI
- future OCI CLI
- future Terraform
- future Tailscale tooling if it follows the same pattern

---

## Background

UIS already has a partial tool installation system:

- install scripts exist under `provision-host/uis/tools/`
- the CLI exposes `./uis tools list`
- the CLI exposes `./uis tools install <tool>`
- `.uis.extend/enabled-tools.conf` exists as a repo-local config file

However, the current implementation appears incomplete compared with the desired model for remote targets:

- `target setup` needs provider tools to be available without the user memorizing prerequisites
- accepted tools should survive container recreation
- provider credentials and account references need a clear home under `.uis.secrets/`
- auth and login flows need to be understandable and repeatable across machines

This is closely related to, but separate from:

- target UX and lifecycle
- cluster bootstrap
- kubeconfig merging
- the overall `.uis.secrets/` architecture

Those concerns should stay in their own documents.

---

## Part 1: Current UIS Tool Installation Model

### What exists today

Current UIS commands:

- `./uis tools list`
- `./uis tools install azure-cli`
- `./uis tools install aws-cli`
- `./uis tools install gcp-cli`

Current implementation pieces:

- `provision-host/uis/manage/uis-cli.sh`
- `provision-host/uis/lib/tool-installation.sh`
- `provision-host/uis/tools/install-azure-cli.sh`
- `provision-host/uis/tools/install-aws-cli.sh`
- `provision-host/uis/tools/install-gcp-cli.sh`
- `provision-host/uis/templates/uis.extend/enabled-tools.conf.default`

### Gaps currently visible

The current UIS implementation has working per-tool installers, but the full declarative pattern does not appear to be wired through yet.

Likely gaps:

- `enabled-tools.conf` exists, but does not yet appear to drive automatic reinstall on container rebuild
- `target setup` is expected to depend on tool availability, but that dependency model is not fully defined
- provider login and credential persistence are not yet separated cleanly from target lifecycle logic
- old pre-UIS tooling supported more providers than the current `uis tools` set

### Current tool support inventory

| Tool | Old pre-UIS support | Current `uis tools` support |
|------|---------------------|-----------------------------|
| Azure CLI | Yes | Yes |
| AWS CLI | Yes | Yes |
| Google Cloud SDK / CLI | Yes | Yes |
| OCI CLI | Yes | No |
| Terraform | Yes | No |

---

## Part 2: Reference Pattern from `devcontainer-toolbox`

The nearby `devcontainer-toolbox` project already implements a fuller model for optional tools, persisted enablement, and prerequisite checking. It should be treated as a primary design reference.

Reference paths:

- Repo root: `/Users/terje.christensen/learn/projects-2026/urb-family/devcontainer-toolbox`
- Main setup script: `/Users/terje.christensen/learn/projects-2026/urb-family/devcontainer-toolbox/.devcontainer/manage/dev-setup.sh`
- Tool auto-enable library: `/Users/terje.christensen/learn/projects-2026/urb-family/devcontainer-toolbox/.devcontainer/additions/lib/tool-auto-enable.sh`
- Tool installation library: `/Users/terje.christensen/learn/projects-2026/urb-family/devcontainer-toolbox/.devcontainer/additions/lib/tool-installation.sh`
- Prerequisite checking library: `/Users/terje.christensen/learn/projects-2026/urb-family/devcontainer-toolbox/.devcontainer/additions/lib/prerequisite-check.sh`

### Important ideas from that project

- tools are discovered from metadata-driven install scripts
- installation prerequisites are checked before install
- enabling a tool updates `enabled-tools.conf`
- newly enabled tools are installed immediately
- enabled tools are reinstalled on rebuild
- configuration prerequisites and install prerequisites are treated separately

### Why this matters for UIS

UIS needs the same kind of behavior inside `uis-provision-host`:

- easy discovery of optional tools
- low-friction installation
- reproducibility after container recreation
- consistent handling of per-provider prerequisites

The key point is that a tool install should not be a one-off mutation inside a throwaway container. It should become remembered repo-local state.

---

## Part 3: Proposed UIS Design Direction

### Recommended split

For UIS, the likely correct model is:

1. **Built-in base tools** in the container image
   - examples: `kubectl`, `helm`, `ansible`, `k9s`
2. **Optional/provider tools** installed on demand inside `uis-provision-host`
   - examples: `azure-cli`, `aws-cli`, `gcp-cli`, later `tailscale`, `terraform`, `oci`
3. **Declarative persistence** through `.uis.extend/enabled-tools.conf`
   - used so accepted tools are re-ensured after container rebuild or recreation

### Expected behavior

Recommended lifecycle:

1. UIS determines which tools are required for a workflow
2. If a required tool is missing, UIS offers to install it
3. If the user accepts, UIS installs it immediately inside `uis-provision-host`
4. UIS records that choice in `.uis.extend/enabled-tools.conf`
5. Future startup or rebuild logic re-installs enabled tools automatically

### Command model

Low-level commands:

- `./uis tools list`
- `./uis tools install <tool>`

Potential follow-up commands:

- `./uis tools verify <tool>`
- `./uis tools uninstall <tool>`
- `./uis tools ensure <tool>`

High-level UX:

- `./uis target setup <name>` should call into this system instead of reimplementing provider-tool logic itself

That means `target setup` should depend on this investigation, not absorb it.

---

## Part 4: Provider Credentials and `.uis.secrets`

The canonical `.uis.secrets/` model is now documented in:

- `website/docs/contributors/architecture/secrets.md`

For provider tooling, the most relevant folders are:

- `.uis.secrets/cloud-accounts/`
- `.uis.secrets/service-keys/`
- `.uis.secrets/ssh/`
- `.uis.secrets/generated/kubeconfig/`

### Likely split of responsibility

Recommended rule:

1. **Provider credentials and account references** for `uis-provision-host` should live in dedicated files under `.uis.secrets/`
2. **Cluster-deployed application secrets** should continue to live in `.uis.secrets/secrets-config/`
3. **Generated kubeconfig output** should continue to live in `.uis.secrets/generated/kubeconfig/`

Likely examples:

- Azure account or tenant/subscription references in `.uis.secrets/cloud-accounts/azure-default.env`
- AWS account credentials in `.uis.secrets/cloud-accounts/aws-default.env`
- GCP account or project references in `.uis.secrets/cloud-accounts/gcp-default.env`

### Important design question

Tool installation and provider auth are related, but not identical:

- installing `azure-cli` is not the same as authenticating Azure
- authenticating Azure is not the same as choosing which Azure account or subscription a target uses

The same applies to AWS and GCP.

This investigation should therefore separate:

1. tool presence
2. provider login/auth
3. provider credential files in `.uis.secrets/`
4. target-specific references to those credentials

---

## Part 5: Key Questions to Investigate

1. Should `.uis.extend/enabled-tools.conf` become the authoritative source for re-installing optional tools on startup/rebuild?
2. Should successful `./uis tools install <tool>` automatically add that tool to `.uis.extend/enabled-tools.conf`?
3. Should `target setup` auto-install missing tools, or only prompt and delegate to `./uis tools install <tool>`?
4. Which provider credential files should be standardized under `.uis.secrets/cloud-accounts/`?
5. Should provider auth state be recreated from `.uis.secrets/` inputs, or should users run provider login commands interactively inside `uis-provision-host`?
6. How should UIS verify that Azure/AWS/GCP auth is healthy without conflating auth validation with target validation?
7. Should OCI CLI and Terraform be restored now, or only when a real target workflow depends on them?
8. Should Tailscale follow the same optional-tool pattern, or be treated separately because it is tightly coupled to VM bootstrap and connectivity?
9. Which parts of the `devcontainer-toolbox` pattern can be ported directly, and which parts depend too much on devcontainer-specific assumptions?

---

## Proposed Approach

This should remain a separate investigation from remote targets.

Recommended next steps:

1. Audit the current UIS startup path to confirm whether `enabled-tools.conf` is processed anywhere beyond template creation
2. Decide the authoritative behavior for `./uis tools install <tool>`
3. Define standard credential file names under `.uis.secrets/cloud-accounts/`
4. Define whether provider login should be interactive, file-driven, or hybrid
5. Make `target setup` consume this system rather than owning provider-tool logic directly
6. Port or adapt the relevant patterns from `devcontainer-toolbox`

---

## Dependency on Remote Targets

`INVESTIGATE-remote-deployment-targets.md` should depend on the outcome of this investigation for:

- how missing provider tools are installed
- where provider credentials live in `.uis.secrets/`
- how `target setup` verifies tool and auth prerequisites

But this file should own the detailed design for those questions.
