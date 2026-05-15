# Investigate: customer onboarding flow for "I need a database for my app"

**Status**: Draft / not yet scheduled.
**Source**: First end-to-end walkthrough with a UIS customer (the Railway Next.js rewrite at `helpers/railway/`). The conversation lives at `helpers/railway/talk/talk.md`.
**Triggered by**: Railway's full DB + PostgREST + JWT provisioning (Phases 1–4) completed successfully but took non-obvious workarounds at eleven distinct points (F1–F11). F1–F7 surfaced in Phase 1 (database + DDL). F8–F10 surfaced in Phases 3–4 (PostgREST deploy + JWT auth). F11 surfaced after handover, when the customer had to mint a staff JWT for their admin UI without platform help. The pattern is reproducible — any future customer doing the same task will hit the same friction unless we make the path explicit.

---

## TL;DR

UIS has the right primitives to onboard an app with its own Postgres database + PostgREST API, but **the customer-facing path is implicit**. A novice following the docs cannot complete the flow without escalating to `kubectl exec` into the postgres pod, base64-decoding a K8s secret, and reverse-engineering the multi-instance deployment pattern from another app's YAML.

This investigation surveys the gaps and proposes (a) two new `./uis` commands, (b) a documentation page that doesn't exist yet, and (c) a small DX polish on `./uis configure postgresql` so it surfaces what comes next.

The Railway round is the proof point: every friction below was hit, none of them was a bug, all of them are reproducible.

---

## The flow as actually walked

The Railway customer needed a Postgres database with:

- Custom schemas (`railway`, `auth`) per their data model
- The `citext` extension
- Four PostgreSQL roles for the PostgREST pattern (`railway_owner` / `authenticator` / `anon` / `authenticated`)
- 16 application tables, 5 auth tables, RPCs, RLS policies, grants
- A `railway-postgrest` deployment alongside the existing `atlas-postgrest`
- A long-lived anon JWT and a shared HS256 signing key with their Next.js app

The five-command "novice-friendly" sketch the customer's `db/README.md` implied:

```bash
./uis configure postgresql --app railway --database railway --json   # database
# (apply 01..05.sql — the customer's DDL files)                       # schema
psql ... < seeds.sql                                                  # data
./uis deploy postgrest --app railway                                  # API
# (mint anon JWT, wire into the Next.js app's .env)                   # connectivity
```

What actually happened, in five rounds across the talk file:

1. **`./uis configure postgresql --app railway --database railway --json`** worked perfectly. Returned a JSON with `host.docker.internal:35432` + `localhost:35432` URLs, an auto-generated password, and auto-exposed the service. Great DX. **Friction-free.**
2. **Applying the customer's DDL files failed immediately** — the `railway` user UIS issued has no `CREATEROLE` / `CREATEDB` / superuser, so the first SQL file (which creates the four PostgREST roles) errored out. **Friction.**
3. **Finding the postgres superuser credential** required:
   - knowing that the Bitnami postgres chart stores it in a K8s secret in `default` namespace
   - knowing the secret is named `postgresql`
   - knowing the field is `postgres-password`
   - knowing to base64-decode it
   None of this is documented. **Friction.**
4. **Applying SQL once authenticated as postgres** required `kubectl exec postgresql-0 -n default -- psql ...` because `psql` is not in `uis-provision-host` and is not on macOS by default. **Friction.**
5. **The full `./uis deploy postgrest --app railway`** path is in the `uis` CLI but isn't documented anywhere reachable. The customer learned the multi-instance pattern by reading another app's deployment YAML (`atlas-postgrest`). **Friction.**

End-to-end: ~30 minutes of senior-platform-engineer guidance for a flow that, if streamlined, should take ~10 minutes of a novice's time.

---

## Friction inventory

Each friction below is reproducible from a clean rancher-desktop install + a fresh `./uis pull && ./uis start`. Severity is "how badly does this block a novice", not "how hard to fix".

### F1 — `./uis configure postgresql` issues an app user with no DDL privileges

The user it creates can `SELECT / INSERT / UPDATE / DELETE` in the database it owns, but cannot:

