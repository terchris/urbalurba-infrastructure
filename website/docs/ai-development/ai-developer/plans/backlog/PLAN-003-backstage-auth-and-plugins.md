# PLAN-003: Backstage Authentik Integration and TechDocs

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Add optional Authentik OIDC authentication and TechDocs plugin to Backstage

**Last Updated**: 2026-03-12

**Investigation**: [INVESTIGATE-backstage.md](INVESTIGATE-backstage.md)

**Prerequisites**: PLAN-002-backstage-deployment must be complete (Backstage must be running)

**Priority**: Low — optional, Backstage works without auth

---

## Overview

This plan adds two optional enhancements to the Backstage deployment from PLAN-002:

1. **Authentik OIDC** — SSO login via the existing Authentik identity provider (if deployed)
2. **TechDocs** — documentation rendering plugin (when developer-written docs become relevant)

Both are optional. Backstage works without authentication on local clusters. The Grafana plugin is already included in PLAN-002 as a required plugin.

### Reference services

- **OpenWebUI** (`200-*`) — reference for Authentik OIDC integration pattern
- **Authentik blueprint** (`073-authentik-2-openwebui-blueprint.yaml`) — pattern for creating OAuth2 provider

---

## Phase 1: Authentik OIDC Integration

Add OIDC authentication so users log in via Authentik.

### Tasks

- [ ] 1.1 Create Authentik blueprint `manifests/073-authentik-3-backstage-blueprint.yaml` — OAuth2/OIDC provider and application for Backstage
- [ ] 1.2 Add OIDC secrets to `provision-host/uis/templates/secrets-templates/00-common-values.env.template` (client ID, client secret)
- [ ] 1.3 Update `manifests/650-backstage-config.yaml` — add OIDC auth provider configuration (conditional — only active when Authentik secrets are present)
- [ ] 1.4 Update `ansible/playbooks/650-setup-backstage.yml` — apply Authentik blueprint if Authentik is deployed
- [ ] 1.5 Add OIDC test to `ansible/playbooks/650-test-backstage.yml`

### Implementation Details

**1.1 Authentik blueprint** — follows the OpenWebUI pattern (`073-authentik-2-openwebui-blueprint.yaml`):
- Create OAuth2/OIDC Provider: `backstage`
- Create Application: `backstage`
- Redirect URI: `http://backstage.localhost:7007/api/auth/oidc/handler/frame`
- Scopes: `openid`, `email`, `profile`

**1.3 OIDC config** — add to Helm values:
```yaml
auth:
  providers:
    oidc:
      development:
        metadataUrl: http://authentik-server.authentik.svc.cluster.local/application/o/backstage/.well-known/openid-configuration
        clientId: ${AUTH_OIDC_CLIENT_ID}
        clientSecret: ${AUTH_OIDC_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: emailMatchingUserEntityProfileEmail
```

**Important:** RHDH's Keycloak plugin and the generic OIDC provider both work with Authentik. The exact provider choice (keycloak vs generic oidc) should be verified during implementation.

**Conditional activation:** The setup playbook should check if Authentik is deployed before applying the blueprint. If Authentik is not deployed, Backstage continues to work with guest access.

### Validation

- [ ] With Authentik deployed: users can log in via OIDC
- [ ] Without Authentik: Backstage still works with guest access
- [ ] Verify test confirms OIDC when available

---

## Phase 2: TechDocs (When Needed)

Add TechDocs plugin for developer-written documentation alongside integration code.

### Tasks

- [ ] 2.1 Add TechDocs plugin to `dynamic-plugins.yaml` in the Helm values
- [ ] 2.2 Test documentation rendering for at least one service

### Implementation Details

**Dynamic plugins** — RHDH adds plugins via config, no image rebuild:

```yaml
# In 650-backstage-config.yaml Helm values
global:
  dynamic:
    plugins:
      - package: "@backstage/plugin-techdocs"
        disabled: false
```

### Validation

- [ ] TechDocs page renders for at least one service
- [ ] Plugin loads without errors in Backstage logs

---

## Phase 3: Cleanup

### Tasks

- [ ] 3.1 Update `INVESTIGATE-backstage.md` — note PLAN-003 is complete
- [ ] 3.2 Update documentation page `website/docs/packages/management/backstage.md` — add auth and TechDocs sections
- [ ] 3.3 Move this plan to `completed/`

### Validation

User confirms status updates are correct.

---

## Acceptance Criteria

- [ ] Authentik OIDC login works when Authentik is deployed
- [ ] Backstage still works without Authentik (guest access)
- [ ] TechDocs plugin is functional (when enabled)
- [ ] No image rebuild was required (all via dynamic plugin config)
- [ ] Documentation updated with auth and TechDocs details

---

## Files to Create

| File | Type |
|------|------|
| `manifests/073-authentik-3-backstage-blueprint.yaml` | Authentik blueprint |

## Files to Modify

| File | Change |
|------|--------|
| `manifests/650-backstage-config.yaml` | Add OIDC provider config and TechDocs plugin |
| `provision-host/uis/templates/secrets-templates/00-common-values.env.template` | Add OIDC client ID/secret |
| `ansible/playbooks/650-setup-backstage.yml` | Apply Authentik blueprint conditionally |
| `ansible/playbooks/650-test-backstage.yml` | Add OIDC test |
| `website/docs/packages/management/backstage.md` | Add auth and TechDocs sections |
