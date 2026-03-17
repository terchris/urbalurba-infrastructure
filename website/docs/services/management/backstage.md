---
title: Backstage (RHDH)
sidebar_label: Backstage
---

# Backstage (RHDH)

Developer portal with software catalog and Kubernetes visibility.

| | |
|---|---|
| **Category** | Management |
| **Deploy** | `./uis deploy backstage` |
| **Undeploy** | `./uis undeploy backstage` |
| **Depends on** | PostgreSQL |
| **Required by** | None |
| **Helm chart** | `rhdh-chart/backstage` |
| **Default namespace** | `backstage` |

## What It Does

Backstage (via Red Hat Developer Hub) provides a centralized developer portal for the UIS platform. It gives developers a single place to discover all services, see how they relate to each other, and check their live status.

Key capabilities:
- **Software Catalog** — browse all UIS services, systems, and their relationships
- **Kubernetes Plugin** — live pod status and deployment health for each service
- **Grafana Plugin** — links services to their monitoring dashboards
- **Service Relationships** — visualize dependencies between components and resources

## Deploy

```bash
# Prerequisites
./uis deploy postgresql

# Generate catalog (if not already done)
./uis catalog generate

# Deploy Backstage
./uis deploy backstage
```

The setup playbook automatically:
1. Creates the `backstage` namespace
2. Creates the database in PostgreSQL
3. Generates the catalog and creates a ConfigMap
4. Deploys via Helm
5. Sets up the IngressRoute

## Verify

```bash
# Quick check
./uis verify backstage

# Manual check
kubectl get pods -n backstage

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://backstage.localhost
# Expected: 200
```

Access the portal at [http://backstage.localhost](http://backstage.localhost).

## Configuration

### Key Files

| File | Purpose |
|------|---------|
| `manifests/650-backstage-config.yaml` | Helm values (image, database, plugins, resources) |
| `manifests/651-backstage-ingressroute.yaml` | Traefik routing for backstage.localhost |
| `manifests/652-backstage-rbac.yaml` | ServiceAccount + ClusterRoleBinding for K8s plugin |
| `manifests/653-backstage-catalog.yaml` | Catalog ConfigMap (generated) |
| `ansible/playbooks/650-setup-backstage.yml` | Setup playbook |
| `ansible/playbooks/650-remove-backstage.yml` | Removal playbook |
| `ansible/playbooks/650-test-backstage.yml` | Verification playbook |

### Catalog

The catalog is generated from UIS service definitions:

```bash
# Generate catalog files
./uis catalog generate

# Files are written to generated/backstage/catalog/
```

The setup playbook creates a ConfigMap from these files and mounts it into the Backstage pod.

### Resource Limits

Backstage is configured with laptop-friendly resource limits (overriding RHDH defaults):

| | Request | Limit |
|---|---------|-------|
| **CPU** | 250m | 1000m |
| **Memory** | 256Mi | 1Gi |

If Backstage runs out of memory, increase the limits in `650-backstage-config.yaml`.

## Undeploy

```bash
./uis undeploy backstage
```

The PostgreSQL database is preserved for redeployment. To remove it manually:

```bash
kubectl exec -n default postgresql-0 -- psql -U postgres -c "DROP DATABASE backstage;"
```

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n backstage -l app.kubernetes.io/name=backstage
kubectl logs -n backstage -l app.kubernetes.io/name=backstage --tail=100
```

**Catalog is empty:**
```bash
# Regenerate and update ConfigMap
./uis catalog generate
kubectl create configmap backstage-catalog --from-file=generated/backstage/catalog/ -n backstage --dry-run=client -o yaml | kubectl apply -f -
# Restart Backstage to reload
kubectl rollout restart deployment backstage -n backstage
```

**Database connection fails:**
```bash
# Check secrets exist
kubectl get secret urbalurba-secrets -n backstage
# Check PostgreSQL
kubectl get pods -n default -l app.kubernetes.io/name=postgresql
```

## Learn More

- [Backstage documentation](https://backstage.io/docs)
- [Red Hat Developer Hub](https://github.com/redhat-developer/rhdh)
