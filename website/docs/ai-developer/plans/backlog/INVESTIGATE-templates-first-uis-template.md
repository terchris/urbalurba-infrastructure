# Investigate: First UIS Stack Template

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Decide which UIS stack template to create first, then build it as the reference implementation for `uis template`.

**Priority**: Medium

**Last Updated**: 2026-04-04

**Related**:
- `helpers-no/dev-templates` → `INVESTIGATE-unified-template-system.md` — unified template system spec (all decisions, formats, 21MSG confirms UIS commands are implemented)
- [PLAN-001-uis-configure-expose.md](../completed/PLAN-001-uis-configure-expose.md) — `uis configure` and `uis expose` are implemented and tested
- UIS `stacks.json` — existing stack definitions (observability, ai-local, analytics)

**Depends on**: TMP registry is published (`template-registry.json` exists with generation pipeline). The `uis template` command itself does not exist yet — this investigation also covers whether to build that command or contribute templates to TMP first.

---

## Context

UIS now has the commands DCT needs (`uis configure`, `uis expose`), but there are no UIS templates yet. The TMP registry has 8 templates, all `context: dct`. We need to create the first `context: uis` template.

UIS already has `stacks.json` with 3 stack definitions and `uis stack install <stack>` which deploys all services in a stack. The question is: what does a UIS **template** add beyond what `uis stack install` already does?

### What `uis stack install` does today

```
uis stack install observability    → deploys 5 services (prometheus, tempo, loki, otel-collector, grafana)
uis stack install ai-local         → deploys 2 services (litellm, openwebui)
uis stack install analytics        → deploys 3 services (spark, jupyterhub, unity-catalog)
```

This already works. It reads `stacks.json`, deploys each service in order via `uis deploy`. No configuration beyond deployment.

### What a UIS template would add

```
uis template → picks "Web App Developer Stack"
→ deploys postgresql, redis, authentik, argocd
→ runs uis configure for each service that needs app-specific setup
→ applies init files (authentik blueprint with default users/groups, grafana dashboards)
→ returns connection details
→ documentation about what was deployed and how to use it
```

The key difference: templates include **configuration** (init files, params) and **documentation**, not just service deployment.

### The overlap problem

The existing stacks (observability, ai-local, analytics) are pure deployment — they don't need `uis configure` because apps don't connect to them directly. Making UIS templates for these stacks adds little value over `uis stack install` — just documentation and a registry listing.

The real value of UIS templates is for stacks where:
1. **Apps need to connect** → `uis configure` creates per-app resources
2. **Services need configuration** → init files set up users, schemas, dashboards
3. **Multiple services wire together** → authentik protects apps, PostgreSQL stores data, etc.

This means the first UIS template should be one that actually exercises `uis configure` and init files — not just repackaging an existing `uis stack install`.

---

## Candidates

### 1. Minimal Data Stack (postgresql + pgadmin)

**What it deploys**: PostgreSQL + pgAdmin

**What it configures**: Nothing beyond default deployment — pgAdmin auto-connects to PostgreSQL using shared `urbalurba-secrets` credentials.

**Pros**:
- Simplest possible stack (2 services)
- Validates the template format end-to-end
- pgAdmin provides immediate visual verification (open `pgadmin.localhost`)
- Low risk — both services are well-tested

**Cons**:
- Doesn't exercise `uis configure` or init files
- Not very useful as a standalone template — most developers just run `uis deploy postgresql`
- Doesn't demonstrate the template system's unique value over `uis stack install`

**Verdict**: Good for format validation, but too simple to be a useful first template.

### 2. Observability Stack (prometheus + tempo + loki + otel-collector + grafana)

**What it deploys**: Full monitoring stack (5 services)

**What it configures**: Could include init files for Grafana dashboards (JSON import) showing UIS service health.

**Pros**:
- Already defined in `stacks.json` — well-understood deployment
- 5 services tests ordering and dependency handling
- Grafana init file exercises the init file mechanism
- Useful for any developer — monitoring is always needed

**Cons**:
- Apps don't `requires` observability services — no `uis configure` exercise
- No per-app credentials or database creation
- Mostly duplicates what `uis stack install observability` already does

**Verdict**: Good template but doesn't demonstrate the configure/expose integration.

### 3. Web App Developer Stack (postgresql + redis + authentik + argocd)

