# Investigate: Backstage Developer Portal for UIS

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Completed

**Goal**: Deploy Backstage as the developer portal for UIS, modeling all existing services in a software catalog

**Last Updated**: 2026-03-12

**Implementation**: [PLAN-002-backstage-deployment.md](../completed/PLAN-002-backstage-deployment.md) — completed 2026-03-12. Backstage (RHDH 1.9) deployed with 25 catalog components, K8s plugin, guest auth, full deploy/undeploy/verify cycle.

**Depends on:** PostgreSQL (042), Traefik ingress. Authentik (070-079) is optional — Backstage works without authentication.

**Draft catalog:** [catalog/](catalog/) — 25 Backstage entity files (components, systems, domains, resources, groups) ready to load

---

## Questions to Answer

1. ~~How should the custom Docker image be built?~~ → **Resolved: Use RHDH pre-built community image with dynamic plugins. No custom image needed.**
2. ~~Which plugins?~~ → **Resolved: Start with RHDH built-in (K8s, OIDC, ArgoCD). Add TechDocs via config.**
3. ~~PostgreSQL?~~ → **Resolved: Reuse existing shared PostgreSQL.**
4. ~~Catalog source of truth?~~ → **Resolved: Generate from service definitions.**
5. ~~Which RHDH version to pin?~~ → **Resolved: Pin to a specific release tag.** Update manually when needed.
6. Should TechDocs be enabled for developer-written integration docs? (Deferred — the existing Docusaurus site at uis.sovereignsky.no covers platform docs. TechDocs becomes relevant when developers write docs alongside their integration code in separate repos. Decide when that need arises.)
7. ~~Is RHDH too heavy for a laptop?~~ → **Deferred: Start with RHDH (tuned-down resources), measure, switch to custom image if needed.** See "Resource Usage and Image Strategy" section.

---

## Problem Statement

UIS deploys 40+ services across 11 namespaces, but there is no single place to discover what's running, who owns what, how services relate to each other, or where to find documentation. Developers must read manifests, Ansible playbooks, and numbered file conventions to understand the platform.

Backstage (by Spotify) is an open-source developer portal that provides a software catalog, documentation hub, and Kubernetes visibility in one UI. The goal is to deploy Backstage in UIS and model all existing systems so developers get a "single pane of glass" for the platform.

---

## What is Backstage?

Backstage is a CNCF Incubating project originally built at Spotify, adopted by 3,000+ companies. It is a Node.js/TypeScript application that provides:

- **Software Catalog** — Central registry of all services, APIs, resources, and their relationships
- **TechDocs** — "Docs like code" rendered from Markdown alongside source code
- **Software Templates (Scaffolder)** — Wizard-driven project creation following org standards
- **Kubernetes Plugin** — Live pod status, deployment health, logs from within the portal
- **Plugin Ecosystem** — Hundreds of plugins for GitHub, Grafana, ArgoCD, and more

### Entity Model

Backstage models software using these entity types:

| Entity | Description | UIS Example |
|--------|-------------|-------------|
| **Domain** | Business area grouping related systems | `uis-infrastructure` (one domain for the whole platform) |
| **System** | Collection of components exposing APIs | `observability`, `ai`, `databases` (9 systems, one per SCRIPT_CATEGORY) |
| **Component** | A piece of software (service, website, library) | OpenWebUI, Grafana, Authentik |
| **API** | Boundary between components (REST, gRPC, events) | LiteLLM proxy API, Gravitee gateway API |
| **Resource** | Infrastructure dependency (database, cache, queue) | PostgreSQL, Redis, RabbitMQ |
| **Group** | Organizational unit (team, department) | `platform-team`, `app-team` |
| **User** | Individual person | Developers using UIS |

Entities are defined in `catalog-info.yaml` YAML files and ingested by Backstage.

---

## Deployment in UIS

Follow the [Adding a Service](../../../contributors/guides/adding-a-service.md) guide. This section maps Backstage to the UIS service conventions.

### Distribution: Red Hat Developer Hub (RHDH)

Instead of vanilla Backstage (which requires building a custom Docker image with plugins), UIS starts with **Red Hat Developer Hub (RHDH)** — an open-source (Apache 2.0) Backstage distribution that ships with plugins pre-installed and supports adding more via config at runtime.

