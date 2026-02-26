# PLAN: Fix Password Architecture — Connect Orphaned Defaults to Templates

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

**Related**: [INVESTIGATE-passwords](INVESTIGATE-passwords.md)
**Created**: 2026-02-26
**Status**: Active

**Goal**: Make `default-secrets.env` the true single source of truth — all DEFAULT_ variables must flow through to templates, and no credentials should be hardcoded in templates.

**Last Updated**: 2026-02-26

**Priority**: Medium — affects developer experience and security posture

---

## Problem Summary

The password system has a broken "single source of truth" pattern:

1. **8 of 11 DEFAULT_ variables in `default-secrets.env` are orphaned** — `copy_secrets_templates()` only applies 3 via sed (`DEFAULT_ADMIN_EMAIL`, `DEFAULT_ADMIN_PASSWORD`, `DEFAULT_DATABASE_PASSWORD`). The other 8 are sourced but never substituted.

2. **Hardcoded credentials in `00-common-values.env.template`** that should come from defaults:
   - `REDIS_PASSWORD=YourRedisPassword123` (should use `DEFAULT_REDIS_PASSWORD`)
   - `AUTHENTIK_SECRET_KEY=your-secret-key-here` (should use `DEFAULT_AUTHENTIK_SECRET_KEY`)
   - `AUTHENTIK_BOOTSTRAP_PASSWORD=SecretPassword1` (should use `DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD`)

3. **Redundant email variables** — four email variables exist but only one is used:
   - `DEFAULT_ADMIN_EMAIL` — the **only one** referenced by the master template (pgAdmin, Gravitee, Grafana, Redis Commander, Authentik)
   - `ADMIN_EMAIL` — in common-values template but never used by master template
   - `AUTHENTIK_BOOTSTRAP_EMAIL` — in common-values template but overridden by master template line 490 which uses `${DEFAULT_ADMIN_EMAIL}`
   - `DEFAULT_AUTHENTIK_BOOTSTRAP_EMAIL` — in `default-secrets.env` but never connected to anything

4. **Hardcoded credentials in `00-master-secrets.yml.template`**:
   - `redis-commander-password: "MyCustomRedisCommanderPassword999"`
   - Hardcoded Authentik OAuth client ID and secret
   - `LITELLM_PROXY_MASTER_KEY: "sk-1234567890abcdef"`

5. **Validation only checks 3 variables** — `secrets-management.sh` should validate all DEFAULT_ variables.

6. **Redundant DEFAULT_ variables** that map to the same value:
   - `DEFAULT_POSTGRES_PASSWORD` and `DEFAULT_DATABASE_PASSWORD` — templates already use `${DEFAULT_DATABASE_PASSWORD}` for PGPASSWORD
   - `DEFAULT_DATABASE_ROOT_PASSWORD` — unclear purpose, not used anywhere
   - `DEFAULT_MONGODB_ROOT_PASSWORD` — templates already use `${DEFAULT_DATABASE_PASSWORD}` for MONGODB_ROOT_PASSWORD

### Design Decision: One Admin Email

`DEFAULT_ADMIN_EMAIL` is the single email used everywhere. The master template already uses `${DEFAULT_ADMIN_EMAIL}` for pgAdmin, Grafana, Redis Commander, Gravitee, and Authentik bootstrap. The other three email variables (`ADMIN_EMAIL`, `AUTHENTIK_BOOTSTRAP_EMAIL`, `DEFAULT_AUTHENTIK_BOOTSTRAP_EMAIL`) are orphaned and will be removed.

Email validation is critical because pgAdmin crashes with an unhelpful error if the email lacks a proper domain (rejects `localhost`, `.local`).

### Design Decision: Keep Two Master Passwords

