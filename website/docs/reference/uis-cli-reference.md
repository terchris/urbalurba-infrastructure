---
title: UIS CLI Reference
sidebar_label: CLI Reference
---

# UIS CLI Reference

The `./uis` command manages the UIS provision-host container and all services within it. Commands are organized into host-level (managing the container) and service-level (managing Kubernetes services inside the container).

## Container Management

These commands run on the host machine and manage the UIS container.

| Command | Description |
|---------|-------------|
| `./uis start` | Start the UIS provision-host container |
| `./uis stop` | Stop the container |
| `./uis restart` | Restart the container |
| `./uis container` | Show container status |
| `./uis shell` | Open interactive bash shell in the container |
| `./uis exec <command>` | Execute a command inside the container |
| `./uis logs [--tail N]` | Show container logs (default: last 50 lines) |
| `./uis build` | Build the container image locally as `uis-provision-host:local` |
| `./uis provision` | Run Kubernetes provisioning for rancher-desktop |

## Service Management

### Discovery

| Command | Description |
|---------|-------------|
| `./uis list` | List all services with deployment status |
| `./uis list --category <id>` | Filter by category (e.g., `DATABASES`, `OBSERVABILITY`) |
| `./uis list --all` | Show all services including disabled |
| `./uis status` | Show deployed services health and cluster context |
| `./uis categories` | List all service categories |

### Deploy and Undeploy

| Command | Description |
|---------|-------------|
| `./uis deploy` | Deploy all enabled/autostart services |
| `./uis deploy <service-id>` | Deploy a specific service (auto-enables it) |
| `./uis undeploy <service-id>` | Remove a service from the cluster |

### Autostart Configuration

Services can be marked for automatic deployment.

| Command | Description |
|---------|-------------|
| `./uis enable <service-id>` | Add service to autostart (deploys on next `./uis deploy`) |
| `./uis disable <service-id>` | Remove from autostart (does not undeploy) |
| `./uis list-enabled` | Show all services in autostart configuration |
| `./uis sync` | Auto-enable all currently deployed services |

### Verification

| Command | Description |
|---------|-------------|
| `./uis verify <service-id>` | Run service-specific verification checks |

## Stack Management

Stacks are pre-configured groups of related services deployed together.

| Command | Description |
|---------|-------------|
| `./uis stacks` | List all available stacks |
| `./uis stack info <stack-id>` | Show stack details (components, dependencies) |
| `./uis stack install <stack-id>` | Install all services in a stack in order |
| `./uis stack install <stack-id> --skip-optional` | Skip optional services |
| `./uis stack remove <stack-id>` | Remove all services in a stack |

Available stacks: `observability`, `ai-local`, `analytics`

## Secrets Management

| Command | Description |
|---------|-------------|
| `./uis secrets init` | Create `.uis.secrets/` directory with templates |
| `./uis secrets status` | Show which secrets are configured vs missing |
| `./uis secrets edit` | Open secrets config in editor |
| `./uis secrets generate` | Generate Kubernetes secrets from templates |
| `./uis secrets apply` | Apply generated secrets to the cluster |
| `./uis secrets validate` | Validate secrets config and check required values |

## Testing

| Command | Description |
|---------|-------------|
| `./uis test-all` | Deploy and undeploy all services (full integration test) |
| `./uis test-all --dry-run` | Show test plan without executing |
| `./uis test-all --clean` | Undeploy everything first, then run tests |
| `./uis test-all --only <svc> [svc...]` | Test only specified services and their dependencies |

## Service-Specific Commands

### Tailscale

| Command | Description |
|---------|-------------|
| `./uis tailscale expose <service-id>` | Expose a service via Tailscale Funnel |
| `./uis tailscale unexpose <service-id>` | Remove service from Tailscale Funnel |
| `./uis tailscale verify` | Check Tailscale secrets, API, devices, and operator |

### Cloudflare

| Command | Description |
|---------|-------------|
| `./uis cloudflare verify` | Check tunnel network and pod status |
| `./uis cloudflare teardown` | Remove tunnel (shows manual dashboard steps) |

### ArgoCD

| Command | Description |
|---------|-------------|
| `./uis argocd register <repo>` | Register a GitHub repo as ArgoCD application |
| `./uis argocd remove <repo>` | Remove an ArgoCD application |
| `./uis argocd list` | List registered ArgoCD applications |
| `./uis argocd verify` | Run ArgoCD health checks |

## Host Configuration

Manage configurations for different deployment targets.

| Command | Description |
|---------|-------------|
| `./uis host add` | List available host templates |
| `./uis host add <template-id>` | Add a host configuration from template |
| `./uis host list` | List configured hosts with status |

## Other Commands

| Command | Description |
|---------|-------------|
| `./uis init` | First-time setup wizard (cluster type, domain, project name) |
| `./uis setup` | Interactive TUI menu for browsing and deploying services |
| `./uis tools list` | List optional tools with installation status |
| `./uis tools install <tool-id>` | Install an optional tool (aws-cli, azure-cli, etc.) |
| `./uis docs generate [dir]` | Generate JSON data files for website documentation |
| `./uis version` | Show UIS version |
| `./uis help` | Show help |

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `UIS_IMAGE` | Override container image | `ghcr.io/terchris/uis-provision-host:latest` |
| `UIS_KUBECONFIG_DIR` | Override kubeconfig directory | `$HOME/.kube` |
