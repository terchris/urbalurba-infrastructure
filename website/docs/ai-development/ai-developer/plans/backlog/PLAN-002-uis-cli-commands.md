# PLAN-002: UIS CLI Commands for Secrets Management

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Implement the CLI commands for managing hosts and secrets (`./uis host add`, `./uis secrets status`, etc.)

**Last Updated**: 2025-01-23

**Branch**: `feature/secrets-migration`

**Prerequisites**: PLAN-001 must be complete (templates and init code exist)

**Related**: [INVESTIGATE-secrets-consolidation.md](./INVESTIGATE-secrets-consolidation.md)

---

## Context: Contributor vs User

**We are contributors** - we build the CLI commands that run inside the container.

**Users run** these commands which operate on their mounted folders:
- `/mnt/urbalurbadisk/.uis.extend/` (mounted from user's `.uis.extend/`)
- `/mnt/urbalurbadisk/.uis.secrets/` (mounted from user's `.uis.secrets/`)

The commands we build read templates from the container and write to user's mounted folders.

---

## Overview

Implement the user-facing CLI commands:

| Command | Purpose |
|---------|---------|
| `./uis host add` | List available host templates |
| `./uis host add <template>` | Copy template to user's config |
| `./uis host list` | List user's configured hosts |
| `./uis host create <name>` | Create cloud resources |
| `./uis host generate <name>` | Generate cloud-init for physical devices |
| `./uis secrets status` | Show what's configured in user's secrets |
| `./uis secrets validate` | Validate user's configuration |

---

## Phase 1: Core Library Functions

Create the shared library that CLI commands will use.

### Tasks

- [ ] 1.1 Create `provision-host/uis/lib/uis-secrets.sh` with functions:
  ```bash
  # Paths inside container
  TEMPLATES_DIR="/mnt/urbalurbadisk/provision-host/uis/templates"
  USER_EXTEND="/mnt/urbalurbadisk/.uis.extend"
  USER_SECRETS="/mnt/urbalurbadisk/.uis.secrets"

  # Copy template to user's secrets folder
  secrets_copy_template() {
    local template_name="$1"
    local dest_name="$2"
    # Copies from $TEMPLATES_DIR/uis.secrets/ to $USER_SECRETS/
  }

  # Check if a secrets file exists
  secrets_check_file_exists() {
    local file_path="$1"
    # Checks in $USER_SECRETS/
  }

  # Generate SSH keys in user's secrets folder
  secrets_generate_ssh_keys() {
    # Creates $USER_SECRETS/ssh/id_rsa_ansible
  }

  # Load an env file safely
  secrets_load_env() {
    local env_file="$1"
    # Source file and validate
  }
  ```

- [ ] 1.2 Create `provision-host/uis/lib/uis-hosts.sh` with functions:
  ```bash
  # List available templates (from container)
  hosts_list_templates() {
    # Lists from $TEMPLATES_DIR/uis.extend/hosts/
  }

  # List user's configured hosts
  hosts_list_configured() {
    # Lists from $USER_EXTEND/hosts/
  }

  # Get host type from template name
  hosts_get_type() {
    local template="$1"
    # Returns: managed, cloud-vm, physical, or local
  }

  # Check if host type needs SSH keys
  hosts_requires_ssh() {
    local host_type="$1"
    # physical and cloud-vm need SSH
  }

  # Check if host type needs Tailscale
  hosts_requires_tailscale() {
    local host_type="$1"
    # physical and cloud-vm need Tailscale
  }
  ```

- [ ] 1.3 Add unit tests in `provision-host/uis/tests/unit/`:
  - `test-uis-secrets.sh`
  - `test-uis-hosts.sh`

### Validation

Unit tests pass for library functions.

---

## Phase 2: Host Management Commands

### Tasks

- [ ] 2.1 Implement `./uis host add` (no arguments):
  - Lists available templates from container:
    ```
    Available host templates:

    managed/     (Cloud-managed Kubernetes)
      azure-aks
      gcp-gke
      aws-eks

    cloud-vm/    (VM in cloud running K8s)
      azure-microk8s
      gcp-microk8s

    physical/    (Physical device running K8s)
      raspberry-pi

    local/       (Local development)
      rancher-desktop

    Usage: ./uis host add <template>
    ```

- [ ] 2.2 Implement `./uis host add <template>`:
  - Validate template exists in container
  - Create `$USER_EXTEND/hosts/<type>/` folder if needed
  - Copy host config template to user's folder
  - Copy required secrets templates if they don't exist in user's secrets
  - Auto-generate SSH keys if host type requires them
  - Print "Next steps" telling user what files to edit

- [ ] 2.3 Implement `./uis host list`:
  - List configured hosts from `$USER_EXTEND/hosts/`
  - Show status (ready/incomplete based on secrets)
  - Example:
    ```
    Configured hosts:

    managed/
      my-azure-aks        ✓ ready

    cloud-vm/
      my-azure-microk8s   ✗ missing: tailscale.env

    local/
      rancher-desktop     ✓ ready (default)
    ```

- [ ] 2.4 Create `provision-host/uis/manage/uis-host.sh` to route host subcommands

### Validation

User confirms `./uis host add` and `./uis host list` work correctly.

---

## Phase 3: Secrets Status Commands

### Tasks

- [ ] 3.1 Implement `./uis secrets status`:
  - Show what's configured in user's `$USER_SECRETS/`:
    ```
    Secrets Status:

    SSH Keys:
      ✓ ssh/id_rsa_ansible
      ✓ ssh/id_rsa_ansible.pub

    Cloud Accounts:
      ✓ cloud-accounts/azure-default.env
      ✗ cloud-accounts/gcp-default.env (not configured)

    Service Keys:
      ✓ service-keys/tailscale.env
      ✗ service-keys/openai.env (not configured)

    Defaults:
      ✓ defaults.env
    ```

- [ ] 3.2 Implement `./uis secrets validate`:
  - Check required secrets exist for user's configured hosts
  - Validate env files have non-empty required values
  - Example:
    ```
    Validating secrets for configured hosts...

    my-azure-aks:
      ✓ azure-default.env exists
      ✓ AZURE_TENANT_ID is set
      ✓ AZURE_SUBSCRIPTION_ID is set

    my-azure-microk8s:
      ✓ azure-default.env exists
      ✓ tailscale.env exists
      ✗ TAILSCALE_AUTH_KEY is empty

    Validation failed: 1 issue found
    ```

- [ ] 3.3 Create `provision-host/uis/manage/uis-secrets.sh` for secrets commands

### Validation

User confirms `./uis secrets status` and `./uis secrets validate` work correctly.

---

## Phase 4: Host Create & Generate Commands

### Tasks

- [ ] 4.1 Implement `./uis host generate <name>`:
  - For physical devices (Raspberry Pi)
  - Validates required secrets exist in user's folder
  - Reads cloud-init template from container
  - Generates cloud-init file to `$USER_SECRETS/generated/ubuntu-cloud-init/`
  - Embeds SSH public key and Tailscale key from user's secrets
  - Prints instructions for flashing SD card

- [ ] 4.2 Implement `./uis host create <name>`:
  - For managed K8s (AKS, GKE, EKS) and cloud VMs
  - Validates required secrets exist
  - Routes to appropriate creation script based on host type
  - For cloud-vm: generates cloud-init, then creates VM
  - For managed: calls provider CLI (az, gcloud, aws)
  - Stores kubeconfig in `$USER_SECRETS/generated/kubeconfig/`

- [ ] 4.3 Update main command routing in `provision-host/uis/manage/`

### Validation

User confirms `./uis host generate` creates valid cloud-init file.

---

## Phase 5: Integration with Existing Commands

### Tasks

- [ ] 5.1 Update `./uis deploy` to work with new structure:
  - Read enabled services from `$USER_EXTEND/enabled-services.conf`
  - Work with zero config for local Rancher Desktop

- [ ] 5.2 Ensure backwards compatibility:
  - If `topsecret/` is mounted (old setup), use that
  - If `.uis.secrets/` is mounted (new setup), use that
  - Prefer new paths when both exist

- [ ] 5.3 Update help output to show new commands

### Validation

User confirms `./uis deploy` works with both old and new setups.

---

## Acceptance Criteria

- [ ] `./uis host add` lists available templates from container
- [ ] `./uis host add <template>` copies config to user's folder
- [ ] `./uis host list` shows user's configured hosts with status
- [ ] `./uis secrets status` shows user's secrets configuration
- [ ] `./uis secrets validate` validates against configured hosts
- [ ] `./uis host generate <name>` creates cloud-init in user's folder
- [ ] `./uis host create <name>` provisions at least one host type
- [ ] SSH keys auto-generated only when needed
- [ ] All commands have clear, helpful output
- [ ] Backwards compatibility with old `topsecret/` setup

---

## Files to Create

**Libraries:**
- `provision-host/uis/lib/uis-secrets.sh`
- `provision-host/uis/lib/uis-hosts.sh`

**Commands:**
- `provision-host/uis/manage/uis-host.sh`
- `provision-host/uis/manage/uis-secrets.sh`

**Tests:**
- `provision-host/uis/tests/unit/test-uis-secrets.sh`
- `provision-host/uis/tests/unit/test-uis-hosts.sh`

**Modified:**
- `provision-host/uis/manage/` (command routing)
