# Plan: Documentation Restructure and README Rewrite

## Overview

This plan covers:
1. Rename `docs/` folder to `docs/`
2. Update all 239+ references to `docs/`
3. Completely rewrite `README.md` to reflect current system state
4. Rewrite getting started documentation to show how easy it is
5. Add secrets setup to the installation flow

---

## Phase 1: Rename `docs/` to `docs/`

### Steps
1. `git mv doc docs`
2. Update all references in:
   - `README.md` (7 references)
   - `docs/*.md` files (~200+ internal cross-references)
   - Shell scripts in `provision-host/` (~10 references)
   - `topsecret/*.sh` (2 references)
   - `install-rancher.sh` (1 reference)

### Commands
```bash
# Rename folder
git mv doc docs

# Update all references (sed command)
find . -type f \( -name "*.md" -o -name "*.sh" -o -name "*.yaml" -o -name "*.yml" \) \
  -not -path "./.git/*" \
  -exec sed -i '' 's|doc/|docs/|g' {} \;

# Verify no broken references remain
grep -r "docs/" --include="*.md" --include="*.sh" . | grep -v ".git" | grep -v "docs/"
```

---

## Phase 2: Rewrite README.md

### Current System Inventory

**55 Kubernetes Manifests** organized by category:

| Range | Category | Services |
|-------|----------|----------|
| 000-019 | Core Infrastructure | Storage classes, Traefik ingress |
| 020-029 | Web Services | Nginx web server |
| 030-039 | Observability | Prometheus, Grafana, Loki, Tempo, OTel Collector |
| 040-049 | Databases | PostgreSQL, MySQL, MongoDB, Qdrant (vector DB) |
| 050-059 | Caching | Redis |
| 060-069 | Search | Elasticsearch |
| 070-079 | Authentication | Authentik SSO, Whoami test service |
| 080-089 | Message Queues | RabbitMQ |
| 090-099 | API Management | Gravitee |
| 200-229 | AI & ML | OpenWebUI, LiteLLM, Tika, Ollama |
| 220-229 | Development | ArgoCD GitOps |
| 300-329 | Data Science | Spark, JupyterHub, Unity Catalog |
| 600-799 | Admin Tools | pgAdmin, RedisInsight |
| 800-899 | Networking | Tailscale operator |

**60 Ansible Playbooks** for automated deployment

**76 Documentation Files** covering all aspects

### New README.md Structure

```markdown
# Urbalurba Infrastructure

One-line description + badge row

## What is This?
- Complete local datacenter on laptop
- Same stack runs in production cloud
- Zero cloud dependencies during development

## Services Included

### Core Infrastructure
- Kubernetes (Rancher Desktop)
- Traefik Ingress Controller
- Nginx Web Server

### Observability Stack
- Prometheus (metrics)
- Grafana (visualization)
- Loki (logs)
- Tempo (traces)
- OpenTelemetry Collector

### Databases
- PostgreSQL
- MySQL
- MongoDB
- Qdrant (vector database)
- Redis (cache)
- Elasticsearch

### AI & Machine Learning
- OpenWebUI (ChatGPT-like interface)
- LiteLLM (model proxy)
- Ollama (local LLM runtime)
- Tika (document extraction)

### Authentication
- Authentik (SSO/Identity Provider)

### Message Queues
- RabbitMQ

### API Management
- Gravitee

### Data Science
- Apache Spark
- JupyterHub
- Unity Catalog

### Development Tools
- ArgoCD (GitOps)
- pgAdmin
- RedisInsight

### Networking
- Tailscale integration
- Cloudflare Tunnels

## Quick Start

### Prerequisites
- macOS, Linux, or Windows with WSL2
- 16GB RAM minimum (32GB recommended)
- 50GB free disk space
- Rancher Desktop or Docker Desktop

### Installation
1. Install Rancher Desktop
2. Clone this repo
3. Run secrets setup
4. Deploy services

## Documentation

Link to docs/README.md (documentation index)

## Architecture

Brief overview with link to detailed docs

## Repository Structure

Updated tree showing current structure

## Contributing

Guidelines

## License

License info
```

---

## Phase 3: Update docs/README.md (Documentation Index)

Ensure the documentation index properly categorizes all 76 doc files.

---

---

## Phase 4: Rewrite Getting Started Documentation

### Current Problems with `overview-getting-started.md`

1. **References non-existent scripts**: `start-urbalurba.sh`, `start-urbalurba.bat`
2. **Missing secrets setup**: Critical step completely omitted
3. **Wrong script paths**: Points to `./provision-host/kubernetes/99-test/not-in-use/`
4. **No full stack deployment**: Only shows whoami test service
5. **Outdated**: Last updated September 2024

### Actual Installation Flow (Current Reality)

```
1. Install Rancher Desktop
2. Clone/download repo
3. Run ./install-rancher.sh          # Creates provision-host container
4. Run ./login-provision-host.sh     # Enter management container
5. cd topsecret && ./create-kubernetes-secrets.sh  # Generate secrets
6. Edit secrets-config/00-common-values.env.template  # Add your values
7. Re-run ./create-kubernetes-secrets.sh  # Regenerate with your values
8. kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml  # Deploy secrets
9. Deploy services via Ansible playbooks
```

### New Getting Started Structure

