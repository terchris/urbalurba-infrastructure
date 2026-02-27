---
title: Identity
sidebar_label: Identity
---

# Identity

The identity package provides authentication and authorization for all protected services in UIS. It is built on Authentik with the Auth10 extension for automated multi-domain configuration.

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [Authentik](./authentik.md) | Identity provider with SSO, MFA, and proxy auth | `./uis deploy authentik` |

## Quick Start

```bash
./uis deploy postgresql   # Required dependency
./uis deploy redis        # Required dependency
./uis deploy authentik
```

## How It Works

1. **Authentik** handles all authentication via OAuth2/OIDC, SAML, and proxy auth
2. **Auth10** automatically generates multi-domain OAuth configurations from templates
3. **Forward-auth middleware** in Traefik checks authentication before allowing access
4. Protected services get SSO — users log in once and access everything

Access the admin interface at [http://authentik.localhost/if/admin/](http://authentik.localhost/if/admin/).

## Guides

- [Auth10 system design](./auth10.md) — template-driven authentication configuration
- [Developer guide](./developer-guide.md) — how to protect new services
- [Blueprint syntax](./blueprints-syntax.md) — Authentik blueprint reference
- [Technical implementation](./technical-implementation.md) — architecture details
- [Test users](./test-users.md) — default credentials for development
