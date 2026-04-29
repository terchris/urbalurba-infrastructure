# NOTE — PostgREST documentation review: approved (2026-04-29)

A reply from the Atlas team to the UIS contributor's [`NOTE-from-uis-postgrest-doc-feedback-merged.md`](NOTE-from-uis-postgrest-doc-feedback-merged.md).

**TL;DR**: All three verification items pass. **Approved — proceed with PLAN-002.** Two minor non-blocking notes at the bottom.

---

## Verification

### 1. Addendum captures Finding 1 faithfully ✓

[`INVESTIGATE-postgrest.md` § "Addendum: 2026-04-29"](INVESTIGATE-postgrest.md) line 29:

> "anonymous requests get `401 Unauthorized` or empty results because `<app>_web_anon` has no `SELECT` privilege on the new object. Silent until someone re-runs configure."

Captures the silent-401 / empty-result symptom precisely. The reload-of-schema-cache + OpenAPI-still-lists-the-view framing matches exactly what I reproduced in the docker-PostgREST test.

Bonus: the addendum explicitly notes "Atlas's experiment 3 reproduced this against a synthetic `pgrst_q*_marts` / `pgrst_q*_api` pair on the platform's PostgreSQL" — that's the right pointer if anyone wants to re-run the experiment. The addendum protocol (existing 23 decisions stay frozen; only the addendum + PLAN-002 change) is the right scope discipline.

### 2. Two new subsections in `postgrest.md` ✓

[`postgrest.md` § "Embedded resources require real FK constraints"](../../../services/integration/postgrest.md#embedded-resources-require-real-fk-constraints) (lines 182–190):

The three-row test table from my NOTE has been consolidated into prose. The wording loses the table format but **gains clarity** — the docs-page audience cares about the principle (`@source` / `@references` are navigation aids, not metadata synthesisers) more than the row-by-row test reproduction. Critical claims preserved:

- "PostgREST reading `pg_constraint` for actual `FOREIGN KEY` constraints" — the mechanism.
- "`@source` and `@references` comment hints are *navigation aids* that point at existing FK metadata — they don't synthesise it" — the corollary I established by elimination.
- Three workarounds listed in the right order (FK constraints / computed relationships / skip embeds), with Atlas's skip-embeds choice named as the working example.

The `+constraints_enabled: true` link to dbt-postgres docs is accurate. Closing line "If you're unsure, start without embeds and add them later" is a good editorial addition — it's the right operational stance for early-stage projects.

[`postgrest.md` § "Column descriptions don't propagate to wrapper views"](../../../services/integration/postgrest.md#column-descriptions-dont-propagate-to-wrapper-views) (lines 192–194):

Accurate. The `target/manifest.json` workaround call-out is precisely the path Atlas's PLAN-004 generator takes — it reads dbt's manifest and re-emits `COMMENT ON COLUMN api_v1.X.col` per column. Nothing missing.

### 3. `ALTER DEFAULT PRIVILEGES` line in PLAN-002 Phase 2.4 ✓

[`PLAN-002-postgrest-deployment.md` Phase 2.4](PLAN-002-postgrest-deployment.md) (lines 97–105):

```sql
CREATE ROLE <app>_web_anon NOLOGIN;
CREATE ROLE <app>_authenticator LOGIN PASSWORD '<pw>' NOINHERIT;
GRANT <app>_web_anon TO <app>_authenticator;
GRANT USAGE ON SCHEMA <schema> TO <app>_web_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA <schema> TO <app>_web_anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA <schema> GRANT SELECT ON TABLES TO <app>_web_anon;
```

- **Position correct**: `ALTER DEFAULT PRIVILEGES` is after `GRANT SELECT ON ALL TABLES`. Belt-and-suspenders order. ✓
- **Schema parameter correct**: `<schema>` is the placeholder; for Atlas's `./uis configure postgrest --app atlas --schema api_v1` invocation it substitutes to `api_v1`. ✓
- **Target role**: `<app>_web_anon` (per-app), **not** `PUBLIC`. ✓ — this was the corner-cut trap I flagged in my original NOTE; you avoided it.
- **Load-bearing tag** + back-reference to the addendum is exactly the right framing.

---

## Approved — proceed with PLAN-002

No blocking issues. Ship it.

When `./uis configure postgrest --app atlas --schema api_v1 --url-prefix api-atlas` and `./uis deploy postgrest --app atlas` work end-to-end, signal back via the NOTE chain. Atlas's PLAN-004 (currently in Phase 4 — applying the generated `api_v1` SQL + running the runtime validation gates) will be ready by then; the four smoke checks from my original NOTE's "Coordination next steps" section are the natural validation.

---

## Two minor non-blocking notes

Capturing for the record; neither would change PLAN-002's scope.

**(a) The dbt-postgres link in `postgrest.md` line 186** — `https://docs.getdbt.com/reference/resource-properties/constraints` — could optionally be deepened with a sentence noting that **`+constraints_enabled: true` is a per-model flag with non-trivial side effects** (build ordering, fail-on-violation semantics, potential incompatibility with views that filter their dim_* on `is_active`). The current docs page leaves the impression that flipping the flag is a quick win; for Atlas it's a separate workstream (Atlas's INVESTIGATE-postgrest-api-v1-wrapper.md [Q10] expanded on this). A 10-word "non-trivial side effects" qualifier in postgrest.md would set expectations for the next consumer who hits this. Not a change-request.

**(b) The `pg_graphql` cross-reference in postgrest.md "Out of scope"** is correctly split into the separate `INVESTIGATE-pg-graphql.md` per Decision #13. Just an acknowledgement that the boundary is drawn cleanly — graph-shaped queries over `api_v1` are a different question with different trade-offs (RLS interaction, schema introspection cost, etc.) and deserve their own investigation. No change needed.

---

## Coordination state (post-approval)

| Step | UIS state | Atlas state |
|---|---|---|
| **PLAN-001 (UIS)** — documentation gate | ✅ Merged 2026-04-28 | — |
| **PLAN-004 (Atlas)** — `api_v1` wrapper layer | — | Phase 3 done; Phase 4–7 underway |
| **Re-review (this note)** | ✅ Approved 2026-04-29 | — |
| **PLAN-002 (UIS)** — PostgREST deployment | Unblocked; ready to start | Blocks `./uis configure postgrest --app atlas` |
| **PLAN-D.2 / PLAN-005 (Atlas)** — post-deploy smoke test | — | Pending PLAN-002 |

— signed, the Atlas team (via Claude Code agent), 2026-04-29
