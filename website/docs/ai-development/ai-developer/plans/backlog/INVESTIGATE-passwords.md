# INVESTIGATE: Password Architecture

## Problem

The password system has a design mismatch between two files that serve different roles.

## Current State

### Template (user-facing, production path)

File: `provision-host/uis/templates/secrets-templates/00-common-values.env.template`

Uses 2 master passwords with inheritance:

| Master Variable | Cascades To |
|----------------|-------------|
| `DEFAULT_ADMIN_PASSWORD` | `ADMIN_PASSWORD`, `AUTHENTIK_BOOTSTRAP_PASSWORD`, `JUPYTERHUB_AUTH_PASSWORD` |
| `DEFAULT_DATABASE_PASSWORD` | `PGPASSWORD`, `MYSQL_ROOT_PASSWORD`, `MONGODB_ROOT_PASSWORD`, `RABBITMQ_PASSWORD` |

Change one master password, all downstream services update. Clean design.

### Development Defaults (zero-config path)

File: `provision-host/uis/templates/default-secrets.env`

Uses 8 independent passwords that do NOT cascade:

```
DEFAULT_ADMIN_PASSWORD=LocalDev123
DEFAULT_DATABASE_PASSWORD=LocalDevDB456
DEFAULT_DATABASE_ROOT_PASSWORD=LocalDevRoot789
DEFAULT_REDIS_PASSWORD=LocalDevRedis123
DEFAULT_MONGODB_ROOT_PASSWORD=LocalDevMongo123
DEFAULT_POSTGRES_PASSWORD=LocalDevPostgres123
DEFAULT_AUTHENTIK_SECRET_KEY=LocalDevAuthentikSecret123
DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD=LocalDevAuthentik123
DEFAULT_OPENWEBUI_SECRET_KEY=LocalDevOpenWebUI123
```

These are all different values. They don't reference each other.

## Questions to Resolve

1. Should `default-secrets.env` follow the same inheritance pattern as the template?
2. Do we need separate `DEFAULT_POSTGRES_PASSWORD` vs `DEFAULT_DATABASE_PASSWORD` vs `DEFAULT_DATABASE_ROOT_PASSWORD`? What does each one actually map to?
3. Which passwords does each service actually consume? Trace the full flow: `default-secrets.env` -> secrets generation -> Kubernetes secrets -> Helm values -> running service.
4. Are any of these 8+ passwords unused or redundant?
5. Is `REDIS_PASSWORD` in the template (set to `YourRedisPassword123`) related to `DEFAULT_REDIS_PASSWORD` in the defaults (set to `LocalDevRedis123`)? They don't share a name pattern.

## Password Restriction

These characters must NOT be used in any password: `!  $  \`  \  "`

Bitnami Helm charts pass passwords through bash during container initialization, which escapes these characters. For example, `Pass!` becomes `Pass\!` in the database, causing authentication failures.

## Related Files

- `provision-host/uis/templates/default-secrets.env` - development defaults
- `provision-host/uis/templates/secrets-templates/00-common-values.env.template` - user template
- `provision-host/uis/lib/secrets-management.sh` - generation logic
- `provision-host/uis/lib/first-run.sh` - sed replacements for defaults
- `provision-host/uis/templates/uis.secrets/README.md` - user documentation

## Context

Discovered during PLAN-007 (Authentik Automatic Secrets) testing when `!` in passwords caused PostgreSQL authentication failures. The password restriction is documented but the overall architecture needs review to ensure the two files are consistent and no passwords are orphaned.
