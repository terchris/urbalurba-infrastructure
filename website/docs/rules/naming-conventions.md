# Naming Conventions

**Purpose:** Define consistent naming patterns for all files, resources, and identifiers in the urbalurba-infrastructure project.

**Principle:** Predictable names enable automation and make the codebase easier to navigate.

---

## File Naming Conventions

### Manifest Files (manifests/*.yaml)

**Pattern:** `NNN-component-type.yaml`

**Number Ranges:**
- **000-029:** Core infrastructure (storage, ingress, DNS, networking)
- **030-039:** Monitoring and observability
- **040-069:** Data services (databases, caches, message queues)
- **070-079:** Authentication and authorization
- **080-099:** Reserved for future core services
- **200-229:** AI and ML services
- **230-299:** Application services
- **600-799:** Management and admin tools
- **800-899:** Development and testing
- **900-999:** Reserved for custom/experimental

**Type Suffixes:**
- `-config.yaml` - Helm values configuration
- `-ingressroute.yaml` - Traefik IngressRoute definition
- `-configmap.yaml` - Kubernetes ConfigMap
- `-secret.yaml` - Kubernetes Secret (never committed)
- `-dashboards.yaml` - Grafana dashboard ConfigMaps

**Examples:**
```
030-prometheus-config.yaml          # Prometheus Helm values
031-tempo-config.yaml               # Tempo Helm values
032-loki-config.yaml                # Loki Helm values
033-otel-collector-config.yaml      # OTEL Collector Helm values
034-grafana-config.yaml             # Grafana Helm values
035-grafana-dashboards.yaml         # Installation test dashboards
036-grafana-sovdev-verification.yaml # sovdev-logger verification dashboard
037-grafana-loggeloven-dashboards.yaml # Loggeloven test suite
038-grafana-ingressroute.yaml       # Grafana UI ingress
039-otel-collector-ingressroute.yaml # OTEL ingress

040-postgresql-config.yaml          # PostgreSQL
041-mysql-config.yaml               # MySQL
042-mongodb-config.yaml             # MongoDB
043-redis-config.yaml               # Redis

070-authentik-config.yaml           # Authentik SSO
071-authentik-blueprints.yaml       # Authentik user/group definitions
076-authentik-csp-middleware.yaml   # CSP headers middleware

200-openwebui-config.yaml           # OpenWebUI
201-ollama-config.yaml              # Ollama
202-litellm-config.yaml             # LiteLLM
```

**Numbering Rules:**
1. Main component gets base number (e.g., 030 for Prometheus)
2. Related configs use sequential numbers (031, 032, 033...)
3. IngressRoutes use component's number + 8 (e.g., Grafana=034, Ingress=038)
4. Dashboards use component's number + variations (035, 036, 037)
5. Leave gaps for future expansion within each range

---

### Ansible Playbooks (ansible/playbooks/*.yml)

**Pattern:** `NNN-action-component.yml`

**Number:** Must match corresponding manifest file number

**Actions:**
- `setup-` - Deploy/install component
- `remove-` - Uninstall/delete component
- `update-` - Modify existing component
- `test-` - Verification/testing playbook

**Examples:**
```
030-setup-prometheus.yml            # Deploys using manifests/030-prometheus-config.yaml
030-remove-prometheus.yml           # Removes Prometheus
031-setup-tempo.yml                 # Deploys using manifests/031-tempo-config.yaml
031-remove-tempo.yml                # Removes Tempo
033-setup-otel-collector.yml        # Deploys OTEL Collector
033-remove-otel-collector.yml       # Removes OTEL Collector
034-setup-grafana.yml               # Deploys Grafana
034-remove-grafana.yml              # Removes Grafana
```

**Pattern Rules:**
1. Setup playbook references external manifest via `values_files: ["{{ config_file }}"]` or `-f {{ config_file }}`
2. Remove playbook just removes Helm chart
3. Number MUST match manifest file (030 playbook uses 030 manifest)
4. Never use inline Helm values - always reference external manifest

---

### Service Metadata Files (provision-host/uis/services/)

**Pattern:** `service-[name].sh`

**Location:** `provision-host/uis/services/<category>/`

