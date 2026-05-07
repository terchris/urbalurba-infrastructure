# INVESTIGATE backlog — priority view

**Purpose**: triage tool, not a roadmap. Decides *what to investigate next* — not *what to build next*. The 25 INVESTIGATE files in `backlog/` were written at different times for different reasons; this doc separates the ones ready to be done from the ones that should wait, and orders the ready ones by what they unblock.

**Last updated**: 2026-05-07. Re-rank whenever an INVESTIGATE moves to `completed/`, a child PLAN ships, or a new INVESTIGATE lands.

**How to read the tiers**: tier order is the order to *start* the investigation, not the order to *finish*. Tier 1 means "next on deck"; Tier 4 means "don't open this yet — wait for prereqs or product clarity." Tier 0 is "active or recently completed and worth surfacing here for context."

**UIS lifecycle convention**: an INVESTIGATE moves from `backlog/` to `completed/` once every child PLAN has shipped (or the investigation is otherwise closed). The Tier 0 list below points into `completed/` for the items that have already moved, and into `backlog/` for the ones that are *active* — i.e. their work isn't finished yet, even though no fresh investigation is needed.

---

## Tier 1 — do next (load-bearing or unblocks active work)

| # | Investigation | Effort | Why this tier |
|---|---|---|---|
| 1 | [secrets-template-defaults-clarity](INVESTIGATE-secrets-template-defaults-clarity.md) | S | Foundational fix to the secrets workflow every service depends on. The current silent-overwrite confusion between `00-common-values.env.template` and `default-secrets.env` produces bug reports from contributors and slows every onboarding. Investigation already half-shipped via the existing template scaffolding; closing it out is a small read-and-decide. |
| 2 | [uis-deploy-no-playbook-semantics](INVESTIGATE-uis-deploy-no-playbook-semantics.md) | S | Genuine ambiguity in the deploy code today: services with `SCRIPT_PLAYBOOK=""` produce undefined behaviour. Affects every "metadata-only" service. Investigation gap is small; pinning the contract removes a class of latent bugs across all current and future services. |
| 3 | [uis-deploy-auto-regen-secrets](INVESTIGATE-uis-deploy-auto-regen-secrets.md) | M | UX gap that bites tester loops repeatedly: stale `kubernetes-secrets.yml` produces silent failures. Decisions here lock down idempotency for the whole deploy command. Tester-feedback-driven; high payoff per hour. |
| 4 | [undeploy-purge-flag](INVESTIGATE-undeploy-purge-flag.md) | S | Tester-reported friction (PLAN-002 testing): stateful PVCs survive undeploy, requiring manual `kubectl delete pvc`. Already partially solved for postgrest (`--purge`); unifying the contract across all stateful services prevents drift between handlers. |

## Tier 2 — do after Tier 1 (independent, ready, valuable)

| # | Investigation | Effort | Why this tier |
|---|---|---|---|
| 5 | [in-cluster-port-on-services](INVESTIGATE-in-cluster-port-on-services.md) | S | Small `services.json` schema addition that downstream consumers (Backstage catalog, docs generator, future MCP integrations) keep working around. Cheap to land; immediate downstream payoff. |
| 6 | [version-pinning](INVESTIGATE-version-pinning.md) | M | Cross-cutting consistency review: which services have pinned image tags vs `:latest`. Affects supply-chain hygiene and CI reproducibility. Independent of other tiers; ships value on its own. |
| 7 | [service-version-metadata](INVESTIGATE-service-version-metadata.md) | M | Tied to docs/CLI display: how service scripts expose version info. Closes a presentation gap visible on every service page. Pairs naturally with #6 if done together. |
| 8 | [uis-connect-commands](INVESTIGATE-uis-connect-commands.md) | M | User-facing convenience: `uis connect <service>` opens an interactive client without requiring host-side tooling. Independent of platform/deployment tiers; shippable as a self-contained slice. |
| 9 | [docs-markdown-update-logic](INVESTIGATE-docs-markdown-update-logic.md) | M | Improves the docs-generation pipeline so metadata-driven sections update without overwriting manual prose. Quality-of-life for contributors maintaining service pages. |
| 10 | [verification-playbooks-usage](INVESTIGATE-verification-playbooks-usage.md) | M | Hygiene work on the post-deploy verification playbooks: which services have them, which don't, what shape verifies what. Pays off the next time anything ships. |
| 11 | [host-docs-migration](INVESTIGATE-host-docs-migration.md) | M | Stale host pages still describe the legacy bash-script flow rather than `./uis`. Banner already in place; investigation needed on what to keep vs delete. Independent; closes an external-developer gotcha. |