**Why RHDH as the starting point:**
- Pre-built image with **Kubernetes and Keycloak/OIDC plugins** included out of the box
- **Dynamic plugins** — add/remove plugins via `dynamic-plugins.yaml` config, no image rebuild, just restart
- Plugins distributed as **OCI artifacts** pulled at startup (RHDH 1.9 pattern)
- **ARM64 community image** available — works on Apple Silicon Macs with Rancher Desktop
- Eliminates the custom Docker image build and maintenance burden entirely
- Runs on vanilla Kubernetes (not limited to OpenShift)

**Current version:** RHDH 1.9 (as of early 2026)

```bash
helm repo add rhdh-chart https://redhat-developer.github.io/rhdh-chart
helm upgrade -i backstage rhdh-chart/backstage -n backstage
```

**Images:**
- Community: `quay.io/rhdh-community/rhdh` (free, ARM64 supported)
- Red Hat supported: `quay.io/organization/rhdh` (requires subscription)

**Source:** [github.com/redhat-developer/rhdh](https://github.com/redhat-developer/rhdh)

### Resource Usage and Image Strategy

RHDH is heavier than vanilla Backstage because it bundles 50+ plugins (many OpenShift-focused) and a dynamic plugin download infrastructure. The RHDH Helm chart defaults are significant for a laptop:

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| **Backstage app** | 250m | 1000m | 1 Gi | 2.5 Gi |
| **Plugin installer** (init container) | 250m | 1000m | 256 Mi | 2.5 Gi |
| **PostgreSQL** (if not shared) | 250m | 250m | 256 Mi | 1 Gi |

For comparison, vanilla Backstage sets `resources: {}` (no defaults).

**What UIS actually needs from the image:**

| Plugin | Why | Required? | Included in RHDH? |
|--------|-----|-----------|-------------------|
| Software Catalog | Core — the whole point | Yes | Yes (built-in) |
| Kubernetes | Live pod status, deploy/undeploy visibility | Yes | Yes |
| Grafana | Link services to their monitoring dashboards | Yes | Add via config |
| OIDC auth | Login via Authentik (optional) | Optional | Yes |
| ArgoCD | Deployment status (nice-to-have) | Nice-to-have | Yes |
| TechDocs | Docs rendering (deferred) | Deferred | Add via config |

The OpenShift-specific plugins (Tekton, Topology, OCM) are bundled but not useful on vanilla Kubernetes. They can be ignored.

**No lightweight alternative exists.** The ecosystem is split between:
- Official vanilla image (`ghcr.io/backstage/backstage`) — demo only, no K8s plugin
- RHDH community image — includes everything we need, but heavy
- SaaS products (Roadie, Port, Cortex) — not self-hosted
- Custom image — exactly what you need, but requires a Node.js build pipeline

**Strategy: Start with RHDH, optimize later.**
1. Deploy RHDH with tuned-down resources (256Mi request / 1Gi limit instead of defaults) — validates the catalog, K8s plugin, and OIDC integration work correctly
2. Measure actual resource usage on the cluster
3. If too heavy: build a minimal custom image with only the K8s and OIDC plugins — the catalog generator, playbooks, and manifests remain the same, only the image reference and Helm values change

### Requirements

| Requirement | UIS Approach |
|-------------|--------------|
| PostgreSQL | Reuse existing PostgreSQL (042-series) or deploy dedicated instance |
| Container port | 7007 (backend serves API + frontend) |
| Health check | `/healthcheck` on port 7007 |
| Ingress | Traefik IngressRoute for `backstage.localhost` |
| Authentication | Optional — Authentik via OIDC (070-series) if deployed. Backstage works without auth on local clusters. |
| Kubernetes access | ServiceAccount with read-only cluster RBAC |

### Category and Manifest Number

Backstage is a management/developer portal tool → **MANAGEMENT** category (600-799).

Proposed manifest prefix: **650**

### UIS Service Files

Following the [Adding a Service](../../../contributors/guides/adding-a-service.md) guide:

| Piece | File | Purpose |
|-------|------|---------|
| Service definition | `provision-host/uis/services/management/service-backstage.sh` | CLI metadata, deploy/undeploy/status |
| Setup playbook | `ansible/playbooks/650-setup-backstage.yml` | Helm install + IngressRoute + RBAC |
| Remove playbook | `ansible/playbooks/650-remove-backstage.yml` | Helm uninstall + cleanup |
| Verify playbook | `ansible/playbooks/650-test-backstage.yml` | E2E health and catalog tests |
| Helm values | `manifests/650-backstage-config.yaml` | RHDH Helm values (uses `upstream.backstage`, `global.dynamic` keys — different from vanilla Backstage chart) |
| IngressRoute | `manifests/651-backstage-ingressroute.yaml` | Traefik route for `backstage.localhost` |
| RBAC | `manifests/652-backstage-rbac.yaml` | ServiceAccount + ClusterRoleBinding for K8s plugin |
| Catalog entities | `manifests/653-backstage-catalog.yaml` | ConfigMap with catalog entity definitions |
| DB setup | `ansible/playbooks/utility/u10-backstage-create-postgres.yml` | Create backstage database in shared PostgreSQL |
| Secrets | `provision-host/uis/templates/secrets-templates/` | OIDC client ID/secret, session secret, DB password |
| Helm repo | `ansible/playbooks/05-install-helm-repos.yml` | Add `rhdh-chart` Helm repo |
| Documentation | `website/docs/packages/management/backstage.md` | Docs website page |

### Service Definition

```bash
#!/bin/bash
# service-backstage.sh - Backstage Developer Portal metadata

# === Service Metadata (Required) ===
SCRIPT_ID="backstage"
SCRIPT_NAME="Backstage"
SCRIPT_DESCRIPTION="Developer portal with software catalog, TechDocs, and Kubernetes visibility"
SCRIPT_CATEGORY="MANAGEMENT"

# === Deployment (Required) ===
SCRIPT_PLAYBOOK="650-setup-backstage.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n backstage -l app.kubernetes.io/name=backstage --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="650-remove-backstage.yml"
SCRIPT_REQUIRES="postgresql"
# Note: Authentik is NOT listed as a requirement. Backstage works without auth.
SCRIPT_PRIORITY="50"

# === Deployment Details (Optional) ===
SCRIPT_IMAGE="quay.io/rhdh-community/rhdh:1.9"
SCRIPT_HELM_CHART="rhdh-chart/backstage"
SCRIPT_NAMESPACE="backstage"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Open-source developer portal for software catalog, documentation, and Kubernetes visibility"
SCRIPT_SUMMARY="Developer portal (Red Hat Developer Hub / Backstage) providing a single pane of glass for discovering services, viewing Kubernetes status, and browsing documentation. Uses RHDH with dynamic plugins — no custom image build required."
SCRIPT_LOGO="backstage-logo.webp"
SCRIPT_WEBSITE="https://backstage.io"
SCRIPT_TAGS="developer-portal,catalog,documentation,kubernetes"
SCRIPT_DOCS="/docs/packages/management/backstage"
```

### Secrets

Add to `provision-host/uis/templates/secrets-templates/00-common-values.env.template`:

```bash
# Backstage
BACKSTAGE_OIDC_CLIENT_ID=backstage
BACKSTAGE_OIDC_CLIENT_SECRET=generate-a-secret-here
BACKSTAGE_SESSION_SECRET=generate-a-session-secret-here
BACKSTAGE_DB_PASSWORD=${DEFAULT_DATABASE_PASSWORD}
```

Add a Secret block to `00-master-secrets.yml.template` for the `backstage` namespace.

### Authentication with Authentik

RHDH ships with a Keycloak/OIDC plugin that works with any OIDC-compliant provider, including Authentik. Configuration in `app-config.yaml`:

```yaml
# app-config.yaml snippet
auth:
  providers:
    oidc:
      development:
        metadataUrl: http://authentik-server.authentik.svc.cluster.local/application/o/backstage/.well-known/openid-configuration
        clientId: ${AUTH_OIDC_CLIENT_ID}
        clientSecret: ${AUTH_OIDC_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: emailMatchingUserEntityProfileEmail
```

**Note:** RHDH's Keycloak plugin and the generic OIDC provider both work with Authentik since it is fully OIDC-compliant. The exact provider choice (keycloak vs generic oidc) should be verified during Phase 4 deployment.

**Authentik setup required:**
- Create an OAuth2/OpenID Provider and Application in Authentik
- Set redirect URI to `http://backstage.localhost:7007/api/auth/oidc/handler/frame`
- This follows the same pattern as the existing OpenWebUI OAuth setup (see `073-authentik-2-openwebui-blueprint.yaml`)

### PostgreSQL Database Setup

Backstage needs its own database within the shared PostgreSQL instance. This follows the existing pattern:

- Create a utility playbook `ansible/playbooks/utility/u10-backstage-create-postgres.yml` (same pattern as `u09-authentik-create-postgres.yml`)
- The setup playbook calls this before Helm install
- Database name: `backstage`, user: `backstage`, password from secrets

### Kubernetes Plugin

The Kubernetes plugin shows live pod status, deployments, and logs for catalog entities:

```yaml
# app-config.yaml snippet
kubernetes:
  clusterLocatorMethods:
    - type: config
      clusters:
        - url: https://kubernetes.default.svc
          name: uis-local
          authProvider: serviceAccount
          serviceAccountToken: ${K8S_SA_TOKEN}
```

Entities link to K8s resources via annotations:
```yaml
metadata:
  annotations:
    backstage.io/kubernetes-id: openwebui
    backstage.io/kubernetes-namespace: ai
```

### Runtime Visibility: Deploy/Undeploy Awareness

UIS users start and stop services dynamically (`./uis deploy grafana`, `./uis undeploy grafana`). The Backstage catalog handles this in two layers:

**Static catalog (all available services):** The generated catalog YAML lists every service that *can* be deployed in UIS. This doesn't change when services start/stop. A user browsing the catalog sees the full platform — what's available, how services relate, who owns what.

**Dynamic runtime status (Kubernetes plugin):** For each catalog entity with `backstage.io/kubernetes-id` and `backstage.io/kubernetes-namespace` annotations, the K8s plugin queries the cluster in real-time and shows:
- Pod status (Running, Pending, CrashLoopBackOff)
- Deployment health and replica counts
- Events and container logs
- **No pods found** — when the service is not deployed

So when a user runs `./uis undeploy grafana`, Backstage still shows Grafana in the catalog, but the Kubernetes tab shows no running pods. When they `./uis deploy grafana`, pods appear automatically. No catalog update is needed — the K8s plugin reflects reality in real-time.

This works out of the box with the annotations already added to all catalog components.

---

## UIS Service Catalog Model

The catalog uses a simple hierarchy that maps directly to `SCRIPT_CATEGORY`, so the generator can produce it automatically:

- **1 Domain** (`uis-infrastructure`) — the entire UIS platform
- **9 Systems** — one per category that has services (observability, ai, analytics, identity, databases, management, applications, networking, integration). The STORAGE category exists in `categories.sh` but has no services, so no system is generated for it.
- **Components** — services and tools (`SCRIPT_KIND="Component"`)
- **Resources** — databases, caches, message brokers (`SCRIPT_KIND="Resource"`)

See the draft [catalog/](catalog/) for the complete entity definitions. The generator will produce this structure from service definitions.

---

## Example Catalog Entity File

This example shows how the generator output aligns with the 1-domain / 9-systems model:

```yaml
# generated/backstage/catalog/components/openwebui.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: openwebui
  description: "ChatGPT-like web interface for AI models"
  annotations:
    backstage.io/kubernetes-id: openwebui
    backstage.io/kubernetes-namespace: ai
    uis.sovereignsky.no/docs-url: "https://uis.sovereignsky.no/docs/packages/ai/openwebui"
    uis.sovereignsky.no/business-owner: "business-owners"
  links:
    - url: https://uis.sovereignsky.no/docs/packages/ai/openwebui
      title: "openwebui Docs"
      icon: docs
spec:
  type: service
  lifecycle: production
  owner: app-team
  system: ai
  dependsOn:
    - resource:postgresql
    - resource:qdrant
    - component:litellm
```

See the draft [catalog/](catalog/) for the complete set of entities (domain, systems, resources, groups, components).

---

## Plugin Configuration (No Custom Image Needed)

RHDH ships with Kubernetes and Keycloak/OIDC plugins pre-installed. Additional plugins are added via `dynamic-plugins.yaml` — no image rebuild required:

```yaml
# dynamic-plugins.yaml (mounted as ConfigMap or via Helm values)
plugins:
  - package: "@backstage/plugin-techdocs"
    disabled: false
  - package: "@backstage/plugin-catalog-backend-module-github"
    disabled: false
```

### Plugins needed for UIS

| Plugin | Pre-installed in RHDH? | Purpose | Required? |
|--------|------------------------|---------|-----------|
| Kubernetes | Yes | K8s pod status, logs in catalog | Yes |
| Grafana | Add via config | Link services to monitoring dashboards | Yes |
| Keycloak/OIDC | Yes | Authentik OIDC login | Optional |
| ArgoCD | Yes | Deployment status in catalog | Nice-to-have |
| TechDocs | Add via config | Documentation rendering | Deferred |
| GitHub catalog | Add via config | Auto-discover catalog entities | Optional |

---

## Integration Opportunities

| Integration | Plugin/Method | Value |
|-------------|---------------|-------|
| **Grafana dashboards** | `@backstage/plugin-grafana` | Link services to their dashboards |
| **ArgoCD status** | `@roadiehq/backstage-plugin-argo-cd` | Deployment status in catalog |
| **GitHub** | `@backstage/plugin-catalog-backend-module-github` | Auto-discover catalog entities from repos |
| **Authentik groups** | OIDC group claims | Map Authentik groups to Backstage teams |
| **OpenMetadata** | API integration | Data lineage and governance visibility |

---

## Design Decision: Catalog Generation from Service Definitions

### Decision

Generate Backstage catalog YAML from UIS service definitions (`provision-host/uis/services/*/service-*.sh`), following the existing pattern where `uis-docs.sh` generates website JSON from the same source.

### Why

UIS already has a single source of truth for service metadata. The docs website is generated from it (`./uis docs generate`). The Backstage catalog should follow the same pattern — otherwise two sets of metadata drift apart.

### How it maps

| Backstage field | UIS service definition field | Status |
|---|---|---|
| `metadata.name` | `SCRIPT_ID` | Exists |
| `metadata.description` | `SCRIPT_DESCRIPTION` | Exists |
| `spec.system` | `SCRIPT_CATEGORY` (lowercased) | Exists |
| `spec.dependsOn` | `SCRIPT_REQUIRES` | Exists |
| `backstage.io/kubernetes-namespace` | `SCRIPT_NAMESPACE` | Exists |
| `metadata.tags` | `SCRIPT_TAGS` | Exists |
| `links` | `SCRIPT_WEBSITE`, `SCRIPT_DOCS` | Exists |
| `spec.owner` | — | **Needs new field** |
| `spec.type` | — | **Needs new field** |
| `backstage.io/kubernetes-id` | — | Can default to `SCRIPT_ID` |
| Backstage `kind` (Component vs Resource) | — | **Needs new field** |

### New service definition fields needed

These are general-purpose metadata fields — not Backstage-specific. Both the Backstage catalog generator and the docs generator (`uis-docs.sh`) can consume them:

```bash
# === Extended Metadata (Optional) ===
SCRIPT_KIND="Component"        # Component | Resource
SCRIPT_TYPE="service"          # service | tool | library | database | cache | message-broker
SCRIPT_OWNER="platform-team"   # platform-team | app-team
```

| Field | Description | Used by Backstage | Used by docs generator |
|-------|-------------|-------------------|------------------------|
| `SCRIPT_KIND` | Whether this is a software component or an infrastructure resource | `kind:` (Component vs Resource) | Categorization, filtering |
| `SCRIPT_TYPE` | What kind of component/resource (service, tool, database, etc.) | `spec.type` | Badge/label on service pages |
| `SCRIPT_OWNER` | Which team owns this service | `spec.owner` | Ownership display on service pages |

**Documentation to update when adding these fields:**

| File | What to update |
|------|---------------|
| `website/docs/contributors/guides/adding-a-service.md` | Add new fields to the service definition example and field reference table (Step 2) |
| `website/docs/contributors/rules/kubernetes-deployment.md` | Add new fields to the service metadata reference |
| `website/docs/contributors/rules/naming-conventions.md` | Add naming conventions for the new fields |
| `website/docs/contributors/rules/provisioning.md` | Mention new fields if relevant to playbook conventions |
| `provision-host/uis/schemas/service.schema.json` | Add new fields to the JSON schema |
These are optional — the generator can use sensible defaults:
- `SCRIPT_KIND` defaults to `Component`; `DATABASES` category defaults to `Resource`
- `SCRIPT_TYPE` defaults to `service`
- `SCRIPT_OWNER` defaults to `platform-team`

### Bundled sub-components (Tika, OnlyOffice)

Some services are bundled inside other services' playbooks and have no service definition:

| Service | Currently bundled in | Backstage representation |
|---------|---------------------|--------------------------|
| **Tika** | AI stack / OpenWebUI playbook | Component in `ai` system |
| **OnlyOffice** | Nextcloud playbook | Component in `applications` system |

**Approach: metadata first, split later.** In the first phase, add these as manually maintained entries in the generator's static entities (alongside Domain, Systems, Groups). They appear in the catalog with correct metadata and K8s annotations, so the K8s plugin shows their runtime status.

Splitting them into standalone services with their own playbooks (`service-tika.sh`, `service-onlyoffice.sh`) is deferred to a later phase — that work requires a running cluster and extensive testing. Once split, they move from static entries to auto-generated like everything else.

**RabbitMQ** already has its own service definition (`service-rabbitmq.sh`) and would be generated as a Resource (same as PostgreSQL, Redis, etc.).

### Generator implementation

Add a new function to `uis-docs.sh` (or a new script `uis-backstage-catalog.sh`) that:

1. Scans all service definitions via `service-scanner.sh`
2. For each service, emits a Backstage entity YAML file
3. Generates `all.yaml` (Location entity) referencing all files
4. Also generates static entities: Domain (`uis-infrastructure`), Systems (one per category), Groups, Users
5. Includes Tika and OnlyOffice as hardcoded static entries (until Phase 7 splits them into standalone services)

CLI command: `./uis docs generate-backstage-catalog`

### Generated file location and deployment flow

Generated files go to: **`generated/backstage/`** at the repo root.

This directory is committed to the repo and available inside the provision-host container at `/mnt/urbalurbadisk/generated/backstage/`. The `generated/backstage/` structure reserves space for future Backstage-related generated content:

```
generated/
└── backstage/
    ├── catalog/              ← Phase 2: Generated from service definitions
    │   ├── all.yaml
    │   ├── domains/
    │   ├── systems/
    │   ├── components/
    │   ├── resources/
    │   └── groups/
    ├── app-config.yaml       ← Future: Backstage config generated from UIS settings
    └── templates/            ← Future: Scaffolder templates for creating new services
```

- **`catalog/`** — Backstage entity YAML generated from service definitions. This is Phase 2 work.
- **`app-config.yaml`** — Backstage's main config file (database connection, Authentik OIDC, cluster URL, catalog location). Could be generated from existing UIS settings like secrets and Authentik config, similar to how `075-authentik-config.yaml.j2` is a template filled with UIS variables. For RHDH, this is delivered via the Helm values file (`650-backstage-config.yaml`) or as a ConfigMap mounted into the pod. Details TBD when we deploy Backstage.
- **`templates/`** — Backstage Software Templates that let developers create new services via a wizard form. Could generate `service-*.sh`, playbook skeletons, and manifests. Nice-to-have for later.

### Deployment flow

```
1. Generator runs (Phase 2, offline — no cluster needed)
   provision-host/uis/services/*/service-*.sh  →  generated/backstage/catalog/

2. Setup playbook deploys Backstage (Phase 3, requires cluster)
   ansible-playbook 650-setup-backstage.yml
     → Helm install Backstage
     → Wait for Backstage to be ready

3. Setup playbook loads catalog into Backstage
   → Package catalog as ConfigMap, mount into Backstage pod
     (same pattern as Authentik blueprints)
```

### Draft catalog as validation reference

The current [catalog/](catalog/) in this backlog folder serves as the reference to validate generator output against. Once the generator produces matching output, the draft catalog can be removed.

---

## Resolved Questions

1. ~~Custom image build pipeline~~ → **Resolved: Use RHDH pre-built community image.** No custom image needed. Plugins added via `dynamic-plugins.yaml` config.
2. ~~Plugin selection~~ → **Resolved: Start with what RHDH ships** (K8s, OIDC, ArgoCD). Add TechDocs via config. Low effort to add/remove — just a config change and restart.
3. **PostgreSQL** → **Decision: Reuse existing shared PostgreSQL** (042-series). Same pattern as Authentik, OpenMetadata, and every other UIS service.
4. ~~Catalog source of truth~~ → **Resolved: Generate from service definitions.** See Design Decision section.

## Open Questions

Two deferred:

1. **TechDocs** — Deferred. The Docusaurus site covers platform docs. TechDocs becomes relevant when developers write docs alongside integration code in separate repos. Just a config toggle in RHDH when the time comes.
2. **RHDH vs custom image** — Deferred to after PLAN-002 deployment. Start with RHDH community image (tuned-down resources). Measure actual usage. If too heavy for a laptop, build a minimal custom image with only K8s and OIDC plugins. The switch only changes the image reference and Helm values — everything else (catalog, playbooks, manifests) stays the same. See "Resource Usage and Image Strategy" section.

---

## Effort Estimate

| Phase | Work | Risk | Requires cluster |
|-------|------|------|-------------------|
| **Phase 1: Service definition enrichment** | Add `SCRIPT_KIND`, `SCRIPT_TYPE`, `SCRIPT_OWNER` fields to all 29 service definitions | None | No |
| **Phase 2: Catalog generator** | Build `uis-backstage-catalog.sh` or extend `uis-docs.sh` to generate Backstage catalog YAML from service definitions. Include Tika and OnlyOffice as static entries. Validate output against draft [catalog/](catalog/). | None | No |
| **Phase 3: UIS service integration** | Create all files per [Adding a Service](../../../contributors/guides/adding-a-service.md): service definition, setup/remove/verify playbooks, Helm values (RHDH chart), IngressRoute, secrets, Helm repo registration, enabled-services.conf entry. No custom image — uses RHDH community image with dynamic plugins. | Medium | Yes |
| **Phase 4: Authentik integration (optional)** | If Authentik is deployed: create OAuth2/OIDC provider, add Authentik blueprint for Backstage app. Backstage works without this. | Medium | Yes |
| **Phase 5: Plugin enrichment** | Add TechDocs, Grafana plugins via `dynamic-plugins.yaml` config — just config changes, no rebuild | Low | Yes |
| **Phase 6: Sub-component extraction** | Split Tika and OnlyOffice into standalone services with own playbooks and manifests. Move from static catalog entries to auto-generated. | High — requires playbook refactoring and testing | Yes |

### Reference Services

Use these existing services as implementation models (per the adding-a-service guide):

- **OpenMetadata** (complex, Helm + dependencies + verify) — closest match to Backstage's complexity
- **OpenWebUI** (Helm + secrets + auth) — good reference for Authentik OIDC integration

---

## Next Steps — Implementation Plans

This investigation produced three ordered plans:

| Plan | Scope | Cluster needed? | Status |
|------|-------|-----------------|--------|
| [PLAN-001-backstage-metadata-and-generator.md](../completed/PLAN-001-backstage-metadata-and-generator.md) | Add metadata fields + build catalog generator | No | **Complete** |
| [PLAN-002-backstage-deployment.md](PLAN-002-backstage-deployment.md) | Deploy RHDH following adding-a-service guide | Yes | Backlog |
| [PLAN-003-backstage-auth-and-plugins.md](PLAN-003-backstage-auth-and-plugins.md) | Authentik OIDC + TechDocs (optional) | Yes | Backlog |

Sub-component extraction (Tika/OnlyOffice into standalone services) remains a separate backlog item — high risk, requires playbook refactoring and testing.
