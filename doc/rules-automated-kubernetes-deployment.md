# Rules for Automated Kubernetes Deployment

**File**: `doc/rules-automated-kubernetes-deployment.md`
**Purpose**: Define the **ORCHESTRATION LAYER** - how deployment scripts are organized, discovered, and executed automatically when cluster is built
**Target Audience**: Developers, DevOps engineers, and LLMs working with the automated deployment system
**Scope**: Directory structure, naming conventions, execution order, and automation flow

## Relationship to Other Rules

This document covers the **orchestration and automation framework**:
- How scripts are organized in numbered directories
- How `provision-kubernetes.sh` discovers and executes scripts
- Alphabetic ordering and dependency management
- Active/inactive script management

For **how to write individual deployment scripts**, see:
→ [Rules for Provisioning](rules-provisioning.md) - Implementation patterns for scripts and playbooks

## Core Principles

1. **Automated Orchestration**: The `provision-kubernetes.sh` script is the master orchestrator that executes all deployment scripts
2. **Alphabetic Execution Order**: Directories and scripts are executed in strict alphabetic order based on their names
3. **Sequential Dependency Management**: Applications MUST be deployed in order based on their dependencies via alphabetic naming
4. **Idempotency**: All deployment scripts MUST be safe to run multiple times
5. **Error Resilience**: Deployment process MUST continue even if individual scripts fail, with errors tracked
6. **Parameterization**: All scripts MUST accept target host as a parameter

## Automated Orchestration System

### Master Script: provision-kubernetes.sh

The **`provision-kubernetes.sh`** is the central automation controller that orchestrates all deployments:

**Repository Path**: `provision-host/kubernetes/provision-kubernetes.sh`
**Container Path**: `/mnt/urbalurbadisk/provision-host/kubernetes/provision-kubernetes.sh` (when running inside provision-host)

**Key Functions**:
- Automatically discovers all numbered directories (e.g., `01-core`, `02-databases`)
- Executes directories in **strict alphabetic order** (not numeric - this is critical!)
- Within each directory, executes all `*.sh` scripts in **alphabetic order**
- Ignores scripts in `not-in-use/` folders
- Passes target host parameter to every script
- Continues execution even if individual scripts fail
- Generates comprehensive summary report

**CRITICAL**: The system uses **alphabetic sorting**, not numeric sorting:
- `01` comes before `02` (correct)
- `10` comes before `2` (would be wrong - always use leading zeros!)
- This is why `05-setup-postgres.sh` comes before `10-setup-mysql.sh`

### Automated Execution

**IMPORTANT**: This script is called **automatically** by `install-rancher.sh` during cluster build:

```bash
# Automatically executed by install-rancher.sh:
docker exec provision-host bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes && ./provision-kubernetes.sh rancher-desktop default"
```

**Path Context**: Commands shown above use container paths (`/mnt/urbalurbadisk/`) because they run inside the provision-host container.

The complete cluster setup flow:
1. User runs `./install-rancher.sh` in the repo on his host machine (Windows, Mac, Linux)
2. install-rancher.sh creates the provision-host container and sets it up with all tools to manage the cluster
3. install-rancher.sh **automatically calls** provision-kubernetes.sh inside the provision-host container
4. provision-kubernetes.sh deploys all services in alphabetic order

### Manual Usage (for testing/debugging)

```bash
# From within provision-host container:
cd /mnt/urbalurbadisk
./provision-host/kubernetes/provision-kubernetes.sh [target-host]
```

Default target-host is `rancher-desktop` if not specified.

## Directory Structure Rules

### Category Numbering Standards

Deployment scripts MUST be organized in numbered categories:

**Repository Structure**:
```
provision-host/kubernetes/
├── 01-core/             # Storage, ingress, DNS, basic infrastructure
├── 02-databases/        # PostgreSQL, MySQL, MongoDB, etc.
├── 03-queues/          # Redis, RabbitMQ, message brokers
├── 04-search/          # Elasticsearch, Solr, search engines
├── 05-apim/            # API management platforms
├── 06-management/      # Admin tools (pgAdmin, phpMyAdmin, etc.)
├── 07-ai/              # AI/ML services (OpenWebUI, LiteLLM, etc.)
├── 08-development/     # CI/CD tools (ArgoCD, Jenkins, etc.)
├── 09-network/         # VPN, tunnels, network tools
├── 10-datascience/    # Jupyter, Unity Catalog, analytics
├── 11-monitoring/      # Prometheus, Grafana, observability
└── 12-auth/            # Authentication services (Authentik, Keycloak)
```

**Container Path**: `/mnt/urbalurbadisk/provision-host/kubernetes/` (when mounted in provision-host)

### Script Naming Convention

Scripts must follow standard naming patterns. For **implementation details** (naming conventions, script structure), see:
→ [Rules for Provisioning](rules-provisioning.md) - Script Template Pattern section

### Active vs Inactive Management

**Purpose**: Control what gets deployed during **automated cluster build** by `install-rancher.sh`

- **Active scripts**: Placed directly in the category folder - will be deployed automatically
- **Inactive scripts**: Placed in `not-in-use/` subfolder - skipped during automated build
- **Activation**: Move script from `not-in-use/` to parent directory for next cluster build
- **Deactivation**: Move script to `not-in-use/` to exclude from automated deployment

**IMPORTANT**: Scripts in `not-in-use/` can still be run manually anytime:
```bash
# Manual execution of inactive script (from provision-host container):
cd /mnt/urbalurbadisk/provision-host/kubernetes/02-databases/not-in-use/
./04-setup-mongodb.sh rancher-desktop
```

**Note**: The path above uses the container mount point (`/mnt/urbalurbadisk/`).

This allows you to:
- Keep optional services ready but not auto-deployed
- Test services before adding to automated build
- Maintain different cluster configurations

## Script Requirements for Orchestration

### Compatibility with Automation

For scripts to work with the automated orchestration system, they MUST:

1. **Be executable**: File permissions must be 755 (`chmod +x script.sh`)
2. **Accept target host as first parameter**: The orchestrator passes this automatically
3. **Follow naming convention**: `[NN]-setup-[service].sh` for proper alphabetic ordering
4. **Be placed in correct directory**: Active scripts in category folder, inactive in `not-in-use/`

For **implementation details** (how to write the scripts), see:
→ [Rules for Provisioning](rules-provisioning.md)


## Dependency Management Rules

### Execution Order (Alphabetic!)

1. Categories are processed in **alphabetic order** (01 before 02, 10 before 11, etc.)
2. Scripts within categories execute in **alphabetic order**
3. Dependencies MUST be satisfied by proper alphabetic ordering:
   - Databases (02) before applications that use them
   - Authentication (12) after databases it depends on
   - Monitoring (11) after services to monitor



## Automation Integration

The **`provision-kubernetes.sh`** master script implements these orchestration requirements:

1. **Discover all category directories** in alphabetic order
2. **Execute scripts within each directory** in alphabetic order
3. **Skip scripts** in `not-in-use/` folders
4. **Pass target host parameter** to every script
5. **Continue execution** even if individual scripts fail
6. **Track successes and failures** for summary report
7. **Generate comprehensive summary** of all deployment results
8. **Return appropriate exit code** based on overall success/failure


**Key Point**: This discovery pattern ensures **strict alphabetic execution order** for both directories and scripts.

---

**Related Documentation:**
- [Provision Host Kubernetes Guide](provision-host-kubernetes.md)
- [Rules Overview](rules-readme.md)
- [Secrets Management](rules-secrets-management.md)