**Relationship to Playbooks:**
- Metadata file declares which Ansible playbook to run (`SCRIPT_PLAYBOOK`)
- The UIS CLI reads the metadata and calls the playbook automatically
- No imperative code — metadata files are declarative variable assignments
- Files starting with `_` are skipped by the scanner (used for helper scripts)

**Examples:**
```
provision-host/uis/services/
├── observability/
│   ├── service-prometheus.sh        # SCRIPT_PLAYBOOK="030-setup-prometheus.yml"
│   ├── service-tempo.sh             # SCRIPT_PLAYBOOK="031-setup-tempo.yml"
│   ├── service-loki.sh              # SCRIPT_PLAYBOOK="032-setup-loki.yml"
│   ├── service-otel-collector.sh    # SCRIPT_PLAYBOOK="033-setup-otel-collector.yml"
│   └── service-grafana.sh           # SCRIPT_PLAYBOOK="034-setup-grafana.yml"
├── databases/
│   ├── service-postgresql.sh        # SCRIPT_PLAYBOOK="040-database-postgresql.yml"
│   ├── service-mysql.sh             # SCRIPT_PLAYBOOK="041-database-mysql.yml"
│   └── service-redis.sh             # SCRIPT_PLAYBOOK="043-setup-redis.yml"
└── ai/
    ├── service-litellm.sh           # SCRIPT_PLAYBOOK="210-setup-litellm.yml"
    └── service-openwebui.sh         # SCRIPT_PLAYBOOK="208-setup-openwebui.yml"
```

**Metadata File Structure:**
```bash
#!/bin/bash
# service-[name].sh - [Service] service metadata

# === Required ===
SCRIPT_ID="name"                        # Unique CLI identifier
SCRIPT_NAME="Display Name"              # Human-readable name
SCRIPT_DESCRIPTION="Brief description"
SCRIPT_CATEGORY="CATEGORY_ID"           # One of the 9 categories

# === Deployment (Optional) ===
SCRIPT_PLAYBOOK="NNN-setup-name.yml"    # Ansible playbook
SCRIPT_REMOVE_PLAYBOOK="NNN-remove-name.yml"
SCRIPT_CHECK_COMMAND="kubectl get pods ..."
SCRIPT_REQUIRES=""                      # Space-separated service IDs
SCRIPT_PRIORITY="50"                    # Deploy order (lower = earlier)
```

---

### Directory Structure

**UIS Service Directory** — services organized by category:
```
provision-host/uis/services/
├── ai/                             # AI & ML services
├── analytics/                      # Data science and analytics
├── databases/                      # Data storage and caching
├── identity/                       # Identity and access management
├── integration/                    # Messaging and API gateways
├── management/                     # Admin tools and GitOps
├── networking/                     # VPN tunnels and network access
├── observability/                  # Metrics, logs, and tracing
└── storage/                        # Platform storage infrastructure
```

**Supporting Directories:**
```
provision-host/uis/
├── lib/                            # Core libraries (categories, stacks, deployment logic)
├── manage/                         # CLI entry point (uis-cli.sh)
├── services/                       # Service metadata files (see above)
└── templates/                      # Config templates and defaults
```

**Rules:**
1. Category directories match the 9 UIS categories (lowercase)
2. Service files use `service-[name].sh` naming pattern
3. Helper files use `_` prefix (skipped by scanner)

---

## Kubernetes Resource Naming

### Namespaces

**Pattern:** `lowercase-descriptive`

Most services deploy to the `default` namespace. Dedicated namespaces are used when a service requires isolation or when the Helm chart creates its own namespace.

**Examples:**
```
default            # Most services (PostgreSQL, MySQL, Redis, pgAdmin, whoami, LiteLLM, etc.)
monitoring         # Observability stack (Prometheus, Grafana, Loki, Tempo, OTEL)
authentik          # Authentik SSO
kube-system        # Kubernetes system
traefik            # Traefik ingress controller
```

**Rules:**
1. Single word or hyphenated
2. All lowercase
3. Prefer `default` namespace unless isolation is needed
4. No version numbers

---

### Helm Release Names

**Pattern:** `component-name`

