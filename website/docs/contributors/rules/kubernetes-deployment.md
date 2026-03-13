# Rules for UIS Deployment System

## Relationship to Other Rules

This document covers the **orchestration and automation framework**:
- How the UIS CLI discovers and deploys services
- Service metadata files and the deploy/undeploy lifecycle
- Stacks (pre-defined service bundles)
- Autostart configuration via `enabled-services.conf`

For **how to write individual Ansible playbooks**, see:
> [Rules for Provisioning](./provisioning.md) - Implementation patterns for playbooks

For **file and resource naming patterns**, see:
> [Naming Conventions](./naming-conventions.md)

## Core Principles

1. **Declarative Service Metadata**: Each service is defined by a metadata file (`service-*.sh`) that declares its properties, deployment method, dependencies, and health check
2. **CLI-Driven Deployment**: All deployments are performed through `./uis deploy` and `./uis undeploy` commands
3. **Dependency Management**: Services declare their requirements via `SCRIPT_REQUIRES` and the system verifies dependencies before deploying
4. **Ansible for Heavy Lifting**: Metadata files delegate actual deployment to Ansible playbooks — no business logic in metadata
5. **Idempotency**: All deployments MUST be safe to run multiple times
6. **Health Verification**: Services define a `SCRIPT_CHECK_COMMAND` for post-deploy health checks

## UIS CLI Commands

### Service Deployment

```bash
# Deploy a single service (also enables it for autostart)
./uis deploy postgresql

# Deploy all enabled services (from enabled-services.conf)
./uis deploy

# Undeploy a single service
./uis undeploy postgresql
```

### Service Management

```bash
# List all available services (grouped by category)
./uis list
./uis list --all            # Include disabled services
./uis list --category AI    # Filter by category

# Show deployed services with health status
./uis status

# Enable/disable autostart (does not deploy/undeploy)
./uis enable postgresql
./uis disable postgresql

# List enabled services
./uis list-enabled
```

### Stack Operations

```bash
# List available stacks
./uis stack list

# Show stack details (services, descriptions)
./uis stack info observability

# Install a stack (deploys all services in order)
./uis stack install observability

# Install stack without optional services
./uis stack install observability --skip-optional

# Remove a stack (undeploys in reverse order)
./uis stack remove observability
```

### Other Commands

```bash
# Show version
./uis version

# Interactive setup menu
./uis setup

# First-time initialization
./uis init

# Sync enabled list with what's actually running in cluster
./uis sync

# Legacy: run old provision-kubernetes.sh system
./uis provision
```

## Service Architecture

### Service Metadata Files

Every service is defined by a metadata file in `provision-host/uis/services/<category>/`:

```
provision-host/uis/services/
├── ai/
│   ├── service-litellm.sh
│   └── service-openwebui.sh
├── analytics/
│   ├── service-jupyterhub.sh
│   ├── service-spark.sh
│   └── service-unity-catalog.sh
├── databases/
│   ├── service-elasticsearch.sh
│   ├── service-mongodb.sh
│   ├── service-mysql.sh
│   ├── service-postgresql.sh
│   └── service-redis.sh
├── identity/
│   └── service-authentik.sh
├── integration/
│   └── service-rabbitmq.sh
├── management/
│   ├── service-argocd.sh
│   ├── service-pgadmin.sh
│   ├── service-redisinsight.sh
│   └── service-whoami.sh
├── networking/
│   ├── service-cloudflare-tunnel.sh
│   └── service-tailscale-tunnel.sh
└── observability/
    ├── service-grafana.sh
    ├── service-loki.sh
    ├── service-otel-collector.sh
    ├── service-prometheus.sh
    └── service-tempo.sh
```

### Metadata File Structure

Each metadata file declares service properties as shell variables. The scanner reads these by parsing the file line-by-line (it does NOT `source` the file during discovery, for safety).

