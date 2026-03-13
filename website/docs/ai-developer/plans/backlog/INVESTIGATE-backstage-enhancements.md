# Investigate: Backstage Enhancements

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Evaluate and prioritize additional Backstage features beyond the initial deployment (PLAN-002)

**Last Updated**: 2026-03-13

**Context**: Exploratory conversation about Backstage capabilities (notes captured in this document)

**Depends on**: [INVESTIGATE-backstage.md](INVESTIGATE-backstage.md) (completed), PLAN-002 (completed)

---

## Background

With Backstage (RHDH 1.9) deployed and the Kubernetes plugin working (PLAN-002 complete), several additional capabilities were identified during exploration. This investigation captures those ideas, assesses feasibility in UIS, and recommends prioritization.

---

## Enhancement 1: API Entities and Relationships — COMPLETE

Implemented in [PLAN-004](../completed/PLAN-004-backstage-api-entities.md). 7 API entities generated with text descriptions, K8s annotations inherited from parent services. `spec.type: description` used to avoid OpenAPI renderer errors.

**Future enhancement**: Use `$text` references to in-cluster OpenAPI endpoints for interactive API documentation in Backstage (see tester suggestion in talk session).

### What
Add `kind: API` entities to the Backstage catalog so that services show "Provided APIs" and "Consumed APIs" tabs. Link components to APIs via `providesApis` and `consumesApis` in the spec.

### Why
The dependency graph in Backstage currently shows component-to-component and component-to-resource relationships (via `dependsOn`). Adding API entities makes the actual integration boundaries visible — a developer can see that openwebui consumes the litellm-api, and click through to see the API spec.

### UIS Services That Provide APIs

| Service | API Name | Type | Has OpenAPI spec endpoint? |
|---------|----------|------|---------------------------|
| litellm | litellm-api | openapi | Yes — `/openapi.json` |
| authentik | authentik-api | openapi | Yes — `/api/v3/schema/` |
| openmetadata | openmetadata-api | openapi | Yes |
| gravitee | gravitee-api | openapi | Yes |
| grafana | grafana-api | openapi | Yes |
| tika | tika-api | openapi | Needs checking |
| openwebui | openwebui-api | openapi | Needs checking |
| prometheus | prometheus-query-api | grpc | No standard OpenAPI |

### UIS Services That Consume APIs

| Service | Consumes |
|---------|----------|
| openwebui | litellm-api |
| grafana | prometheus-query-api |
| openmetadata | postgresql (already modeled as resource dependency) |

### Implementation

**New service definition fields:**
```bash
# === Extended Metadata (Optional) ===
SCRIPT_PROVIDES_APIS=""         # comma-separated: "litellm-api,litellm-admin-api"
SCRIPT_CONSUMES_APIS=""         # comma-separated: "litellm-api"
```

**Catalog generator changes:**
1. Extract new fields in `extract_all_metadata()`
2. Add `providesApis`/`consumesApis` to `generate_service_entity()` spec
3. New `generate_api_entity()` function for `kind: API` entities
4. Update `all.yaml` to include API entity files
5. Update static entities (tika) if applicable

**API definition approach (decided):**
- **Step 1 (this plan):** Text descriptions only. The generator creates API entities with a plain text `spec.definition` field (e.g., "OpenAI-compatible LLM proxy REST API"). This gives full relationship and dependency graph value with zero infrastructure dependency.
- **Step 2 (future, when building own integrations):** Add `SCRIPT_API_SPEC_URL` field or repo convention (`openapi.yaml` in repo root). Enables interactive API explorer in Backstage and Gravitee integration. Most services generate their OpenAPI spec dynamically at runtime (e.g., LiteLLM via FastAPI) — there's no static file to reference. Decide after seeing how text-only API entities feel in practice.

### Effort
Medium — similar scope to the K8s label selector work. ~1 day.

### Decision: Ready for a plan
This enhancement is ready to implement. Scope: add `SCRIPT_PROVIDES_APIS`/`SCRIPT_CONSUMES_APIS` fields, generate API entities with text descriptions, link via `providesApis`/`consumesApis`.

---

## Enhancement 2: Grafana Plugin Integration

### What
Enable the Grafana plugin in RHDH so that entity pages show embedded dashboard panels and Loki log streams.

### Why
The `grafana/dashboard-selector` annotation is already generated for all catalog entities. The backend config (`grafana.domain`) is already in `654-backstage-app-config.yaml`. The missing piece is the dynamic plugin itself.

### Current State
- `grafana` config block exists in `654-backstage-app-config.yaml`
- `grafana/dashboard-selector: "tag:<id>"` annotation on all entities
- Grafana plugin is **not bundled in RHDH 1.9** — commented out in `650-backstage-config.yaml`
- The community plugin package path needs investigation

### What Needs Investigation
1. Is `@backstage-community/plugin-grafana` available as a RHDH-compatible dynamic plugin?
2. What is the exact package path in the RHDH dynamic plugins format?
3. Does it need a Grafana service account token? (Likely yes)
4. Can Loki log queries be embedded via `grafana/loki-query` annotation?

