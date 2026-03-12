# UIS Backstage Catalog

Backstage Software Catalog for the [Urbalurba Infrastructure Stack (UIS)](https://uis.sovereignsky.no/docs).

## Structure

```
catalog/
├── all.yaml              ← Master location file (load this in Backstage)
├── domains/              ← 1 domain: uis-infrastructure
├── systems/              ← 9 systems (observability, databases, integration, ...)
├── resources/            ← 7 resources (postgresql, redis, rabbitmq, ...)
├── components/           ← 25 components (grafana, authentik, openwebui, ...)
├── groups/               ← 3 groups (platform-team, app-team, business-owners)
└── users/                ← User entities
```

## Loading into Backstage

Add this to your `app-config.yaml`:

```yaml
catalog:
  locations:
    - type: file
      target: ../../catalog/all.yaml
```

## Ownership Model

Every entity has:
- `spec.owner` — technical owner (`platform-team` or `app-team`)
- `metadata.annotations.uis.sovereignsky.no/business-owner` — business owner group

### platform-team owns
observability · databases · identity · networking · management

### app-team owns
ai · integration · applications · analytics

## Observability Stack

The OTLP Collector routes to → Prometheus (metrics), Loki (logs), Tempo (traces).
Grafana queries all three backends for unified visualization.

Currently only `sovdev-logger` (a library) explicitly sends telemetry to the OTLP Collector. Other services may be instrumented in the future.

## Key Dependency Chains

```
openwebui → litellm → [OpenAI / Anthropic / Google]
openwebui → postgresql
litellm   → postgresql

authentik → postgresql
authentik → redis

pgadmin      → postgresql
redisinsight → redis

otlp-collector → prometheus
otlp-collector → loki
otlp-collector → tempo
grafana        → prometheus
grafana        → loki
grafana        → tempo

nextcloud    → redis

openmetadata → postgresql
openmetadata → elasticsearch
unity-catalog → postgresql

gravitee     → mongodb
gravitee     → elasticsearch

onlyoffice   → nextcloud
```

## Adding New Services

1. Decide: is it a `Component` (a service/tool) or a `Resource` (infrastructure)?
2. Create a file in `/components/` or `/resources/`
3. Add `spec.system` pointing to one of the 9 systems
4. Add `spec.dependsOn` for any known dependencies
5. Add the file reference to `all.yaml`