**What it deploys**: The services a web app developer needs — database, cache, authentication, deployment pipeline.

**What it configures**:
- Authentik init file (blueprint): default groups (admins, developers, users), test users
- Could pre-configure ArgoCD (though `uis argocd register` handles this per-app)

**Pros**:
- Directly aligned with the DCT template story (developer picks "Next.js + PostgreSQL" → needs these services)
- Exercises the full producer/consumer chain from the investigation
- Authentik blueprint init file demonstrates native format rule (10UIS)
- Most useful for the target audience (developers building web apps)

**Cons**:
- 4 services with complex dependencies (authentik requires postgresql + redis)
- Authentik is the most complex service to deploy and configure
- If authentik deployment fails, the whole stack is blocked

**Verdict**: The flagship template, but risky as a first attempt.

### 4. AI Local Stack (litellm + openwebui)

**What it deploys**: LiteLLM API gateway + Open WebUI chat interface

**What it configures**: Both require PostgreSQL (auto-dependency). Could include OpenWebUI configuration overlay.

**Pros**:
- Already defined in `stacks.json`
- Only 2 services (but implicitly pulls in postgresql)
- AI tooling is popular and immediately useful

**Cons**:
- Requires Ollama running on the host (external dependency)
- Doesn't exercise `uis configure` for per-app resources
- Niche compared to a general developer stack

**Verdict**: Good template but niche.

---

## Recommendation

**Start with the Web App Developer Stack** — it's the only candidate that exercises what makes UIS templates different from `uis stack install`:

- `uis configure` for per-app database/user creation
- Init files (Authentik blueprints) with native format
- The producer/consumer chain (UIS deploys infra → DCT template wires app to it)

The existing stacks (observability, ai-local, analytics) can be added to the TMP registry later as simple `provides`-only templates, but they don't need `uis configure` and don't justify building `uis template` on their own. They already work via `uis stack install`.

### Why not "prove the format first with something simple"?

Because the simple case is already solved by `uis stack install`. If we build an observability template first, we'd build the `uis template` command only to duplicate what `uis stack install` already does. The `uis template` command only justifies its existence when it does something `uis stack install` can't: configure services, apply init files, and wire to DCT templates.

---

## Pre-requisites: `uis template` command

Before we can test any template, we need the `uis template` command in the UIS CLI. This command:

1. Fetches `template-registry.json` from TMP's published site (or raw GitHub)
2. Filters by `context: uis`
3. Shows a menu (or accepts a template ID as argument)
4. Sparse-checkouts the selected template from the TMP repo
5. Reads `template-info.yaml`
6. For `install_type: stack`: calls `uis deploy` for each service in `provides`, then `uis configure` with init files
7. Reports results

This is a new command that doesn't exist yet. It could be a separate PLAN or part of the first template PLAN.

---

## Where templates live

Per the investigation decision: UIS templates live in the TMP repo (`helpers-no/dev-templates`) under `uis-stack-templates/`. UIS contributes the template content, TMP owns the repo and generation pipeline.

```
helpers-no/dev-templates/
├── uis-stack-templates/
│   ├── template-categories.yaml          # context=uis
│   ├── observability-stack/
│   │   ├── template-info.yaml
│   │   ├── README-observability-stack.md
│   │   └── config/
│   │       └── grafana-dashboards.json
│   └── webapp-developer-stack/
│       ├── template-info.yaml
│       ├── README-webapp-developer-stack.md
│       └── config/
│           └── authentik-setup.yaml
```

---

## Questions to Decide

1. ~~**Order**: Observability first or Web App Developer first?~~ — **Web App Developer Stack** (see Recommendation above). Observability adds no value over `uis stack install`.
2. **`uis template` command**: Build it as part of this work, or as a separate PLAN?
3. **Where to contribute**: Should UIS create a PR to the TMP repo for the template content, or should TMP create the folder structure and UIS fills in the config?
4. ~~**Stack composition in `provides`**~~ — **Agreed** (26MSG/27MSG). Templates can reference stacks by ID. UIS resolves them from `stacks.json` at deploy time, sorted by priority. TMP updated the spec.

## Next Steps

- [x] Wait for TMP/DCT response on 26MSG (stack composition in `provides`) — **agreed in 27MSG**
- [ ] Decide on `uis template` command scope
- [ ] Create PLAN(s) for implementation
