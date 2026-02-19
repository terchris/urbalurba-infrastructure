# INVESTIGATE: Rancher Reset and Full Service Verification

**Related**: [STATUS-service-migration](STATUS-service-migration.md)
**Created**: 2026-02-19

## Goal

Determine the exact procedure to factory-reset Rancher Desktop, reprovision from scratch, and verify all 24 services deploy and undeploy correctly.

## Two Types of Reset

### Reset Kubernetes (lighter)

Rancher Desktop → Troubleshooting → Reset Kubernetes:
- **Wipes**: K3s cluster, all pods, PersistentVolumes, kubeconfig
- **Survives**: Only host filesystem files

### Factory Reset (full wipe)

Rancher Desktop → Troubleshooting → Factory Reset:
- **Wipes**: Everything above, plus Rancher Desktop settings
- **Survives**: Only host filesystem files

Both reset types wipe the `uis-provision-host` container and image (must be re-pulled or rebuilt).

What **survives** on the host:
- `.uis.extend/` (enabled-services.conf, cluster-config.sh)
- `.uis.secrets/` (generated secrets, SSH keys, templates)
- All repo files

## Recovery Procedure (Modern UIS Path)

After a reset and re-enabling Kubernetes:

```bash
./uis start            # pulls/creates container if missing (factory reset), or restarts existing one
./uis deploy           # calls ensure_secrets_applied() automatically, deploys enabled services
```

The `ensure_secrets_applied()` function in `first-run.sh` handles re-applying secrets to a fresh cluster. The `uis deploy` command calls it before every deployment.

For individual services:
```bash
./uis deploy <service>
```

## Current Verification Status

From STATUS-service-migration.md — only 5 of 24 services are verified:

| Status | Services |
|--------|----------|
| Verified (5) | whoami, postgresql, redis, authentik, argocd |
| Not verified (16) | nginx, prometheus, tempo, loki, otel-collector, grafana, mysql, mongodb, qdrant, elasticsearch, rabbitmq, openwebui, litellm, unity-catalog, spark, jupyterhub |
| Broken/Missing (3) | gravitee (broken), tailscale-tunnel (no remove playbook), cloudflare-tunnel (no remove playbook) |

## Proposed Test Strategy

### Phase 1: Reset and Bootstrap

1. Factory reset Rancher Desktop
2. Re-enable Kubernetes, wait for ready
3. `./uis restart`
4. `./uis secrets apply`
5. Verify cluster is healthy: `kubectl get nodes`, `kubectl get pods -A`

### Phase 2: Deploy and Verify Each Service

Test each service: deploy → verify pods running → verify connectivity → undeploy → verify clean removal.

**Suggested order** (dependencies first):

1. **whoami** — simplest, baseline test
2. **nginx** — core web server
3. **postgresql** — required by authentik, openwebui, litellm, unity-catalog
4. **redis** — required by authentik
5. **mysql** — standalone database
6. **mongodb** — standalone database
7. **qdrant** — standalone vector database
8. **elasticsearch** — standalone search
9. **rabbitmq** — standalone queue
10. **authentik** — depends on postgresql + redis
11. **openwebui** — depends on postgresql
12. **litellm** — depends on postgresql
13. **prometheus** — monitoring, standalone
14. **grafana** — monitoring, standalone
15. **loki** — monitoring, standalone
16. **tempo** — monitoring, standalone
17. **otel-collector** — monitoring, standalone
18. **argocd** — management
19. **jupyterhub** — data science
20. **spark** — data science
21. **unity-catalog** — data science, depends on postgresql

Skip for now (require external accounts or broken):
- **tailscale-tunnel** — requires Tailscale auth key
- **cloudflare-tunnel** — requires Cloudflare token
- **gravitee** — was broken before migration

### Phase 3: Stack Tests

After individual verification, test deploying full stacks:
- Observability stack: prometheus + grafana + loki + tempo + otel-collector
- AI stack: openwebui + litellm
- Data science stack: jupyterhub + spark + unity-catalog

## Open Questions

1. **Should we test via the tester workflow?** The tester at `testing/uis1/` has been effective. A factory reset test would need the tester to actually reset their Rancher Desktop.

2. **How long does a full cycle take?** Deploying all 21 testable services sequentially could take a long time. Can we parallelize or batch?

3. **What about data persistence?** After reset, PVs are gone. Services like PostgreSQL start fresh. Is that the expected behavior for a developer platform?

4. **The `enabled-services.conf` default only has nginx.** After reset, `./uis deploy` only deploys nginx. For full verification, we need to either enable all services or deploy them individually.

5. **The legacy `install-rancher.sh` vs modern `./uis` path** — which should we standardize on? The `install-rancher.sh` script checks for existing containers and may conflict.