```bash
#!/bin/bash
# service-postgresql.sh - PostgreSQL service metadata

# === Service Metadata (Required) ===
SCRIPT_ID="postgresql"                    # Unique ID used in CLI commands
SCRIPT_NAME="PostgreSQL"                  # Human-readable display name
SCRIPT_DESCRIPTION="Open-source relational database"
SCRIPT_CATEGORY="DATABASES"               # Must match a category ID

# === Deployment Configuration (Optional) ===
SCRIPT_PLAYBOOK="040-database-postgresql.yml"   # Ansible playbook (preferred)
SCRIPT_MANIFEST=""                              # Direct kubectl manifest (alternative)
SCRIPT_REMOVE_PLAYBOOK="040-remove-database-postgresql.yml"
SCRIPT_CHECK_COMMAND="kubectl get pods -n default -l app.kubernetes.io/name=postgresql --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REQUIRES=""                        # Space-separated service IDs
SCRIPT_PRIORITY="30"                      # Deploy order (lower = earlier, default: 50)

# === Deployment Details (Optional) ===
SCRIPT_HELM_CHART="bitnami/postgresql"
SCRIPT_NAMESPACE="default"

# === Extended Metadata (Optional) ===
SCRIPT_KIND="Resource"            # Component | Resource
SCRIPT_TYPE="database"            # service | tool | library | database | cache | message-broker
SCRIPT_OWNER="platform-team"     # platform-team | app-team
SCRIPT_PROVIDES_APIS=""          # API names this service provides (e.g., "myservice-api")
SCRIPT_CONSUMES_APIS=""          # API names this service consumes (e.g., "litellm-api")

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="World's most advanced open-source relational database"
SCRIPT_LOGO="postgresql-logo.webp"
SCRIPT_WEBSITE="https://www.postgresql.org"
SCRIPT_TAGS="database,sql,relational,postgres,rdbms"
SCRIPT_SUMMARY="PostgreSQL is a powerful, open-source object-relational database system..."
SCRIPT_DOCS="/docs/packages/databases/postgresql"
```

**Three metadata groups:**

| Group | Fields | Purpose |
|-------|--------|---------|
| Required | `SCRIPT_ID`, `SCRIPT_NAME`, `SCRIPT_DESCRIPTION`, `SCRIPT_CATEGORY` | Service identity and discovery |
| Deployment | `SCRIPT_PLAYBOOK`, `SCRIPT_MANIFEST`, `SCRIPT_CHECK_COMMAND`, `SCRIPT_REMOVE_PLAYBOOK`, `SCRIPT_REQUIRES`, `SCRIPT_PRIORITY`, `SCRIPT_NAMESPACE` | How to deploy, verify, and remove |
| Extended | `SCRIPT_KIND`, `SCRIPT_TYPE`, `SCRIPT_OWNER`, `SCRIPT_PROVIDES_APIS`, `SCRIPT_CONSUMES_APIS` | Backstage catalog generation |
| Website | `SCRIPT_ABSTRACT`, `SCRIPT_LOGO`, `SCRIPT_WEBSITE`, `SCRIPT_TAGS`, `SCRIPT_SUMMARY`, `SCRIPT_DOCS` | Documentation generation |

**Important constraints:**
- `SCRIPT_PLAYBOOK` and `SCRIPT_MANIFEST` are mutually exclusive — if both are set, playbook takes precedence
- `SCRIPT_REMOVE_PLAYBOOK` can include extra Ansible parameters after the filename (space-separated)
- Files starting with `_` (e.g., `_helper.sh`) are skipped by the scanner
- Each variable must be on its own line in `KEY="value"` format for the line-by-line parser

### Categories

Services are organized into 9 categories (defined in `provision-host/uis/lib/categories.sh`):

| Category ID | Display Name | Description | Manifest Range |
|------------|--------------|-------------|----------------|
| `OBSERVABILITY` | Observability | Metrics, logs, and tracing | 030-039 |
| `AI` | AI & ML | AI and machine learning services | 200-229 |
| `ANALYTICS` | Analytics | Data science and analytics platforms | 300-399 |
| `IDENTITY` | Identity | Identity and access management | 070-079 |
| `DATABASES` | Databases | Data storage and caching services | 040-099 |
| `MANAGEMENT` | Management | Admin tools, GitOps, and test services | 600-799 |
| `NETWORKING` | Networking | VPN tunnels and network access | — |
| `STORAGE` | Storage | Platform storage infrastructure | 000-009 |
| `INTEGRATION` | Integration | Messaging, API gateways, and event streams | — |

**Note**: `STORAGE` and `NETWORKING` are platform-dependent — Traefik and storage provisioners are managed by Rancher Desktop, not by `./uis deploy`.

### Service Discovery

The service scanner (`provision-host/uis/lib/service-scanner.sh`) discovers services by:

1. Walking `provision-host/uis/services/` recursively for `*.sh` files
2. Skipping files starting with `_` (helper scripts)
3. Parsing each file line-by-line for `SCRIPT_ID=`, `SCRIPT_NAME=`, etc.
4. Caching results for performance (cache is an in-memory indexed array)