```markdown
# Getting Started - 15 Minutes to Full Stack

## Prerequisites
- Rancher Desktop installed and running
- Git (for cloning)
- Text editor (for secrets)

## Step 1: Clone and Setup (5 minutes)
git clone ...
cd urbalurba-infrastructure
./install-rancher.sh

## Step 2: Configure Secrets (5 minutes)
./login-provision-host.sh
cd topsecret
./create-kubernetes-secrets.sh
# Edit your values
./create-kubernetes-secrets.sh
kubectl apply -f kubernetes/kubernetes-secrets.yml

## Step 3: Deploy Services (5 minutes)
# Option A: Deploy everything
ansible-playbook ansible/playbooks/...

# Option B: Deploy specific services
ansible-playbook ansible/playbooks/034-setup-grafana.yml

## Step 4: Access Your Services
- Grafana: http://grafana.localhost
- OpenWebUI: http://openwebui.localhost
- Authentik: http://authentik.localhost
- pgAdmin: http://pgadmin.localhost

## What You Get
[Table of all services with URLs]
```

### New Installation Guide Structure

```markdown
# Installation Guide

## Quick Install (Recommended)
For most users - get running fast

## Custom Install
Choose which services to deploy

## Linux-Specific Notes
- Ubuntu/Debian
- Linux Mint
- Fedora

## macOS-Specific Notes

## Windows (WSL2) Notes

## Troubleshooting
Common issues and solutions
```

---

## Phase 5: Update docs/README.md (Documentation Index)

Reorganize to match new structure and ensure all 76 docs are categorized.

---

## Execution Order

1. [ ] Create new branch: `feature/docs-restructure`
2. [ ] Rename `docs/` to `docs/`
3. [ ] Update all internal references (239+ files)
4. [ ] Write new README.md
5. [ ] Rewrite docs/overview-getting-started.md
6. [ ] Rewrite docs/overview-installation.md
7. [ ] Update docs/README.md index
8. [ ] Test all links
9. [ ] Create PR
10. [ ] Review and merge

---

## Risks

- Broken links if any reference is missed
- Large diff may be hard to review

## Mitigation

- Use automated find/replace
- Test with `grep` to verify no orphaned references
- Split into multiple commits for clearer history

---

## Time Estimate

- Phase 1 (rename + update refs): ~30 minutes
- Phase 2 (README rewrite): ~1 hour
- Phase 3 (docs index): ~30 minutes
- Phase 4 (getting started rewrite): ~1 hour
- Phase 5 (installation guide): ~30 minutes
- Testing and PR: ~30 minutes

**Total: ~4 hours**

---

## Service URLs Reference (for documentation)

After deployment, users can access:

| Service | URL | Purpose |
|---------|-----|---------|
| Nginx | http://localhost | Default landing page |
| Whoami | http://whoami.localhost | Test service |
| Grafana | http://grafana.localhost | Monitoring dashboards |
| Prometheus | http://prometheus.localhost | Metrics |
| Authentik | http://authentik.localhost | SSO/Identity |
| OpenWebUI | http://openwebui.localhost | AI Chat interface |
| LiteLLM | http://litellm.localhost | LLM Proxy |
| pgAdmin | http://pgadmin.localhost | PostgreSQL admin |
| RedisInsight | http://redisinsight.localhost | Redis admin |
| RabbitMQ | http://rabbitmq.localhost | Queue management |
| ArgoCD | http://argocd.localhost | GitOps |
| JupyterHub | http://jupyterhub.localhost | Notebooks |

---

## Key Messages for README

1. **"Complete datacenter on your laptop"** - All cloud services locally
2. **"Same config in dev and prod"** - No environment surprises
3. **"15 minutes to full stack"** - Easy to get started
4. **"Privacy-first AI"** - Run LLMs locally on your data
5. **"55+ services ready to deploy"** - Comprehensive stack
6. **"Run anywhere - same config everywhere"** - True multi-platform portability

---

## Platform Support (Key Selling Point!)

### Supported Platforms

| Platform | CPU Architecture | Use Case |
|----------|------------------|----------|
| **Rancher Desktop** (macOS/Windows/Linux) | ARM64, x86_64 | Local development |
| **Azure AKS** | x86_64 | Production cloud |
| **Ubuntu Server** (cloud or physical) | ARM64, x86_64 | Self-hosted production |
| **Linux Mint / Debian** | x86_64 | Desktop development |
| **Raspberry Pi** | ARM64 | Edge computing, IoT, home lab |

### The Key Message

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   "Once Kubernetes is running, the rest is identical"          │
│                                                                 │
│   Same manifests. Same Ansible playbooks. Same services.       │
│   Whether it's your laptop, Azure, or a Raspberry Pi.          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture Support

- **ARM64** (Apple Silicon M1/M2/M3, Raspberry Pi, AWS Graviton)
- **x86_64** (Intel/AMD, most cloud VMs)

### README Section: "Run Anywhere"

```markdown
## 🌍 Run Anywhere

Urbalurba Infrastructure runs on any Kubernetes cluster - same configuration everywhere:

| Platform | Architecture | Notes |
|----------|--------------|-------|
| 💻 **Laptop** (Rancher Desktop) | ARM64 / x86_64 | macOS, Windows, Linux |
| ☁️ **Azure AKS** | x86_64 | Production cloud |
| 🖥️ **Ubuntu Server** | ARM64 / x86_64 | Cloud VM or bare metal |
| 🍓 **Raspberry Pi** | ARM64 | Edge computing, home lab |

**One codebase. Any platform. Same result.**

The magic: Once your Kubernetes cluster is running (Step 1), everything else
is identical regardless of where it runs. Same manifests, same Ansible
playbooks, same services, same URLs.

### Development → Production Flow

1. **Develop** on your laptop with Rancher Desktop
2. **Test** the exact same configuration
3. **Deploy** to Azure AKS or self-hosted Ubuntu with zero changes
4. **Scale** to Raspberry Pi cluster for edge computing

No "works on my machine" - because it's literally the same machine configuration.
```
