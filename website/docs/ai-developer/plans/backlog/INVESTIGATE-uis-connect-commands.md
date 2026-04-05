# Investigate: UIS Connect Commands for All Services

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Design and build `uis connect <service>` commands that open interactive clients into deployed services without requiring clients in the uis-provision-host image.

**Priority**: Low — the pod-exec fallback works; shell commands are a convenience.

**Last Updated**: 2026-04-05

**Related**:
- [PLAN-002-uis-template-command.md](../active/PLAN-002-uis-template-command.md) — initial `uis connect` with 4 services (postgresql, mysql, redis, mongodb) landed here
- [PLAN-001-uis-configure-expose.md](../completed/PLAN-001-uis-configure-expose.md) — same pod-exec pattern used by `uis configure`

---

## Problem

Testers and developers often need to verify deployments by querying the service directly. Each service has a native client (psql, mysql, redis-cli, mongosh, etc.), but:

1. **We can't bake every client into `uis-provision-host`** — postgresql-client, mysql-client, mongosh, redis-tools, etc. add 50-200MB combined. And we'd need to keep them updated with each service version.

2. **The host machine may not have clients installed** — macOS doesn't ship with psql, developers don't always want to install DB clients globally.

3. **Every service pod already has its own native client** — that's how `uis configure` works internally. We just need to expose that pattern.

## Initial Implementation (in PLAN-002)

A minimal `uis connect <service>` command was added with 4 services:

```bash
uis connect postgresql              # psql as admin
uis connect postgresql demo_db      # psql into specific database
uis connect mysql                   # mysql as root
uis connect redis                   # redis-cli with auth
uis connect mongodb                 # mongosh as root
```

Implementation: `provision-host/uis/lib/shell.sh` uses a lookup table (`SHELL_CONFIG`) mapping service → pod selector, namespace, client command, secret key for admin password.

## Open Design Questions

1. **Coverage** — which services need connects? Data services (postgresql, mysql, mongodb, redis, elasticsearch, qdrant) are obvious. What about:
   - **Observability**: grafana (has a CLI), prometheus (promtool), loki (logcli)?
   - **Messaging**: rabbitmq (rabbitmqctl)?
   - **Search**: elasticsearch (via curl), qdrant (via curl)?
   - **Auth**: authentik (Django shell)?

2. **Non-shell services** — some services don't have interactive clients (web-only admin like pgAdmin, Grafana). For these, `uis connect` could:
   - Return an error "use the web UI at http://grafana.localhost"
   - Run a generic `sh`/`bash` shell in the pod for debugging
   - Open a `curl`-based query prompt

3. **Admin vs app-user credentials** — currently all connects connect as the service admin (postgres, root, etc.). Should there be:
   - `uis connect postgresql --as demo_app` to connect as an app user (requires stored password)
   - Default to admin (simpler, always works)

4. **Data source for SHELL_CONFIG** — currently hardcoded in shell.sh. Could be moved to `services.json` as a `shell` field per service:
   ```json
   {
     "id": "postgresql",
     "shell": {
       "selector": "app.kubernetes.io/name=postgresql",
       "namespace": "default",
       "client": "psql -U postgres",
       "secret": "PGPASSWORD"
     }
   }
   ```
   This makes adding connects for new services a metadata change, not a code change.

5. **Pod entrypoint vs direct command** — for some services, the client binary is at a specific path or needs environment setup. Do we always `exec -it pod -- <client>`, or sometimes `exec -it pod -- sh -c "source env && <client>"`?

## Candidate Services to Add

After the initial 4 services (postgresql, mysql, mongodb, redis), candidates in priority order:

| Service | Client | Priority | Notes |
|---------|--------|----------|-------|
| elasticsearch | curl + Elasticsearch API | High | No interactive CLI, need curl wrapper |
| qdrant | curl + Qdrant API | High | Same — curl-based |
| rabbitmq | rabbitmqctl | Medium | Built into pod |
| authentik | ak (Django management) | Medium | Admin-only commands |
| nginx | shell | Low | Just for debugging |

## Related Convenience Commands

If we build connects, other similar commands may follow:
- `uis logs <service>` — kubectl logs for the service pod
- `uis describe <service>` — kubectl describe for debugging
- `uis port <service>` — alias for `uis expose`

These could all share a common `uis service <verb>` namespace in the future.

## Next Steps

- [ ] Decide on coverage (which services get connects)
- [ ] Decide on config source (hardcoded vs services.json)
- [ ] Decide on elasticsearch/qdrant approach (curl wrapper vs skip)
- [ ] Create PLAN when scope is clear
