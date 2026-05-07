# Investigate: Surface in-cluster service port on `services.json`

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Add the primary in-cluster Kubernetes Service port to each service entry in `website/src/data/services.json` so that downstream consumers (documentation generators, template tooling, dashboards) can render accurate `<service>.<namespace>.svc.cluster.local:<port>` references without hardcoding per-service ports or guessing from conventions.

**Last Updated**: 2026-04-13

**Requested by**: TMP (`helpers-no/dev-templates`) — see [their mirror investigation](https://github.com/helpers-no/dev-templates/blob/main/website/docs/ai-developer/plans/backlog/INVESTIGATE-uis-in-cluster-port.md) for the consumer-side context.

---

## Background

UIS's `services.json` is consumed by multiple downstream projects to build template documentation, dashboards, and developer tooling. The TMP project (dev-templates) recently ran into a gap: it needs the in-cluster service port (e.g. `5432` for PostgreSQL, `6379` for Redis) to render:

1. **Architecture diagrams** that show a deployed pod connecting to a service: `pod -->|postgresql.default.svc.cluster.local:5432| svc`. Today the port is hardcoded `5432` in the TMP builder because PostgreSQL is the only supported service. The moment a second service is added, the hardcode becomes a bug.

2. **Expected-output samples** rendered on template detail pages — a mock of what `dev-template configure` prints when a developer runs it, including a port-forward ASCII diagram that references the in-cluster port explicitly.

3. **Dashboards and tooling** (future): any consumer that needs to construct or display in-cluster connection strings.

UIS knows these port numbers (they're embedded in each service's Helm chart defaults or its Ansible playbook). They just aren't surfaced on the public `services.json` entry.

---

## Current state

### What `services.json` already exposes per service

Verified 2026-04-13 on `website/src/data/services.json`:

| Field | Purpose |
|---|---|
| `id` | Service identifier (e.g., `postgresql`) |
| `name` | Display name (e.g., `PostgreSQL`) |
| `description` / `abstract` / `summary` | Text fields for UI |
| `category`, `tags`, `priority` | Classification |
| `docs`, `website` | External links |
| `logo` | Icon path |
| `helmChart` | Helm chart name (e.g., `bitnami/postgresql`) |
| `namespace` | Default K8s namespace |
| **`exposePort`** | Host-facing port after `kubectl port-forward` (e.g., `35432`) |
| `configurable`, `checkCommand`, `playbook`, `removePlaybook` | Operational metadata |

**Missing**: the in-cluster Kubernetes Service port — what a pod inside the cluster would dial at `<service>.<namespace>.svc.cluster.local:<port>`.

### Concrete gap for TMP consumers

| Service | `exposePort` (exposed) | In-cluster port (not in services.json) |
|---|---|---|
| postgresql | 35432 | 5432 |
| redis | 36379 | 6379 |
| mongodb | 37017 | 27017 |
| mysql | 33306 | 3306 |
| mariadb | 33306 | 3306 |
| elasticsearch | 39200 | 9200 |
| rabbitmq | 35672 | 5672 |

There appears to be a **30000-offset convention** (`exposePort = inClusterPort + 30000`) but it's undocumented and consumers cannot safely rely on it — a service that doesn't follow the pattern would break silently.

---

## Why not derive it from existing data?

- **Not on the service entry**: as shown above
- **`exposePort - 30000`**: works today for all listed services, but the convention is unwritten and not guaranteed. A single exception (a service using a different offset or a fixed pass-through port) breaks every consumer
- **Parsing the Helm chart**: consumers can't realistically introspect Helm values at registry-generation time. That's UIS's job.
- **Parsing playbook files**: brittle, slow, and repeats work UIS already does internally.

The right place for the port is on the service entry itself. UIS owns the chart/playbook for each service, so UIS is the authoritative source.

---

## Options

### Option 1: Add a single `inClusterPort: number` field

```json
{
  "id": "postgresql",
  "name": "PostgreSQL",
  "exposePort": 35432,
  "inClusterPort": 5432,
  "namespace": "default",
  ...
}
```

**Pros:**
- Simplest possible change
- Matches the existing `exposePort` field in style (both are port numbers with clear semantics)
- Backward compatible — consumers that don't read the field are unaffected
- Easy to validate in UIS's CI (assert that it matches the service's helm values / K8s Service definition)

**Cons:**
- Doesn't handle services with multiple ports (postgres is single-port; rabbitmq has 5672 amqp + 15672 management + 25672 clustering)
- For multi-port services, "the primary port" is a value judgment

### Option 2: Add a structured `ports: { [name]: number }` map

```json
{
  "id": "postgresql",
  "ports": {
    "postgres": 5432
  }
}
{
  "id": "rabbitmq",
  "ports": {
    "amqp": 5672,
    "management": 15672,
    "clustering": 25672
  }
}
```

**Pros:**
- Handles multi-port services cleanly
- Matches the Kubernetes `Service.spec.ports[].name` convention
- Extensible — can add protocol/targetPort/etc. as needed

**Cons:**
- More complex than Option 1
- Consumers need to know which port name to read per service — increases coupling
- Most consumers only care about the "primary" port

