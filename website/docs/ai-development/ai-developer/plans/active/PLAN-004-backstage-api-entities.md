# PLAN-004: Backstage API Entities

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: In Progress

**Goal**: Add API entities to the Backstage catalog so that services show "Provided APIs" and "Consumed APIs" tabs with dependency relationships

**Last Updated**: 2026-03-13

**Investigation**: [INVESTIGATE-backstage-enhancements.md](INVESTIGATE-backstage-enhancements.md) — Enhancement 1

**Prerequisites**: PLAN-002 complete (Backstage deployed with catalog)

---

## Overview

The Backstage catalog currently has Components and Resources linked via `dependsOn`. This plan adds `kind: API` entities so developers can see which services provide and consume APIs. The dependency graph becomes richer — showing actual integration boundaries, not just infrastructure dependencies.

**Scope:** Text descriptions only for API definitions. No OpenAPI spec URLs — that's a future enhancement when we build our own integrations with `openapi.yaml` files in repos.

**Service definition field schema:** `provision-host/uis/schemas/service.schema.json` — single source of truth for all field definitions.

---

## Phase 1: Add New Fields to Service Definitions

### Tasks

- [ ] 1.1 Add `SCRIPT_PROVIDES_APIS` and `SCRIPT_CONSUMES_APIS` to `provision-host/uis/schemas/service.schema.json`
- [ ] 1.2 Add fields to service definitions that provide APIs
- [ ] 1.3 Add fields to service definitions that consume APIs
- [ ] 1.4 Update docs files to match schema (`adding-a-service.md`, `naming-conventions.md`, `kubernetes-deployment.md`)

### Implementation Details

**New fields:**
```bash
# === Extended Metadata (Optional) ===
SCRIPT_PROVIDES_APIS=""         # comma-separated: "litellm-api"
SCRIPT_CONSUMES_APIS=""         # comma-separated: "litellm-api"
```

**Services that provide APIs:**

| Service | SCRIPT_PROVIDES_APIS | API Description |
|---------|---------------------|-----------------|
| litellm | `litellm-api` | OpenAI-compatible LLM proxy REST API |
| authentik | `authentik-api` | Identity provider OAuth/OIDC/SAML API |
| openmetadata | `openmetadata-api` | Data governance and metadata REST API |
| gravitee | `gravitee-api` | API management and gateway REST API |
| grafana | `grafana-api` | Dashboard and datasource query REST API |
| tika | `tika-api` | Document text extraction REST API |
| openwebui | `openwebui-api` | AI chat web interface and REST API |

**Services that consume APIs:**

| Service | SCRIPT_CONSUMES_APIS |
|---------|---------------------|
| openwebui | `litellm-api` |

**Note:** Most services consume database Resources (already modeled via `dependsOn`). Only model explicit API consumption where it adds clarity — not every HTTP call needs an API entity.

### Validation

- [ ] Schema validates with new fields
- [ ] Service definitions have correct field values

---

## Phase 2: Update Catalog Generator

### Tasks

- [ ] 2.1 Extract `SCRIPT_PROVIDES_APIS` and `SCRIPT_CONSUMES_APIS` in `extract_all_metadata()`
- [ ] 2.2 Add `providesApis` and `consumesApis` to `generate_service_entity()` spec section
- [ ] 2.3 Create `generate_api_entity()` function for `kind: API` entities
- [ ] 2.4 Update `generate_all_yaml()` to include API entity references
- [ ] 2.5 Update static entity for tika to include `providesApis` if applicable

### Implementation Details

**New function `generate_api_entity()`:**

Generates one API entity per API name found in any service's `SCRIPT_PROVIDES_APIS`. The generator needs to build a mapping of API name → description. Approach:

- API name comes from `SCRIPT_PROVIDES_APIS` (e.g., `litellm-api`)
- API description is derived from the providing service's description + " API"
- `spec.type` is `openapi` for all (can be refined later)
- `spec.definition` is a text description
- `spec.system` matches the providing service's system
- `spec.owner` matches the providing service's owner

