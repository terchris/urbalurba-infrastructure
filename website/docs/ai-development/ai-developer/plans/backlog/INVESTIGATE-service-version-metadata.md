# Investigate: Version Metadata in Service Scripts

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Decide how service scripts should expose version information for docs generation and CLI display

**Last Updated**: 2026-03-09

**Related**:
- [INVESTIGATE-version-pinning.md](INVESTIGATE-version-pinning.md) — Tracks which services are pinned
- [adding-a-service.md](../../../contributors/guides/adding-a-service.md) — Service definition guide (must be updated with the decision)

---

## Problem

The docs generator (`uis-docs-markdown.sh`) hardcodes "(unpinned)" for every service with a `SCRIPT_HELM_CHART` field — even for services that ARE pinned (ArgoCD `7.8.26`, Gravitee `4.8.4`, Authentik `2025.8.1`). There is no metadata field for version information.

Versions currently live in different places depending on the service:

| Service | Where version lives | Service script knows? |
|---------|--------------------|-----------------------|
| ArgoCD | Playbook var `argocd_chart_version: "7.8.26"` | No |
| Gravitee | Hardcoded `--version 4.8.4` in playbook | No |
| Authentik | Playbook var `authentik_chart_version` | No |
| Elasticsearch | `imageTag: "9.3.0"` in Helm values yaml | No |
| MongoDB | `SCRIPT_IMAGE="mongo:8.0.5"` | Yes (baked into image tag) |
| MySQL | `SCRIPT_IMAGE="mysql:8.0"` | Yes (baked into image tag) |
| Whoami | `SCRIPT_IMAGE="traefik/whoami:v1.10.2"` | Yes (baked into image tag) |

Services using `SCRIPT_IMAGE` already have version info in the script. Helm-based services do not.

---

## Questions to Answer

1. Should we add a version field to service scripts (e.g. `SCRIPT_HELM_CHART_VERSION`)?
2. If yes, is it acceptable to maintain the version in two places (script + playbook/config)?
3. Should the field be required or optional?
4. Should the docs generator show "(unpinned)" or nothing when no version is set?
5. Could the version be extracted automatically from the playbook or config file instead of duplicating it?

---

## Options

### Option A: Add optional `SCRIPT_HELM_CHART_VERSION` field

Add a new metadata field. Services that want their version shown in docs set it. Others leave it blank.

**Pros:**
- Simple to implement
- Service script remains the single source of truth for docs
- Optional — no obligation to set for all services

**Cons:**
- Dual maintenance — version must be updated in both the script and the playbook/config
- Risk of version drift between script metadata and actual deployed version

### Option B: Extract version automatically from playbooks/configs

The docs generator reads the actual playbook or config file to find the version.

**Pros:**
- Single source of truth — no dual maintenance
- Always accurate

**Cons:**
- Complex parsing — different services store versions differently (playbook vars, `--version` flags, `imageTag` in yaml)
- Fragile — tightly couples docs generator to playbook/config format
- May not work for all services

### Option C: Keep it manual — edit docs pages directly

Don't add a metadata field. When a version is pinned, manually update the generated docs page.

**Pros:**
- No new metadata fields or generator changes
- Works now for Elasticsearch (just edit the `.md` file)

**Cons:**
- Generated pages can overwrite manual edits (if `--force` is used)
- No programmatic way to list versions (e.g. `./uis list --versions`)
- Inconsistent — some info comes from metadata, some is manually maintained

---

## Current State

- 19 metadata fields exist in service scripts (none for versions)
- `uis-docs-markdown.sh` line 184 hardcodes "(unpinned)" for all Helm charts
- `uis-docs.sh` (JSON generator) outputs `helmChart` but no version field
- The docs pages are generated once (skip if exists), so manual edits survive unless `--force` is used
- 3 of 21 Helm charts are pinned, 18 are unpinned

---

## Next Steps

- [ ] Decide on an approach
- [ ] Create PLAN to implement the chosen approach
- [ ] Update `adding-a-service.md` with the new convention