### Implementation (Once Plugin Path is Known)
1. Add Grafana service account token to secrets
2. Add proxy config for Grafana API in `654-backstage-app-config.yaml`
3. Enable plugin in `650-backstage-config.yaml` `global.dynamic.plugins`
4. Add `grafana/loki-query` annotation generation to catalog script
5. Test dashboard embedding on entity pages

### Effort
Small to medium — mostly config once the plugin compatibility is confirmed. The spike to check RHDH compatibility is the unknown.

---

## Enhancement 3: Scaffolder / Software Templates

### What
Use Backstage's Scaffolder to create new repos from templates. Developers fill a web form, and Backstage creates a GitHub or Azure DevOps repo with skeleton files, registers it in the catalog, and optionally provisions infrastructure (e.g., PostgreSQL user).

### Why
The user already has `urbalurba-dev-templates` repo with skeleton projects and a CLI-based workflow. The Scaffolder replaces this with a browser-based experience that:
- Creates the repo automatically (no manual step)
- Registers the new service in Backstage immediately
- Can trigger infrastructure provisioning (DB user, ArgoCD registration)
- Works cross-platform (browser, no shell scripts)

### Current State
- `urbalurba-dev-templates` repo exists with TypeScript skeleton projects
- RHDH bundles the Scaffolder plugin (may need enabling)
- No GitHub/Azure DevOps integration configured in Backstage yet
- No templates registered in the catalog

### Key Decisions Needed
1. **GitHub vs Azure DevOps** — which is the primary target? (Chat suggested both, with ADO for Red Cross integration repos)
2. **Authentication** — GitHub PAT vs GitHub App for repo creation
3. **Template scope** — start with one template (TypeScript basic webserver) or multiple?
4. **Infrastructure automation** — how to handle PostgreSQL user creation (Kubernetes Job vs external script)

### Dependencies
- Needs GitHub PAT or GitHub App configured
- Needs Scaffolder plugin enabled in RHDH
- Template files need to be written and registered

### What to Reuse from urbalurba-dev-templates
- Skeleton folder structure maps directly to Scaffolder skeleton
- `register-argocd.sh` logic becomes a Scaffolder step
- `setup-local-dns.sh` logic becomes a Scaffolder step
- GitHub Actions workflows copy as-is

### Effort
Large — this is a standalone project. Needs its own plan with multiple phases.

### Reference
- [Red Hat curated template library](https://github.com/redhat-developer/red-hat-developer-hub-software-templates) — learning examples, not production-ready
- Chat notes (deleted, content captured in this investigation) — contained detailed template.yaml examples

---

## Enhancement 4: TechDocs

### What
Enable the TechDocs plugin so that documentation written in repos (in `docs/` folders with `mkdocs.yml`) renders inline on Backstage entity pages.

### Why
When the Scaffolder creates repos with pre-populated `docs/` folders (overview, architecture, configuration, operations, troubleshooting, handover checklist), TechDocs renders those docs directly in Backstage. Operations staff can read runbooks from the entity page without hunting for wikis.

### Current State
- `backstage.io/techdocs-ref` annotation is already generated for all entities — but points to the external docs website URL, not `dir:.`
- TechDocs plugin is bundled in RHDH but needs enabling
- No repos currently have `mkdocs.yml` + `docs/` folders

### Why It Should Wait
TechDocs only becomes valuable **after** the Scaffolder creates repos with `docs/` folders. For UIS platform services, the existing link to the docs website is sufficient. Enabling TechDocs now would show empty doc pages for all entities.

### Implementation (When Ready)
1. Enable TechDocs backend + frontend dynamic plugins
2. Configure TechDocs builder (local vs CI/CD)
3. Update Scaffolder skeleton to include `mkdocs.yml` + `docs/` folder with template markdown files
4. For repos with docs: change annotation from URL to `dir:.`

### Effort
Small for enabling the plugin. The value comes from the Scaffolder creating repos with docs — so this is sequenced after Enhancement 3.

---

## Enhancement 5: Authentik OIDC Authentication

Already captured in [INVESTIGATE-backstage-auth.md](INVESTIGATE-backstage-auth.md) (was PLAN-003, downgraded to investigation). Not duplicated here.

---

## Suggested Priority Order

| Priority | Enhancement | Why this order |
|----------|------------|----------------|
| 1 | API Entities | Enriches the existing catalog immediately. No new plugins needed. Makes dependency graphs meaningful. |
| 2 | Grafana Plugin | High value if the plugin works in RHDH 1.9. Needs a spike first. |
| 3 | Scaffolder | Large but transformative. Separate project with its own plan. |
| 4 | TechDocs | Depends on Scaffolder creating repos with docs. Enable after Enhancement 3. |
| 5 | OIDC Auth | Optional, already planned in PLAN-003. Do when needed. |

---

## Next Steps

1. Create a plan for Enhancement 1 (API Entities) — estimated 1 day of implementation
2. Spike Enhancement 2 (Grafana Plugin) — check RHDH 1.9 compatibility, ~2 hours
3. Create investigation for Enhancement 3 (Scaffolder) when ready to start that work
