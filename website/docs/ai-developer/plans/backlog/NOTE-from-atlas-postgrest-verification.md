# NOTE — PostgREST verification findings from Atlas (2026-04-29)

A note from the Atlas team to the UIS contributor working on
[`INVESTIGATE-postgrest.md`](INVESTIGATE-postgrest.md).

Context: Atlas is the first consuming app to need UIS's PostgREST service. Atlas drafted [PLAN-004 — `api_v1` wrapper layer for PostgREST](../../../../../atlas/website/docs/ai-developer/plans/active/PLAN-004-postgrest-api-v1-wrapper.md) and ran four pre-flight experiments against UIS Postgres + a local PostgREST container. Three findings affect your INVESTIGATE-postgrest.md / forthcoming PLAN-001 directly. Sharing them here so they can fold into your design.

**TL;DR**: your `api_v1` + role-pair + `NOINHERIT` design works as expected. Two improvements worth making to your PLAN-001:

1. **Add `ALTER DEFAULT PRIVILEGES`** to the configure handler's role-creation block — otherwise views added to `api_v1` AFTER configure runs are silently invisible to anonymous requests.
2. **Document the FK-constraint requirement** for resource embedding — `@source` / `@references` comment hints alone don't work; the underlying tables must have actual Postgres `FOREIGN KEY` constraints. Atlas's `marts.*` doesn't have those (dbt's `relationships:` tests are SQL assertions, not DDL), so v1 of Atlas's API skips embeds. Other consuming apps may have the same constraint.

Plus: confirmation that PostgREST 14.10 works against UIS PostgreSQL 16.6 with your planned env-var shape.

---

## Test setup

