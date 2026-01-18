# Authentik Blueprint Creation and Management

## Overview

This document describes the blueprint architecture for Authentik authentication in the Urbalurba infrastructure, covering both the new **Auth10 dynamic blueprint system** and the legacy **static blueprint approach**.

The Auth10 system represents a major evolution from manual blueprint creation to fully automated, configuration-driven blueprint generation that supports multi-domain authentication out of the box.

## Table of Contents

1. [Auth10 Dynamic Blueprint System](#auth10-dynamic-blueprint-system)
2. [Configuration in kubernetes-secrets.yml](#configuration-in-kubernetes-secretsyml)
3. [Template Architecture](#template-architecture)
4. [Deployment Workflow](#deployment-workflow)
5. [Adding New Services](#adding-new-services)
6. [Multi-Domain Support](#multi-domain-support)
7. [Legacy Static Blueprints](#legacy-static-blueprints)
8. [Migration Guide](#migration-guide)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Configuration](#advanced-configuration)

---

## Auth10 Dynamic Blueprint System

### What is Auth10?

Auth10 is a template-driven system that automatically generates Authentik blueprints, configurations, and routing rules based on simple YAML configuration. It solves the **external domain limitation** mentioned in previous documentation by automating the creation of multi-domain authentication providers.

### Key Benefits

- **🎯 Configuration-Driven**: Define services once, get multi-domain auth automatically
- **🌐 Multi-Domain Support**: Automatic provider creation for localhost, Tailscale, Cloudflare domains
- **🔄 Dynamic Generation**: Templates rendered during deployment, always current
- **🛡️ Outpost Integration**: Automatic provider linking to embedded outpost
- **📝 Zero Manual Steps**: No manual provider configuration in Authentik UI required
- **🚀 Scalable**: Add new services by updating configuration only

### Architecture Overview

```
kubernetes-secrets.yml (config)
    ↓
Auth10 Jinja2 Templates (.j2 files)
    ↓
Ansible Template Rendering (during deployment)
    ↓
Generated Manifests (.yaml files)
    ↓
Kubernetes Deployment
    ↓
Multi-Domain Authentication Ready
```

---

## Configuration in kubernetes-secrets.yml

### Domain Configuration

The `domains` section defines all available domains for authentication:

```yaml
# ================================================================
# DOMAIN CONFIGURATION FOR AUTH10
# ================================================================
domains:
  localhost:
    enabled: true
    base_domain: "localhost"
    protocol: "http"
    description: "Local development domain"

  tailscale:
    enabled: true
    base_domain: "dog-pence.ts.net"  # Your actual Tailscale domain
    protocol: "https"
    description: "Tailscale MagicDNS domain"

  cloudflare:
    enabled: true
    base_domain: "urbalurba.no"      # Your actual Cloudflare domain
    protocol: "https"
    description: "Cloudflare external domain"
```

#### Domain Fields

- **`enabled`**: Boolean - Whether this domain should be processed
- **`base_domain`**: String - The base domain (e.g., "localhost", "urbalurba.no")
- **`protocol`**: String - "http" or "https"
- **`description`**: String - Human-readable description for documentation

### Protected Services Configuration

The `protected_services` section defines which services should be protected with authentication:

```yaml
# ================================================================
# PROTECTED SERVICES CONFIGURATION FOR AUTH10
# ================================================================
protected_services:
  # Example: Basic proxy authentication service
  - name: whoami
    type: proxy
    description: "Whoami test service"
    domains: ["localhost", "tailscale", "cloudflare"]
    application_slug: "whoami-app"

  # Example: OAuth2/OIDC service (for future use)
  - name: grafana
    type: oauth2
    description: "Grafana monitoring dashboard"
    domains: ["localhost", "cloudflare"]
    oauth_config:
      client_id: "grafana-client-id"
      client_secret: "grafana-client-secret"
      redirect_uri: "/oauth/callback"

  # Example: Basic auth service
  - name: private-docs
    type: basic
    description: "Private documentation site"
    domains: ["localhost", "tailscale"]
```

#### Service Fields

- **`name`**: String - Service name (used for provider/application naming)
- **`type`**: String - Authentication type: `proxy`, `oauth2`, or `basic`
- **`description`**: String - Human-readable description
- **`domains`**: Array - List of domain keys this service should be available on
- **`application_slug`**: String - (Optional) Custom application slug
- **`oauth_config`**: Object - (Required for oauth2 type) OAuth configuration

#### Authentication Types

1. **`proxy`**: Forward authentication via Authentik embedded outpost
   - Best for: Services that don't have built-in OAuth support
   - Flow: Service → Authentik → Login → Service (with headers)

2. **`oauth2`**: Direct OAuth2/OIDC integration
   - Best for: Services with built-in OAuth support (Grafana, etc.)
   - Flow: Service → Authentik OAuth → Login → Service (with tokens)

3. **`basic`**: HTTP Basic Authentication
   - Best for: Simple services requiring basic protection
   - Flow: Browser basic auth dialog → Authentik verification

---

## Template Architecture

### Template Location

Auth10 templates are stored in:
```
ansible/templates/auth10/
├── 073-authentik-service-protection-blueprint.yaml.j2
├── 075-authentik-config.yaml.j2
├── 076-authentik-ingressroute.yaml.j2
├── 078-service-protection-ingressroute.yaml.j2
└── 079-basic-auth-middleware.yaml.j2
```

### Generated Files

During deployment, templates generate:

1. **Service Protection Blueprint** (`073-authentik-service-protection-blueprint.yaml`)
   - Creates Authentik providers for each service-domain combination
   - Creates applications linked to providers
   - Links all providers to embedded outpost
   - Creates property mappings for groups/roles

2. **Authentik Configuration** (`075-authentik-config.yaml`)
   - Helm values for Authentik deployment
   - Dynamic CSRF trusted origins
   - Blueprint discovery configuration

3. **Service Protection IngressRoute** (`078-service-protection-ingressroute.yaml`)
   - Traefik routing rules for protected services
   - Unified routing using HostRegexp patterns
   - Middleware linkage for authentication

### Template Variables

Templates receive these variables from `kubernetes-secrets.yml`:
- `domains`: Complete domain configuration
- `protected_services`: Array of services to protect

---

## Deployment Workflow

### Automatic Deployment

The Auth10 system is integrated into the main Authentik deployment playbook:

```bash
# Deploy complete Authentik infrastructure with Auth10
ansible-playbook ansible/playbooks/070-setup-authentik.yml -e kube_context="rancher-desktop"
```

### Deployment Steps

1. **Configuration Loading** (Step 24.1-24.3)
   - Load `kubernetes-secrets.yml`
   - Validate Auth10 configuration
   - Display loaded configuration

2. **Template Rendering** (Step 24.4-24.6)
   - Render service protection blueprint
   - Render Authentik configuration
   - Render service protection IngressRoute

3. **Blueprint Deployment** (Step 25)
   - Deploy generated blueprint before Helm
   - Ensure ConfigMap is available for mounting

4. **Authentik Deployment** (Steps 30+)
   - Deploy Authentik with generated configuration
   - Blueprint discovery and processing
   - Outpost configuration and provider linking

5. **Route Deployment** (Step 46)
   - Deploy generated IngressRoute for service protection
   - Enable multi-domain routing

---

## Adding New Services

### Step 1: Update Configuration

Add your service to `topsecret/kubernetes/kubernetes-secrets.yml`:

```yaml
protected_services:
  # Existing services...

  # New service
  - name: myapp
    type: proxy
    description: "My awesome application"
    domains: ["localhost", "cloudflare"]  # Choose relevant domains
```

### Step 2: Deploy Service

Ensure your service is deployed in Kubernetes:

```yaml
# Create your service deployment and service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: my-app:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

### Step 3: Re-run Deployment

```bash
# Re-run the Authentik playbook to generate new configuration
ansible-playbook ansible/playbooks/070-setup-authentik.yml -e kube_context="rancher-desktop"
```

### Step 4: Verify

Your service will automatically be available at:
- `http://myapp.localhost` (if localhost domain enabled)
- `https://myapp.urbalurba.no` (if cloudflare domain enabled)

All domains will require authentication and redirect to `authentik.localhost` for login.

---

## Multi-Domain Support

### How It Works

Auth10 creates separate Authentik providers for each service-domain combination:

```
Service: whoami
Domains: [localhost, tailscale, cloudflare]

Generated Providers:
├── whoami-localhost-provider (http://whoami.localhost)
├── whoami-tailscale-provider (https://whoami.dog-pence.ts.net)
└── whoami-cloudflare-provider (https://whoami.urbalurba.no)

All providers linked to: authentik Embedded Outpost
```

### Domain Resolution

- **Development**: `http://whoami.localhost` → `http://authentik.localhost`
- **Tailscale**: `https://whoami.dog-pence.ts.net` → `http://authentik.localhost`
- **Cloudflare**: `https://whoami.urbalurba.no` → `http://authentik.localhost`

### Adding New Domains

1. **Add domain configuration**:
```yaml
domains:
  # Existing domains...

  newdomain:
    enabled: true
    base_domain: "example.com"
    protocol: "https"
    description: "New external domain"
```

2. **Update services** to include the new domain:
```yaml
protected_services:
  - name: whoami
    domains: ["localhost", "tailscale", "cloudflare", "newdomain"]  # Add newdomain
```

3. **Re-deploy** to generate new providers and routing

---

## Legacy Static Blueprints

### Overview

Before Auth10, Authentik blueprints were created manually as static YAML files. This approach required:
- Manual creation of each blueprint
- Hardcoded domains and service configurations
- Manual provider configuration in Authentik UI for external domains
- Separate files for each service or configuration

### Static Blueprint Examples

#### Test Users and Groups Blueprint
```yaml
# manifests/073-authentik-1-test-users-groups-blueprint.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-users-groups-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  test-users-groups.yaml: |
    version: 1
    metadata:
      name: "Test Users and Groups"

    entries:
      # Create test groups
      - model: authentik_core.group
        state: present
        identifiers:
          name: "HQ"
        attrs:
          name: "HQ"
          users: []

      # Create test users
      - model: authentik_core.user
        state: present
        identifiers:
          username: "it1@urbalurba.no"
        attrs:
          username: "it1@urbalurba.no"
          email: "it1@urbalurba.no"
          name: "IT Bruker 1"
          groups:
            - !Find [authentik_core.group, [name, "HQ"]]
```

#### OpenWebUI OAuth Blueprint (Template-based Legacy)
```yaml
# manifests/073-authentik-2-openwebui-blueprint.yaml.j2
apiVersion: v1
kind: ConfigMap
metadata:
  name: openwebui-blueprint
  namespace: authentik
  labels:
    app.kubernetes.io/name: authentik
    app.kubernetes.io/component: blueprint
    blueprints.goauthentik.io/instantiate: "true"
data:
  openwebui.yaml: |
    version: 1
    metadata:
      name: "OpenWebUI OAuth2/OIDC"

    entries:
      # Create OAuth2 provider
      - model: authentik_providers_oauth2.oauth2provider
        state: present
        identifiers:
          name: openwebui-dev-provider
        attrs:
          name: openwebui-dev-provider
          client_type: confidential
          client_id: "{{ openwebui_oauth_client_id }}"
          client_secret: "{{ openwebui_oauth_client_secret }}"
          redirect_uris:
            - "{{ openwebui_oauth_redirect_uri }}"
```

### Limitations of Static Blueprints

1. **Manual Provider Creation**: Each external domain required manual configuration
2. **Hardcoded Values**: Domain-specific values embedded in templates
3. **Scalability Issues**: Adding services required creating new blueprint files
4. **External Domain Problem**: Providers created via blueprints weren't automatically linked to outposts
5. **Maintenance Overhead**: Multiple files to maintain for similar configurations

### When to Use Static Blueprints

Static blueprints are still appropriate for:
- **One-time configuration**: Test users, groups, flows that don't change
- **Complex custom flows**: Authentication flows requiring specific customization
- **Integration-specific config**: Service-specific OAuth providers (OpenWebUI, Grafana)
- **System configuration**: Core system settings that don't vary by service

---

## Migration Guide

### From Static to Auth10

If you have existing static blueprints for service protection:

1. **Identify Protected Services**: List services currently using static blueprints
2. **Extract Configuration**: Identify domains, authentication types, and settings
3. **Update kubernetes-secrets.yml**: Add services to `protected_services` section
4. **Remove Static Files**: Delete old static blueprint files
5. **Test Deployment**: Run Auth10 deployment and verify functionality

### Example Migration

**Before (Static)**:
```yaml
# manifests/072-authentik-myapp-blueprint.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-blueprint
data:
  myapp.yaml: |
    entries:
      - model: authentik_providers_proxy.proxyprovider
        identifiers:
          name: myapp-localhost-provider
        attrs:
          external_host: http://myapp.localhost
          internal_host: http://myapp.default.svc.cluster.local
```

**After (Auth10)**:
```yaml
# topsecret/kubernetes/kubernetes-secrets.yml
protected_services:
  - name: myapp
    type: proxy
    description: "My application"
    domains: ["localhost", "cloudflare"]
```

---

## Troubleshooting

### Common Issues

#### 1. Configuration Not Loading
```bash
# Check if kubernetes-secrets.yml is valid
ansible-playbook ansible/playbooks/070-setup-authentik.yml --syntax-check

# Verify Auth10 configuration sections exist
grep -A 10 "domains:" topsecret/kubernetes/kubernetes-secrets.yml
grep -A 10 "protected_services:" topsecret/kubernetes/kubernetes-secrets.yml
```

#### 2. Templates Not Rendering
```bash
# Check template files exist
ls -la ansible/templates/auth10/

# Verify Ansible can access templates
ansible localhost -m template -a "src=ansible/templates/auth10/073-authentik-service-protection-blueprint.yaml.j2 dest=/tmp/test.yaml" --extra-vars "@topsecret/kubernetes/kubernetes-secrets.yml"
```

#### 3. Providers Not Created
```bash
# Check blueprint application
kubectl logs -n authentik deployment/authentik-worker | grep -i blueprint

# Verify ConfigMap exists
kubectl get configmap -n authentik service-protection-blueprint -o yaml

# Check provider creation
kubectl exec -n authentik deployment/authentik-server -- python manage.py shell -c "from authentik.providers.proxy.models import ProxyProvider; print([p.name for p in ProxyProvider.objects.all()])"
```

#### 4. External Domains Not Working
```bash
# Verify outpost provider linking
kubectl logs -n authentik deployment/authentik-worker | grep -i outpost

# Check if providers are linked to outpost
# (Access Authentik admin UI to verify outpost configuration)
```

#### 5. DNS Resolution Issues
```bash
# Test domain resolution
nslookup whoami.localhost
curl -I http://whoami.localhost

# For external domains, verify tunnel/DNS configuration
curl -I https://whoami.urbalurba.no
```

### Deployment Verification

After deployment, verify Auth10 is working:

```bash
# 1. Check generated files exist
ls -la manifests/073-authentik-service-protection-blueprint.yaml
ls -la manifests/075-authentik-config.yaml
ls -la manifests/078-service-protection-ingressroute.yaml

# 2. Test localhost authentication
curl -I http://whoami.localhost
# Expected: HTTP 302 redirect to authentik.localhost

# 3. Test external domain (if tunnel active)
curl -I https://whoami.dog-pence.ts.net
# Expected: HTTP 302 redirect to authentik.localhost

# 4. Verify providers in Authentik
# Access http://authentik.localhost/if/admin/
# Check Applications → Providers for generated providers
```

---

## Advanced Configuration

### Custom OAuth2 Configuration

For services requiring OAuth2/OIDC:

```yaml
protected_services:
  - name: grafana
    type: oauth2
    description: "Grafana monitoring dashboard"
    domains: ["localhost", "cloudflare"]
    oauth_config:
      client_id: "grafana-oauth-client"
      client_secret: "super-secret-key"
      redirect_uri: "/oauth/callback"
      scopes: ["openid", "email", "profile", "groups"]
      token_validity:
        access_code: "minutes=1"
        access_token: "hours=1"
        refresh_token: "days=30"
```

### Basic Authentication Services

For simple HTTP basic auth:

```yaml
protected_services:
  - name: private-wiki
    type: basic
    description: "Private documentation wiki"
    domains: ["localhost", "tailscale"]
    basic_config:
      realm: "Private Documentation"
      users:
        - username: "admin"
          password_hash: "$2b$12$hash..."
```

### Conditional Domain Assignment

Enable services only on specific domains:

```yaml
protected_services:
  # Development only
  - name: debug-app
    type: proxy
    domains: ["localhost"]

  # Production only
  - name: prod-dashboard
    type: proxy
    domains: ["cloudflare"]

  # Internal network only
  - name: internal-tools
    type: proxy
    domains: ["tailscale"]
```

### Custom Application Configuration

Override default application settings:

```yaml
protected_services:
  - name: special-app
    type: proxy
    domains: ["localhost", "cloudflare"]
    application_config:
      slug: "custom-app-slug"
      meta_launch_url: "https://special-app.urbalurba.no/dashboard"
      policy_engine_mode: "all"  # Require all policies to pass
      meta_description: "Special application with custom settings"
```

---

## Quick Reference

### Add New Service (Most Common)

1. Edit `topsecret/kubernetes/kubernetes-secrets.yml`:
```yaml
protected_services:
  - name: newservice
    type: proxy
    description: "New service description"
    domains: ["localhost", "cloudflare"]
```

2. Deploy your service to Kubernetes

3. Run deployment:
```bash
ansible-playbook ansible/playbooks/070-setup-authentik.yml -e kube_context="rancher-desktop"
```

4. Access: `http://newservice.localhost` (requires authentication)

### Add New Domain

1. Edit `topsecret/kubernetes/kubernetes-secrets.yml`:
```yaml
domains:
  newdomain:
    enabled: true
    base_domain: "new.example.com"
    protocol: "https"
    description: "New domain"
```

2. Update services to include new domain

3. Re-deploy Auth10 system

### Configuration File Locations

- **Auth10 Config**: `topsecret/kubernetes/kubernetes-secrets.yml`
- **Auth10 Templates**: `ansible/templates/auth10/`
- **Generated Manifests**: `manifests/073-*.yaml`, `manifests/075-*.yaml`, `manifests/078-*.yaml`
- **Deployment Playbook**: `ansible/playbooks/070-setup-authentik.yml`

### Support Resources

- **Blueprint Documentation**: `docs/package-auth-authentik-blueprints-syntax.md`
- **General Authentication**: `docs/package-auth-authentik.md`
- **Test Users**: `docs/package-auth-authentik-testusers.md`
- **Authentik Official Docs**: https://docs.goauthentik.io/blueprints/

---

*This documentation reflects the Auth10 system as implemented in the Urbalurba infrastructure. For questions or improvements, please refer to the project repository and issue tracker.*