**Examples:**
```
prometheus              # Prometheus monitoring
tempo                   # Tempo tracing
loki                    # Loki log aggregation
otel-collector          # OpenTelemetry Collector
grafana                 # Grafana visualization
authentik               # Authentik SSO
openwebui               # OpenWebUI
```

**Rules:**
1. Match component name
2. Lowercase with hyphens
3. No namespace prefix (namespace is separate)
4. Use official chart name when possible

---

### ConfigMap Names

**Pattern:** `component-purpose` or `component-purpose-generated`

**Examples:**
```
grafana-dashboards-installation     # Installation test dashboards
grafana-dashboards-sovdev           # sovdev-logger verification
grafana-dashboards-loggeloven       # Loggeloven test suite
otel-collector-config               # OTEL Collector configuration
```

**Rules:**
1. Start with component name
2. Add descriptive suffix
3. Use `-generated` suffix for auto-generated content
4. All lowercase with hyphens

---

### IngressRoute Names

**Pattern:** `component` or `component-variant`

**Examples:**
```
grafana                 # Grafana UI ingress
otel-collector          # OTEL Collector ingress
prometheus              # Prometheus UI ingress (if needed)
authentik               # Authentik SSO ingress
whoami-protected        # Test service with auth
whoami-public          # Test service without auth
```

**Rules:**
1. Match component name
2. Add variant suffix if multiple routes for same component
3. Use descriptive suffixes: `-protected`, `-public`, `-api`, `-ui`

---

## Git and Version Control

### Branch Names

**Pattern:** `type/description`

**Types:**
- `feature/` - New feature development
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Testing changes

**Examples:**
```
feature/monitoring-stack-migration
feature/sovdev-logger-integration
fix/authentik-csp-headers
docs/development-workflow
refactor/monitoring-030-039
```

**Rules:**
1. Lowercase with hyphens
2. Descriptive but concise
3. Type prefix required
4. No ticket numbers (use PR description)

---

### Commit Messages

**Pattern:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Tests
- `chore:` - Maintenance

**Examples:**
```
feat: Add sovdev-logger TypeScript implementation

- Multi-transport architecture (Console + File + OTLP)
- Smart defaults for production vs development
- Full Loggeloven compliance with credential filtering

Closes #123

---

fix: OTLP collector ingress Host header routing

Add missing Host header to OTEL Collector IngressRoute
to enable proper Traefik routing for external OTLP ingestion.

---

docs: Create development workflow rules

Add docs/rules-development-workflow.md explaining
Claude Code vs manual workflows and path conventions.
```

**Rules:**
1. Subject line: 50 chars max, imperative mood, no period
2. Body: Wrap at 72 chars, explain what and why
3. Footer: Reference issues/PRs
4. Use type prefix

---

## Summary

**Key Principles:**
1. ✅ Numbers indicate deployment order and relationships
2. ✅ Manifest number = Playbook number (030 manifest → 030 playbook)
3. ✅ Scripts are sequential within directory (01, 02, 03...)
4. ✅ All lowercase with hyphens for most names
5. ✅ Descriptive suffixes for variants (-config, -ingressroute, -dashboards)
6. ✅ Leave gaps in numbering for future expansion
7. ✅ External manifest files, never inline Helm values
8. ✅ Consistent patterns across all file types

**When adding new components:**
1. Create a service metadata file in `provision-host/uis/services/<category>/service-<name>.sh`
2. Choose appropriate manifest number range for the category
3. Create manifest config file(s) in `manifests/`
4. Create matching Ansible playbooks (setup + remove) in `ansible/playbooks/`
5. Set `SCRIPT_PLAYBOOK`, `SCRIPT_REMOVE_PLAYBOOK`, and `SCRIPT_CHECK_COMMAND` in metadata
6. Declare dependencies with `SCRIPT_REQUIRES` if needed
7. Test with `./uis deploy <name>` and `./uis status`

**Reference:**
- [doc/rules-development-workflow.md](./development-workflow.md) - Workflow and command execution
- [doc/rules-automated-kubernetes-deployment.md](./kubernetes-deployment.md) - UIS deployment system
- [doc/rules-ingress-traefik.md](./ingress-traefik.md) - IngressRoute patterns
