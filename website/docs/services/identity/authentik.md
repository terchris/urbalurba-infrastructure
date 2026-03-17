---
title: Authentik
sidebar_label: Authentik
---

# Authentik

Open-source identity provider with SSO, MFA, and automated multi-domain authentication.

| | |
|---|---|
| **Category** | Identity |
| **Deploy** | `./uis deploy authentik` |
| **Undeploy** | `./uis undeploy authentik` |
| **Depends on** | postgresql, redis |
| **Required by** | None |
| **Helm chart** | `authentik/authentik` `2025.8.1` |
| **Default namespace** | `authentik` |

## What It Does

Authentik is an identity provider that handles authentication and authorization for all protected services in UIS. It supports OAuth2/OIDC, SAML, LDAP, and proxy authentication with built-in MFA.

UIS extends Authentik with the **Auth10 system** — a template-driven approach that automatically generates multi-domain authentication configurations. Instead of manually creating OAuth providers in the Authentik UI for each service and domain combination, Auth10 renders Jinja2 templates during deployment to produce Authentik blueprints that configure everything automatically.

Key capabilities:
- **Single Sign-On** across all protected services (one login for everything)
- **Multi-domain support** — localhost, Tailscale, and Cloudflare domains configured automatically via Auth10
- **Forward-auth middleware** — Traefik forwards authentication checks to Authentik before allowing access
- **Blueprint-driven** — all configuration is declarative and version-controlled, not manual UI clicks

## Deploy

```bash
# Deploy dependencies first
./uis deploy postgresql
./uis deploy redis

# Deploy Authentik
./uis deploy authentik
```

Deployment takes several minutes as it sets up the database schema, creates the admin user, and applies all blueprints.

## Verify

```bash
# Quick check
./uis verify authentik

# Manual check
kubectl get pods -n authentik

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://authentik.localhost/if/flow/initial-setup/
# Expected: 200
```

Access the admin interface at [http://authentik.localhost/if/admin/](http://authentik.localhost/if/admin/).

## Configuration

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_AUTHENTIK_SECRET_KEY` | `.uis.secrets/secrets-config/default-secrets.env` | Internal encryption key |
| `DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD` | `.uis.secrets/secrets-config/default-secrets.env` | Initial admin password |
| `DEFAULT_ADMIN_EMAIL` | `.uis.secrets/secrets-config/default-secrets.env` | Admin user email |

### Protected Services (Auth10)

To protect a service with Authentik authentication, add it to the `protected_services` section in `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`:

```yaml
protected_services:
  - name: whoami
    host: whoami
```

Auth10 automatically creates OAuth providers and forward-auth middleware for each service across all configured domains.

### Key Files

| File | Purpose |
|------|---------|
| `manifests/075-authentik-config.yaml` | Helm values (AUTHENTIK_HOST, CSRF origins) |
| `manifests/076-authentik-csp-middleware.yaml` | CSP headers for external HTTPS domains |
| `ansible/playbooks/070-setup-authentik.yml` | Deployment playbook with blueprint rendering |
| `ansible/playbooks/070-remove-authentik.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy authentik
```

This removes Authentik but preserves PostgreSQL and Redis. Protected services will lose authentication — they'll either become publicly accessible or return errors depending on their middleware configuration.

## Troubleshooting

**Pods stuck in CrashLoopBackOff:**
Usually a database connection issue. Check that PostgreSQL and Redis are running:
```bash
kubectl get pods -n default -l app.kubernetes.io/name=postgresql
kubectl get pods -n default -l app.kubernetes.io/name=redis
kubectl logs -n authentik -l app.kubernetes.io/name=authentik --tail=20
```

**Login fails with default credentials:**
Default credentials are set from `DEFAULT_ADMIN_EMAIL` and `DEFAULT_AUTHENTIK_BOOTSTRAP_PASSWORD` in your secrets. Check:
```bash
./uis secrets status
```

**Protected service returns 500 after Authentik redeploy:**
The OAuth provider configuration may have changed. Restart the affected service or check that the forward-auth middleware is pointing to the correct Authentik endpoint:
```bash
kubectl get middleware -A | grep authentik
```

**External domain shows mixed content errors:**
The CSP middleware (`076-authentik-csp-middleware.yaml`) adds `upgrade-insecure-requests` to fix this. Verify it's applied:
```bash
kubectl get middleware -n authentik authentik-csp-headers
```

**Blueprints not applying:**
Check blueprint status in the Authentik admin UI under System > Blueprints, or check logs:
```bash
kubectl logs -n authentik -l app.kubernetes.io/name=authentik -c authentik-server --tail=50 | grep -i blueprint
```

## Learn More

- [Official Authentik documentation](https://goauthentik.io)
- [Auth10 system design](./auth10.md)
- [Auth10 developer guide](./developer-guide.md)
- [Blueprint syntax reference](./blueprints-syntax.md)
- [Technical implementation details](./technical-implementation.md)
- [Test users and credentials](./test-users.md)
