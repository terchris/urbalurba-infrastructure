---
title: Enonic XP
sidebar_label: Enonic XP
---

# Enonic XP

Headless CMS platform for content management and delivery, used by Norwegian organizations (NAV, Gjensidige, Helsedirektoratet).

| | |
|---|---|
| **Category** | Integration |
| **Deploy** | `./uis deploy enonic` |
| **Undeploy** | `./uis undeploy enonic` |
| **Verify** | `./uis verify enonic` |
| **Depends on** | Nothing (embedded storage) |
| **Image** | `enonic/xp:7.16.2-ubuntu` (pinned) |
| **Default namespace** | `enonic` |

## What It Does

Enonic XP provides a complete CMS platform with:
- **Content Studio** — editorial UI for content management
- **Headless APIs** — GraphQL and REST content delivery
- **Embedded storage** — built-in Elasticsearch and NoSQL (no external database needed)
- **App ecosystem** — composable architecture with installable apps
- **Management API** — port 4848 for admin operations and CI/CD integration

## Deploy

```bash
# Deploy Enonic XP (no dependencies needed)
./uis deploy enonic
```

Access at `http://enonic.localhost`. On first visit, Enonic shows a welcome page — click **"Log in as Guest"** to access the admin console as Super User (the label is misleading — it grants full admin access, not guest access). Do not click "create an Admin User" unless you want to create an additional admin account.

Password for API/CLI access: `./uis secrets show DEFAULT_ADMIN_PASSWORD` (user: `su`).

## Verify

```bash
# Run all 6 E2E tests
./uis verify enonic

# Manual checks
kubectl get pods -n enonic
curl http://enonic.localhost
```

## Configuration

Enonic XP configuration is in `manifests/085-enonic-config.yaml`. Key settings:

| Setting | Value | Notes |
|---------|-------|-------|
| Image | `enonic/xp:7.16.2-ubuntu` | Pinned version |
| Storage | Embedded | No external database needed |
| JVM heap | 512m–1g | ~30% of container memory limit |
| CPU request | 500m | Dev-appropriate |
| Memory request | 1Gi | Dev-appropriate |
| Web port | 8080 | Content Studio, admin, APIs |
| Management port | 4848 | Admin operations (internal only) |
| Stats port | 2609 | Health checks, metrics (internal only) |

### Admin Credentials

Enonic XP uses `su` as the superuser account. The password is set via `xp.suPassword` in `$XP_HOME/config/system.properties` (Enonic does not support environment variables for the su password). The StatefulSet entrypoint injects the password from the `ENONIC_ADMIN_PASSWORD` secret into `system.properties` before XP starts.

### Secrets

| Variable | Source | Purpose |
|----------|--------|---------|
| `ENONIC_ADMIN_PASSWORD` | `DEFAULT_ADMIN_PASSWORD` | Superuser password (user: `su`) |

### Key Files

| File | Purpose |
|------|---------|
| `manifests/085-enonic-config.yaml` | ConfigMap (JVM settings) |
| `manifests/085-enonic-statefulset.yaml` | StatefulSet + Service + PVC + ServiceAccount |
| `manifests/085-enonic-ingressroute.yaml` | Traefik IngressRoute |
| `ansible/playbooks/085-setup-enonic.yml` | Deployment playbook |
| `ansible/playbooks/085-remove-enonic.yml` | Removal playbook |
| `ansible/playbooks/085-test-enonic.yml` | E2E verification (6 tests) |

## Undeploy

```bash
./uis undeploy enonic
```

Note: All PVC data (content, indexes, blobstore) is deleted on undeploy.

## Troubleshooting

**Pod won't start (OOM or Java errors):**
```bash
kubectl describe pod -n enonic -l app=enonic-xp
kubectl logs -n enonic -l app=enonic-xp --tail=50
```

**Health check failing:**
```bash
# Check statistics endpoint (no auth needed)
kubectl exec -n enonic enonic-xp-0 -- curl -s http://localhost:2609/health
kubectl exec -n enonic enonic-xp-0 -- curl -s http://localhost:2609/ready
```

**Authentication failed:**
```bash
# Check credentials in secrets
kubectl get secret urbalurba-secrets -n enonic -o jsonpath='{.data.ENONIC_ADMIN_PASSWORD}' | base64 -d
# Test management API
kubectl exec -n enonic enonic-xp-0 -- curl -s -u su:<password> http://localhost:4848/repo/list
```

## Learn More

- [Enonic XP documentation](https://developer.enonic.com/docs/xp/stable)
- [Enonic on GitHub](https://github.com/enonic/xp)
