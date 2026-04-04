---
title: Init File Formats
sidebar_label: Init File Formats
sidebar_position: 6
---

# Init File Formats for `uis configure`

When a template declares a `requires` entry with an `init` field, the referenced file is passed to `uis configure` and applied to the running service. Init files must use the **native format** of the target service — UIS passes them directly to the service's own tooling with no translation layer.

This page documents the expected format for each configurable service, with links to upstream documentation.

## General rules

- Init files are **data only** — never executable code
- Use the service's native format — no custom schemas
- DCT substitutes all `{{ params.* }}` references before passing the file to UIS (see [11UIS](https://github.com/helpers-no/dev-templates))
- UIS receives fully resolved data files
- Init files are applied via stdin: `uis-bridge configure <service> --init-file - < file`

## PostgreSQL

**Format:** Standard SQL

**Applied with:** `psql --set ON_ERROR_STOP=on -f -` (stops on first error)

**Upstream docs:** [PostgreSQL SQL Commands](https://www.postgresql.org/docs/current/sql.html)

### Example

```sql
-- Init file for a volunteer management app
-- Applied by: uis configure postgresql --init-file -

CREATE TABLE IF NOT EXISTS volunteers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assignments (
    id SERIAL PRIMARY KEY,
    volunteer_id INTEGER REFERENCES volunteers(id),
    role VARCHAR(100) NOT NULL,
    location VARCHAR(255),
    start_date DATE,
    end_date DATE
);

CREATE INDEX IF NOT EXISTS idx_volunteers_email ON volunteers(email);
CREATE INDEX IF NOT EXISTS idx_assignments_volunteer ON assignments(volunteer_id);

-- Seed data for development
INSERT INTO volunteers (name, email, status) VALUES
    ('Test User', 'test@example.com', 'active')
ON CONFLICT (email) DO NOTHING;
```

### Tips

- Use `IF NOT EXISTS` / `IF NOT EXISTS` for idempotency — the init file may be re-applied
- Use `ON CONFLICT DO NOTHING` for seed data
- Keep init files focused — schema + seed data, not application logic
- The psql user is the app user created by `uis configure`, not the admin user

## Authentik

**Format:** Authentik Blueprint YAML (version 1)

**Applied with:** Authentik Blueprint API

**Upstream docs:** [Authentik Blueprints](https://docs.goauthentik.io/docs/blueprints/)

### Example

```yaml
# yaml-language-server: $schema=https://goauthentik.io/blueprints/schema.json
version: 1
metadata:
  name: "Volunteer App Setup"
  labels:
    blueprints.goauthentik.io/instantiate: "true"

entries:
  - model: authentik_core.group
    state: present
    identifiers:
      name: "volunteers"
    attrs:
      name: "volunteers"
      is_superuser: false

  - model: authentik_core.user
    state: present
    identifiers:
      username: "testuser"
    attrs:
      username: "testuser"
      name: "Test User"
      email: "test@example.com"
      password: "Password123"
      is_active: true
      groups:
        - !Find [authentik_core.group, [name, "volunteers"]]
```

### Tips

- Use the `$schema` comment for editor validation
- Use `!Find` to reference groups by name instead of hardcoding IDs
- Use `state: present` for idempotency — existing entries are updated, not duplicated
- See UIS's `manifests/073-authentik-1-test-users-groups-blueprint.yaml` for a full example with 11 users

## Grafana

**Format:** Grafana Dashboard JSON (export format)

**Applied with:** Grafana Dashboard HTTP API

**Upstream docs:** [Grafana Dashboard API](https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/)

### How to create

1. Build your dashboard in Grafana UI
2. Export as JSON: Dashboard settings > JSON Model > Copy
3. Save as `config/grafana-dashboards.json` in your template

### Tips

- Export from a working Grafana instance for correct JSON structure
- Remove `id` and set `uid` to null for portability — Grafana assigns new IDs on import
- Handler not yet implemented — see PLAN-001-uis-configure-expose Phase 4

## Redis

**Format:** TBD — will be defined when the Redis configure handler is implemented.

Likely approach: Redis commands file or a YAML definition of key prefixes/namespaces.

**Upstream docs:** [Redis Commands](https://redis.io/docs/latest/commands/)

## MongoDB

**Format:** TBD — will be defined when the MongoDB configure handler is implemented.

Likely approach: JavaScript file for `mongosh` or JSON definitions.

**Upstream docs:** [MongoDB CRUD Operations](https://www.mongodb.com/docs/manual/crud/)

## MySQL

**Format:** Standard SQL (same pattern as PostgreSQL)

**Applied with:** `mysql` CLI

**Upstream docs:** [MySQL SQL Statements](https://dev.mysql.com/doc/refman/8.0/en/sql-statements.html)

### Tips

- Same principles as PostgreSQL: use `IF NOT EXISTS`, keep it idempotent
- Handler not yet implemented — see PLAN-001-uis-configure-expose Phase 4

## RabbitMQ

**Format:** RabbitMQ Definitions JSON (export format)

**Applied with:** RabbitMQ Management API (`/api/definitions`)

**Upstream docs:** [RabbitMQ Definitions](https://www.rabbitmq.com/docs/definitions)

### How to create

1. Configure queues/exchanges in RabbitMQ Management UI
2. Export definitions: Overview > Export definitions > Download
3. Save as `config/rabbitmq-setup.json` in your template

### Tips

- The definitions format includes queues, exchanges, bindings, and policies
- Import is idempotent — existing resources are updated
- Handler not yet implemented — see PLAN-001-uis-configure-expose Phase 4
