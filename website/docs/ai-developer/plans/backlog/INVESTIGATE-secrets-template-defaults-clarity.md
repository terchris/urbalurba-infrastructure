# Investigate: Make `00-common-values.env.template` defaults visibly sourced from `default-secrets.env`

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Eliminate the silent-overwrite confusion in the secrets-template flow. A reader of `provision-host/uis/templates/secrets-templates/00-common-values.env.template` should see, at the line where a `DEFAULT_*` value is defined, that the value is auto-populated from `provision-host/uis/templates/default-secrets.env` at init time. Today the template ships with placeholder values (e.g. `DEFAULT_ADMIN_PASSWORD=TestPassword@123`) that are sed-overwritten by the seven canonical values from `default-secrets.env` during `init_secrets()` — the substitution is invisible to a contributor reading either file in isolation.

**Last Updated**: 2026-05-01

**Request origin**: Surfaced during the gravitee PR-A review while the contributor was explaining the secrets flow to the user. The current shape was deemed confusing: "if this is how it works then i would say that a better setup would be: in `00-common-values.env.template` define `DEFAULT_ADMIN_PASSWORD=<value from default-secrets.env>`. If it is done like that then the human could see that the values are automatically sourced from default-secrets.env."

**Depends on**: nothing — this is a contributor-DX change. Touches `provision-host/uis/templates/secrets-templates/00-common-values.env.template`, optionally `provision-host/uis/lib/first-run.sh::copy_secrets_templates`, and possibly `provision-host/uis/templates/default-secrets.env`.

---

## The current confusion

Two files in the repo carry the seven `DEFAULT_*` values:

```
provision-host/uis/templates/
├── default-secrets.env                                  ← canonical source (7 vars only)
└── secrets-templates/
    └── 00-common-values.env.template                    ← full template (~50 vars, includes
                                                          duplicates of the 7 with placeholder
                                                          values like TestPassword@123)
```

On first `./uis list` or `./uis secrets init`, `provision-host/uis/lib/first-run.sh::copy_secrets_templates` (around lines 244-298) does:

1. Copies `secrets-templates/00-common-values.env.template` → `.uis.secrets/secrets-config/00-common-values.env.template`.
2. Sources `default-secrets.env` (loading the seven values into the shell).
3. Runs `sed` on the user's copy to overwrite the seven `DEFAULT_*` placeholder values with the values from `default-secrets.env`:
   ```bash
   sed -i.bak \
     -e "s/DEFAULT_ADMIN_PASSWORD=.*/DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD}/" \
     ...
   ```

After init, the user's file has `DEFAULT_ADMIN_PASSWORD=LocalDev@123` (from `default-secrets.env`), not `TestPassword@123` (from the template). Per-service references like `PGPASSWORD=${DEFAULT_DATABASE_PASSWORD}` stay as `${...}` references and are resolved by `envsubst` at `./uis secrets generate` time.

**The problem**: nothing on the `DEFAULT_ADMIN_PASSWORD=TestPassword@123` line in the bundled template tells a reader the value will be overwritten. A contributor adding a new service is likely to either:
- Edit the placeholder in `00-common-values.env.template` thinking that's the default → no effect on fresh installs (sed overwrites it), no effect on existing installs (their copy is preserved), so the change appears to work locally but disappears for everyone else.
- Not realize `default-secrets.env` exists at all, since it's not referenced from `00-common-values.env.template`.

---

## Options

### Option A — comment markers (least invasive)

Replace the seven `DEFAULT_*` lines in the bundled template with values that match `default-secrets.env`, plus a comment block above them:

```bash
# These seven values are auto-populated from default-secrets.env at init time.
# Edit default-secrets.env to change defaults; values below are placeholders
# that get overwritten by sed in first-run.sh::copy_secrets_templates.
DEFAULT_ADMIN_EMAIL=admin@example.com
DEFAULT_ADMIN_PASSWORD=LocalDev@123
DEFAULT_DATABASE_PASSWORD=LocalDevDB456
DEFAULT_REDIS_PASSWORD=LocalDevRedis123
DEFAULT_AUTHENTIK_SECRET_KEY=LocalDevAuthentik123
DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD=LocalDevAuthentik123
DEFAULT_OPENWEBUI_SECRET_KEY=LocalDevOpenWebUI123
```

**Pros**: zero code change, preserves the file's standalone parseability (sourcing it before init still works, just with the same values as default-secrets.env), comment makes the intent unambiguous.
**Cons**: still two places to keep in sync — drift between `default-secrets.env` and these placeholders is invisible until someone notices. Doesn't fix the duplication, just labels it.
**Effort**: ~10 minutes, single-file change in `secrets-templates/00-common-values.env.template`.

### Option B — sentinel placeholder values

```bash
DEFAULT_ADMIN_PASSWORD=__AUTO_FROM_DEFAULT_SECRETS_ENV__
DEFAULT_ADMIN_EMAIL=__AUTO_FROM_DEFAULT_SECRETS_ENV__
...
```

**Pros**: a reader scanning the file immediately sees the line is auto-populated; no real value to mistake for the actual default.
**Cons**: file is no longer a valid env file standalone — sourcing it before init returns the literal sentinel string for these variables, which would break any tooling that reads `$DEFAULT_ADMIN_PASSWORD` from the template directly. The sed regex still works, so init produces the same final result.
**Effort**: ~15 minutes; needs a sweep for any tooling that sources the bundled template directly (likely none, but worth a grep).

