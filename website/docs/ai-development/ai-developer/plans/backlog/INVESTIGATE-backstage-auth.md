# Investigate: Backstage Authentik OIDC Authentication

> **IMPLEMENTATION RULES:** Before implementing this plan, read and follow:
> - [WORKFLOW.md](../../WORKFLOW.md) - The implementation process
> - [PLANS.md](../../PLANS.md) - Plan structure and best practices

## Status: Backlog

**Goal**: Investigate adding Authentik OIDC authentication to Backstage (replacing guest access)

**Last Updated**: 2026-03-13

**Parent investigation**: [INVESTIGATE-backstage.md](INVESTIGATE-backstage.md)

**Prerequisites**: Backstage deployed (PLAN-002 complete), Authentik deployed

**Priority**: Low — guest access works fine for local development. Auth becomes relevant when Backstage is exposed externally or per-user permissions are needed.

**Previously**: This was PLAN-003. Downgraded to investigation because the scope is complex (Authentik blueprints, conditional activation, multi-domain considerations) and guest access is sufficient for current use.

---

## Overview

Add Authentik OIDC authentication to Backstage so users log in via SSO instead of guest access.

Backstage currently works with guest access on local clusters. OIDC becomes relevant when:
- Backstage is exposed externally (via Cloudflare/Tailscale tunnel)
- Per-user permissions are needed (RBAC based on Authentik groups)
- Audit logging of who accessed what is required

### Reference services

- **OpenWebUI** (`200-*`) — reference for Authentik OIDC integration pattern
- **Authentik blueprint** (`073-authentik-2-openwebui-blueprint.yaml`) — pattern for creating OAuth2 provider

### Authentik OIDC Configuration

RHDH ships with a Keycloak/OIDC plugin that works with any OIDC-compliant provider, including Authentik:

```yaml
# app-config.yaml snippet
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

**Note:** RHDH's Keycloak plugin and the generic OIDC provider both work with Authentik since it is fully OIDC-compliant. The exact provider choice (keycloak vs generic oidc) should be verified during implementation.

**Authentik setup required:**
- Create an OAuth2/OpenID Provider and Application in Authentik
- Set redirect URI to `http://backstage.localhost:7007/api/auth/oidc/handler/frame`
- This follows the same pattern as the existing OpenWebUI OAuth setup (see `073-authentik-2-openwebui-blueprint.yaml`)

**Secrets needed:**
```bash
# Add to 00-common-values.env.template
BACKSTAGE_OIDC_CLIENT_ID=backstage
BACKSTAGE_OIDC_CLIENT_SECRET=generate-a-secret-here
```

### Multi-domain considerations

If Backstage is exposed on an external domain (e.g., `backstage.urbalurba.no`), the same challenges apply as with other protected services — see the CSP middleware solution in `076-authentik-csp-middleware.yaml` and the domain addition limitations documented in [INVESTIGATE-backstage.md](INVESTIGATE-backstage.md).

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

## Questions to Answer

1. **Keycloak vs generic OIDC provider** — RHDH has both. Which works better with Authentik?
2. **Conditional activation** — How to gracefully handle Backstage config when Authentik is not deployed? (Skip OIDC secrets, fall back to guest)
3. **Group mapping** — Can Authentik groups be mapped to Backstage teams via OIDC group claims?
4. **Multi-domain** — Does the OIDC redirect URI work for both `backstage.localhost` and external domains?

---

## Acceptance Criteria

- [ ] Authentik OIDC login works when Authentik is deployed
- [ ] Backstage still works without Authentik (guest access)
- [ ] No image rebuild was required (all via dynamic plugin config)

---

## Files to Create

| File | Type |
|------|------|
| `manifests/073-authentik-3-backstage-blueprint.yaml` | Authentik blueprint |

## Files to Modify

| File | Change |
|------|--------|
| `manifests/650-backstage-config.yaml` | Add OIDC provider config |
| `provision-host/uis/templates/secrets-templates/00-common-values.env.template` | Add OIDC client ID/secret |
| `ansible/playbooks/650-setup-backstage.yml` | Apply Authentik blueprint conditionally |
| `ansible/playbooks/650-test-backstage.yml` | Add OIDC test |
