---
title: PostgREST
sidebar_label: PostgREST
---

# PostgREST

Auto-generated REST API from a curated PostgreSQL schema.

| | |
|---|---|
| **Category** | Integration |
| **Deploy** | `./uis deploy postgrest --app <name>` (per-instance) |
| **Undeploy** | `./uis undeploy postgrest --app <name>` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Image** | `postgrest/postgrest:<pinned-during-implementation>` |
| **Default namespace** | `postgrest` |

## What It Does

PostgREST is a single Haskell binary that introspects a PostgreSQL schema and exposes its tables and views as REST endpoints, with foreign keys becoming embedded-resource relations and OpenAPI metadata served at `GET /`. PostgREST 12.x (the version UIS currently pins) emits Swagger 2.0; later releases may upgrade to OpenAPI 3.x. UIS deploys one PostgREST instance per consuming application, all sharing a single namespace and the platform's PostgreSQL service. Each instance is configured separately via `./uis configure postgrest --app <name>`.

## Configuration

PostgREST is a multi-instance service: one Deployment per consuming application, configured independently. Before deploying you must answer four questions: which app, which database, which schema, and what URL prefix.

### The `api_v1` contract (application-side, required)

PostgREST must point at a curated `api_v1` schema of views — never at raw application tables. The application owns this schema; UIS does not write it for you. Minimum setup, run once against your application's database:

```sql
CREATE SCHEMA api_v1;

-- Curated views over your internal model. Hide debug columns,
-- expose only what you want as a public API.
CREATE VIEW api_v1.kommune AS
  SELECT kommune_nr, name, fylke_nr, population_latest
  FROM marts.dim_kommune;
```

Why this rule:

- **Decouples the API contract from internal models** — refactor your tables without breaking clients.
- **Column-level control** — internal-only columns (raw scrape timestamps, debug fields) stay in `marts.*` and never reach the API.
- **Versioning** — when v2 lands, create `api_v2` alongside; deprecate `api_v1` on a schedule, no client breakage.
- **Per-endpoint Row-Level Security** later — RLS policies attach to views, not raw tables.

### Connection model and role naming

PostgREST does **not** connect as your application's owner user (e.g. `my_app`). It uses a separate role pair, created by `./uis configure postgrest`:

- `<app>_authenticator` — `LOGIN`, `NOINHERIT`, with a generated password. The role PostgREST connects as. `NOINHERIT` is load-bearing: it has no implicit privileges; only what `SET LOCAL ROLE` explicitly switches to is granted.
- `<app>_web_anon` — `NOLOGIN`. The role for unauthenticated requests. Has `SELECT` on `api_v1`.

Per request, PostgREST connects as `<app>_authenticator`, runs `SET LOCAL ROLE <app>_web_anon`, executes the query in that role's permissions, then resets at end of request. Your application's existing user and password are untouched.

The `<app>_` prefix is required because Postgres roles are cluster-wide. Two apps with unprefixed `web_anon` would collide on the platform's shared PostgreSQL.

### Lifecycle commands

```bash
# 1. Configure (Postgres-side state + Secret in postgrest namespace)
./uis configure postgrest --app atlas \
    --database atlas \
    --schema api_v1 \
    --url-prefix api-atlas

# 2. Deploy (Kubernetes objects: Deployment, Service, IngressRoute)
./uis deploy postgrest --app atlas

# 3. Verify
./uis verify postgrest --app atlas
curl http://api-atlas.localhost/             # OpenAPI spec
curl http://api-atlas.localhost/kommune      # Sample view
```

What changes at each step:

- **`configure`** creates the role pair (`atlas_web_anon`, `atlas_authenticator`) and writes the `atlas-postgrest` Secret. Idempotent: a second call with the same `--app` is a no-op (skip path). Use `--rotate` to generate a new password and update the Secret.
- **`deploy`** renders per-instance manifests and applies the Deployment, Service, and IngressRoute. Errors out if the instance has not been configured.
- **`undeploy`** removes only the Kubernetes objects. Postgres roles and the Secret remain, so a follow-up `deploy` works without re-configure.
- **`configure --purge`** drops the Postgres roles and removes the Secret. Use after `undeploy` for a full teardown.

### Schema reload

When you add a new view to `api_v1`, PostgREST does not see it until its schema cache is invalidated:

```sql
-- Hot reload, no downtime: signal from any psql session against the database
NOTIFY pgrst, 'reload schema';
```

Or restart the pods for a clean cycle:

```bash
kubectl rollout restart deployment/<app>-postgrest -n postgrest
```

### Multi-instance coexistence

After configuring two apps, the `postgrest` namespace contains:

```
postgrest/
├── atlas-postgrest         (Deployment, Service, IngressRoute, Secret)
│     → Postgres roles: atlas_web_anon, atlas_authenticator
│     → matches HostRegexp(`api-atlas\..+`)
└── customers-postgrest     (Deployment, Service, IngressRoute, Secret)
      → Postgres roles: customers_web_anon, customers_authenticator
      → matches HostRegexp(`api-customers\..+`)
```

No shared state between instances. Independent deploy / undeploy / configure cycles per app.

### Resulting URLs

A single IngressRoute per instance answers every domain Traefik knows, via `HostRegexp` (see [Ingress and Traefik Rules](../../contributors/rules/ingress-traefik.md)):