### Option C — eliminate the duplication

Don't put the seven `DEFAULT_*` lines in the template at all. Change `copy_secrets_templates` to **append** the lines from `default-secrets.env` to the user's copy after copying the template (or `cat` them together). Single source of truth in `default-secrets.env`; per-service `${DEFAULT_*}` references resolve correctly in the user's combined copy because env files are flat and order-insensitive for assignment-then-reference patterns.

**Pros**: no duplication, no sed substitution, no possibility of drift. Cleaner mental model.
**Cons**: someone reading the bundled `00-common-values.env.template` standalone sees `${DEFAULT_DATABASE_PASSWORD}` references with no obvious definition — they have to know to also look at `default-secrets.env`. The "auto-populated section" is invisible until init runs. (This is fixable with a comment at the top of the template explaining where the `DEFAULT_*` values come from, which gets us back to a flavour of Option A's clarity but without the duplicate values.)
**Effort**: ~30-45 minutes — two-file change (template + first-run.sh), plus regression-testing a fresh `./uis secrets init` and confirming all per-service vars resolve correctly.

### Option D — generate `00-common-values.env.template` from a single source

Treat both files as derivatives of a canonical YAML/TOML/whatever-source describing the seven variables and the per-service references. A build step (Makefile target, pre-commit hook, or `./uis dev regen-templates`) emits both files. Overkill for seven variables but listed for completeness.

**Pros**: bulletproof against drift, makes adding a new `DEFAULT_*` a single-file edit.
**Cons**: introduces a code-generation step into a flow that currently has none. Adds maintenance burden for negligible payoff at this scale.
**Effort**: ~half a day plus ongoing tooling cost. Not recommended.

---

## Recommendation

**Option A** is the highest value-per-minute change. It fixes the actual confusion (a contributor reading `00-common-values.env.template` will see the comment and know to look at `default-secrets.env`) without changing any runtime behaviour.

**Option C** is the cleaner long-term shape and worth doing if a future contributor is already touching `copy_secrets_templates` for another reason. The 30-45 minutes of work isn't justified standalone.

**Option B** is dominated by A — same effort, no real upside.

---

## Acceptance criteria

For **Option A** (recommended):

- [ ] `provision-host/uis/templates/secrets-templates/00-common-values.env.template` has a comment block above the seven `DEFAULT_*` lines explaining that values are auto-populated from `default-secrets.env`.
- [ ] The seven placeholder values match `default-secrets.env` verbatim (so the template is parseable standalone with sane values, even pre-init).
- [ ] No code changes to `first-run.sh` — sed substitution behaviour is unchanged.
- [ ] Manual verification: a fresh `./uis secrets init` against an empty `.uis.secrets/` produces the same result as before (same seven values land in the user's copy).
- [ ] `provision-host/uis/templates/default-secrets.env` keeps a one-line comment at the top noting it's the source-of-truth for the seven `DEFAULT_*` values consumed by `copy_secrets_templates`.

For **Option C** (if scoped in alongside another change):

- [ ] `00-common-values.env.template` no longer contains the seven `DEFAULT_*` definitions.
- [ ] `copy_secrets_templates` appends the contents of `default-secrets.env` to the user's copy of `00-common-values.env.template` after copying it (or equivalent `cat` / `grep -v` pattern).
- [ ] A comment at the top of the template explains that `DEFAULT_*` values are appended at init time.
- [ ] Fresh `./uis secrets init` produces a working `.uis.secrets/` with all expected variables.
- [ ] Existing `.uis.secrets/` directories (with the old combined-file shape) keep working — `copy_secrets_templates` should detect the existing common-values file and not re-append.

---

## Open questions

1. Are there any tools or scripts that source `secrets-templates/00-common-values.env.template` directly (i.e. without going through `init_secrets`)? If so, Option B's sentinel approach would break them. A `grep -r 'secrets-templates/00-common-values'` should answer this in seconds.
2. Should this work get folded into a broader cleanup of the secrets flow (e.g. the related backlog item about [secrets-template drift detection](#related-backlog-items))? Both share the underlying observation that the secrets-init flow is fragile under contributor edits. Doing them together would reduce duplicate context-loading, but each is independently scoped.
3. Is there a precedent in the repo for "generated section" markers (`# BEGIN AUTO-GENERATED — do not edit`) that we should follow? If so, prefer that style over a free-form comment block.

---

## Related backlog items

- A planned **secrets-template drift detector** — when source `00-common-values.env.template` adds a new variable, existing user `.uis.secrets/secrets-config/00-common-values.env.template` files don't pick it up (this bit the gravitee PR-A tester in Round 2: empty `GRAVITEE_POSTGRES_*` values). Both this clarity work and the drift detector touch the same flow; if scheduled together they share a test/fixture surface. (Standalone INVESTIGATE pending — file when surfaced.)
- The existing [`INVESTIGATE-container-pull-command.md`](../completed/INVESTIGATE-container-pull-command.md) — separate flow but neighbouring contributor-DX surface.

---

## Out of scope

- Changing the actual default values shipped with UIS (those stay as-is in `default-secrets.env`).
- Reshaping the master `00-master-secrets.yml.template` rendering flow.
- Changing how `./uis secrets generate` or `./uis secrets apply` work.
- Migrating to a different secret-management backend (sealed-secrets, external-secrets-operator, etc.).
