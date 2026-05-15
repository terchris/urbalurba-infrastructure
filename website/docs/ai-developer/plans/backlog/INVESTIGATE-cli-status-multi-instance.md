# INVESTIGATE: `./uis status` doesn't show multi-instance services

**Status:** Investigation needed
**Created:** 2026-05-14
**Surfaced by:** talk53 F5 (Tailscale CLI port verification) — tester noticed `railway-postgrest` deployment running healthily but absent from `./uis status` output.
**Related to:** [INVESTIGATE-docs-customer-onboarding-database](https://github.com/helpers-no/urbalurba-infrastructure/blob/main/INVESTIGATE-docs-customer-onboarding-database.md) (the Railway customer onboarding flow that motivated multi-instance PostgREST in the first place), PLAN-002 / customer-onboarding work expanding the `--app <name>` pattern to more services.

---

## Problem Statement

`./uis status` shows only single-instance services. Services deployed via the `--app <name>` pattern (e.g. `./uis deploy postgrest --app railway`) register their resources in a service-specific namespace (`postgrest/railway-postgrest`) instead of as autostart-tagged single-instance services. The status loop doesn't iterate this case, so multi-instance deployments are **invisible** in the official "what's healthy" surface.

## Symptom — talk53 evidence

```
$ ./uis status
ID                NAME              CATEGORY     HEALTH
nginx             Nginx             MANAGEMENT   ✅ Healthy
whoami            Whoami            MANAGEMENT   ✅ Healthy
postgresql        PostgreSQL        DATABASES    ✅ Healthy
tailscale-tunnel  Tailscale Tunnel  NETWORKING   ✅ Healthy
traefik           Traefik           NETWORKING   ✅ Healthy
```

No `postgrest` row. But the deployments are healthy:

```
$ kubectl -n postgrest get pods
NAME                                 READY   STATUS    RESTARTS   AGE
atlas-postgrest-b945447b5-shr5c      1/1     Running   0          8d
atlas-postgrest-b945447b5-wt6dp      1/1     Running   0          8d
railway-postgrest-7dc674c4f9-jk66h   1/1     Running   0          47h
railway-postgrest-7dc674c4f9-kn57x   1/1     Running   0          47h

$ kubectl get ingressroutes -A | grep postgrest
postgrest   atlas-postgrest        8d
postgrest   railway-postgrest      47h

$ curl -o /dev/null -w "%{http_code}\n" http://api-railway.localhost/
200
```

Two PostgREST instances serving traffic, both healthy, neither visible.

## Root cause hypothesis

`cmd_status` (in `provision-host/uis/manage/uis-cli.sh:262`) iterates the registered service IDs from `services.json` and runs each service's `SCRIPT_CHECK_COMMAND`. Multi-instance deployments don't have a per-instance entry in `services.json` — the parent service (`postgrest`) does, but it checks for the default `postgrest` deployment (which may or may not exist). The `<app>-postgrest` deployments in the `postgrest` namespace aren't iterated.

Confirming this requires reading `cmd_status` + the postgrest service's `SCRIPT_CHECK_COMMAND`. The investigation phase of any future PLAN should start there.

## Why it matters

For solo development the gap is cosmetic — the user knows what they deployed and can `kubectl` directly.

For **customer onboarding** (per the `INVESTIGATE-docs-customer-onboarding-database.md` flow with the Railway customer) the gap is misleading. The new user is told `./uis status` is the official "is my stack healthy" signal. If their `--app <name>`-scoped PostgREST doesn't appear there, they'll assume it failed and start debugging the wrong thing. Same false-negative flavor as talk52 F4's "Tailscale deploy reported FAILED but actually worked" — UI says broken, reality says fine.

The `--app <name>` pattern is also the direction PLAN-002 / customer-onboarding work is expanding (likely to `redis --app foo`, future per-customer postgresql namespaces, etc.). Pattern will get worse as more services adopt it.

## Fix candidates

### 1. Extend `./uis status` to iterate multi-instance services

For each multi-instance service type (`postgrest` today; future `redis`, etc.), enumerate `<app>-<service>` deployments in the service's namespace and print each as its own row:

```
postgrest         PostgREST (atlas)    DATA-API     ✅ Healthy
postgrest         PostgREST (railway)  DATA-API     ✅ Healthy
```

- **Pro**: matches user mental model ("what's running?" → "I want to see every running thing")
- **Pro**: aligns with what `./uis list` already does for service types
- **Con**: requires service metadata to flag "this service supports `--app`" so the iteration knows where to look
- **Verdict**: tester's recommended option; matches the false-negative-prevention principle

### 2. Add `./uis status --apps` opt-in flag

Default output unchanged; opt-in flag shows multi-instance variants.

- **Pro**: zero behavior change for existing users / scripts
- **Con**: novices won't discover the flag, so the discoverability gap stays the default
- **Verdict**: too conservative — defeats the point

### 3. Single-line summary at the bottom

Under the per-service table, add a "Multi-instance:" line listing instance counts:

```
Multi-instance services:
  postgrest (2 instances): atlas, railway
```

- **Pro**: smallest visual change; cheap to implement
- **Con**: the instances don't get health-state info, so it's not actually "status"
- **Verdict**: half-measure

## Open questions for a PLAN

1. **Where does multi-instance metadata live?** `services.json` doesn't currently flag multi-instance services. Add a `"multiInstance": true` field per service that supports `--app`, plus a query path so `cmd_status` can iterate the deployments? Or convention-based detection (presence of a `<service>` namespace with multiple deployments matching `<app>-<service>` pattern)?
2. **Health-check command per instance.** The parent service's `SCRIPT_CHECK_COMMAND` likely doesn't generalize across `<app>` instances. Does each `<app>` instance get its own check, or is there a template?
3. **`./uis list` parity.** Does `./uis list` have the same gap? If yes, fix both together.
4. **Naming in output.** `<service> (<app>)` vs `<app>-<service>` vs `<app>/<service>` — what's the clearest format for the status table?
5. **Cross-namespace pattern.** PostgREST deployments live in `postgrest` namespace today. If future services use different namespace patterns (e.g. `<app>` namespace), the iteration logic needs to know where each lives.

## Outcomes — what this investigation should decide

- [ ] Confirm the root cause by reading `cmd_status` + the postgrest service's metadata
- [ ] Decide on metadata vs. convention for multi-instance detection
- [ ] Pick a fix candidate (1 / 2 / 3 / hybrid)
- [ ] Verify whether `./uis list` has the same gap and bundle the fix if so
- [ ] Decide naming convention for the status row

## Implementation Contracts (for a future PLAN)

- **C-1: Multi-instance metadata.** How a service-type declares "supports `--app`" + where the runtime queries for instances.
- **C-2: Per-instance health check.** What command each instance runs to report healthy/unhealthy.
- **C-3: Status output format.** Exact column layout when multi-instance rows appear alongside single-instance rows.
- **C-4: `./uis list` parity.** Whether `list` gets the same treatment or stays single-instance-only.
- **C-5: Backwards compatibility.** Existing scripts that parse `./uis status` output — does the new format break them? Mitigation?