The scanner never `source`s scripts during discovery — this is a safety measure. Only `deploy_single_service` in `service-deployment.sh` actually sources a metadata file (to load all variables for deployment).

## Deploy Flow

When you run `./uis deploy <service>`, the system follows this sequence:

```
./uis deploy postgresql
    │
    ├─ 1. Find service script via service scanner
    │     └─ Locates provision-host/uis/services/databases/service-postgresql.sh
    │
    ├─ 2. Source metadata file (loads all SCRIPT_* variables)
    │
    ├─ 3. Check dependencies (SCRIPT_REQUIRES)
    │     └─ For each required service, verify it's deployed via SCRIPT_CHECK_COMMAND
    │     └─ Fail fast if any dependency is missing
    │
    ├─ 4. Execute deployment (mutually exclusive methods):
    │     ├─ If SCRIPT_PLAYBOOK: ansible-playbook <playbook> -e "target_host=<host>"
    │     └─ If SCRIPT_MANIFEST: kubectl apply -f <manifest>
    │
    ├─ 5. Post-deploy health check (if SCRIPT_CHECK_COMMAND is set)
    │     └─ Wait 2 seconds, then run health check
    │     └─ Failure is a warning, not an error
    │
    └─ 6. Auto-enable service in enabled-services.conf
```

**`./uis deploy` (no argument)** deploys all services listed in `enabled-services.conf`, in order. Stops on first failure.

**`./uis undeploy <service>`** uses a three-tier removal strategy:
1. If `SCRIPT_REMOVE_PLAYBOOK` is set: run the removal playbook
2. Else if `SCRIPT_MANIFEST` is set: `kubectl delete -f <manifest> --ignore-not-found`
3. Else: warn "no removal method found"

### Target Host

The target host (default: `rancher-desktop`) is read from `cluster-config.sh`. This determines which Kubernetes context Ansible uses. Supported cluster types:
- `rancher-desktop` (default, local development)
- `azure-aks`
- `azure-microk8s`
- `multipass-microk8s`
- `raspberry-microk8s`

## Stacks

Stacks are pre-defined bundles of services that work together. They are defined in `provision-host/uis/lib/stacks.sh`.

### Available Stacks

| Stack | Services | Optional |
|-------|----------|----------|
| **observability** | prometheus, tempo, loki, otel-collector, grafana | otel-collector |
| **ai-local** | litellm, openwebui | — |
| **analytics** | spark, jupyterhub, unity-catalog | unity-catalog |

### Stack Behavior

- **Install**: Services are deployed left-to-right in the defined order (dependencies first)
- **Remove**: Services are removed in **reverse** order (dependents first)
- **`--skip-optional`**: Skips services listed as optional for the stack
- Each service installed via a stack is automatically added to `enabled-services.conf`

## Autostart Configuration

The file `.uis.extend/enabled-services.conf` controls which services are deployed when running `./uis deploy` without arguments.

```bash
# Enable a service (adds to enabled-services.conf)
./uis enable postgresql

# Disable a service (removes from enabled-services.conf)
./uis disable postgresql

# List what's enabled
./uis list-enabled

# Sync enabled list with cluster state
./uis sync
```

The `sync` command scans the cluster for running services and adds them to the enabled list — useful after manual deployments or when the enabled list gets out of sync.

## Adding a New Service

For a complete step-by-step walkthrough, see the **[Adding a Service Guide](../guides/adding-a-service.md)**.

## Legacy System

The old deployment system (`provision-host/kubernetes/` with numbered directories and `provision-kubernetes.sh`) still exists for backward compatibility:

```bash
# Run the old orchestration system
./uis provision
```

This executes `provision-host/kubernetes/provision-kubernetes.sh`, which discovers numbered directories (e.g., `01-core/`, `02-databases/`) and runs scripts within them in alphabetic order. The old system uses `not-in-use/` subdirectories to control which scripts execute.

**The old system is not actively maintained.** New services should use the UIS metadata + Ansible pattern described above.

---

**Related Documentation:**
- [Rules for Provisioning](./provisioning.md) - Ansible playbook patterns
- [Naming Conventions](./naming-conventions.md) - File and resource naming
- [Rules Overview](./index.md)
- [Secrets Management](./secrets-management.md)
- [Ingress and Traefik](./ingress-traefik.md)
