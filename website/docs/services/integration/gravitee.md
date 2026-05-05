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
| **Helm chart** | `graviteeio/apim` (4.11.3) |
| **Default namespace** | `gravitee` |

## What It Does

Gravitee API Management is an open-source API gateway and management platform. UIS deploys APIM 4.11 with **PostgreSQL** as the management/config store via the JDBC repository plugin — no MongoDB, no Elasticsearch, no Redis. Four pods run in the `gravitee` namespace: Management API, Management UI (Console), Developer Portal, and the API Gateway. The platform's shared `postgresql` service holds Gravitee's metadata (API definitions, policies, users, audit log); Liquibase auto-applies the schema on first start.

## Architecture

Single shared instance per UIS cluster. Routing via Traefik `IngressRoute` resources with `HostRegexp` patterns so the same routes work across `*.localhost`, `*.<tailnet>.ts.net`, and Cloudflare-tunneled domains:

| URL pattern | Routes to | Purpose |
|---|---|---|
| ``gravitee.<domain>/`` | `gravitee-apim-ui:8002` | Management Console SPA |
| ``gravitee.<domain>/management/`` | `gravitee-apim-api:83` | Management REST API (Console XHR target) |
| ``gravitee.<domain>/portal/`` | `gravitee-apim-api:83` | Portal-facing REST API (Portal SPA XHR target) |
| ``gravitee.<domain>/_portal/`` | `gravitee-apim-portal:8003` | Developer Portal SPA |
| ``gravitee-gw.<domain>`` | `gravitee-apim-gateway:82` | Public API Gateway runtime |

**Why Console, Portal, and both APIs share the `gravitee.<domain>` hostname.** Gravitee uses an HttpOnly session cookie for Console authentication. Cross-origin XHR (Console / Portal calling APIs on different subdomains) needs `SameSite=None; Secure` cookies, which require HTTPS. Plain HTTP for laptop dev forces same-origin: route both APIs under `/management/*` and `/portal/*` paths on the shared hostname, and serve the Portal SPA itself at `/_portal/*` so it inherits the same origin. Cookies travel trivially. The same chart values work without edits across `gravitee.localhost`, Tailscale, and Cloudflare-tunneled domains — `ui.baseURL`, `portal.baseURL`, and `ui.portal.entrypoint` are all relative URLs that resolve against the page's origin at fetch time.

The Management API connects to the cluster's shared `postgresql` service against database `graviteedb` as role `gravitee_user`. The setup playbook creates both during `./uis deploy gravitee`. No inter-component coupling reaches outside the `gravitee` namespace except for the PostgreSQL connection.

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

### Enterprise-only Console features

The Helm chart we deploy is the OSS Gravitee APIM image. The Console SPA still ships UI for several Enterprise-licensed modules, which appear with a lock icon and are non-functional without an EE license:

- **API Products**, **Kafka Clusters**, **Audit**, **Alerts** in the left navigation.
- A `503` on `GET /management/v2/organizations/DEFAULT/ui/customization` (Console branding/customization) — served by an EE component the OSS chart does not deploy. Login, navigation, and API management work normally; only the customization UI is unavailable.

These are expected on an OSS install and are not regressions to investigate.

### Cross-domain redirects use chart-baked URLs (not `X-Forwarded-Host`)

The Management API uses chart-baked installation URLs for outbound `Location:` redirect construction; it ignores `X-Forwarded-Host` from upstream proxies. A request with `X-Forwarded-Host: gravitee.example.com` to `/management/organizations/DEFAULT/environments/DEFAULT/portal/redirect` returns `Location: http://gravitee.localhost/...` — echoes the chart-baked host, ignores the proxy hint. Domain agility for the api pod's redirect path is upstream-bounded; chart `installation.api.url` is the only knob and it requires an absolute URL (relative values crash the api pod's Spring URI constructor at startup).

UIS covers the SPA-served paths (Console XHRs, Portal asset loads) via relative URLs in `ui.baseURL`, `portal.baseURL`, and `ui.portal.entrypoint` — those resolve against the requesting page origin, so a single chart render serves any hostname Traefik routes. The api pod's emitted absolute URLs (login redirects, future password-reset email links, future webhook payloads) still echo `gravitee.localhost`. An upstream patch to `gravitee-io/gravitee-api-management` honouring `X-Forwarded-Host` in the Vert.x filter chain is the only path to closing this for cross-domain installs (Tailscale, Cloudflare tunnel). Practical impact: cross-domain Console navigation and Portal asset loads work correctly; only the absolute-URL emit paths echo the chart-baked host.

### What's been verified — and what hasn't

