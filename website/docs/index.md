# Urbalurba Infrastructure

**Complete datacenter on your laptop** - A zero-friction developer platform that provides production-grade infrastructure locally.

## What is This?

Urbalurba Infrastructure is a comprehensive Kubernetes-based platform that runs the same configuration in development and production:

- **Local Development**: Run everything on your laptop with Rancher Desktop
- **Production Ready**: Deploy the exact same configuration to Azure AKS or any Kubernetes cluster
- **Zero Cloud Dependencies**: Develop and test without internet connectivity
- **Privacy-First AI**: Run LLMs locally on your own data

## Run Anywhere

| Platform | Architecture | Use Case |
|----------|--------------|----------|
| **Laptop** (Rancher Desktop) | ARM64 / x86_64 | Local development |
| **Azure AKS** | x86_64 | Production cloud |
| **Ubuntu Server** | ARM64 / x86_64 | Self-hosted production |
| **Raspberry Pi** | ARM64 | Edge computing, home lab |

:::tip One codebase. Any platform. Same result.
Once your Kubernetes cluster is running, everything else is identical regardless of where it runs. Same manifests, same Ansible playbooks, same services, same URLs.
:::

## Services Included

### Core Infrastructure
- **Kubernetes** - Container orchestration via Rancher Desktop
- **Traefik** - Ingress controller with automatic TLS
- **Nginx** - Web server

### Observability Stack
- **Prometheus** - Metrics collection
- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **OpenTelemetry Collector** - Telemetry pipeline

### Databases
- **PostgreSQL** - Primary relational database
- **MySQL** - Alternative SQL database
- **MongoDB** - Document database
- **Qdrant** - Vector database for AI
- **Redis** - Cache and message broker
- **Elasticsearch** - Search engine

### AI & Machine Learning
- **OpenWebUI** - ChatGPT-like interface
- **LiteLLM** - LLM proxy for multiple providers
- **Ollama** - Local LLM runtime
- **Tika** - Document extraction

### Authentication
- **Authentik** - SSO and identity provider with blueprints

### Message Queues
- **RabbitMQ** - Message broker

### Development Tools
- **ArgoCD** - GitOps continuous deployment
- **pgAdmin** - PostgreSQL administration
- **RedisInsight** - Redis administration

### Networking
- **Tailscale** - Secure mesh VPN
- **Cloudflare Tunnels** - Public access without port forwarding

## Quick Start

### Prerequisites

- macOS, Linux, or Windows with WSL2
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- [Rancher Desktop](https://rancherdesktop.io/) installed

### Installation

```bash
# Clone the repository
git clone https://github.com/terchris/urbalurba-infrastructure.git
cd urbalurba-infrastructure

# Start the UIS container
./uis start

# Deploy all services to kubernetes
./uis provision

# Access the provision host shell
./uis shell

# Or deploy individual services
./uis deploy grafana
```

### Access Your Services

After deployment, access services at:

| Service | URL |
|---------|-----|
| Nginx | [http://localhost](http://localhost) |
| Grafana | [http://grafana.localhost](http://grafana.localhost) |
| Prometheus | [http://prometheus.localhost](http://prometheus.localhost) |
| Authentik | [http://authentik.localhost](http://authentik.localhost) |
| OpenWebUI | [http://openwebui.localhost](http://openwebui.localhost) |
| pgAdmin | [http://pgadmin.localhost](http://pgadmin.localhost) |
| ArgoCD | [http://argocd.localhost](http://argocd.localhost) |

## Documentation Structure

- **[Getting Started](./getting-started/overview.md)** - First steps and quick start guide
- **[Hosts & Platforms](./hosts/index.md)** - Supported platforms and setup guides
- **[Packages](./packages/ai/index.md)** - Service documentation by category
- **[Networking](./networking/index.md)** - External access via Tailscale and Cloudflare
- **[Rules & Standards](./rules/index.md)** - Development conventions and patterns
- **[Troubleshooting](./reference/troubleshooting.md)** - Common issues and solutions

## Repository Structure

```
urbalurba-infrastructure/
├── ansible/              # Ansible playbooks for deployment
├── docs/                 # Documentation (this site)
├── manifests/            # Kubernetes manifests (numbered by category)
├── provision-host/       # Provision host container scripts
├── .uis.secrets/         # Secrets management (gitignored)
├── uis                   # UIS CLI wrapper (main entry point)
└── mkdocs.yml            # Documentation site configuration
```

## Contributing

Contributions are welcome! Please read the [development workflow](./rules/development-workflow.md) and [git workflow](./rules/git-workflow.md) guides before submitting changes.

## License

This project is maintained by the Urbalurba development team.
