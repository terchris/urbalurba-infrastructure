---
title: Gravitee
sidebar_label: Gravitee
---

# Gravitee

API management and gateway platform.

| | |
|---|---|
| **Category** | Integration |
| **Deploy** | `./uis deploy gravitee` |
| **Undeploy** | `./uis undeploy gravitee` |
| **Depends on** | None |
| **Required by** | None |
| **Helm chart** | `graviteeio/apim3` (unpinned) |
| **Default namespace** | `default` |

## What It Does

Gravitee provides API management capabilities including an API gateway, developer portal, and management console. It is used for creating, publishing, and managing APIs with policies for rate limiting, authentication, and transformation.

:::warning Skipped in Testing
Gravitee is not included in automated test runs due to its complexity and resource requirements. It may require additional configuration to work correctly.
:::

## Deploy

```bash
./uis deploy gravitee
```

No dependencies (uses its own embedded Elasticsearch and MongoDB, or can use the shared instances).

## Verify

```bash
# Quick check
./uis verify gravitee

# Manual check
kubectl get pods -n default -l app.kubernetes.io/name=gravitee
```

## Configuration

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/090-setup-gravitee.yml` | Deployment playbook |
| `ansible/playbooks/090-remove-gravitee.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy gravitee
```

## Learn More

- [Official Gravitee documentation](https://documentation.gravitee.io/)