Install-level integration is heavily verified: Console SPA loads, Portal SPA loads, Management API responds, all four pods (`api`, `gateway`, `ui`, `portal`) reach Ready, IngressRoutes match for `gravitee.localhost` + `HostRegexp(\`gravitee\..+\`)`, drop-database test passes, post-deploy DB seeds for org name and portal entrypoint fire correctly, login + Console navigation + Developer Portal access via same-origin auth cookies all work. The diagnostic trail in `talk.md` Rounds 1–10 covers ten back-to-back tester rounds across these surfaces.

**Gateway-use is not part of the install verification suite.** The deployment has only been verified as "installed correctly" — not as "functional as an API gateway":

- No API has been created through the Console wizard or the Management API as part of integration tests.
- No traffic has flowed through `gravitee-gw.localhost` to a real backend during automated verification. The Verify-section smoke check returns `404 No context-path matches the request URI` — that confirms the gateway is up and responding, *not* that the route + policy + backend pipeline is functional.
- Built-in policies (transform-headers, JWT, mock, key-auth, …) — those that don't require Elasticsearch or Redis — haven't been applied or exercised.
- Developer Portal API publication / subscription flow hasn't been used.

The [End-to-end smoke test](#end-to-end-smoke-test-deploy-a-hello-world-api) under Verify is the recommended first exercise after a fresh deploy. It walks through creating a single proxy API in the Console and calling it through the gateway. If anything in that flow breaks, the symptom is most likely a Console wizard error or a non-404 failure when calling through `gravitee-gw.localhost`; common shapes are listed in [Troubleshooting](#troubleshooting).

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
# Pods (expect 6: api, gateway, portal, ui×3)
kubectl get pods -n gravitee
kubectl get ingressroute -n gravitee

# Smoke checks (run from host)
curl -fsS http://gravitee.localhost/                            # Console SPA  -> 200
curl -fsS http://gravitee.localhost/_portal/                    # Portal SPA   -> 200
curl -fsS -u admin:LocalDev@123 \
    http://gravitee.localhost/management/organizations/DEFAULT  # Mgmt API     -> 200
curl -sS -o /dev/null -w "%{http_code}\n" http://gravitee-gw.localhost/
                                                                # Gateway      -> 404 by design
                                                                # (no APIs deployed yet; 404 with body
                                                                # "No context-path matches the request URI"
                                                                # is the gateway responding correctly)
```

Get the admin credentials in one line:

```bash
EMAIL=$(kubectl get secret urbalurba-secrets -n gravitee -o jsonpath='{.data.GRAVITEE_ADMIN_EMAIL}' | base64 -d)
PASSWORD=$(kubectl get secret urbalurba-secrets -n gravitee -o jsonpath='{.data.GRAVITEE_ADMIN_PASSWORD}' | base64 -d)
echo "Console: http://gravitee.localhost/   login: admin (or $EMAIL) / $PASSWORD"
```

The smoke checks above only confirm Gravitee is *installed* — they don't prove it works as an API gateway. To validate that, run the end-to-end smoke test below.

### End-to-end smoke test: deploy a hello-world API

Five-minute walkthrough that proves the Console → API definition → Gateway → backend pipeline is functional on this cluster. Run once after a fresh deploy.

1. **Log in** at `http://gravitee.localhost/` with the credentials from the snippet above. The Console lands on the APIs list (empty on a fresh install).

2. **Create a Proxy API.** Click **+ Add API** → choose the **Create from scratch** flow (or the v2 wizard, whichever the version offers). Set:

   | Field | Value |
   |---|---|
   | Name | `hello` |
   | Version | `1` |
   | Description | (anything) |
   | Context path | `/hello` |
   | Endpoint / Target URL | `https://httpbin.org/get` |

   Save. The API lands in `STARTED` status under the APIs list.

3. **Deploy and publish.** Open the new API → **Deploy API** (puts the definition on the gateway pod) → **Publish API** (makes it visible in the Developer Portal — optional for the smoke test, but useful to verify the Portal works too).

4. **Call through the gateway** (no auth — proxy APIs default to keyless until you attach a plan/policy):

   ```bash
   curl -fsS http://gravitee-gw.localhost/hello | jq '{url, headers}'
   ```

   Expected: a JSON response from httpbin showing the request URL and headers. The `headers` object should include `X-Gravitee-Request-Id` and `X-Gravitee-Transaction-Id` — Gravitee's tracing headers, proof the request actually traversed the gateway and didn't bypass it.

5. **Confirm in gateway logs:**

   ```bash
   kubectl logs -n gravitee deployment/gravitee-apim-gateway --tail=20 | grep -i hello
   ```

   Should show the request being proxied (DEBUG-level logs are off by default; INFO shows context-path resolution). If the gateway log is silent and step 4 returned data, the request hit a different path — re-check the context path matches `/hello`.

6. **Cleanup** (optional, before next purge): from the Console, **Stop API** then **Delete API**. The definition is removed from the gateway and the API list.

If step 4 returns `404 No context-path matches the request URI`, the API definition didn't reach the gateway — most often because the API was created but not deployed (step 3). If it returns `502` or `504`, the gateway reached the backend but timed out — try a backend on the same cluster (e.g. `http://nginx-root-catch-all.default.svc.cluster.local`) to rule out outbound DNS / egress problems.

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

| Key | Source | Purpose | Wired? |
|---|---|---|---|
| `GRAVITEE_POSTGRES_USER` | first-class env var | Postgres role for the management connection | ✅ |
| `GRAVITEE_POSTGRES_PASSWORD` | first-class env var | Postgres role password (env-injected on api + gateway as `GRAVITEE_MANAGEMENT_JDBC_PASSWORD`) | ✅ |
| `GRAVITEE_POSTGRES_DATABASE` | first-class env var | Database name (default `graviteedb`) | ✅ |
| `GRAVITEE_POSTGRES_HOST` | derived | Cluster-internal Postgres service hostname | ✅ |
| `GRAVITEE_POSTGRES_PORT` | derived | `5432` | ✅ |
| `GRAVITEE_POSTGRES_JDBC_URL` | derived | Pre-assembled JDBC URL passed to `management.jdbc.url` | ✅ |
| `GRAVITEE_ADMIN_EMAIL` | derived from `DEFAULT_ADMIN_EMAIL` | Console admin email (passed to chart as `adminEmail`) | ✅ |
| `GRAVITEE_ADMIN_PASSWORD` | derived from `DEFAULT_ADMIN_PASSWORD` | Console admin password (bcrypted at deploy time, passed to chart as `adminPasswordBcrypt`) | ✅ |
| `GRAVITEE_ADMIN_PASSWORD_BCRYPT` | computed by setup playbook | Cached bcrypt hash; reused on subsequent deploys to keep `helm upgrade` idempotent. Not user-editable — wiped by `./uis secrets apply`, recomputed on next deploy. | (auto) |
| `GRAVITEE_ENCRYPTION_KEY` | derived | Encrypts sensitive data at rest (env-injected on api + gateway as `GRAVITEE_API_PROPERTIES_ENCRYPTION_SECRET`) | ✅ |

After editing the source common-values, run `./uis secrets generate` and `./uis secrets apply`. New variables added to the source template are **not** propagated to existing `.uis.secrets/` directories — append them manually or `rm -rf .uis.secrets` to re-init.

### Helm chart pin

`SCRIPT_IMAGE` in `service-gravitee.sh` and the chart version reference in `090-setup-gravitee.yml` are pinned to the same APIM patch (currently `4.11.3`). Bumps are deliberate — chart breakages are usually visible as Liquibase migration errors on first start of the Management API pod.

### SPA URL configuration

The Console and Developer Portal SPAs read their API URL from `/constants.json` (Console) and `/assets/config.json` (Portal). UIS overrides `ui.baseURL`, `portal.baseURL`, and `ui.portal.entrypoint` in `manifests/090-gravitee-config.yaml`. All three are **relative URLs** (`/management`, `/portal`, `/_portal/`) so the SPAs resolve them against the current page origin at fetch time — a single chart render serves any hostname Traefik routes (localhost, Tailscale, Cloudflare-tunneled) without per-domain configuration. The Portal SPA's `PORTAL_BASE_HREF` env var is set to `/_portal/` so its assets and route paths align with the sub-path it's served from. See the [Architecture](#architecture) section for the same-origin/auth-cookie rationale.

### Deploy-time DB seed values

The setup playbook writes two values to PostgreSQL after the api pod reaches Ready (Liquibase migrations have completed by then). Both operations are idempotent — re-running `./uis deploy gravitee` always converges to the configured value:

| Value | DB target | Lever | Configured by |
|---|---|---|---|
| Organisation name | `organizations.name` (single row, `id=DEFAULT`) | `UPDATE organizations SET name=…` | `DEFAULT_ORGANIZATION_NAME` (default `UIS Local Dev`) |
| Portal entrypoint | `parameters` row (`key='portal.entrypoint'`, `reference_type='ENVIRONMENT'`) | `INSERT … ON CONFLICT DO UPDATE` | hardcoded `/_portal/` in `_gravitee_portal_entrypoint` (bound to ingress topology) |

The portal entrypoint exists because the Gravitee api pod's Java model (`gravitee-apim-rest-api-model-*.jar`) returns a hardcoded `https://api.company.com` fallback when no DB row defines the `portal.entrypoint` settings key — visible in the Console settings UI and in the Management API's `/management/.../environments/DEFAULT/settings.portal.entrypoint` response. The deploy-time INSERT overrides the fallback. The chart's `templates/api/api-deployment.yaml` also emits a literal-dot `portal.entrypoint` env var on the api Deployment, but POSIX env-var name rules cause containerd to silently filter it from `execve()` envp — the JVM never sees it. See the comment block in `manifests/090-gravitee-config.yaml` (api section) for context.

See `ansible/playbooks/090-setup-gravitee.yml` tasks 27 + 28 for the SQL.

## Undeploy

```bash
# Default: leaves persistent state intact
./uis undeploy gravitee

# Full teardown
./uis undeploy gravitee --purge          # prompts for confirmation
./uis undeploy gravitee --purge --yes    # automation override
```

Default mode removes the Helm release and the four IngressRoute objects. PostgreSQL state (`graviteedb`, `gravitee_user`) and the namespace secret are preserved; re-deploy works without re-bootstrap.

`--purge` additionally drops the database, role, secret, all PVCs in the namespace, and the namespace itself. The next `./uis deploy gravitee` after a purge re-bootstraps from scratch — Liquibase recreates the schema. The confirmation prompt requires an interactive TTY; in scripted contexts pass `--yes` to skip it (or the command bails before destroying anything).

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

Expected — see [What we lose by skipping Elasticsearch and Redis](#what-we-lose-by-skipping-elasticsearch-and-redis). With `ratelimit.type: none`, the gateway loads `Repository [RATE_LIMIT] loaded by none` at startup; the management API and Console UI accept rate-limit policies without complaint, but the gateway does not enforce them at runtime. **There is no UI warning** that the policy is inert — operators have to know. Add Redis and switch `ratelimit.type: redis` if rate-limiting is required.

### Analytics tab in Console is empty

Same root cause — no Elasticsearch. Gateway request logs are accessible via `kubectl logs deployment/gravitee-apim-gateway -n gravitee`.

### Admin login fails with the secret-stored credentials

The setup playbook bcrypts `GRAVITEE_ADMIN_PASSWORD` and passes it to the chart as `adminPasswordBcrypt`, with `adminEmail` from the secret. If login fails, verify the rendered chart values:

```bash
helm get values gravitee-apim -n gravitee | grep -E 'admin(Email|Password)'
```

Expected: `adminEmail` and `adminPasswordBcrypt: $2a$10$...`. The Console accepts either `admin` or the email address as the username field — both authenticate to the same in-memory account.

If `adminPasswordBcrypt` is missing or still the chart-default `$2a$10$Ihk05VSds5rUSgMdsMVi9OKMIx2yUvMz7y9VP3rJmQeizZLrhLMyq`, the playbook's bcrypt step (`090-setup-gravitee.yml` task 20d) didn't run or didn't populate the helm flag. Re-deploy with `./uis deploy gravitee`.

### Pods log "You still use the default secret" for the encryption key

If you see this warning, the api/gateway pod isn't picking up `GRAVITEE_API_PROPERTIES_ENCRYPTION_SECRET`. Verify with:

```bash
kubectl get pod -n gravitee -l app.kubernetes.io/component=api \
    -o jsonpath='{.items[0].spec.containers[0].env[*].name}{"\n"}'
```

The list should include `GRAVITEE_API_PROPERTIES_ENCRYPTION_SECRET` and `GRAVITEE_MANAGEMENT_JDBC_PASSWORD`. If missing, the `env:` block under `api:` and `gateway:` in `manifests/090-gravitee-config.yaml` got renamed back to the chart-ignored `extraEnvs:` — the chart honors `env:` (or `deployment.extraEnvs:`) but silently drops bare `extraEnvs:`.

### Console SPA loads but no data appears (page stays empty / 404 on XHR)

The Console at `http://gravitee.localhost/` fetches `/constants.json` to learn the management API URL. If `constants.json` baseURL points at `apim.example.com` (the chart's placeholder), every XHR fails. Verify with:

```bash
curl -fsS http://gravitee.localhost/constants.json | head
```

Expected `baseURL: "http://gravitee.localhost/management"`. If you see `apim.example.com`, `manifests/090-gravitee-config.yaml` is missing the `ui.baseURL` and `portal.baseURL` overrides; re-deploy after restoring them.

## Learn More

- [Official Gravitee documentation](https://documentation.gravitee.io/)
- [Gravitee JDBC repository (PostgreSQL configuration)](https://documentation.gravitee.io/apim/installation-and-upgrades/repositories/jdbc)
