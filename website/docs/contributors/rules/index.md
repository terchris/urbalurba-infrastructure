# Rules & Standards

Rules, standards, and best practices for working with the UIS platform. These rules are used by both human developers and AI assistants.

## Rule Guides

### [Provisioning Rules](./provisioning.md)

How to deploy and manage infrastructure on Kubernetes using UIS patterns. Covers shell script + Ansible separation, cluster testing with `kubectl run`, progress feedback, error handling, and Helm repository management.

### [Kubernetes Deployment Rules](./kubernetes-deployment.md)

Mandatory patterns for the automated deployment system. Covers directory structure, script requirements, dependency ordering, namespace standards, and health checks.

### [Ingress & Networking Rules](./ingress-traefik.md)

Traefik IngressRoute standards, multi-domain routing with HostRegexp, Authentik authentication middleware, DNS architecture, and CSP security patterns.

### [Secrets Management Rules](./secrets-management.md)

The template + gitignore pattern for secrets, variable substitution with `${VARIABLE}`, security verification, namespace organization, and rotation procedures.

### [Git Workflow Rules](./git-workflow.md)

Feature branch workflow, pull request requirements, code review standards, commit message conventions, and branch management.

### [Development Workflow Rules](./development-workflow.md)

Standards for working with the codebase — path conventions, file operations, command execution (host vs. container), and Kubernetes operations.

### [Naming Conventions Rules](./naming-conventions.md)

Naming patterns for manifests (sequential numbering 000–999), files, Kubernetes resources, namespaces, labels, scripts, and Ansible playbooks.

### [Documentation Standards](./documentation.md)

Writing consistent documentation — structure, formatting, code blocks, cross-references, and keeping docs synchronized with code.

## Quick Start by Role

**New to UIS?** Start with [Git Workflow](./git-workflow.md), then [Development Workflow](./development-workflow.md), then [Naming Conventions](./naming-conventions.md).

**Deploying services?** Read [Provisioning Rules](./provisioning.md) and [Kubernetes Deployment Rules](./kubernetes-deployment.md).

**Configuring access?** Read [Ingress & Networking Rules](./ingress-traefik.md) and [Secrets Management Rules](./secrets-management.md).

## Contributing

Add new rules when recurring anti-patterns are discovered or new deployment patterns are established. Each rule should include correct and incorrect examples, background explanation, and links to working code.

## Related Documentation

- **[Architecture](../../getting-started/architecture.md)** — System architecture overview
- **[UIS CLI Reference](../../reference/uis-cli-reference.md)** — Complete command reference
- **[Provision Host](../../provision-host/index.md)** — Container tools and deployment
