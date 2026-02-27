# INVESTIGATE: Version Pinning for Helm Charts and Container Images

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Created**: 2026-02-27
**Status**: Backlog

## Problem Statement

Everything works today, but 18 of 21 Helm charts and several container images have no version pinning. Any upstream release — intentional or accidental — can break the system without warning. A single `./uis deploy` could pull a new chart version with breaking changes.

---

## Current State

### Helm Charts — Version Pinning Status

| Service | Chart | Version | Status |
|---------|-------|---------|--------|
| **argocd** | `argo/argo-cd` | `7.8.26` | PINNED |
| **gravitee** | `graviteeio/apim` | `4.8.4` | PINNED |
| **authentik** | `authentik/authentik` | `2025.8.1` | PINNED |
| **prometheus** | `prometheus-community/prometheus` | — | UNPINNED |
| **tempo** | `grafana/tempo` | — | UNPINNED |
| **loki** | `grafana/loki` | — | UNPINNED |
| **otel-collector** | `open-telemetry/opentelemetry-collector` | — | UNPINNED |
| **grafana** | `grafana/grafana` | — | UNPINNED |
| **postgresql** | `bitnami/postgresql` | — | UNPINNED |
| **redis** | `bitnami/redis` | — | UNPINNED |
| **rabbitmq** | `bitnami/rabbitmq` | — | UNPINNED |
| **elasticsearch** | `elastic/elasticsearch` | — | UNPINNED |
| **qdrant** | `qdrant/qdrant` | — | UNPINNED |
| **tika** | `tika/tika` | — | UNPINNED |
| **open-webui** | `open-webui/open-webui` | — | UNPINNED |
| **litellm** | `oci://ghcr.io/berriai/litellm-helm` | — | UNPINNED |
| **spark** | `spark-kubernetes-operator/spark-kubernetes-operator` | — | UNPINNED |
| **jupyterhub** | `jupyterhub/jupyterhub` | — | UNPINNED |
| **pgadmin** | `runix/pgadmin4` | — | UNPINNED |
| **redisinsight** | `redisinsight/redisinsight` | — | UNPINNED |
| **mysql** | (manifest, no helm) | — | N/A |

**Summary: 3 pinned, 18 unpinned out of 21 Helm charts.**

### Container Images — Version Pinning Status

Images explicitly set in manifests or config files:

| Service | Image | Tag | Status |
|---------|-------|-----|--------|
| **whoami** | `traefik/whoami` | `v1.10.2` | PINNED |
| **mongodb** | `mongo` | `8.0.5` | PINNED |
| **rabbitmq** | `bitnamilegacy/rabbitmq` | `3.13.7-debian-12-r5` | PINNED |
| **tika** | `apache/tika` | `3.0.0.0` | PINNED |
| **redis** | `redis` | `7.4` | FLOATING (minor) |
| **mysql** | `mysql` | `8.0` | FLOATING (minor) |
| **postgresql** | `ghcr.io/terchris/urbalurba-postgresql` | `latest` | UNPINNED |
| **unity-catalog** | `unitycatalog/unitycatalog` | `latest` | UNPINNED |
| **cloudflare-tunnel** | `cloudflare/cloudflared` | `latest` | UNPINNED |
| **pgadmin init** | `busybox` | `latest` | UNPINNED |

Images controlled by Helm chart (not explicitly set in our config — chart decides):
- prometheus, grafana, tempo, loki, otel-collector, elasticsearch, qdrant, open-webui, litellm, spark, jupyterhub, pgadmin, redisinsight, authentik, argocd

---

## Questions to Investigate

### Q1: What is the right pinning strategy?

Options:
- **Pin everything** — maximum stability, requires manual updates
- **Pin Helm charts only** — charts control image versions, so pinning charts is sufficient
- **Pin charts + explicit images** — pin what we control, let pinned charts manage their own images

### Q2: Where should versions live?

Options:
- **In each playbook** — `chart_version` parameter in ansible helm tasks (current pattern for argocd/gravitee/authentik)
- **In a central versions file** — single file listing all versions, sourced by playbooks
- **In config manifests** — alongside other service config in `manifests/*-config.yaml`

### Q3: How do we handle updates?

Options:
- **Manual** — developer checks for updates periodically, updates versions, tests
- **Automated detection** — script/CI that checks for newer versions and reports
- **Dependabot/Renovate** — GitHub-native dependency update PRs

### Q4: Helm repos — RESOLVED

`05-install-helm-repos.yml` was the original approach. The current pattern is that each playbook manages its own helm repo. The 2 repos still in `05-install-helm-repos.yml` (bitnami, runix) are legacy — they should move into the playbooks that use them. No further investigation needed.

### Q5: Bitnami subscription changes

Bitnami changed their distribution model (Aug 2025). RabbitMQ already uses `bitnamilegacy` image. Are other Bitnami charts affected? Will future updates break?

---

## Helm Repos Inventory

| Repository | URL | Where Added |
|------------|-----|-------------|
| bitnami | `https://charts.bitnami.com/bitnami` | `05-install-helm-repos.yml` |
| runix | `https://helm.runix.net` | `05-install-helm-repos.yml` |
| graviteeio | `https://helm.gravitee.io` | `090-setup-gravitee.yml` |
| prometheus-community | `https://prometheus-community.github.io/helm-charts` | `030-setup-prometheus.yml` |
| grafana | `https://grafana.github.io/helm-charts` | multiple playbooks |
| open-telemetry | `https://open-telemetry.github.io/opentelemetry-helm-charts` | `033-setup-otel-collector.yml` |
| argo | `https://argoproj.github.io/argo-helm` | `220-setup-argocd.yml` |
| elastic | `https://helm.elastic.co` | `060-setup-elasticsearch.yml` |
| qdrant | `https://qdrant.github.io/qdrant-helm` | `044-setup-qdrant.yml` |
| open-webui | `https://helm.openwebui.com/` | `200-setup-open-webui.yml` |
| jupyterhub | `https://hub.jupyter.org/helm-chart/` | `350-setup-jupyterhub.yml` |
| authentik | `https://charts.goauthentik.io` | `070-setup-authentik.yml` |
| redisinsight | `https://mrnim94.github.io/redisinsight/` | `651-adm-redisinsight.yml` |
| spark-kubernetes-operator | `https://apache.github.io/spark-kubernetes-operator` | `330-setup-spark.yml` |

---

## Risk Assessment

**High risk (unpinned chart + critical service):**
- postgresql (all data services depend on it)
- redis (authentik depends on it)
- elasticsearch

**Medium risk (unpinned chart + important service):**
- grafana, prometheus, loki, tempo, otel-collector (observability stack)
- open-webui, litellm (AI stack)
- jupyterhub, spark (data science stack)

**Lower risk (unpinned chart + admin/utility):**
- pgadmin, redisinsight, qdrant, tika

**`:latest` images (highest breakage risk):**
- postgresql (custom image — we control this)
- unity-catalog
- cloudflare-tunnel
- busybox (pgadmin init container)

---

## Next Step

Investigate the questions above, then create a PLAN with a phased approach to pin versions across all services.