- **Container**: `postgrest/postgrest:latest` (resolved to PostgREST 14.10 at the time of testing — worth pinning explicitly per your `INVESTIGATE-version-pinning.md`).
- **Database**: UIS's `default/postgresql` (Postgres 16.6) reached via `kubectl port-forward svc/postgresql 35432:5432`.
- **Schemas**: synthetic `pgrst_q*_marts` (underlying tables) + `pgrst_q*_api` (wrapper views) created in the existing `my_app_db`. Cleaned up after.
- **PostgREST config** (matches your INVESTIGATE's planned env-vars):
  ```
  PGRST_DB_URI=postgresql://my_app:<pw>@host.docker.internal:35432/my_app_db
  PGRST_DB_SCHEMA=pgrst_q10_api
  PGRST_DB_ANON_ROLE=my_app
  ```
  (Used `my_app` as both authenticator and anon-role for the test — your role-pair design with `NOINHERIT` is what production will use; my test wasn't checking the role-switching semantics.)

PostgREST started cleanly, loaded the schema cache, and served the OpenAPI spec at `GET /` as your INVESTIGATE expects.

---

## Finding 1 — `ALTER DEFAULT PRIVILEGES` should be added to your configure handler

**The issue.** Your INVESTIGATE [§ "What configure generates"](INVESTIGATE-postgrest.md) (lines 218–225) specifies:

```sql
CREATE ROLE atlas_web_anon NOLOGIN;
CREATE ROLE atlas_authenticator LOGIN PASSWORD '<generated>' NOINHERIT;
GRANT atlas_web_anon TO atlas_authenticator;
GRANT USAGE ON SCHEMA api_v1 TO atlas_web_anon;
GRANT SELECT ON ALL TABLES IN SCHEMA api_v1 TO atlas_web_anon;
```

The last line grants `SELECT` on **existing** tables/views in `api_v1` at the moment configure runs. Postgres does **not** auto-grant on objects created later — unless you add `ALTER DEFAULT PRIVILEGES`.

**The failure mode.** Consuming app adds a new view to `api_v1` (e.g. via dbt migration). The view exists, PostgREST's schema cache reloads (via `NOTIFY pgrst, 'reload schema'`), the OpenAPI spec lists it. But anon requests get `401 Unauthorized` or empty results because `atlas_web_anon` doesn't have `SELECT` on the new view. Silent until someone re-runs configure. Common gotcha; security-correct but surprising.

**The fix — one line in the configure handler.** After the `GRANT SELECT ON ALL TABLES…` line:

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA api_v1 GRANT SELECT ON TABLES TO atlas_web_anon;
```

This grants `SELECT` on **future** tables/views in `api_v1` automatically. Belt-and-suspenders alongside the existing GRANT-on-existing line.

**Atlas's mitigation if UIS doesn't fix this**: Atlas's PLAN-004 generator emits guarded grants in a `DO $$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname='atlas_web_anon') THEN ... END IF; END $$;` block, so Atlas's migration is idempotent regardless of whether the role exists yet. But this distributes responsibility — every consuming app would need similar guarded blocks. Cleaner to fix once in UIS's configure handler.

---

## Finding 2 — FK embeds require actual Postgres `FOREIGN KEY` constraints

**The issue.** Your INVESTIGATE doesn't deeply discuss resource embedding, but the [PostgREST docs you cite](https://postgrest.org) heavily feature it (`?select=*,kommune(*)` etc.) and the worked example in [`website/docs/services/integration/postgrest.md`](../../../services/integration/postgrest.md) at line 177 shows it as a key capability:

> ```bash
> # An NGO with its kommune embedded — one query, two tables joined
> curl 'http://api-atlas.localhost/ngo?select=*,kommune(*)&id=eq.123'
> ```

> The third query is the access pattern PostgREST is being chosen for: foreign keys become embedded-resource relations, no hand-coded join endpoint required.

**What I tested.** Three combinations of `api_v1`-style wrapper views:

| Setup | PostgREST schema cache | `?select=*,kommune(*)` result |
|---|---|---|
| Underlying table WITH `REFERENCES` constraint + view `@source` comment | "4 Relationships loaded" | ✓ embed works; nested object returned |
| Underlying table WITHOUT FK + view `@source` comment | "0 Relationships loaded" | ✗ `PGRST200: Could not find a relationship between 'chapter' and 'kommune'` |
| Underlying table WITHOUT FK + column `@references api_v1.kommune` comment | "0 Relationships loaded" | ✗ same `PGRST200` error |

**Bottom line**: PostgREST's `@source` and `@references` comment hints are **navigation aids** that point at FK constraints in `pg_constraint`. They don't synthesise FK metadata where none exists. To get embeds, the underlying tables need real `REFERENCES col` constraints, OR consumers can use PostgREST's "computed relationships" (SQL functions returning `SETOF` of the related type — significant boilerplate per relationship).

**Atlas's situation.** `marts.*` has zero Postgres FK constraints. dbt's `relationships:` tests are SQL queries that run during `dbt test`, not DDL — they don't translate into FK constraints. So Atlas's PLAN-004 [Q10] resolves as **(c) skip embeds in v1**; the `mart_*` views are designed as fat rows (joined columns inline) so external consumers don't need embeds. Atlas can revisit later via dbt-postgres `+constraints_enabled: true` or computed relationships if external demand surfaces.

**Recommendation for UIS**: in `website/docs/services/integration/postgrest.md`, add a short subsection — something like:

> ### Embedded resources require FK constraints
>
> The `?select=*,kommune(*)` embed pattern relies on PostgREST reading `pg_constraint` for actual `FOREIGN KEY` constraints on the underlying tables. Wrapper views over fact-style tables (e.g. dbt-built marts) typically don't have FK constraints, so embeds won't work out of the box. Three workarounds:
>
> - Add `FOREIGN KEY` constraints to the underlying tables (in dbt: `+constraints_enabled: true` per the dbt-postgres docs).
> - Define [computed relationships](https://docs.postgrest.org/en/v12/references/api/computed_relationships.html) — SQL functions PostgREST recognises as relations.
> - Skip embeds; consumers do two queries.
>
> The `@source` / `@references` comment hints in PostgREST docs are navigation aids that reference existing FK metadata; they don't create it.

This sets correct expectations for the next consuming app that comes along.

---

## Finding 3 — `service-postgrest.sh` is metadata-only today (you already know)

Read confirmation, not a new finding: `provision-host/uis/services/integration/service-postgrest.sh` line 23 has `SCRIPT_PLAYBOOK=""` per your comment lines 8–14 ("METADATA ONLY — `./uis deploy` does not yet do anything"). Atlas's PLAN-004 design accommodates this: Atlas's `api_v1` migration can apply against today's UIS Postgres (which has no `atlas_authenticator` / `atlas_web_anon` roles) without aborting, because Atlas emits guarded grants per Finding 1.

When your PLAN-001 lands and `./uis configure postgrest --app atlas` becomes real, Atlas's same migration re-runs and the (now-existing) roles get granted. No coordination needed at the SQL layer — Atlas's migration is idempotent regardless of UIS's deploy state. Just signal Atlas when configure works and we'll run `./uis configure postgrest --app atlas --schema api_v1 --url-prefix api-atlas`.

---

## Finding 4 — Confirmation: column descriptions don't propagate to wrapper views

Less critical for UIS (it's an Atlas-side generator concern), but worth knowing if you draft examples for the docs:

| | Column comment present? |
|---|---|
| `marts.mart_X.col` (underlying, with `COMMENT ON COLUMN`) | ✓ |
| `api_v1.X.col` (view = `SELECT * FROM marts.mart_X`) | **✗** (NULL `obj_description`) |

So PostgREST projects empty descriptions in the OpenAPI spec unless the consuming app explicitly emits `COMMENT ON COLUMN api_v1.X.col IS '...'` per column. Atlas's PLAN-004 generator does this automatically (reads descriptions from dbt's `target/manifest.json`).

---

## Coordination next steps

1. **Atlas's PLAN-004** is currently active (Phase 1 done; Phase 2–7 underway). Once merged, the Atlas database has the `api_v1` schema with 9 wrapper views populated.
2. **UIS PLAN-001** (PostgREST deployment) — when this lands and `./uis configure postgrest --app atlas` works, Atlas can hit `./uis configure postgrest --app atlas --schema api_v1 --url-prefix api-atlas` + `./uis deploy postgrest --app atlas` and be live.
3. **End-to-end smoke test** from Atlas's side once UIS is up:
   - `curl http://api-atlas.localhost/` returns OpenAPI spec listing all 9 endpoints
   - `curl 'http://api-atlas.localhost/indicator_summary?source_id=eq.ssb-08764'` returns rows
   - (Embeds are not in v1; consumers fetch each `mart_*` separately.)

Atlas will also write a [PLAN-D.2 / PLAN-005](../../../../../atlas/website/docs/ai-developer/plans/active/PLAN-004-postgrest-api-v1-wrapper.md) covering the post-deploy verification once UIS is ready. No code change on Atlas at that point, just the smoke test.

---

## Cross-references

- Atlas's [INVESTIGATE-postgrest-api-v1-wrapper.md](../../../../../atlas/website/docs/ai-developer/plans/backlog/INVESTIGATE-postgrest-api-v1-wrapper.md) — design rationale for Atlas's wrapper layer + 18 decision points
- Atlas's [PLAN-004-postgrest-api-v1-wrapper.md](../../../../../atlas/website/docs/ai-developer/plans/active/PLAN-004-postgrest-api-v1-wrapper.md) — the Atlas-side implementation; Phase 1 outcomes section captures the experiments referenced above
- Atlas's [PLAN-001-api-mart-views.md](../../../../../atlas/website/docs/ai-developer/plans/completed/PLAN-001-api-mart-views.md) — built the 9 `mart_*` views the wrappers will project
- [PostgREST resource-embedding docs](https://docs.postgrest.org/en/v12/references/api/resource_embedding.html)
- [PostgREST computed-relationships docs](https://docs.postgrest.org/en/v12/references/api/computed_relationships.html)
- [dbt-postgres constraints support](https://docs.getdbt.com/reference/resource-properties/constraints)

— signed, the Atlas implementation team (via Claude Code agent), 2026-04-29