The template's inheritance pattern (2 master passwords cascading to all services) is the correct design. The fix should:
- **Keep** `DEFAULT_ADMIN_PASSWORD` and `DEFAULT_DATABASE_PASSWORD` as the two masters
- **Keep** service-specific defaults for services that genuinely need different credentials (Redis, Authentik secret key, OpenWebUI secret key)
- **Remove** redundant database-password aliases (`DEFAULT_POSTGRES_PASSWORD`, `DEFAULT_MONGODB_ROOT_PASSWORD`, `DEFAULT_DATABASE_ROOT_PASSWORD`)
- **Connect** the remaining defaults so they actually flow through

### Existing User Copies Are Safe

`copy_secrets_templates()` skips if `00-common-values.env.template` already exists — so these changes only affect **new installations**. Existing users keep their current configs.

---

## Phase 1: Clean Up `default-secrets.env` — DONE

### Tasks

- [x] 1.1 Remove redundant variables from `default-secrets.env` ✓
  - Removed `DEFAULT_DATABASE_ROOT_PASSWORD`, `DEFAULT_POSTGRES_PASSWORD`, `DEFAULT_MONGODB_ROOT_PASSWORD`, `DEFAULT_AUTHENTIK_BOOTSTRAP_EMAIL`

- [x] 1.2 Remove orphaned email variables from `00-common-values.env.template` ✓
  - Removed `ADMIN_EMAIL` and `AUTHENTIK_BOOTSTRAP_EMAIL`

- [x] 1.3 Kept 7 DEFAULT_ variables that serve real purposes ✓

---

## Phase 2: Connect Defaults to `00-common-values.env.template` — DONE

### Tasks

- [x] 2.1 Replace hardcoded values in `00-common-values.env.template` with `DEFAULT_*` variable placeholders ✓

  | Line | Current Value | Replace With |
  |------|--------------|--------------|
  | 83 | `REDIS_PASSWORD=YourRedisPassword123` | `REDIS_PASSWORD=DEFAULT_REDIS_PASSWORD` |
  | 99 | `AUTHENTIK_SECRET_KEY=your-secret-key-here` | `AUTHENTIK_SECRET_KEY=DEFAULT_AUTHENTIK_SECRET_KEY` |
  | 101 | `AUTHENTIK_BOOTSTRAP_PASSWORD=SecretPassword1` | `AUTHENTIK_BOOTSTRAP_PASSWORD=DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD` |

  Note: `AUTHENTIK_BOOTSTRAP_EMAIL` and `ADMIN_EMAIL` are removed entirely (Phase 1.2) — master template already uses `${DEFAULT_ADMIN_EMAIL}` directly.

  Note: Use the literal string `DEFAULT_*` as the **value** (not `${DEFAULT_*}` syntax) so sed can replace it.

- [x] 2.2 Add sed replacements in `first-run.sh` `copy_secrets_templates()` for all DEFAULT_ variables ✓

  ```bash
  sed -i.bak \
      -e "s/DEFAULT_ADMIN_EMAIL=.*/DEFAULT_ADMIN_EMAIL=${DEFAULT_ADMIN_EMAIL}/" \
      -e "s/DEFAULT_ADMIN_PASSWORD=.*/DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD}/" \
      -e "s/DEFAULT_DATABASE_PASSWORD=.*/DEFAULT_DATABASE_PASSWORD=${DEFAULT_DATABASE_PASSWORD}/" \
      -e "s/ADMIN_PASSWORD=.*/ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD}/" \
      -e "s/REDIS_PASSWORD=DEFAULT_REDIS_PASSWORD/REDIS_PASSWORD=${DEFAULT_REDIS_PASSWORD}/" \
      -e "s/AUTHENTIK_SECRET_KEY=DEFAULT_AUTHENTIK_SECRET_KEY/AUTHENTIK_SECRET_KEY=${DEFAULT_AUTHENTIK_SECRET_KEY}/" \
      -e "s/AUTHENTIK_BOOTSTRAP_PASSWORD=DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD/AUTHENTIK_BOOTSTRAP_PASSWORD=${DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD}/" \
      -e "s/DEFAULT_OPENWEBUI_SECRET_KEY=.*/DEFAULT_OPENWEBUI_SECRET_KEY=${DEFAULT_OPENWEBUI_SECRET_KEY}/" \
      "$common_values"
  ```

  Note: Removed `ADMIN_EMAIL` and `AUTHENTIK_BOOTSTRAP_EMAIL` sed lines — those variables no longer exist in the template.

