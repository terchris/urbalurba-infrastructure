# Investigate: `./uis deploy <svc>` should auto-regenerate stale `kubernetes-secrets.yml`

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Decide whether (and how) `./uis deploy <svc>` should detect a stale generated `kubernetes-secrets.yml` and either regenerate it automatically or refuse to deploy until the user does. Today, edits to `default-secrets.env`, `00-common-values.env.template`, or `00-master-secrets.yml.template` silently no-op for any service that's already deployed unless the user remembers to run `./uis secrets generate && ./uis secrets apply` between the template edit and the next deploy.

**Last Updated**: 2026-05-04

**Reported in**: Round 6.5 of `/Users/terje.christensen/learn/helpers/testing/uis1/talk/talk.md` (uis-user1 tester report). Reproducer below.

**Why now is too soon**: this is a UIS-wide infrastructure improvement, not a Gravitee concern. Surfacing it during the Gravitee Round 6.5 admin-email change makes the cost concrete (one wasted deploy cycle, one corrective rerun), but the fix touches every service's deploy path — wider blast radius than appropriate during the Gravitee experiment chain. Land the gravitee-config work first, then do this.

---

## Reproducer (verbatim from Round 6.5)

1. Edit `provision-host/uis/templates/default-secrets.env` → change `DEFAULT_ADMIN_EMAIL` to a new value.
2. Edit `.uis.secrets/secrets-config/00-common-values.env.template` → same line.
3. Run `./uis undeploy gravitee --purge --yes` (wipes in-cluster secret + DB).
4. Run `./uis deploy gravitee`.
5. Inspect the live secret + DB admin row.

**Observed**: secret + DB admin row both still show the OLD email value. The chain has four touchpoints (default-secrets.env → common-values → master-secrets template → generated YAML); steps 1-3 are correct end-to-end but step 4 (the on-disk `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`) is a months-old artefact that nothing in the deploy path regenerates. `--purge` wipes in-cluster state but not host-side generated files; `secrets apply` reads the stale generated file and faithfully re-applies it.

**Corrective rerun** that worked: insert `./uis secrets generate && ./uis secrets apply` between the template edit and the deploy.

---

## Options

### Option A — auto-regenerate on mtime drift (recommended)

`./uis deploy <svc>` checks whether any of:
- `provision-host/uis/templates/default-secrets.env`
- `.uis.secrets/secrets-config/00-common-values.env.template`
- `.uis.secrets/secrets-config/00-master-secrets.yml.template`

is newer than `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`. If yes, runs `secrets generate && secrets apply` automatically before the per-service playbook fires. Prints a clear log line: `Regenerating secrets — templates changed since last generate (drift detected on: <file>)`.

**Pros**: zero user friction. The mental model "edit template → next deploy applies it" just works. Matches the rest of UIS's "things just work without ceremony" philosophy.

**Cons**: hides template drift in logs; a hotfix where the user wants yesterday's secret values needs an explicit `--no-regen` flag (small) or a comment-and-redeploy workaround.

### Option B — warn but require explicit action

Same mtime check, but instead of regenerating, prints `Templates have changed since the last 'secrets generate' run. Run './uis secrets generate && ./uis secrets apply' before deploying.` and exits non-zero.

**Pros**: explicit; impossible to accidentally pick up an in-flight template edit. Easier to reason about in CI/CD-style workflows where the deploy step shouldn't have side effects on the generated artefact.

**Cons**: extra step on every template edit. Friction for the common case.

### Option C — leave as-is, document loudly

Add a clearer note to `gravitee.md` (and any other service docs) that template edits require manual regeneration. No code change.

**Pros**: zero implementation work.

**Cons**: doesn't actually fix the trap; just moves it from "silent failure" to "documented silent failure." Round 6.5 cost a deploy cycle even though the doc surface for Finding 7 already mentioned this — the user didn't read the doc before the experiment.

---

## Recommendation (to be confirmed at PLAN time)

**Option A.** The deploy command's responsibility is "make the deployed state match the configured state"; if the configured state has changed since the generated artefact was produced, that artefact is stale and the deploy should refresh it. A printed log line preserves visibility for anyone who actually wants to see what changed.

The escape hatch (`--no-regen` flag for the hotfix-yesterday's-values case) is a 5-line addition that shouldn't gate Option A landing.

---

## Open questions for the PLAN phase

1. **Where does the mtime check live** — in `./uis` CLI (`uis-cli.sh` `cmd_deploy`), in `service-deployment.sh:deploy_single_service`, or in a small helper sourced by both? Probably the wrapper, parallel to where `service-deployment.sh:deploy_single_service` already sources `default-secrets.env` (Round 5 change). Check whether `cmd_deploy` already has secret-handling logic.
2. **What about `secrets apply`** — does the apply step itself check whether the generated YAML has actually changed since last apply? Probably worth a similar idempotence guard: if `kubernetes-secrets.yml` is unchanged since last apply, skip the apply (saves a `kubectl apply` round trip on every redeploy).
3. **Multi-service deploys** (`deploy_enabled_services`) — does the regen happen once for the whole loop, or per service? Once is correct (templates are per-cluster, not per-service).
4. **Edge case: `kubernetes-secrets.yml` doesn't exist yet** — should the deploy fail with "run `./uis secrets generate` first" or auto-generate on first run? Auto-generate matches the principle of least surprise.
5. **CI/CD interaction** — if a future workflow runs `./uis deploy` from a checked-out repo without ever running `./uis secrets generate`, the generated YAML doesn't exist. Auto-generate on first run handles this; if we adopt Option B's "fail explicitly" stance, this needs a separate rule.

Each of these can be answered at PLAN time with a 5-min code read.

---

## Scope

- **In scope**: deploy-time detection of template-vs-generated drift; one of A/B/C above adopted across the deploy path.
- **Out of scope**:
  - Re-architecting the secrets pipeline itself (e.g. removing the `kubernetes-secrets.yml` intermediate file in favour of in-memory generation on every deploy). Bigger surgery; separate plan if anyone wants it.
  - Multi-environment secrets profiles (`UIS_PROFILE=dev|prod`). Adjacent to Finding 8's broader "minimal-dev vs prod-overlay" question; tracked separately.
  - Per-template-key auditing ("which DEFAULT_* changed and which secret keys it affects"). Nice-to-have, not load-bearing.

---

## When to revisit

After the gravitee-config experiment chain (currently OQ5, then PLAN-001+ for Findings 1/2/3/4) lands. This INVESTIGATE → PLAN cycle then runs separately, no dependency.
