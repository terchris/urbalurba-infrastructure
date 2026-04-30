---
title: Gravitee
sidebar_label: Gravitee
---

# Gravitee

API management and gateway platform — Gravitee APIM 4.11 on PostgreSQL.

| | |
|---|---|
| **Category** | Integration |
| **Deploy** | `./uis deploy gravitee` |
| **Undeploy** | `./uis undeploy gravitee` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Helm chart** | `graviteeio/apim:4.11.x` |
| **Default namespace** | `gravitee` |

:::warning Implementation in Progress
This page describes the **target architecture** per [INVESTIGATE-gravitee-fix.md](../../ai-developer/plans/backlog/INVESTIGATE-gravitee-fix.md). The deployment is being rewritten end-to-end — `./uis deploy gravitee` may not yet match this shape. The previous Gravitee setup (MongoDB-backed, namespace `default`) is being replaced. Treat this page as authoritative for the *new* deployment once the implementation plan lands.
:::

## What It Does

Gravitee API Management is an open-source API gateway and management platform. UIS deploys APIM 4.11 with **PostgreSQL** as the management/config store via the JDBC repository plugin — no MongoDB, no Elasticsearch, no Redis. Four pods run in the `gravitee` namespace: Management API, Management UI (Console), Developer Portal, and the API Gateway. The platform's shared `postgresql` service holds Gravitee's metadata (API definitions, policies, users, audit log); Liquibase auto-applies the schema on first start.

## Architecture

Single shared instance per UIS cluster. Routing via Traefik `IngressRoute` resources with `HostRegexp` patterns so the same routes work across `*.localhost`, `*.<tailnet>.ts.net`, and Cloudflare-tunneled domains:

| Component | Hostname pattern | Purpose |
|---|---|---|
| Management Console | ``HostRegexp(`gravitee\..+`)`` | Admin UI for API designers |
| Management API | ``HostRegexp(`gravitee-api\..+`)`` | Backend REST API for Console + Portal |
| API Gateway | ``HostRegexp(`gravitee-gw\..+`)`` | Runtime API proxy endpoint |
| Developer Portal | ``HostRegexp(`gravitee-portal\..+`)`` | Public/internal API catalog |

The Management API connects to the cluster's shared `postgresql` service against database `graviteedb` as role `gravitee_user`. The setup playbook creates both during `./uis deploy gravitee`. The Console UI and Developer Portal SPA both call the Management API over HTTP using the cluster-internal service name; no inter-component coupling reaches outside the `gravitee` namespace except for the PostgreSQL connection.

## Limitations and gotchas

### What we lose by skipping Elasticsearch and Redis

UIS deploys Gravitee without Elasticsearch and Redis to keep the laptop-scale resource footprint down. Each is independently optional in APIM 4.x; the trade-offs are listed here so a future contributor knows exactly what to switch on if any of these gaps become real requirements.

- **Empty analytics view in the Console.** Without Elasticsearch, the Console's analytics tab has no per-API request counts, latency graphs, or status-code distributions. APIs still serve traffic — Gravitee just doesn't aggregate it. Gateway request logs are visible via `kubectl logs deployment/gravitee-apim-gateway -n gravitee` for ad-hoc debugging.
- **No rate-limiting or quota policies.** The chart is configured with `ratelimit.type: none`. Applying a rate-limit policy in the Console may succeed at design time but will not enforce limits at runtime. Gravitee's recommended rate-limit store is Redis; the JDBC/PostgreSQL alternative has [known concurrency bugs](https://github.com/gravitee-io/issues/issues/6563) (closed wontfix) and is discouraged.
- **No response caching policy.** Same shape as rate-limiting — depends on Redis.
- **No log search in the Console.** The Console's log-search feature depends on Elasticsearch. Gateway request logs are stdout-only.

All four are first-class production features; none are required to validate "Gravitee is deployed and the gateway proxies traffic." For a single-developer or local-dev cluster, the omissions are usually acceptable. Add Elasticsearch and/or Redis later if a real need surfaces; both are independent toggles in `manifests/090-gravitee-config.yaml`.

### PostgreSQL is the management store, not the rate-limit store