### Option 3: Hybrid — `inClusterPort` (primary) + optional `additionalPorts[]`

```json
{
  "id": "postgresql",
  "inClusterPort": 5432
}
{
  "id": "rabbitmq",
  "inClusterPort": 5672,
  "additionalPorts": [
    { "name": "management", "port": 15672 },
    { "name": "clustering", "port": 25672 }
  ]
}
```

**Pros:**
- Simple common case, flexibility for multi-port
- Consumers that only need the primary port just read `inClusterPort`
- Additive — Option 1 today, add `additionalPorts` later if demanded

**Cons:**
- Two fields to maintain
- Primary/secondary distinction can feel arbitrary (e.g. rabbitmq amqp vs management)

### Option 4: Inline a full URL template field

```json
{
  "id": "postgresql",
  "inClusterUrlTemplate": "postgresql://{{ user }}:{{ password }}@{{ service }}.{{ namespace }}.svc.cluster.local:5432/{{ database }}"
}
```

**Pros:**
- Encodes the full connection-string shape

**Cons:**
- Way too specific — bakes in formatting choices that vary per consumer
- Templating language inside data is a code smell
- Hard to extract just the port for non-URL use cases

---

## Recommendation

**Option 1 — add a single `inClusterPort: number` field.**

Reasoning:
- Matches the existing `exposePort` field in style and precision
- Unambiguous, easy to implement, easy to validate in CI
- Backward compatible — no consumer breaks
- Covers the overwhelmingly common case (single-port services)
- For the rare multi-port case (rabbitmq is the only current example), UIS can add `additionalPorts: [{name, port}]` later as a separate, additive change without breaking existing consumers

**Draft spec:**

> Each service entry in `website/src/data/services.json` SHOULD have an `inClusterPort: number` field. The value is the primary port exposed by the service's Kubernetes `Service` resource inside the cluster (i.e., what a pod would dial at `<service-name>.<namespace>.svc.cluster.local:<inClusterPort>`). For services that expose multiple ports, `inClusterPort` is the primary one (e.g., `amqp` for rabbitmq, `postgres` for postgresql); additional ports can be added later via an optional `additionalPorts: [{name, port}]` array.
>
> The value comes from the service's Helm chart default or playbook definition. UIS CI should validate that the declared `inClusterPort` matches the actual Kubernetes Service port after `uis deploy <service>` completes.

---

## Implementation notes (for the follow-up PLAN)

- **Source of truth**: each service's Helm chart values file or Ansible playbook. For bitnami charts, the service port is typically in `values.yaml` under `primary.service.ports.postgresql` (postgres), `master.service.ports.redis` (redis), etc.
- **Generation**: if `services.json` is generated from a source file (playbook metadata, yaml, etc.), update the generator to read the port from the chart values. If `services.json` is hand-maintained, add the field per service in one PR.
- **Validation**: add a CI step that deploys each service to a test cluster (or parses the helm template) and asserts the declared `inClusterPort` matches the actual Service port. Prevents drift when helm charts are upgraded.
- **Downstream consumers** (at time of writing):
  - TMP's `scripts/generate-registry.ts` vendors `services.json` into `website/src/data/uis-services.json`. When UIS ships `inClusterPort`, TMP re-vendors and reads the new field.
  - TMP's `scripts/lib/build-architecture-mermaid.ts` currently hardcodes `5432`. It will migrate to read from the new field.
  - TMP's planned `scripts/lib/build-expected-output.ts` will use the field for port-forward diagrams and in-cluster URL rendering.

---

## Decisions needed

- [ ] Confirm Option 1 (single `inClusterPort`) vs one of the alternatives
- [ ] Decide whether to also add `additionalPorts[]` now or defer until a multi-port use case actually arises
- [ ] Decide the validation strategy (CI deploy-and-check vs static helm template parse vs trust the author)
- [ ] Decide the rollout: all services in one PR, or service-by-service as we touch them

---

## Next Steps

- [ ] UIS team reviews this investigation and picks an option (recommendation: Option 1)
- [ ] Create a PLAN file in UIS's `plans/backlog/` based on the chosen option, detailing the per-service values, the validation approach, and the rollout plan
- [ ] Implement the PLAN — add `inClusterPort` to all service entries, update `services.json` generation (if automated), add CI validation
- [ ] Notify downstream consumers (TMP at minimum) that the field is available so they can migrate off stopgap hardcoded maps

---

## Reference: consumer-side stopgap (TMP)

While this investigation is pending, TMP plans to ship a small stopgap map at `scripts/lib/service-ports.ts`:

```ts
export const IN_CLUSTER_PORTS: Record<string, number> = {
  postgresql: 5432,
  redis: 6379,
  mongodb: 27017,
  mysql: 3306,
  mariadb: 3306,
  elasticsearch: 9200,
  rabbitmq: 5672,
};
```

When UIS ships `inClusterPort` on `services.json`, TMP will delete this file and read from the registry field instead. Tracking the stopgap and migration:
- TMP consumer investigation: `website/docs/ai-developer/plans/backlog/INVESTIGATE-uis-in-cluster-port.md`
- TMP plan that introduces the stopgap: `website/docs/ai-developer/plans/backlog/PLAN-expected-output-and-numbering.md`
