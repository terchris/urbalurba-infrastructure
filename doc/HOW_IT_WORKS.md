# How It Works

Urbalurba Infrastructure gives you a complete, production-like datacenter running locally. It uses Kubernetes, containers, and declarative manifests so what you develop on your laptop runs the same in the cloud.

## High-Level Architecture

- Kubernetes cluster (via Rancher Desktop) provides orchestration and networking
- Docker runtime executes containers for all services and apps
- Declarative manifests in `manifests/` define desired state for services
- The provision-host container is the central management environment

## The Role of the Provision Host

The provision-host is your day-to-day control plane for managing the local stack:

- Central toolchain with kubectl, helm, k9s, CLI tools, and scripts
- Applies Kubernetes manifests and runs provisioning workflows
- Organizes configuration, manifests, and automation in a consistent directory structure
- Provides a secure place to work with deployment credentials and secrets

At a glance inside the provision-host:

- `/mnt/urbalurbadisk/manifests/` — Kubernetes manifests for services
- `/mnt/urbalurbadisk/provision-host/kubernetes/` — Provisioning scripts grouped by domain
- `/mnt/urbalurbadisk/ansible/` — Playbooks for advanced automation
- `/mnt/urbalurbadisk/secrets/` — Sensitive files stored locally

Typical workflow:

```bash
# Enter the provision-host
docker exec -it provision-host bash

# Navigate to provisioning scripts
cd /mnt/urbalurbadisk/provision-host/kubernetes/

# Provision active services or run a specific setup
./provision-kubernetes.sh
```

For detailed usage, see [Provision Host Documentation](provision-host-readme.md).