### Validation

User confirms template variables and sed replacements are correct.

---

## Phase 3: Fix Hardcoded Credentials in Master Template — DONE

### Tasks

- [x] 3.1 Investigated hardcoded values ✓
  - `redis-commander-password` → changed to `${DEFAULT_ADMIN_PASSWORD}`
  - `LITELLM_PROXY_MASTER_KEY` → changed to `"sk-${DEFAULT_ADMIN_PASSWORD}"` (matches OPENWEBUI_OPENAI_API_KEY)
  - OAuth client ID/secret → kept as-is (matched with Authentik blueprint, not passwords)

- [x] 3.2 No new variables needed — reused existing `DEFAULT_ADMIN_PASSWORD` ✓
- [x] 3.3 Replaced hardcoded values in `00-master-secrets.yml.template` ✓

---

## Phase 4: Extend Validation — DONE

### Tasks

- [x] 4.1 Extended required_vars to all 7 DEFAULT_ variables ✓
- [x] 4.2 Added weak-password checks using `^LocalDev` pattern for all password/key variables ✓
- [x] 4.3 Added email format validation for `DEFAULT_ADMIN_EMAIL` ✓
  - Checks for `@` with text on both sides and dotted domain
  - Clear error message mentioning pgAdmin crash
  - Added validation call in `generate_secrets()` to fail early
- [x] 4.4 Updated `show_secrets_status` to show all 7 core variables ✓
- [x] 4.5 Updated masking to also mask `*SECRET*` variables ✓

---

## Phase 5: Test

### Variable → Service Map

Each variable must be tested by deploying at least one service that uses it:

| Variable | Services that use it | Test with |
|----------|---------------------|-----------|
| `DEFAULT_ADMIN_EMAIL` | pgAdmin, Grafana, Redis Commander, Gravitee, Authentik | pgadmin, grafana |
| `DEFAULT_ADMIN_PASSWORD` | pgAdmin, Grafana, ArgoCD, Authentik, JupyterHub, Unity Catalog | pgadmin, grafana |
| `DEFAULT_DATABASE_PASSWORD` | PostgreSQL (PGPASSWORD), MySQL, MongoDB, RabbitMQ, OpenWebUI, LiteLLM | postgresql |
| `DEFAULT_REDIS_PASSWORD` | Redis, Authentik (AUTHENTIK_REDIS__PASSWORD) | redis |
| `DEFAULT_AUTHENTIK_SECRET_KEY` | Authentik | authentik |
| `DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD` | Authentik | authentik |
| `DEFAULT_OPENWEBUI_SECRET_KEY` | OpenWebUI | openwebui |

### Minimum test set (covers all variables)

Deploy these 6 services in order (respecting dependencies):

1. **postgresql** — tests `DEFAULT_DATABASE_PASSWORD`
2. **redis** — tests `DEFAULT_REDIS_PASSWORD`
3. **pgadmin** — tests `DEFAULT_ADMIN_EMAIL` (email validation!) + `DEFAULT_ADMIN_PASSWORD` (needs postgresql)
4. **grafana** — tests `DEFAULT_ADMIN_EMAIL` + `DEFAULT_ADMIN_PASSWORD`
5. **authentik** — tests `DEFAULT_AUTHENTIK_SECRET_KEY` + `DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD` + `DEFAULT_REDIS_PASSWORD` (needs postgresql + redis)
6. **openwebui** — tests `DEFAULT_OPENWEBUI_SECRET_KEY` (needs postgresql)

### Tasks

#### 5A: Email validation test (negative test)

