# NOTE — Response to Atlas's PostgREST verification findings (2026-04-28)

A note from the UIS contributor working on [`INVESTIGATE-postgrest.md`](INVESTIGATE-postgrest.md) back to the Atlas team.

**In response to**: [`NOTE-from-atlas-postgrest-verification.md`](NOTE-from-atlas-postgrest-verification.md) (2026-04-29 from Atlas).

**TL;DR**: All four of your findings are addressed. Please re-read the listed locations and confirm the wording captures your intent. The actual implementation lives in [PLAN-002-postgrest-deployment.md](../completed/PLAN-002-postgrest-deployment.md) — that plan is the next gate where your feedback bites in real code.

---

## Where each of your findings landed

### Finding 1 — `ALTER DEFAULT PRIVILEGES` for new objects

**Bucket (c) — design gap**, recorded as an addendum at the top of [`INVESTIGATE-postgrest.md`](INVESTIGATE-postgrest.md) per [PLAN-001-postgrest-documentation.md](../completed/PLAN-001-postgrest-documentation.md) §Phase 4.3 case (c). The existing 23 decisions are unchanged; the new constraint and its implementation impact are documented as additive.

**Where the fix lands in code:** [`PLAN-002-postgrest-deployment.md`](../completed/PLAN-002-postgrest-deployment.md) §Phase 2.4 — the `configure-postgrest.sh` create-path SQL block now includes:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> GRANT SELECT ON TABLES TO <app>_web_anon;
```

Tagged as **load-bearing** in PLAN-002 with a back-reference to your reproduction. Without this line, every consumer would either need to re-run configure on every schema change, or distribute guarded-grant blocks in their migrations (your PLAN-004's mitigation). Fixing once in UIS is the cleaner home, matches the platform/consumer boundary stated in the investigate.

### Finding 2 — FK embeds require real `FOREIGN KEY` constraints

**Bucket (b) — documentation gap**. Added a new subsection to [`website/docs/services/integration/postgrest.md`](../../../services/integration/postgrest.md) titled **"Embedded resources require real FK constraints"**, placed immediately after the Atlas worked example so readers see the caveat right where the embed query is shown.

The subsection explains what `pg_constraint` actually drives, what `@source`/`@references` *don't* do, and lists three workarounds in decreasing-effort order: dbt-postgres `+constraints_enabled: true`, computed relationships (with link to the PostgREST docs), and skip-embeds. Atlas's choice to skip embeds in v1 is named directly as the working example.

### Finding 3 — `service-postgrest.sh` is metadata-only

Confirmation only, no action required. PLAN-001 (this plan) closes today and ships exactly the metadata-only state you tested against. The transition to a deployable service happens in PLAN-002.

### Finding 4 — Column descriptions don't propagate to wrapper views

**Bucket (b) — documentation gap**, lower priority. Added a short subsection to `postgrest.md` titled **"Column descriptions don't propagate to wrapper views"**, placed right after the FK-embed subsection. The note tells consumers they need to re-emit `COMMENT ON COLUMN api_v1.*.col` if they want descriptions in PostgREST's OpenAPI output, and points at your PLAN-004 generator pattern (reading from `target/manifest.json`) as the established working approach.

### Editorial fix you also flagged

The "platforms PostgreSQL service" without an apostrophe in `services.json` was a bug in the docs generator stripping single quotes. Source `SCRIPT_SUMMARY` now reads "the shared PostgreSQL service" — avoids the apostrophe, reads naturally, no generator fix needed for this PR. The generator bug itself is out of scope here; tracked separately if it bites another field later.

---

## What I'd appreciate you re-reading before PLAN-002 starts

1. **The addendum text** at the top of `INVESTIGATE-postgrest.md` — does it capture your reproduction accurately? (Especially the "failure mode" paragraph; I want to make sure I described the silent-401 / empty-result symptom faithfully.)
2. **The two new subsections in `postgrest.md`** — does the FK-embeds wording match what you confirmed in your three-row test table? The wording differs slightly from the suggested text in your note; I tightened it a bit and named your skip-embeds choice as the working example.
3. **The SQL in PLAN-002 Phase 2.4** — is the position of `ALTER DEFAULT PRIVILEGES` correct (after `GRANT SELECT ON ALL TABLES`)? Is `IN SCHEMA <schema>` parametrising the right way for your case (where `<schema>` will be `api_v1`)?

If anything is off, leave another `NOTE-from-atlas-*.md` file alongside this one and I'll fold it into PLAN-002 before that plan starts implementation.

---

## Coordination next steps

Per your "Coordination next steps" section:

| Step | UIS state | Atlas state |
|---|---|---|
| **PLAN-001 (UIS)** — documentation gate | ✅ Closing today | — |
| **PLAN-004 (Atlas)** — `api_v1` wrapper layer | — | In progress (Phase 1 done; Phase 2-7 underway per your note) |
| **PLAN-002 (UIS)** — PostgREST deployment | Backlog; ready to start | Blocks Atlas's `./uis configure postgrest --app atlas` |
| **PLAN-D.2 / PLAN-005 (Atlas)** — post-deploy smoke test | — | Pending PLAN-002 (UIS) |

Once PLAN-002 lands and `./uis configure postgrest --app atlas --schema api_v1 --url-prefix api-atlas` works, you can run the four smoke checks from your "Coordination next steps" section against `http://api-atlas.localhost`. Will signal in this NOTE chain when that's ready.

— signed, the UIS contributor (via Claude Code agent), 2026-04-28
