# Provision Host

The provision host is a Docker container that serves as the management hub for UIS. It contains all tools needed to deploy and manage services on any Kubernetes cluster — you don't need to install anything on your local machine besides Docker.

## How it Works

The `./uis` CLI on your host machine talks to the provision host container. The container has Ansible, Helm, kubectl, and all playbooks baked in. Your local configuration (`.uis.extend/` and `.uis.secrets/`) is mounted into the container.

```
Host Machine
├── ./uis CLI                    # Sends commands to the container
├── .uis.extend/                 # Your service configuration
├── .uis.secrets/                # Your credentials (gitignored)
│
└── Provision Host Container
    ├── Ansible playbooks        # Service deployment logic
    ├── Helm charts              # Templated Kubernetes deployments
    ├── Kubernetes manifests     # Declarative service definitions
    ├── kubectl, helm, k9s       # Cluster management tools
    └── jq, yq, git, curl       # Utility tools
            │
            ▼
    Kubernetes Cluster
    └── Your deployed services
```

## Common Commands

```bash
./uis start          # Start the provision host container
./uis stop           # Stop the container
./uis shell          # Open a shell inside the container
./uis deploy grafana # Deploy a service
./uis list           # Show all services and their status
./uis help           # Show all available commands
```

## Guides

- **[Tools Reference](./tools.md)** — All tools available inside the container
- **[Kubernetes Deployment](./kubernetes.md)** — How services are deployed to the cluster
- **[Rancher Desktop Integration](./rancher.md)** — Setup specific to Rancher Desktop

## Key Concepts

- **No local tool installation** — Only Docker is required on your machine
- **OS agnostic** — Same container works on macOS, Linux, and Windows
- **Version controlled** — All tool versions are pinned inside the container image
- **Isolation** — No conflicts with locally installed tools

## Related Documentation

- **[Architecture](../getting-started/architecture.md)** — Full system architecture
- **[Secrets Management](../reference/secrets-management.md)** — How credentials are managed
- **[UIS CLI Reference](../reference/uis-cli-reference.md)** — Complete command reference
