# Tools Reference

Complete reference for all tools available inside the UIS provision host container.

## Accessing the Tools

All tools are pre-installed in the container. Access them via:

```bash
# Open a shell in the provision host
./uis shell

# Or run a command directly
./uis exec kubectl get pods -A
```

## Kubernetes Tools

| Tool | Purpose |
|------|---------|
| **kubectl** | Kubernetes cluster management |
| **helm** | Kubernetes package management |
| **k9s** | Terminal-based Kubernetes dashboard |
| **ansible** | Infrastructure automation and service deployment |

## Cloud Provider CLIs

The container includes CLIs for all major cloud providers:

| Tool | Provider |
|------|----------|
| **az** | Azure CLI |
| **aws** | AWS CLI v2 |
| **gcloud** | Google Cloud SDK (gcloud, bq, gsutil) |
| **oci** | Oracle Cloud Infrastructure CLI |
| **terraform** | Multi-cloud infrastructure as code |

### Cloud Authentication

Authenticate from inside the provision host:

```bash
./uis shell

# Azure
az login

# AWS
aws configure

# Google Cloud
gcloud auth login

# Oracle Cloud
oci setup config
```

## Networking Tools

| Tool | Purpose |
|------|---------|
| **cloudflared** | Cloudflare Tunnel client |
| **tailscale** | Mesh VPN (requires separate configuration) |

## Utility Tools

| Tool | Purpose |
|------|---------|
| **jq** | JSON processing |
| **yq** | YAML processing |
| **gh** | GitHub CLI |
| **git** | Version control |
| **python3** | Python runtime |
| **curl, wget** | HTTP clients |
| **vim** | Text editor |

## Helm Repositories

Pre-configured chart repositories:

| Repository | Charts |
|------------|--------|
| **bitnami** | PostgreSQL, MySQL, MongoDB, Redis, Grafana, etc. |
| **runix** | pgAdmin |
| **gravitee** | API management platform |

Update repositories:

```bash
./uis shell
helm repo update
```

## Architecture Support

All tools support both architectures:
- **x86_64** (AMD64) — Intel/AMD machines
- **aarch64** (ARM64) — Apple Silicon, Raspberry Pi

## Related Documentation

- **[Provision Host Overview](../../provision-host/index.md)** — How the provision host works
- **[Deploy System](./deploy-system.md)** — Deploying services
- **[UIS CLI Reference](../../reference/uis-cli-reference.md)** — Complete command reference
