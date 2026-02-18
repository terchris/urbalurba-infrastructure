# INVESTIGATE: Authentik User Config Migration

**Status:** Investigation Complete — Ready for PLAN
**Created:** 2026-01-28 (split from INVESTIGATE-authentik-automation)
**Last Updated:** 2026-01-31
**Related to:** [INVESTIGATE-authentik-auto-deployment](../completed/INVESTIGATE-authentik-auto-deployment.md) (completed), Auth10 System
**Depends on:** None — can be implemented independently

---

## Problem Statement

User-configurable Authentik data (test users, domains, protected services, OAuth apps) is hardcoded in `manifests/` where users shouldn't be editing files. This data should live in `.uis.extend/` so users can customize their setup without touching infrastructure code.

### Current State: User Data in Manifests

| File | Contains | Should User Edit? |
|------|----------|-------------------|
| `073-authentik-1-test-users-groups-blueprint.yaml` | Test users, passwords, groups (727 lines) | Yes — org specific |
| `073-authentik-2-openwebui-blueprint.yaml` | OAuth client config | Yes — app specific |
| `073-authentik-3-app-slot1-blueprint.yaml` | Placeholder app config | Yes — future apps |
| `073-authentik-service-protection-blueprint.yaml` | Protected services list | Yes — which services |
| `075-authentik-config.yaml.j2` | Helm values template | No — infrastructure |
| `076-authentik-ingressroute.yaml.j2` | Routing template | No — infrastructure |

### What Moves Where

| Current Location | New Location | Reason |
|------------------|--------------|--------|
| `manifests/073-authentik-1-test-users-groups-blueprint.yaml` | `.uis.extend/authentik/test-users.yml` | User defines their test users |
| `AUTH10_PROTECTED_SERVICES` (in secrets) | `.uis.extend/authentik/protected-services.yml` | Not secret, just config |
| `AUTH10_DOMAINS` (in secrets) | `.uis.extend/authentik/domains.yml` | Not secret, just config |
| OAuth client IDs (in secrets) | Keep in `.uis.secrets/` | Sensitive |
| OAuth client secrets (in secrets) | Keep in `.uis.secrets/` | Sensitive |

---

## Design Decisions

### Q1: Where does service configuration go?

**Decision:** In `.uis.extend/` alongside enabled services.

Two folders total:
- `.uis.extend/` = WHAT to deploy + HOW to configure (non-sensitive)
- `.uis.secrets/` = sensitive values only (passwords, keys)

Simpler mental model: "edit `.uis.extend/` to customize your setup"

### Q2: How does config get into the playbook?

**Decision:** Part of generation pipeline.

The secrets generation already combines templates → output. Extend this to:
1. Read config from `.uis.extend/authentik/`
2. Read secrets from `.uis.secrets/secrets-config/`
3. Generate blueprint YAML into `.uis.secrets/generated/kubernetes/`
4. Playbook applies the generated file

This keeps the playbook simple — it just applies generated files.

### Q3: Should test users be optional?

**Decision:** Test users deploy by default.

Rationale:
- Proves the system works out-of-box
- Developers can immediately test authentication flows
- Users customize later by editing `.uis.extend/authentik/test-users.yml`
- Empty file or `enabled: false` would skip test users

### Q4: Auth10 config location

**Decision:** Move non-secret Auth10 config to `.uis.extend/`

Current (in kubernetes-secrets.yml — not actually secret):
```yaml
AUTH10_DOMAINS: |           # ← Not a secret
AUTH10_PROTECTED_SERVICES:  # ← Not a secret
```

Target:
```
.uis.extend/authentik/
├── domains.yml             ← Move AUTH10_DOMAINS here
├── protected-services.yml  ← Move AUTH10_PROTECTED_SERVICES here
└── test-users.yml          ← New: test user definitions
```

---

## Target Architecture

### File Structure

```
.uis.extend/                                    ← User's deployment config
├── enabled-services.conf                       ← Which services to deploy
├── hosts/                                      ← Host definitions
└── authentik/                                  ← NEW: Authentik configuration
    ├── domains.yml                             ← Domain definitions
    ├── protected-services.yml                  ← Which services need auth
    ├── test-users.yml                          ← Test users and groups
    └── applications/                           ← OAuth application configs
        ├── openwebui.yml
        └── app-slot1.yml

.uis.secrets/                                   ← Sensitive data only
├── secrets-config/                             ← Templates with passwords
│   ├── 00-common-values.env.template           ← Has AUTHENTIK_TEST_USER_PASSWORD
│   └── 12-auth-secrets.yml.template            ← Authentik secrets
└── generated/kubernetes/                       ← Generated output
    └── kubernetes-secrets.yml                  ← Includes generated blueprints

manifests/                                      ← Infrastructure templates (don't edit)
├── 073-authentik-test-users-blueprint.yaml.j2  ← Template, reads from .uis.extend
├── 073-authentik-app-blueprint.yaml.j2         ← Template for OAuth apps
└── ...
```

### Generation Flow