## Tier 3 — defer until prereqs ship

These have known prerequisites that are still open. Don't open them yet — the prereq's outcome materially changes the investigation's scope.

| # | Investigation | Waits on | Why defer |
|---|---|---|---|
| 12 | [backstage-auth](INVESTIGATE-backstage-auth.md) | authentik-user-config (Tier 0, ready for PLAN) | Adding Authentik OIDC to Backstage assumes Authentik's user-config story is settled. Open the auth investigation only after the user-config PLAN has shipped, otherwise the OIDC client config keeps shifting. |
| 13 | [backstage-enhancements](INVESTIGATE-backstage-enhancements.md) | backstage core deployment (Tier 0, shipped) + #12 | Plugins / scaffolders / catalog enrichment all ride on top of working core. Enhancements don't compete with auth — they queue behind it. |
| 14 | [provision-host-tools-and-auth](INVESTIGATE-provision-host-tools-and-auth.md) | platform-provisioning-layer (Tier 0, in flight) | Decisions about which CLIs (Azure / AWS / GCP / Terraform) live inside `uis-provision-host` depend on the platforms model that the active feature branch is still settling. Designing tool-install + auth-state before platforms lock in = rework. |
| 15 | [dct-argocd-deploy](INVESTIGATE-dct-argocd-deploy.md) | argocd as a stable UIS service | The "deploy from inside DCT with one command" flow needs argocd to be the deployment substrate. ArgoCD has a manifest in UIS but isn't an everyday service yet; investigate this once argocd is operationally normal. |
| 16 | [first-uis-template](INVESTIGATE-first-uis-template.md) | template-framework decision (cross-cutting) | Picking *which* stack template to ship first only matters once `uis template` has a stable shape. Holding until the framework lands prevents picking a target that the framework can't actually build. |
| 17 | [enonic-app-deployment-pipeline](INVESTIGATE-enonic-app-deployment-pipeline.md) | enonic-as-stable-service | Pull-based JAR deployment design assumes Enonic XP is operationally stable in UIS. If Enonic is still in flux, the pipeline shape will too. |
| 18 | [enonic-content-deployment](INVESTIGATE-enonic-content-deployment.md) | #17 | Content-movement design layers on top of app-deployment design. Resolve #17 first or do them as one combined investigation. |
| 19 | [email-smtp-service](INVESTIGATE-email-smtp-service.md) | product clarity (which services need email first?) | Cross-cutting platform service. Worth opening only when the first concrete consumer (Authentik password resets? a notification path?) is actually pulling on it. |

## Tier 4 — ideas, not investigations

These are sketches / parking-lot entries, not concrete research targets. Don't open them as INVESTIGATEs — let the surrounding context resolve, then either promote to a real INVESTIGATE or delete.

