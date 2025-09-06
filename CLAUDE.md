# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Urbalurba Infrastructure is a zero-friction developer platform that provides a complete datacenter environment on a laptop. It runs a local Kubernetes cluster via Rancher Desktop and deploys services using declarative manifests, allowing developers to build and test with production-like infrastructure without cloud dependencies.

## Key Architecture Components

### Infrastructure Stack
- **Kubernetes Cluster**: Managed via Rancher Desktop, provides container orchestration
- **Provision Host**: Central management container at `/mnt/urbalurbadisk/` containing all provisioning tools and scripts
- **Manifests**: Declarative service definitions in `manifests/` directory (numbered for deployment order)
- **Ansible Automation**: Advanced provisioning via `ansible/playbooks/`

### Service Categories
1. **Core Systems** (000-099): Storage, ingress, DNS, networking
2. **Data Services** (040-099): PostgreSQL, MySQL, MongoDB, Redis, RabbitMQ, Elasticsearch
3. **AI & ML** (200-229): OpenWebUI, Ollama, LiteLLM, Tika
4. **Authentication** (070-079): Authentik with blueprints for SSO
5. **Observability** (030-039, 230-239): Grafana, Prometheus, Loki, Tempo
6. **Management** (600-799): pgAdmin, ArgoCD, Cloudflare tunnels

## Common Development Commands

### Kubernetes Operations
```bash
# Apply manifests
kubectl apply -f manifests/[filename].yaml

# Delete resources
kubectl delete -f manifests/[filename].yaml

# Check pod status
kubectl get pods -A

# View logs
kubectl logs -n [namespace] [pod-name]
```

### Provision Host Access
```bash
# Access provision host container
docker exec -it provision-host bash

# Navigate to main working directory
cd /mnt/urbalurbadisk/

# Run full provisioning
./provision-host/kubernetes/provision-kubernetes.sh

# Run specific service setup
cd provision-host/kubernetes/[category]/
./[script-name].sh
```

### Service Management
```bash
# Check service status
kubectl get svc -A

# Port forward for local access
kubectl port-forward -n [namespace] svc/[service-name] [local-port]:[service-port]

# Scale deployment
kubectl scale deployment -n [namespace] [deployment-name] --replicas=[number]
```

## Testing & Validation

When modifying services:
1. Check manifest syntax: `kubectl apply --dry-run=client -f manifests/[file].yaml`
2. Verify deployment: `kubectl rollout status deployment/[name] -n [namespace]`
3. Check logs for errors: `kubectl logs -n [namespace] -l app=[label] --tail=50`
4. Test connectivity: `kubectl exec -it [pod] -- curl [service]:[port]`

## Important Conventions

### Manifest Numbering
- 000-099: Core infrastructure
- 040-099: Databases and caches
- 200-229: AI services
- 070-079: Authentication
- 030-039: Monitoring
- 600-799: Admin tools

### Script Organization
- Active scripts: `provision-host/kubernetes/[category]/[script].sh`
- Inactive scripts: `provision-host/kubernetes/[category]/not-in-use/[script].sh`
- Scripts are numbered for execution order

### Configuration Management
- Secrets: Store in Kubernetes secrets, never commit to repository
- ConfigMaps: Use for non-sensitive configuration in `manifests/*-config.yaml`
- Ingress: Traefik IngressRoutes for routing configuration

## Git Workflow

The repository tracks infrastructure changes in the `main` branch. Current modifications visible in git status should be reviewed before committing:
- Deleted files indicate removed services
- Modified configs show service updates
- New manifests add capabilities

## Debugging Tips

1. **Pod won't start**: Check events with `kubectl describe pod -n [namespace] [pod-name]`
2. **Service unreachable**: Verify ingress with `kubectl get ingressroute -A`
3. **Storage issues**: Check PVC status with `kubectl get pvc -A`
4. **Authentication problems**: Review Authentik blueprints in `manifests/073-authentik-*.yaml`
5. **Network connectivity**: Test from provision-host or use `kubectl exec` to debug from within cluster

## Service-Specific Notes

### OpenWebUI (200-210)
- Integrates with Authentik for SSO
- Configuration in `manifests/208-openwebui-config.yaml`
- Groups synchronized from Authentik

### Authentik (070-079)
- Blueprints define users, groups, and applications
- Forward auth middleware for protecting services
- Test with whoami service (protected vs public endpoints)

### Databases
- PostgreSQL: Primary database, port 5432
- MySQL: Alternative SQL database, port 3306
- MongoDB: NoSQL option, port 27017
- Redis: Cache and message broker, port 6379

Remember: Always prefer editing existing files over creating new ones, and avoid creating documentation unless explicitly requested.