- `CREATE ROLE` (needed for any multi-role pattern — PostgREST, row-level auth, anything beyond one-app-one-user)
- `CREATE EXTENSION` (needed for `citext`, `pg_trgm`, `uuid-ossp`, anything beyond the bare image)
- `CREATE SCHEMA` outside the public schema (needed for any app that organises by schema like `app`, `auth`, `analytics`)

So the moment a customer needs anything more than "one user, public schema, basic types," they have to escalate to the postgres superuser. **There is no documented escalation path.**

**Severity**: high. This affects every customer whose app uses any pattern more advanced than "single ORM dumping tables into public."

### F2 — Postgres superuser credentials are not surfaced anywhere reachable

The Bitnami postgres chart generates a superuser password and stores it in the K8s secret `postgresql.default.postgres-password` (base64-encoded). To find it, a customer has to:

1. Know that "postgres" is the superuser name (true for Bitnami; not universally)
2. Know the secret lives in `default` namespace (UIS convention, not Postgres convention)
3. Know the secret name format (Bitnami-specific)
4. Decode base64 themselves

**None of these are mentioned** in the `./uis configure` output, in the docs site, or in `./uis help`.

**Severity**: high (gates every F1-affected flow).

### F3 — `psql` is not in the `uis-provision-host` container

`./uis shell` drops the user into a container that has `kubectl`, `helm`, `ansible`, `tofu`, `azure-cli`, etc. — but **not** `psql`. Connecting to the database UIS just provisioned therefore needs either:

- `kubectl exec` into the postgres pod (extra hop, awkward for piping files)
- Installing `psql` on the host (not always possible / desired)
- `apt install postgresql-client` inside the container (uncommitted; doesn't survive recycles)

The on-demand-tools pattern (`./uis tools install azure-aks`) doesn't extend to a `./uis tools install postgresql-client`, even though the same affordance would fit cleanly.

**Severity**: medium. Workarounds exist; none are obvious.

### F4 — No `./uis` command for applying a SQL file to a UIS-managed database

The customer wrote five well-organised SQL files (`01-roles.sql` … `05-rls.sql`). Applying them required cobbling together a pipeline:

```bash
cat 01-roles.sql | \
  docker exec -i uis-provision-host \
  kubectl --kubeconfig <path> --context <ctx> \
  exec -i postgresql-0 -n default -- \
  env PGPASSWORD=<from-platform-secret> \
  psql -h localhost -U postgres -d railway -v ON_ERROR_STOP=1
```

That's nine knowledge primitives chained together (Docker exec, in-container kubectl, kubeconfig path, context name, pod name, namespace, env-var password sourced from a platform secret the customer first has to locate and decode, psql flags, error-stop). A `./uis` wrapper that picks up the right cluster context and the right credentials would collapse this to:

```bash
./uis db psql postgresql --app railway --as admin -f 01-roles.sql
```

**Severity**: medium. Solvable with documentation alone; better solved with a command.

### F5 — `./uis deploy postgrest --app <name>` exists but is undocumented

Verified during the round that `./uis list | grep postgrest` shows `postgrest INTEGRATION ❌ Not deployed` even though `atlas-postgrest` is deployed in the `postgrest` namespace. This is the **multi-instance** pattern (one PostgREST per app). The CLI accepts `--app <name>` per `./uis configure 2>&1` but the meaning of "multi-instance" and the resulting naming (`<app>-postgrest`) lives only in the source.

A first-time customer wouldn't know:
- The multi-instance pattern even exists
- The deployment will be named `<app>-postgrest`
- It'll land in the `postgrest` namespace
- The expected ClusterIP DNS name (`<app>-postgrest.postgrest.svc.cluster.local`)

**Severity**: medium. Most customers will be flowing from PostgreSQL to PostgREST, so this is the next docs gap right after F1-F4.

### F6 — Role-password issuance is ad-hoc

`./uis configure postgresql` generates and returns a password for the app user via JSON. Beautiful. But the moment a customer needs additional roles (the PostgREST 4-role pattern, an admin role for migrations, a read-only role for analytics), they're back to `openssl rand -base64 24` and copy-pasting to `ALTER ROLE … WITH PASSWORD`.

There is no:

- UIS secret-store integration for the additional passwords (they don't land in `urbalurba-secrets.yml`)
- Rotation command (rotate the JWT signing key, re-mint anon JWT, restart PostgREST in one shot)
- Path to retrieve a password that was generated earlier (the only copy is whatever the customer captured at issuance time)

In the Railway round, two role passwords were generated, printed once to stdout, and captured to a gitignored `db/.env` file. That works, but it's reinventing a primitive UIS could provide.

**Severity**: low-medium. Doesn't block onboarding; makes the multi-role pattern feel hand-rolled.

### F7 — Docs site has no PostgreSQL service page and no `uis configure` reference

Confirmed via WebFetch against `https://uis.sovereignsky.no`:

- `/docs/services/postgresql` → 404
- The CLI reference (`/docs/reference/uis-cli-reference`) does not mention `./uis configure` at all
- No tutorial under "Developing and Deploying" for "add a database for my app"

The CLI command exists. The pattern exists. The docs don't. **This is the single biggest novice blocker.**

**Severity**: high. Closing the docs gaps alone would address ~60% of the F1–F6 friction even if no new commands were added.

### F8 — `./uis configure postgrest` uses role names that clash with canonical PostgREST docs

`./uis configure postgrest --app railway --schemas railway --url-prefix api-railway` silently created two Postgres roles:

- `railway_authenticator` (LOGIN, NOINHERIT) — wired into `PGRST_DB_URI` in the K8s secret
- `railway_web_anon` (NOLOGIN) — wired as `PGRST_DB_ANON_ROLE` in the deploy env

This naming follows UIS's `<app>_authenticator` / `<app>_web_anon` pattern (visible in the existing `atlas-postgrest` deployment). But the Railway customer's spec (`08-auth.md`, written against the canonical PostgREST docs) calls these roles `authenticator` and `anon`. The customer's 39 RLS policies are `TO anon` — they wouldn't have matched the active session role under UIS's default naming.

Resolution in the field: patched the K8s secret to use the customer's `authenticator` role, set `PGRST_DB_ANON_ROLE=anon` on the deployment, dropped the UIS-created roles. Reversible, but the override gets clobbered if `./uis configure postgrest` is re-run.

**Proposed fix**: add `--authenticator <name>` / `--anon-role <name>` flags to `./uis configure postgrest`. If the customer's DDL has already created `authenticator` and `anon`, they pass those names and UIS wires the secret + deploy env to match instead of creating its own.

**Severity**: high for any customer following canonical PostgREST patterns. The failure mode (200 OK + empty rows because RLS doesn't match) is silent and hard to diagnose.

### F9 — Auto-generated passwords for connection URIs must be URL-safe

When generating a fresh password for the `authenticator` role in the field, the obvious `openssl rand -base64 24` produced `otd1lnW8cjPI+p+/84bpx0LlE0kNZlOw` — containing `+` and `/`, both unreserved-URI-unsafe in the userinfo field. PostgREST refused to start:

```
invalid integer value "otd1lnW8cjPI+p+" for connection option "port"
```

The connection URI parser split on the `+/` and tried to interpret the trailing fragment as a port. Rotated to `openssl rand -hex 24` (`43bd9da2...`) and it parsed cleanly.

UIS already generates passwords for its app users and stores them in K8s secrets whose values get spliced into connection URIs (the postgresql app-user secret, the postgrest `PGRST_DB_URI` secret). If any of those generators use plain `base64`, they're a `+` or `/` away from the same break.

**Proposed fix**: every UIS code path that auto-generates a password destined for a URI should use hex or base64url (`+/` → `-_`) encoding. Add a test that spot-checks generated passwords against URI parsing.

**Severity**: medium. Customer-visible failure with a confusing error message; affects only some generated passwords (probabilistic on the encoding).

### F10 — `./uis deploy postgrest` doesn't bind `PGRST_JWT_SECRET` into the deployment env

`./uis configure postgrest` writes a K8s secret with three keys: `PGRST_DB_URI`, `PGRST_DB_SCHEMAS`, and `PGRST_JWT_SECRET`. The deployment manifest emitted by `./uis deploy postgrest` references the first two via `secretKeyRef` but **does not reference `PGRST_JWT_SECRET`**. PostgREST therefore boots with no signing key.

The failure mode is: unauthenticated requests work fine (PostgREST falls back to `PGRST_DB_ANON_ROLE`), but the first `Authorization: Bearer <jwt>` request returns:

```
HTTP/1.1 500 Internal Server Error
{"code":"PGRST300","details":null,"hint":null,"message":"Server lacks JWT secret"}
```

Fixed in the field by patching the deployment with one env entry:

```yaml
- name: PGRST_JWT_SECRET
  valueFrom: { secretKeyRef: { name: <app>-postgrest, key: PGRST_JWT_SECRET } }
```

**Proposed fix**: add this env binding to UIS's PostgREST deployment template. One line of YAML in the templating layer.

**Severity**: high. Every customer who wants authenticated requests hits this; the error message ("Server lacks JWT secret") is clear but the cause (the secret IS in the K8s secret, just not bound to the env) requires reading the deployment manifest to discover.

### F11 — Customer-onboarding delivers anon JWT but not staff/admin JWT

Phase 4 of the Railway onboarding produced a long-lived **anon** JWT and dropped it in the customer's `.env` as `POSTGREST_ANON_JWT`. That covers public reads. It does **not** cover the admin/staff side of the app.

The Railway customer needed a **staff** Bearer token for their admin UI (`/admin/registrations` etc.) — a JWT with `role: authenticated` and a capability array matching the rows seeded into `auth.capabilities`. UIS didn't provide one. The customer was unblocked because:

- They had `JWT_SECRET` in their `.env` (correctly shared during Phase 4 — apps need it for per-user runtime minting anyway)
- They could read `auth.capabilities` via `psql` to discover the canonical capability names
- They wrote `scripts/mint-staff-jwt.mjs` from scratch to mint the token

…but every step in that list is a platform concern the customer had to reinvent:

| What customer did | What UIS could provide |
|---|---|
| Read `auth.capabilities` to find canonical names | UIS already knows the rows after Phase 2 seeds |
| Choose `role: authenticated` (vs. `web_anon` / others) | UIS configures PostgREST roles; knows the naming |
| Choose `aud: railway` to match anon style | UIS minted the anon JWT with this aud; can mirror |
| Pick an exp lifetime | UIS already has a Phase 4 anon-JWT lifetime policy |
| Hand-roll HS256 minting script | UIS already mints anon JWT (or will, per B.4) |

**Severity**: medium-high. A customer who only wants public reads (read-only marketing site, public form) won't hit this. Any customer with an admin surface — which is most apps — has to redo the minting work UIS already did once for anon.

**Proposed fix**: extend B.4 (`./uis db jwt mint`) to support staff tokens:

```bash
./uis db jwt mint --app railway --role anon            # what we'd already planned
./uis db jwt mint --app railway --role authenticated   # NEW: full capability set from auth.capabilities
./uis db jwt mint --app railway --role authenticated \
    --capabilities registrations:read,content:read     # NEW: subset for limited staff
```

For `--role authenticated` without `--capabilities`, default to **all rows from `<schema>.capabilities`** (or `auth.capabilities` if that's the convention). Customer gets a one-line "give me a full-cap staff token" mint.

Alternative: have `./uis configure postgrest` proactively mint **both** anon and a full-cap staff JWT during Phase 3/4, write both into the customer's `.env`. Cost is zero compared to minting just anon; benefit is the customer never has to think about JWT minting at all unless they want runtime per-user tokens.

---

## Proposed improvements

Three buckets: docs, commands, and DX polish. Roughly in order of cost/benefit (cheapest first).

### Bucket A — Documentation (cheapest, biggest win)

A.1. **Add `/docs/services/postgresql` page** covering:
- What `./uis deploy postgresql` provisions (postgresql-0 pod, postgresql + postgresql-hl services, the postgres superuser credential and where it lives in K8s secrets)
- What `./uis configure postgresql --app <name> --database <name>` does, with the JSON output sample
- The privilege boundary of the app user vs the superuser (resolves F1, F2 in docs alone)
- How to apply DDL files (the `kubectl exec` recipe today; replace with `./uis db psql` after A.2)
- How to expose for host-side `psql` (`./uis expose postgresql` → `localhost:35432`)
- "Multi-app on one Postgres" — multiple databases in one postgresql-0; isolation by DB, not by namespace

A.2. **Add `/docs/services/postgrest` page** covering:
- The multi-instance deployment pattern (`./uis deploy postgrest --app <name>`)
- The naming convention (`<app>-postgrest`)
- The expected secret name + structure (`<app>-postgrest` with `PGRST_DB_URI`, `PGRST_DB_SCHEMAS`)
- The minimum JWT setup (HS256 secret, anon JWT shape, `jwt-aud`)
- A worked example (the Railway round itself could be the source material)

A.3. **Add a `/docs/developing-and-deploying/add-a-database-for-my-app.md` tutorial** that walks the 5-command flow end-to-end:

```bash
./uis configure postgresql --app <myapp> --database <myapp> --json
./uis db psql postgresql --app <myapp> --as admin -f schema.sql   # (after A.2)
./uis db seed postgresql --app <myapp> seeds/                     # (after A.2)
./uis deploy postgrest --app <myapp>
./uis db jwt mint --app <myapp> --role anon --exp 10y > .env.anon
```

Two acceptance criteria for this tutorial: (1) a developer who has never used UIS can run all five commands in 10 minutes; (2) the tutorial doesn't reference `kubectl`, `docker exec`, or `base64 -d` anywhere.

A.4. **Add `./uis configure` to the CLI reference page** under "Service Configuration." The command exists, gets used by every app team, and is currently mentioned nowhere in user-facing docs.

### Bucket B — New `./uis` commands

The minimum viable set to make the tutorial in A.3 land:

B.1. **`./uis db psql <service> --app <name> [--as admin] [-f file.sql]`** — open `psql` (or run a file) against a UIS-managed database, using the credentials UIS already has. The `--as admin` flag elevates to the service's superuser (Bitnami `postgres` for the postgresql chart). Handles F3 (no psql in container), F4 (no SQL-apply command), and the F2 superuser-discovery problem in one stroke.

B.2. **`./uis db seed <service> --app <name> <dir>`** — apply all `*.sql` files in a directory in alphanumeric order with `ON_ERROR_STOP=1`. Wraps B.1; matches the seed-loader pattern in the Railway customer's seed README.

B.3. **`./uis configure postgresql --with-roles <postgrest|read-only|custom-spec.sql>`** — opt-in extension that creates the PostgREST 4-role pattern (or similar named patterns) at configure time, returns all the connection URLs in the JSON, and stores the passwords in a UIS secret so they survive restarts. Addresses F1 head-on without removing the lean-by-default behaviour. **If this lands, it should accept `--authenticator <name>` / `--anon-role <name>` overrides so the customer's existing DDL controls naming** (closes F8).

B.4. **`./uis db jwt mint --app <name> --role <anon|authenticated> [--capabilities <list>] [--exp 10y]`** — mint a JWT signed with the secret UIS already manages for the PostgREST instance. Drops the customer's need to write their own minting script. For `--role authenticated` without `--capabilities`, default to all rows from the app's `<schema>.capabilities` table (or `auth.capabilities` if that's the convention). Closes F11. Even better: have `./uis configure postgrest` mint **both** anon and a full-cap staff JWT by default and write both into the customer's `.env` — zero extra cost, and the customer never has to think about minting unless they want per-user runtime tokens.

B.5. **Fix `./uis deploy postgrest` to wire `PGRST_JWT_SECRET` into the deployment env** (F10). One-line YAML change in the deploy template. Smallest fix in the bucket; should ride along with B.4 since both touch the JWT path.

B.6. **Ensure all auto-generated passwords are URL-safe** (F9). Anywhere UIS generates a password that ends up in a connection URI, use hex or base64url encoding, not plain base64. Smallest fix; could ride along with any password-generating change.

**Order of implementation**: B.1 first (unlocks the docs in A.3), then B.2 (small, ride-along), then B.5 + B.6 (one-line fixes; ship immediately), then B.3 and B.4 (bigger).

### Bucket C — DX polish on existing commands

C.1. **`./uis configure postgresql` output extension** — current JSON returns the app user's connection URL. Extend it (additively; existing callers unaffected) to include:

```json
{
  "status": "ok",
  "service": "postgresql",
  "local":   { … },
  "cluster": { … },
  "database": "railway",
  "username": "railway",
  "password": "fDmyr1oQIZ37tfdcum1qdYApAQGZ4Y",
  "admin": {
    "username": "postgres",
    "retrieve": "./uis secrets get postgres-admin --service postgresql  (proposed; see Bucket B)",
    "url":      "postgresql://postgres:***@localhost:35432/railway"
  },
  "next_steps": [
    "Apply schema:   ./uis db psql postgresql --app railway --as admin -f schema.sql",
    "Deploy API:     ./uis deploy postgrest --app railway",
    "Mint anon JWT:  ./uis db jwt mint --app railway --role anon"
  ]
}
```

Surfacing the admin path in the configure output closes F2 even before commands in Bucket B exist.

C.2. **`./uis tools install postgresql-client`** — add `psql` to the on-demand tools pattern. Solves F3 immediately; no breaking changes.

C.3. **Banner on `./uis deploy postgresql`** to call out the next-step shape: "→ See ./uis configure postgresql --app <name> to provision an app-scoped database." Same shape as the AKS post-up banner.

---

## What I'm NOT proposing

To stay scoped: this investigation only covers the "I need a database for my app" flow. Out of scope:

- Adding Postgres extensions beyond `citext` to the chart default. Customers should be able to install per-DB.
- Rolling our own Postgres operator. Bitnami is fine.
- Backing up / restoring databases. Separate problem, separate investigation.
- Replication, multi-region, HA. Future cloud-platform work, not first-customer onboarding.
- Migrating customers off PostgREST. PostgREST is a deliberate choice; this investigation reinforces it.

---

## Open questions for the maintainer

1. **Is the "one shared postgresql instance, many app-scoped databases" model the intended pattern long-term?** The current `postgresql-0` pod hosts every UIS app's DB. That's fine for local dev; might not scale to multi-tenant. If we're committing to it, the docs should call it out explicitly. If we're moving away, B.1's `--app` resolution has to know.

2. **Is `./uis configure <service>` meant to be the universal "set up app-scoped resource" entry point** for every service that supports it (postgresql, redis, mysql, mongodb)? If yes, the docs page in A.1/A.2 should generalise the pattern. If no, postgresql-specific docs are fine.

3. **Should B.3's role-creation default to PostgREST shape?** The PostgREST 4-role pattern (`railway_owner` / `authenticator` / `anon` / `authenticated`) is well-suited for any HTTP-API-on-Postgres design and not just PostgREST. Hasura, Supabase, even hand-rolled APIs benefit. Making it the default shape with named alternatives (`--with-roles=basic`, `--with-roles=postgrest`, `--with-roles=read-write-admin`) keeps the door open.

4. **JWT minting belongs in UIS or in the app?** B.4 says UIS. The argument for: UIS already holds the signing secret in its secret-store, so UIS minting prevents the secret from ever leaving the cluster. The argument against: app teams may want to mint JWTs from their own code paths (per-user expiry, custom claims). Hybrid: UIS mints the *anon* JWT (one per app instance, rotates on key rotation); apps mint user JWTs themselves with the secret UIS shares.

5. **Where should the customer's DDL artifact live long-term?** The Railway customer's five SQL files sit in `helpers/railway/db/`. That's fine for their app. But if `./uis db seed` is going to find them, there should be a convention (a `db/` folder at the app root with numbered `*.sql` files?). Or do we require apps to point at their DDL explicitly each time?

---

## Suggested next step

If this lands on the queue: pick **Bucket A** (docs first). Three pages + a CLI-reference addition is roughly a day of work and closes the loudest gaps without a single line of new code. The two `INVESTIGATE` files this would supersede (when adopted): nothing yet — this is a fresh angle.

Bucket B's `./uis db psql` is the highest-leverage code change; everything else in B and C can follow.

The Railway customer's `talk/talk.md` is the most concrete artifact to keep alongside the implementation — every friction above has a turn-by-turn reproducer in that file, and the timestamps show how long each workaround took.

---

## Related

- `helpers/railway/talk/talk.md` — the source-of-truth conversation that surfaced this.
- `helpers/railway/db/README.md` — the customer-side spec; describes what UIS should provide.
- `manifests/040-*-postgresql*.yaml` — the existing Bitnami chart wiring.
- `provision-host/uis/manage/uis-cli.sh` — where `cmd_configure_postgresql` lives.
- `INVESTIGATE-active-cluster-visibility-ux.md` (closed via PRs #161-#164) — the closest precedent for "platform-shaped UX gap → multiple-PR implementation."
