# Getting Started

Get UIS running on your machine in a few minutes.

## Prerequisites

- macOS, Linux, or Windows with WSL2
- [Rancher Desktop](https://rancherdesktop.io/) installed and running (Kubernetes enabled)
- 16GB RAM minimum (32GB recommended)

Verify Rancher Desktop is ready:

```bash
kubectl get nodes
```

You should see one node in `Ready` state.

## Install UIS

Download the `uis` CLI script — this is the only file you need:

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/uis -o uis
chmod +x uis
```

**Windows (PowerShell):**

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/terchris/urbalurba-infrastructure/main/uis.ps1" -OutFile "uis.ps1"
```

## Start the Provision Host

```bash
./uis start
```

On first run this will:
1. Pull the `uis-provision-host` container image from the registry
2. Create local configuration directories
3. Initialize default secrets and config files
4. Start the provision host container

Your directory now looks like this:

```
my-project/
├── uis                   # UIS CLI (the only file you downloaded)
├── .uis.extend/          # Service configuration overrides (yours to edit)
├── .uis.secrets/         # Passwords, API keys, certificates (gitignored)
└── .gitignore            # Auto-created, excludes .uis.secrets/
```

- **`.uis.extend/`** — Controls which services are enabled, cluster settings, and tool preferences. Edit these files to tailor UIS to your environment.
- **`.uis.secrets/`** — All credentials and sensitive config. Generated with safe defaults on first run. Never committed to git.

Everything else — manifests, playbooks, tools — lives inside the container image.

## Deploy Your First Service

```bash
./uis deploy whoami
```

Once it completes, open your browser to **http://whoami-public.localhost** — you should see a page showing your request details. This proves your Kubernetes cluster and ingress are working.

Remove it when done:

```bash
./uis undeploy whoami
```

## Common Commands

```bash
./uis list                  # Show all services and their status
./uis deploy postgresql     # Deploy a service
./uis undeploy postgresql   # Remove a service
./uis stack install observability  # Deploy a full package
./uis shell                 # Open a shell in the provision host
./uis help                  # Show all available commands
```

## Monitor Your Cluster

k9s is a terminal-based Kubernetes dashboard available inside the provision host:

```bash
./uis shell
k9s
```

**k9s Navigation Tips**:
- **0** — Show all namespaces
- **:pods** — List all pods
- **:svc** — List all services
- **l** — View logs of selected pod
- **q** — Quit/go back

## How it Works

```
┌─────────────────────────────────────────────┐
│           Your Computer                     │
│                                             │
│  ┌──────────────────┐  ┌─────────────────┐  │
│  │ Provision Host   │  │ Kubernetes      │  │
│  │ Container        │─►│ Cluster         │  │
│  │                  │  │                 │  │
│  │ • Ansible        │  │ • PostgreSQL    │  │
│  │ • Helm           │  │ • Grafana       │  │
│  │ • kubectl        │  │ • Authentik     │  │
│  └──────────────────┘  └─────────────────┘  │
│                            ▲                │
│  ┌─────────────────────────┴──────────────┐ │
│  │        Web Browser                     │ │
│  │  http://grafana.localhost              │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

1. The **Provision Host** container contains all deployment tools (Ansible, Helm, kubectl)
2. The `./uis` CLI sends commands to the provision host
3. The provision host deploys services to your **Kubernetes cluster**
4. You access services through `*.localhost` URLs in your browser

## Next Steps

- **[Services Overview](./services.md)** — See all available services and their cloud equivalents
- **[Architecture](./architecture.md)** — Understand the full system design
- **[Installation Details](./installation.md)** — Platform-specific setup guides
