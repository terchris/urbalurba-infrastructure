# About UIS

**Urbalurba Infrastructure Stack** (UIS) is a zero-friction developer platform that gives you production-grade cloud services running on your own machine. Databases, monitoring, AI, authentication, analytics — all deployed with a single command, no cloud account required.

## Why Local-First Infrastructure?

Organizations need control over their data and infrastructure. UIS provides:

- **Data sovereignty** — Your data stays on your hardware, under your control
- **Offline capability** — Full development and testing without internet dependency
- **No vendor lock-in** — Open-source services with standard APIs, portable across any Kubernetes cluster
- **Cost efficiency** — No cloud bills for development and testing environments

## Part of the SovereignSky Initiative

UIS is developed as part of the [SovereignSky](https://sovereignsky.no) initiative, which builds open-source tools for digital sovereignty and community resilience. The project is supported by [helpers.no](https://helpers.no), connecting technology with organizations that need it.

## What UIS Provides

UIS packages 26+ open-source services into deployable categories:

| Category | What you get |
|----------|-------------|
| **Observability** | Prometheus, Grafana, Loki, Tempo, OpenTelemetry |
| **AI & ML** | OpenWebUI, LiteLLM, Ollama, Qdrant |
| **Analytics** | Spark, JupyterHub, Unity Catalog |
| **Identity** | Authentik SSO with blueprint automation |
| **Databases** | PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch |
| **Management** | ArgoCD, pgAdmin, RedisInsight |
| **Networking** | Tailscale and Cloudflare tunnel integration |
| **Integration** | RabbitMQ, Gravitee API Gateway |

## Get Started

Install the UIS CLI and deploy your first service in minutes:

```bash
curl -fsSL https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/uis -o uis
chmod +x uis
./uis start
./uis deploy postgresql
```

See the [Getting Started guide](./getting-started/overview.md) for full instructions.

## Connect With Us

- **GitHub**: [terchris/urbalurba-infrastructure](https://github.com/terchris/urbalurba-infrastructure)
- **SovereignSky**: [sovereignsky.no](https://sovereignsky.no)
- **Helpers.no**: [helpers.no](https://helpers.no)

Contributions are welcome — see the [Contributors guide](./contributors/index.md) to get involved.