| Environment | URL |
|---|---|
| Local dev (Rancher Desktop) | `http://api-atlas.localhost` |
| Tailscale tunnel | `https://api-atlas.<tailnet>.ts.net` |
| Cloudflare tunnel | `https://api-atlas.<your-public-domain>` |

No per-domain configuration in PostgREST or its IngressRoute.

## Example: Atlas open-data API

A worked example for the Atlas open-data application. Atlas publishes Norwegian public-sector data (kommuner, NGOs, social statistics) sourced from SSB, FHI, NAV, and Brreg.

### Application-side: write the api_v1 schema

In Atlas's data repository, as a migration:

```sql
CREATE SCHEMA api_v1;

CREATE VIEW api_v1.kommune AS
  SELECT kommune_nr, name, fylke_nr, population_latest
  FROM marts.dim_kommune;

CREATE VIEW api_v1.ngo AS
  SELECT id, name, orgnr, kommune_nr, registered_at
  FROM marts.dim_ngo;

CREATE VIEW api_v1.low_income_children AS
  SELECT kommune_nr, year, low_income_share, source
  FROM marts.fct_low_income_children;
```

Atlas does **not** create the `atlas_web_anon` or `atlas_authenticator` roles or grant privileges — `./uis configure postgrest` does that.

### Platform-side: configure and deploy

```bash
./uis configure postgrest --app atlas \
    --database atlas \
    --schema api_v1 \
    --url-prefix api-atlas

./uis deploy postgrest --app atlas
```

### Querying the API

Three queries that demonstrate why PostgREST fits Atlas's relational data:

```bash
# All kommuner in fylke 03 (Oslo)
curl 'http://api-atlas.localhost/kommune?fylke_nr=eq.03'

# A single NGO by org-number
curl 'http://api-atlas.localhost/ngo?orgnr=eq.971234567'

# An NGO with its kommune embedded — one query, two tables joined
curl 'http://api-atlas.localhost/ngo?select=*,kommune(*)&id=eq.123'
```

The third query is the access pattern PostgREST is being chosen for: foreign keys become embedded-resource relations, no hand-coded join endpoint required.

### Embedded resources require real FK constraints

The `?select=*,kommune(*)` embed pattern relies on PostgREST reading `pg_constraint` for actual `FOREIGN KEY` constraints on the underlying tables. PostgREST's `@source` and `@references` comment hints are *navigation aids* that point at existing FK metadata — they don't synthesise it. Wrapper views over fact-style tables (e.g. dbt-built marts, where `relationships:` tests are SQL assertions, not DDL) typically lack FK constraints, so embeds won't work out of the box. Three workarounds, in order of decreasing effort to maintain:

- **Add `FOREIGN KEY` constraints to the underlying tables.** In dbt-postgres: `+constraints_enabled: true` (see [dbt-postgres constraints docs](https://docs.getdbt.com/reference/resource-properties/constraints)). Pure DDL, works with PostgREST's standard discovery — but flipping the flag is rarely a quick win in practice: expect non-trivial side effects on build ordering, fail-on-violation semantics, and compatibility with views that filter by `is_active` or similar soft-delete columns.
- **Define [computed relationships](https://docs.postgrest.org/en/v12/references/api/computed_relationships.html)** — SQL functions returning `SETOF <related_type>` that PostgREST recognises as relations. Significant boilerplate per relationship; useful when FK constraints are infeasible.
- **Skip embeds; consumers do two queries.** The right call when relationships are few and clients can afford the round trip. Atlas's v1 API takes this path — the `mart_*` views are designed as fat rows (joined columns inline) so external consumers don't need embeds.

If you're unsure, start without embeds and add them later if external demand surfaces.

### Column descriptions don't propagate to wrapper views

`COMMENT ON COLUMN marts.dim_kommune.name IS '…'` is **not** visible on `api_v1.kommune` defined as `CREATE VIEW api_v1.kommune AS SELECT … FROM marts.dim_kommune`. PostgREST projects empty `description` fields in the OpenAPI spec for view columns unless the consumer explicitly emits `COMMENT ON COLUMN api_v1.kommune.name IS '…'` per column. If your build pipeline already has descriptions in the underlying-table layer (e.g. dbt's `target/manifest.json`), have the migration generator re-emit them on the view.

## Undeploy

```bash
# Remove K8s objects, keep Postgres roles and Secret (re-deploy works without re-configure)
./uis undeploy postgrest --app atlas

# Full teardown: drop roles, remove Secret
./uis configure postgrest --app atlas --purge
```

## Troubleshooting

### PostgREST returns 404 for a view I just added

PostgREST caches the schema at startup. After adding a view to `api_v1`, signal a reload:

```sql
NOTIFY pgrst, 'reload schema';
```

Or restart the pods: `kubectl rollout restart deployment/<app>-postgrest -n postgrest`.

### PostgREST returns 401 unauthorized for an anonymous request

The `<app>_authenticator` role lacks permission to switch to `<app>_web_anon`. `./uis configure postgrest --app <name>` grants this automatically; if you see this error after a clean configure, run `./uis configure postgrest --app <name> --rotate` to recreate the role pair, or check that the GRANT statement was not rolled back manually.

## Out of scope

- The `api_v1` schema and view definitions — application-side work, owned by the consumer's migrations.
- pg_graphql for GraphQL endpoints — separate future investigation (`INVESTIGATE-pg-graphql.md`).
- JWT authentication and per-user RLS policies — deferred until a real authenticated-endpoint requirement appears.

## Learn More

- [Official PostgREST documentation](https://postgrest.org)