- [ ] 5A.1 Build container: `./uis build`
- [ ] 5A.2 Fresh start (tester removes existing `.uis.secrets/` to trigger first-run)
- [ ] 5A.3 Edit `DEFAULT_ADMIN_EMAIL` to `admin@localhost` in `.uis.secrets/secrets-config/00-common-values.env.template`
- [ ] 5A.4 Run `./uis secrets validate` — must fail with clear email error message
- [ ] 5A.5 Run `./uis secrets generate` — must fail with clear email error message
- [ ] 5A.6 Fix email back to `admin@example.com`

#### 5B: Secrets generation test

- [ ] 5B.1 Fresh start (tester removes existing `.uis.secrets/` to trigger first-run)
- [ ] 5B.2 Verify `00-common-values.env.template` has all defaults applied (no `DEFAULT_*` placeholder strings remaining as values)
- [ ] 5B.3 Run `./uis secrets validate` — must pass
- [ ] 5B.4 Run `./uis secrets generate` — must produce valid `kubernetes-secrets.yml`
- [ ] 5B.5 Inspect generated `kubernetes-secrets.yml` — verify passwords match the defaults from `default-secrets.env` (no leftover hardcoded values like `YourRedisPassword123` or `SecretPassword1`)

#### 5C: Deploy and verify services

- [ ] 5C.1 `./uis deploy postgresql` — verify pod running
- [ ] 5C.2 `./uis deploy redis` — verify pod running
- [ ] 5C.3 `./uis deploy pgadmin` — verify pod running (proves email is valid)
- [ ] 5C.4 `./uis deploy grafana` — verify pod running
- [ ] 5C.5 `./uis deploy authentik` — verify pod running
- [ ] 5C.6 `./uis deploy openwebui` — verify pod running
- [ ] 5C.7 `./uis list` — all 6 show Deployed

#### 5D: Undeploy all

- [ ] 5D.1 `./uis undeploy openwebui`
- [ ] 5D.2 `./uis undeploy authentik`
- [ ] 5D.3 `./uis undeploy grafana`
- [ ] 5D.4 `./uis undeploy pgadmin`
- [ ] 5D.5 `./uis undeploy redis`
- [ ] 5D.6 `./uis undeploy postgresql`
- [ ] 5D.7 `./uis list` — all 6 show Not deployed

### Validation

Tester confirms all tests pass: email validation catches bad emails, secrets generate correctly, all 6 services deploy and undeploy cleanly.

---

## Phase 6: Update Investigation

### Tasks

- [ ] 6.1 Update `INVESTIGATE-passwords.md` to Complete status with findings and link to this plan
- [ ] 6.2 Update this plan to Complete

---

## Acceptance Criteria

- [ ] `default-secrets.env` has no redundant DEFAULT_ variables
- [ ] All DEFAULT_ variables in `default-secrets.env` are applied by `copy_secrets_templates()`
- [ ] No hardcoded credentials in `00-common-values.env.template` (all come from defaults)
- [ ] No hardcoded credentials in `00-master-secrets.yml.template` (all reference variables)
- [ ] `secrets-management.sh` validates all DEFAULT_ variables
- [ ] Email validation rejects `admin@localhost` and `admin@something.local` with clear error message
- [ ] Fresh install produces working secrets
- [ ] Existing user configs are not affected

---

## Files to Modify

| File | Change |
|------|--------|
| `provision-host/uis/templates/default-secrets.env` | Remove 4 redundant variables |
| `provision-host/uis/templates/secrets-templates/00-common-values.env.template` | Remove 2 orphaned email vars, replace hardcoded values with DEFAULT_ placeholders |
| `provision-host/uis/lib/first-run.sh` | Extend sed replacements in `copy_secrets_templates()` |
| `provision-host/uis/templates/secrets-templates/00-master-secrets.yml.template` | Replace hardcoded credentials with `${VARIABLE}` |
| `provision-host/uis/lib/secrets-management.sh` | Extend validation to all DEFAULT_ variables |

## Password Restriction Reminder

These characters must NOT be used in any password: `!  $  \`  \  "`
Bitnami Helm charts pass passwords through bash during container initialization, which escapes these characters.