| # | Item | What to do |
|---|---|---|
| 20 | [espocrm](INVESTIGATE-espocrm.md) | Currently four URLs and zero analysis. Either promote to a real INVESTIGATE (with a goal + comparison against alternatives) or delete. |
| 21 | [dagster](INVESTIGATE-dagster.md) | Broad research file, not a concrete platform decision. Wait for the data-orchestration use case (atlas's deployment-pipeline INVESTIGATE on the atlas side waits on UIS for this signal) to materialise into a real consumer; then open as a focused investigation. |
| 22 | [metabase](INVESTIGATE-metabase.md) | Similar to #21 — internal BI / data exploration tool selection. Hold until there's a concrete first consumer driving the requirements. |

## Tier 0 — recently shipped or in flight

No fresh investigation work needed. Two sub-groups:

**Already in `completed/`** (every child PLAN shipped — link points into `completed/` per the lifecycle convention):

| # | Investigation | State |
|---|---|---|
| — | [postgrest](../completed/INVESTIGATE-postgrest.md) | Recommendation accepted; PLAN-001 + PLAN-002 + PLAN-postgrest-multi-schema-reconciliation all in `completed/`. Moved 2026-05-07. |
| — | [postgrest-multi-schema-reconciliation](../completed/INVESTIGATE-postgrest-multi-schema-reconciliation.md) | Recommendation accepted; child PLAN in `completed/` (PR #140 merged 2026-05-06). Moved 2026-05-07. |
| — | [container-pull-command](../completed/INVESTIGATE-container-pull-command.md) | Recommendation accepted; PLAN-container-pull-command in `completed/`. Moved 2026-05-07. |
| — | [backstage](../completed/INVESTIGATE-backstage.md) | Status: Completed. PLAN-002-backstage-deployment shipped. Followups in #12 + #13. Moved 2026-05-07. |
| — | [gravitee-fix](../completed/INVESTIGATE-gravitee-fix.md) | Gravitee close-out shipped over the work-stream commits ending at `de872dd`. Moved 2026-05-07. |
| — | [gravitee-post-deploy-config](../completed/INVESTIGATE-gravitee-post-deploy-config.md) | Status: Closed (2026-05-05) — all in-scope findings resolved via the gravitee close-out commits. Moved 2026-05-07. |

**Still in `backlog/`** (work in flight or PLAN drafting next — file stays here until every child PLAN ships):

| # | Investigation | State |
|---|---|---|
| — | [platform-provisioning-layer](INVESTIGATE-platform-provisioning-layer.md) | Status: ACTIVE on `feature/platform-aks-opentofu`. AKS Step 1 in progress. |
| — | [remote-deployment-targets](INVESTIGATE-remote-deployment-targets.md) | Status: Investigation Complete. Child PLAN drafting next; do not open as new investigation work. |
| — | [authentik-user-config](INVESTIGATE-authentik-user-config.md) | Status: Investigation Complete — Ready for PLAN. Child PLAN drafting next. Unblocks #12. |

---

## Cross-cutting notes

- **Two natural workstreams**: UIS-internal correctness (Tier 1, all four items) and developer-experience polish (Tier 2, items #5–#11). They can run in parallel — different files, no merge contention.
- **Backstage cluster**: Tier 0 (core shipped) → #12 (auth) → #13 (enhancements). Tight chain; resolve in order.
- **Platform/host cluster**: Tier 0 platform-provisioning-layer (in flight) → #14 (provision-host tools) → revisit #11 (host docs) once #14 settles. Enables remote/cloud deployment story end-to-end.
- **Enonic cluster**: #17 → #18. Same pattern as atlas's supply-side cluster — schema/lifecycle decisions land first, content-flow design inherits the shape.
- **External coupling with atlas**: atlas's deployment-pipeline investigation explicitly waits on UIS's dagster signal (their Tier 3 #14). Resolving #21 unblocks atlas's deployment-pipeline; deferring #21 keeps that block in place — fine if no UIS consumer is pulling on dagster yet, but worth flagging when atlas next asks.
- **Idea-vs-investigation ratio**: 3 of 31 are still ideas (Tier 4 — espocrm, dagster, metabase). Healthy — most of the backlog is concrete work, not brainstorm residue.
- **Investigation-completion debt**: 5 Tier-0 investigations are "ready for PLAN" or "investigation complete" without a child PLAN drafted (notably remote-deployment-targets and authentik-user-config). Picking one of these up as the next PLAN-drafting task closes more uncertainty than starting any Tier-1 investigation. They're out of scope for this priority doc (which orders investigation work, not plan work) but worth surfacing.

## How to use this doc

1. Pick the top unstarted item from Tier 1; if all of Tier 1 is in flight or done, move to Tier 2.
2. When starting an INVESTIGATE, leave it in this folder and update its `Status:` line to note the work is in flight.
3. When an INVESTIGATE produces a recommendation and a child PLAN is drafted, update this doc: move the row to Tier 0 (sub-group "still in `backlog/`") and note the PLAN it spawned.
4. When every child PLAN of an INVESTIGATE has shipped, `git mv` the file to `completed/`, fix any cross-references, and move the Tier 0 row from "still in `backlog/`" into "already in `completed/`" (re-target the link to `../completed/`).
5. When a Tier-3 prereq lands, promote its dependents up to Tier 2 in the next refresh.
6. Re-rank quarterly or after every 3 INVESTIGATEs ship — whichever comes first.
