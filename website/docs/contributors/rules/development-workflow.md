# Development Workflow Rules

How to work with the UIS codebase — file operations, command execution, and project conventions.

## Path Convention

All paths in this project are **relative to the repository root** unless explicitly stated otherwise:

```
manifests/030-prometheus-config.yaml           # Correct
ansible/playbooks/030-setup-prometheus.yml     # Correct
```

Never use absolute paths in documentation, scripts, or configuration files.

## Repository Structure

```
urbalurba-infrastructure/
├── manifests/                    # Kubernetes manifests (Helm values, ConfigMaps, IngressRoutes)
├── ansible/
│   └── playbooks/                # Ansible playbooks for service deployment
│       └── utility/              # Reusable utility playbooks
├── provision-host/
│   └── uis/
│       ├── services/             # Service metadata files (by category)
│       └── lib/                  # UIS CLI library scripts
├── website/                      # Docusaurus documentation site
├── .uis.extend/                  # Service configuration (created on first ./uis start)
├── .uis.secrets/                 # Credentials and secrets (gitignored)
└── uis                           # UIS CLI script (entry point)
```

The provision host container at `/mnt/urbalurbadisk/` mirrors the repository root. Files in the container image are pre-built; `.uis.extend/` and `.uis.secrets/` are volume-mounted.

## Working with the UIS CLI

All service management goes through `./uis`:

```bash
# Deploy and manage services
./uis deploy postgresql
./uis undeploy postgresql
./uis list

# Enter the container shell for direct access
./uis shell

# Run a command inside the container
./uis exec kubectl get pods -A
```

## Command Execution

### kubectl

Runs on either the host machine or inside the container — both share the same kubeconfig:

```bash
kubectl get pods -n monitoring
kubectl apply -f manifests/030-prometheus-config.yaml
kubectl logs -n monitoring -l app=grafana
```

### Ansible playbooks

Run inside the provision host container. The UIS CLI handles this automatically when you use `./uis deploy`. To run a playbook manually:

```bash
./uis shell
ansible-playbook ansible/playbooks/030-setup-prometheus.yml -e "target_host=rancher-desktop"
```

### File editing

Edit files on the host machine. Changes are immediately visible inside the container (volume mount):

```bash
vim manifests/030-prometheus-config.yaml
vim ansible/playbooks/030-setup-prometheus.yml
```

## AI Assistant Workflow

When an AI assistant (Claude Code) is performing tasks:

- Files are edited directly on the host filesystem
- `kubectl` commands run directly on the host
- Ansible playbooks still run inside the container via `./uis deploy` or `./uis exec`
- No manual sync step required — all changes are in the git repository

## Human Developer Workflow

```bash
# 1. Edit files on host
vim manifests/030-prometheus-config.yaml

# 2. Deploy via UIS
./uis deploy prometheus

# 3. Verify
kubectl get pods -n monitoring
```

## File Naming

See [Naming Conventions](./naming-conventions.md) for full details. Quick summary:

| Type | Pattern | Example |
|------|---------|---------|
| Manifest | `NNN-component-type.yaml` | `030-prometheus-config.yaml` |
| Setup playbook | `NNN-setup-component.yml` | `030-setup-prometheus.yml` |
| Remove playbook | `NNN-remove-component.yml` | `030-remove-prometheus.yml` |
| Service metadata | `service-name.sh` | `service-prometheus.sh` |

Playbook numbers match their corresponding manifest numbers.

## Related Documentation

- **[Rules Overview](./index.md)** — All rules and standards
- **[Naming Conventions](./naming-conventions.md)** — Complete naming patterns
- **[Kubernetes Deployment Rules](./kubernetes-deployment.md)** — Service metadata and deploy flow
- **[Provisioning Rules](./provisioning.md)** — Ansible playbook patterns
- **[Git Workflow](./git-workflow.md)** — Branch and commit standards
