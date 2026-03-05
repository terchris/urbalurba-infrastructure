# Contributors

Welcome! UIS is an open-source project and we appreciate contributions of all kinds.

## Ways to Contribute

| Contribution | Description | Good first step |
|-------------|-------------|-----------------|
| **Add a service** | Package a new open-source service for UIS | Read the [Adding a Service Guide](./guides/adding-a-service.md) |
| **Fix bugs** | Fix deployment issues, broken configs, or edge cases | Check [GitHub Issues](https://github.com/terchris/urbalurba-infrastructure/issues) |
| **Improve docs** | Fix errors, add examples, clarify instructions | Read [Documentation Standards](./rules/documentation.md) |
| **File issues** | Report bugs or suggest features | Open an issue on GitHub |

## Quick Start

```bash
# 1. Fork and clone the repository
git clone https://github.com/<your-username>/urbalurba-infrastructure.git
cd urbalurba-infrastructure

# 2. Create a feature branch
git checkout -b feature/my-change

# 3. Build and test locally
./uis build
UIS_IMAGE=uis-provision-host:local ./uis start

# 4. Make your changes and test
UIS_IMAGE=uis-provision-host:local ./uis deploy <service>

# 5. Submit a pull request
git push origin feature/my-change
```

## Contribution Guidelines

### Commit Conventions

Follow [conventional commits](https://www.conventionalcommits.org/):

```
feat: add qdrant vector database service
fix: correct postgresql password escaping
docs: update ingress rules for Traefik 3.x
```

### Pull Request Process

1. Create a feature branch from `main`
2. Make focused, reviewable changes
3. Test your changes locally with `./uis build` and `./uis deploy`
4. Submit a PR with a clear description of what and why

See [Git Workflow](./rules/git-workflow.md) for full details.

## Rules & Standards

All contributions should follow our established patterns:

- **[Rules Overview](./rules/index.md)** — All rules and standards index
- **[Kubernetes Deployment](./rules/kubernetes-deployment.md)** — Service metadata, stacks, and deploy flow
- **[Provisioning](./rules/provisioning.md)** — Ansible playbook patterns
- **[Naming Conventions](./rules/naming-conventions.md)** — File and resource naming

## Architecture

Understand the internal systems before making changes:

- **[Deploy System](./architecture/deploy-system.md)** — How services are deployed to the cluster
- **[Tools Reference](./architecture/tools.md)** — Tools available in the provision host
- **[Manifests](./architecture/manifests.md)** — Kubernetes manifest organization
- **[Secrets](./architecture/secrets.md)** — Secrets management system