```
INPUTS:
  .uis.extend/authentik/test-users.yml          ← User/group definitions
  .uis.extend/authentik/domains.yml             ← Domain config
  .uis.extend/authentik/protected-services.yml  ← Which services need auth
  .uis.secrets/secrets-config/00-common-values.env.template
  manifests/073-authentik-test-users-blueprint.yaml.j2
         ↓
  Generation Script
         ↓
OUTPUT:
  .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
    - Includes namespace definitions
    - Includes secrets with real passwords
    - Includes generated blueprint ConfigMaps
         ↓
  Playbook applies file → Authentik processes blueprints
```

### Example: test-users.yml (50 lines instead of 727)

```yaml
# .uis.extend/authentik/test-users.yml
enabled: true  # Set to false to skip test users

groups:
  - name: HQ
    attributes:
      type: org_group
      scope: hq

  - name: Distrikt
    attributes:
      type: org_group
      scope: district

users:
  - username: ok1
    name: "Ola Nordmann"
    email: "ok1@urbalurba.no"
    groups: [HQ]
    attributes:
      department: "Økonomi og administrasjon"
      title: "Økonomi- og administrasjonsmedarbeider"

  - username: it1
    name: "Erik Larsen"
    email: "it1@urbalurba.no"
    groups: [HQ]
    attributes:
      department: "IT"
      title: "IT Specialist"
```

Password comes from `.uis.secrets/secrets-config/00-common-values.env.template`:
```bash
AUTHENTIK_TEST_USER_PASSWORD=Password123
```

On first run, UIS copies defaults from container to `.uis.extend/` if files don't exist.

---

## Current Auth10 Configuration (for reference)

Auth10 config is already partially in secrets — a good pattern to extend:

```yaml
# In kubernetes-secrets.yml (default namespace)
AUTH10_DOMAINS: |
  localhost:
    enabled: true
    base_domain: "localhost"
    protocol: "http"
  tailscale:
    enabled: true
    base_domain: "taile269d.ts.net"
    protocol: "https"
  cloudflare:
    enabled: true
    base_domain: "urbalurba.no"
    protocol: "https"

AUTH10_PROTECTED_SERVICES: |
  - name: whoami
    type: proxy
    description: "Whoami test service"
    domains: ["localhost", "tailscale", "cloudflare"]
```

This is rendered into blueprints via Jinja2 templates. The pattern works — it just needs to read from `.uis.extend/` instead of secrets.

---

## Authentik-Related File Inventory

**Playbooks:**
- `ansible/playbooks/070-setup-authentik.yml` — Main setup
- `ansible/playbooks/070-remove-authentik.yml` — Removal
- `ansible/playbooks/070-test-authentik-auth.yml` — E2E auth tests
- `ansible/playbooks/070-verify-authentik.yml` — Verification
- `ansible/playbooks/utility/u09-authentik-create-postgres.yml` — DB setup

**Manifests (blueprints — candidates for migration to .uis.extend):**
- `manifests/073-authentik-1-test-users-groups-blueprint.yaml` — Test users
- `manifests/073-authentik-2-openwebui-blueprint.yaml` — OpenWebUI OAuth
- `manifests/073-authentik-3-app-slot1-blueprint.yaml` — App slot
- `manifests/073-authentik-service-protection-blueprint.yaml` — Protected services (generated)

**Manifests (templates — infrastructure, stay in manifests):**
- `manifests/073-authentik-service-protection-blueprint.yaml.j2`
- `manifests/075-authentik-config.yaml.j2`
- `manifests/076-authentik-ingressroute.yaml.j2`
- `manifests/078-service-protection-ingressroute.yaml.j2`

**Manifests (static — infrastructure, stay in manifests):**
- `manifests/070-whoami-service-and-deployment.yaml`
- `manifests/071-whoami-public-ingressroute.yaml`
- `manifests/076-authentik-csp-middleware.yaml`
- `manifests/077-authentik-forward-auth-middleware.yaml`

**Secrets templates:**
- `provision-host/uis/templates/secrets-templates/12-auth-secrets.yml.template`

---

## Implementation Summary

**Files to create:**
- `.uis.extend/authentik/test-users.yml` (default config)
- `.uis.extend/authentik/domains.yml`
- `.uis.extend/authentik/protected-services.yml`
- `.uis.extend/authentik/applications/openwebui.yml`
- `manifests/073-authentik-test-users-blueprint.yaml.j2` (template version)

**Files to modify:**
- Secrets generation script to read from `.uis.extend/`
- `uis` wrapper / first-run to copy defaults on first run
- Remove hardcoded blueprints from `manifests/`

**Effort:** Medium — multiple files, extends existing generation pattern

---

## Next Step

Create a PLAN document with phased implementation tasks.

---

## Future Ideas

### Authentik CLI

Add UIS CLI commands for common Authentik admin tasks:

```bash
./uis authentik users list          # List all users
./uis authentik users create <name> # Create a user
./uis authentik groups list         # List groups
./uis authentik apps list           # List OAuth applications
```

Would use Authentik's REST API with the admin API token from secrets.

**Priority:** Nice-to-have — Authentik UI works fine, but CLI would improve developer experience.