The two roles are separate. Using PostgreSQL for management/config is solid (JDBC repository plugin is first-class in APIM 4.x, Liquibase migrations are auto-applied). Using PostgreSQL as the rate-limit backend is the [bug](https://github.com/gravitee-io/issues/issues/6563) referenced above. If rate-limiting is enabled in the future, plan for Redis — don't route rate-limit policies through PostgreSQL.

### Resource footprint

Default chart values are sized for production. UIS overrides per-component `resources.requests` and `resources.limits` in `manifests/090-gravitee-config.yaml` to a laptop-tuned baseline (~1.2 CPU / 2.5 GiB combined across the four pods). Adjust there if the local cluster has more or less headroom.

## Deploy

```bash
# Required dependency:
./uis deploy postgresql

# Then:
./uis deploy gravitee
```

The setup playbook creates the `gravitee` namespace, ensures the `gravitee/urbalurba-secrets` Secret has the required keys, bootstraps `graviteedb` + `gravitee_user` against the platform's `postgresql` service, installs the `graviteeio/apim` Helm chart, applies the IngressRoute resources, and waits for all four Deployments to reach Available.

## Verify

```bash
# Pods
kubectl get pods -n gravitee
kubectl get ingressroute -n gravitee

# Smoke checks (run from host)
curl -fsS http://gravitee.localhost/                          # Console SPA
curl -fsS http://gravitee-api.localhost/management/health     # Management API health
curl -fsS http://gravitee-gw.localhost/_node/health           # Gateway health
curl -fsS http://gravitee-portal.localhost/                   # Portal SPA
```

The Console default admin login is `${GRAVITEE_ADMIN_EMAIL}` / `${GRAVITEE_ADMIN_PASSWORD}` (sourced from the namespace secret).

## Configuration

### Key files

| File | Purpose |
|------|---------|
| `provision-host/uis/services/integration/service-gravitee.sh` | Service metadata (UIS conventions) |
| `ansible/playbooks/090-setup-gravitee.yml` | Deployment playbook |
| `ansible/playbooks/090-remove-gravitee.yml` | Removal playbook |
| `manifests/090-gravitee-config.yaml` | Helm values overrides (chart pin, JDBC backend, ingress disabled, resource limits) |
| `manifests/091-gravitee-ingress.yaml` | Traefik IngressRoutes |
| `provision-host/uis/templates/secrets-templates/00-common-values.env.template` | First-class `GRAVITEE_POSTGRES_*` variables |

### Secrets

Gravitee reads its PostgreSQL connection and admin credentials from `gravitee/urbalurba-secrets`. Relevant keys:

| Key | Source | Purpose |
|---|---|---|
| `GRAVITEE_POSTGRES_USER` | first-class env var | Postgres role for the management connection |
| `GRAVITEE_POSTGRES_PASSWORD` | first-class env var | Postgres role password |
| `GRAVITEE_POSTGRES_DATABASE` | first-class env var | Database name (default `graviteedb`) |
| `GRAVITEE_POSTGRES_HOST` | derived | Cluster-internal Postgres service hostname |
| `GRAVITEE_POSTGRES_PORT` | derived | `5432` |
| `GRAVITEE_POSTGRES_JDBC_URL` | derived | Pre-assembled JDBC URL passed to `management.jdbc.url` |
| `GRAVITEE_ADMIN_EMAIL` | derived from `DEFAULT_ADMIN_EMAIL` | Console default admin login |
| `GRAVITEE_ADMIN_PASSWORD` | derived from `DEFAULT_ADMIN_PASSWORD` | Console default admin password |
| `GRAVITEE_ENCRYPTION_KEY` | derived | Encrypts sensitive data at rest in the management DB |

After editing `00-common-values.env.template`, run `./uis secrets generate` and `./uis secrets apply`.

### Helm chart pin

`SCRIPT_IMAGE` in `service-gravitee.sh` and the chart version in `090-setup-gravitee.yml` reference the same APIM patch (currently 4.11.x). Bumps are deliberate — see the [investigation](../../ai-developer/plans/backlog/INVESTIGATE-gravitee-fix.md) for the chart pin policy.

## Undeploy

```bash
./uis undeploy gravitee
```

Removes the Helm release and the four IngressRoute objects. PostgreSQL state (`graviteedb`, `gravitee_user`) and the namespace secret are preserved by default; re-deploy works without re-bootstrap.

For a full teardown that drops the database, role, secret, and namespace, the remove playbook accepts an explicit `--purge` extra var.

## Troubleshooting

### Pods stuck in `Init` or `CrashLoopBackOff` after deploy

Check the Management API logs first — most issues surface there:

```bash
kubectl logs -n gravitee deployment/gravitee-apim-api --tail=200
```

Common causes:

- **PostgreSQL not reachable** — Management API logs will show JDBC connection refused. Verify `./uis deploy postgresql` is running and the JDBC URL in the secret resolves.
- **Liquibase migrations failing** — visible in Management API startup logs. Usually a stale `graviteedb` from a prior schema. Drop and redeploy: `./uis undeploy gravitee --purge && ./uis deploy gravitee`.
- **Encryption key changed after first deploy** — anything previously encrypted in the management DB becomes unreadable. The Management API may start but the Console will fail to load existing API definitions. Either restore the original `GRAVITEE_ENCRYPTION_KEY` or purge and redeploy.

### Applied a rate-limit policy and it doesn't enforce

This is expected — see [What we lose by skipping Elasticsearch and Redis](#what-we-lose-by-skipping-elasticsearch-and-redis). Rate-limit policies require a configured rate-limit store; UIS sets `ratelimit.type: none` to avoid the Redis dependency. Add Redis and switch `ratelimit.type` if rate-limiting is needed.

### Analytics tab in Console is empty

Same root cause — no Elasticsearch deployed. Gateway request logs are accessible via `kubectl logs`.

## Learn More

- [Official Gravitee documentation](https://documentation.gravitee.io/)
- [Gravitee JDBC repository (PostgreSQL configuration)](https://documentation.gravitee.io/apim/installation-and-upgrades/repositories/jdbc)
- [INVESTIGATE-gravitee-fix.md](../../ai-developer/plans/backlog/INVESTIGATE-gravitee-fix.md) — current architecture and implementation plan
