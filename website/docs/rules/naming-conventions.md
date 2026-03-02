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

### Shell Scripts (provision-host/kubernetes/*/*)

**Pattern:** `NN-action-component.sh`

**Script Number:** Sequential within directory (01, 02, 03...)

**Actions:** Same as playbooks (`setup-`, `remove-`, `update-`, `test-`)

**Relationship to Playbooks:**
- Script number is independent of playbook number
- Script wraps Ansible playbook call
- Script provides proper context and parameters

**Examples:**
```
provision-host/kubernetes/11-monitoring/not-in-use/
├── 00-setup-all-monitoring.sh      # Orchestrates all setup scripts
├── 00-remove-all-monitoring.sh     # Orchestrates all remove scripts
├── 01-setup-prometheus.sh          # Calls ansible/playbooks/030-setup-prometheus.yml
├── 01-remove-prometheus.sh         # Calls ansible/playbooks/030-remove-prometheus.yml
├── 02-setup-tempo.sh               # Calls ansible/playbooks/031-setup-tempo.yml
├── 02-remove-tempo.sh              # Calls ansible/playbooks/031-remove-tempo.yml
├── 03-setup-loki.sh                # Calls ansible/playbooks/032-setup-loki.yml
├── 03-remove-loki.sh               # Calls ansible/playbooks/032-remove-loki.yml
├── 04-setup-otel-collector.sh      # Calls ansible/playbooks/033-setup-otel-collector.yml
├── 04-remove-otel-collector.sh     # Calls ansible/playbooks/033-remove-otel-collector.yml
├── 05-setup-grafana.sh             # Calls ansible/playbooks/034-setup-grafana.yml
└── 05-remove-grafana.sh            # Calls ansible/playbooks/034-remove-grafana.yml
```

**Script Content Pattern:**
```bash
#!/bin/bash
# Description of what this script does

# Check if target host provided
if [ -z "$1" ]; then
    echo "Usage: $0 <target_host>"
    exit 1
fi

TARGET_HOST="$1"

# Call Ansible playbook
ansible-playbook /mnt/urbalurbadisk/ansible/playbooks/030-setup-prometheus.yml \
    -e "target_host=${TARGET_HOST}"
```

---

### Directory Structure

**Pattern:** Numbered directories for deployment order

**Examples:**
```
provision-host/kubernetes/
├── 00-system/                      # Core system setup
├── 01-storage/                     # Storage provisioners
├── 02-ingress/                     # Traefik ingress
├── 03-dns/                         # DNS services
├── 11-monitoring/                  # Monitoring stack
│   └── not-in-use/                # Testing/development area
├── 12-databases/                   # Database services
├── 13-auth/                        # Authentication services
└── 20-applications/                # Application deployments
```

**Rules:**
1. Two-digit prefix for ordering
2. Descriptive name after number
3. `not-in-use/` subdirectory for scripts under development

---

## Kubernetes Resource Naming

### Namespaces

**Pattern:** `lowercase-descriptive`

**Examples:**
```
monitoring          # Monitoring stack (Prometheus, Grafana, Loki, Tempo, OTEL)
databases          # Database services
authentik          # Authentik SSO
openwebui          # OpenWebUI and AI services
kube-system        # Kubernetes system (default)
traefik            # Traefik ingress controller
```

**Rules:**
1. Single word or hyphenated
2. All lowercase
3. Descriptive of purpose
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
1. Choose appropriate number range
2. Create manifest file with proper suffix
3. Create matching Ansible playbooks (setup + remove)
4. Create shell script wrappers
5. Follow established patterns
6. Leave room for related components

**Reference:**
- [doc/rules-development-workflow.md](./development-workflow.md) - Workflow and command execution
- [doc/rules-automated-kubernetes-deployment.md](./kubernetes-deployment.md) - Ansible patterns *(to be created)*
- [doc/rules-ingress-traefik.md](./ingress-traefik.md) - IngressRoute patterns *(to be created)*
