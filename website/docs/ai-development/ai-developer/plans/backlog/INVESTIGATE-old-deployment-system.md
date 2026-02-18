# INVESTIGATE: Old Deployment System & UIS Migration

**Status:** Investigation Complete
**Created:** 2026-01-31
**Related to:** [STATUS-service-migration](STATUS-service-migration.md)

---

## Summary

The old deployment system (`provision-host/kubernetes/`) used numbered shell scripts that ran automatically on boot. Moving a script to `not-in-use/` disabled it. The new UIS system (`provision-host/uis/`) replaced this with metadata-only service scripts and a CLI orchestrator. Both systems use the same Ansible playbooks.

---

## Old Deployment System

### How It Worked

1. **Boot sequence**: `provision-kubernetes.sh` ran all scripts in numbered category folders
2. **Activation**: Script in main folder = runs on boot
3. **Deactivation**: Move script to `not-in-use/` = disabled
4. **Execution**: Each script validated environment, then called an Ansible playbook

### Category Folders

| Category | Purpose | Scripts (active / disabled) |
|----------|---------|:--:|
| `01-core` | Nginx | 1 / 1 |
| `02-databases` | PostgreSQL, MySQL, MongoDB, Qdrant | 0 / 8 |
| `03-queues` | Redis, RabbitMQ | 0 / 4 |
| `04-search` | Elasticsearch | 0 / 2 |
| `05-apim` | Gravitee | 0 / 1 |
| `06-management` | pgAdmin, RedisInsight | 0 / 4 |
| `07-ai` | OpenWebUI, LiteLLM | 0 / 6 |
| `08-development` | ArgoCD | 0 / 2 |
| `09-network` | Tailscale, Cloudflare tunnels | 0 / 6 |
| `10-datascience` | Spark, JupyterHub, Unity Catalog | 0 / 6 |
| `11-monitoring` | Prometheus, Grafana, Loki, Tempo, OTEL | 0 / 14 |
| `12-auth` | Authentik | 0 / 2 |
| `99-test` | Whoami test service | 0 / 2 |
| **Total** | | **1 / 58** |

58 of 60 scripts have been moved to `not-in-use/`. Only `01-core/020-setup-nginx.sh` remains active.

### Script Pattern

Old scripts followed this pattern:

```bash
#!/bin/bash
# 1. Validate bash version
# 2. Check kubectl connection and context
# 3. Run Ansible playbook
# 4. Print summary
```

Each script was a wrapper around `ansible-playbook` with environment validation. The real logic was always in the Ansible playbook.

---

## New UIS System

### How It Works

1. **Host wrapper**: `./uis` script manages the Docker container and routes commands
2. **CLI**: `uis-cli.sh` inside the container handles all commands
3. **Service discovery**: `service-scanner.sh` finds all `service-*.sh` files and parses metadata
4. **Deployment**: Reads metadata → runs Ansible playbook → verifies health

### Architecture

```
Host machine
    └─> ./uis deploy postgresql
            └─> docker exec provision-host uis-cli.sh deploy postgresql
                    ├─> service-scanner.sh finds service-postgresql.sh
                    ├─> Loads metadata (SCRIPT_PLAYBOOK, SCRIPT_CHECK_COMMAND, etc.)
                    ├─> ansible-playbook 040-database-postgresql.yml
                    └─> Runs health check
```

### Service Metadata Scripts

24 services across 10 categories in `provision-host/uis/services/`:

```bash
# service-postgresql.sh — no executable logic, just variables
SCRIPT_ID="postgresql"
SCRIPT_NAME="PostgreSQL"
SCRIPT_CATEGORY="DATABASES"
SCRIPT_PLAYBOOK="040-database-postgresql.yml"
SCRIPT_REMOVE_PLAYBOOK="040-remove-database-postgresql.yml"
SCRIPT_CHECK_COMMAND="kubectl get pods -n default -l app.kubernetes.io/name=postgresql..."
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="30"
SCRIPT_DOCS="/docs/packages/databases/postgresql"
```

### Key Commands

```bash
./uis list                      # Show services and status
./uis deploy [service]          # Deploy specific or all enabled services
./uis undeploy <service>        # Remove service
./uis enable <service>          # Add to autostart
./uis disable <service>         # Remove from autostart
./uis stack install <stack>     # Deploy service bundle
./uis status                    # Health check all deployed services
./uis provision                 # Legacy: runs old provision-kubernetes.sh
```

### Library Modules (`provision-host/uis/lib/`)

| Library | Purpose |
|---------|---------|
| `paths.sh` | Single source of truth for all paths |
| `utilities.sh` | Common helpers, kubectl checks |
| `logging.sh` | Consistent colored output |
| `service-scanner.sh` | Service discovery and metadata extraction |
| `service-deployment.sh` | Deployment orchestration |
| `service-auto-enable.sh` | Enable/disable management |
| `categories.sh` | Service category organization |
| `stacks.sh` | Pre-defined service bundles |
| `first-run.sh` | Initial configuration setup |
| `secrets-management.sh` | Kubernetes secrets generation |
| `tool-installation.sh` | Optional cloud CLI tools |
| `menu-helpers.sh` | Interactive TUI support |
| `uis-hosts.sh` | Multi-node host configuration |

### Stacks (Pre-defined Bundles)

| Stack | Services |
|-------|----------|
| observability | prometheus, tempo, loki, grafana |
| ai-local | litellm, openwebui |
| datascience | spark, jupyterhub, unity-catalog |

### Configuration

| Location | Purpose |
|----------|---------|
| `.uis.extend/enabled-services.conf` | Which services to deploy |
| `.uis.extend/cluster-config.sh` | Cluster type, domain, project |
| `.uis.secrets/service-keys/` | API keys (Tailscale, Cloudflare, OpenAI) |
| `.uis.secrets/generated/` | Generated Kubernetes secrets |

---

## Mapping: Old System → New System

| Old System | New UIS System | Shared |
|------------|---------------|--------|
| `provision-host/kubernetes/02-databases/05-setup-postgres.sh` | `provision-host/uis/services/databases/service-postgresql.sh` | `ansible/playbooks/040-database-postgresql.yml` |
| `provision-host/kubernetes/12-auth/01-setup-authentik.sh` | `provision-host/uis/services/authentication/service-authentik.sh` | `ansible/playbooks/070-setup-authentik.yml` |
| `provision-host/kubernetes/08-development/02-setup-argocd.sh` | `provision-host/uis/services/management/service-argocd.sh` | `ansible/playbooks/220-setup-argocd.yml` |

The old scripts and new service scripts are different interfaces to the same Ansible playbooks.

---

## Remaining Issue

`01-core/020-setup-nginx.sh` is still in the active position (not in `not-in-use/`). It has a corresponding UIS service script (`service-nginx.sh`), so it could be moved to `not-in-use/` to match the rest.

---

## Key Design Differences

| Aspect | Old System | New UIS System |
|--------|-----------|----------------|
| Activation | File position in folder | `./uis enable` / `enabled-services.conf` |
| Execution | All scripts run on boot | Selective: `./uis deploy <service>` |
| Script content | Validation + Ansible call | Pure metadata (no logic) |
| Dependencies | Implicit (number ordering) | Explicit (`SCRIPT_REQUIRES`) |
| Health checks | None | `SCRIPT_CHECK_COMMAND` |
| Organization | Numbered folders | Named categories |
| Removal | Separate remove scripts | `SCRIPT_REMOVE_PLAYBOOK` metadata |