**Example generated API entity:**
```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: litellm-api
  description: "OpenAI-compatible LLM proxy REST API"
  annotations:
    backstage.io/techdocs-ref: url:https://uis.sovereignsky.no/docs/packages/ai/litellm
    uis.sovereignsky.no/docs-url: "https://uis.sovereignsky.no/docs/packages/ai/litellm"
  links:
    - url: https://uis.sovereignsky.no/docs/packages/ai/litellm
      title: "litellm Docs"
      icon: docs
spec:
  type: openapi
  lifecycle: production
  owner: app-team
  system: ai
  definition: "OpenAI-compatible LLM proxy REST API. Provides /chat/completions, /embeddings, /models endpoints."
```

**Updated Component entity (litellm):**
```yaml
spec:
  type: service
  lifecycle: production
  owner: app-team
  system: ai
  providesApis:
    - litellm-api
  dependsOn:
    - resource:postgresql
```

**Updated Component entity (openwebui):**
```yaml
spec:
  type: service
  lifecycle: production
  owner: app-team
  system: ai
  consumesApis:
    - litellm-api
  dependsOn:
    - resource:postgresql
    - component:litellm
```

### Validation

- [ ] `./uis catalog generate` completes without errors
- [ ] Generated API entity files appear in `generated/backstage/catalog/apis/`
- [ ] Generated component files include `providesApis`/`consumesApis` where appropriate
- [ ] `all.yaml` references the new API entity files

---

## Phase 3: Deploy and Verify

### Tasks

- [ ] 3.1 Build container with updated generator
- [ ] 3.2 Regenerate catalog: `./uis catalog generate`
- [ ] 3.3 Redeploy backstage: `./uis undeploy backstage && ./uis deploy backstage`
- [ ] 3.4 Verify in browser: check litellm entity page → "Provided APIs" tab shows litellm-api
- [ ] 3.5 Verify in browser: check openwebui entity page → "Consumed APIs" tab shows litellm-api
- [ ] 3.6 Verify in browser: check litellm-api entity page → shows provider and consumer
- [ ] 3.7 Verify dependency graph shows API relationships

### Validation

- [ ] API entities visible in Backstage catalog
- [ ] Provided/Consumed APIs tabs populated on component pages
- [ ] Dependency graph includes API relationships

---

## Phase 4: Cleanup

### Tasks

- [ ] 4.1 Update `INVESTIGATE-backstage-enhancements.md` — note Enhancement 1 is complete
- [ ] 4.2 Move this plan to `completed/`

---

## Acceptance Criteria

- [ ] `SCRIPT_PROVIDES_APIS` and `SCRIPT_CONSUMES_APIS` fields added to schema and relevant service definitions
- [ ] Catalog generator produces `kind: API` entities with text descriptions
- [ ] Component entities include `providesApis`/`consumesApis` in spec
- [ ] API relationships visible in Backstage UI (tabs and dependency graph)
- [ ] Docs files updated to match schema

---

## Files to Modify

| File | Change |
|------|--------|
| `provision-host/uis/schemas/service.schema.json` | Add `providesApis` and `consumesApis` fields |
| `provision-host/uis/manage/uis-backstage-catalog.sh` | Extract new fields, add `providesApis`/`consumesApis` to spec, new `generate_api_entity()` function |
| `provision-host/uis/services/ai/service-litellm.sh` | Add `SCRIPT_PROVIDES_APIS="litellm-api"` |
| `provision-host/uis/services/ai/service-openwebui.sh` | Add `SCRIPT_PROVIDES_APIS="openwebui-api"` and `SCRIPT_CONSUMES_APIS="litellm-api"` |
| `provision-host/uis/services/identity/service-authentik.sh` | Add `SCRIPT_PROVIDES_APIS="authentik-api"` |
| `provision-host/uis/services/analytics/service-openmetadata.sh` | Add `SCRIPT_PROVIDES_APIS="openmetadata-api"` |
| `provision-host/uis/services/integration/service-gravitee.sh` | Add `SCRIPT_PROVIDES_APIS="gravitee-api"` |
| `provision-host/uis/services/observability/service-grafana.sh` | Add `SCRIPT_PROVIDES_APIS="grafana-api"` |
| `website/docs/contributors/guides/adding-a-service.md` | Add new fields to example and reference table |
| `website/docs/contributors/rules/naming-conventions.md` | Add new fields |
| `website/docs/contributors/rules/kubernetes-deployment.md` | Add new fields |
