# Auth10 Developer Guide

## Overview
This guide explains how to use the Auth10 dynamic service protection system to protect your Kubernetes services with Authentik authentication.

## Quick Start

### 1. Protect a Service
Edit `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml` and add your service to the `protected_services` list:

```yaml
# In .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
protected_services:
  - name: myapp
    type: proxy
    description: "My awesome application"
    domains: ["localhost", "cloudflare"]
```

### 2. Deploy Configuration
```bash
# Deploy the updated configuration using the Ansible playbook
ansible-playbook ansible/playbooks/070-setup-authentik.yml -e kube_context="rancher-desktop"
```

### 3. Verify Protection
```bash
# Check if service is protected
curl -I http://myapp.localhost
# Should redirect to Authentik login

# Both domains now require authentication automatically:
# - http://myapp.localhost
# - https://myapp.urbalurba.no
```

## Configuration

### Service Types

#### Proxy Services (Forward Auth)
For services that use Traefik forward auth middleware:

```yaml
protected_services:
  - name: whoami
    type: proxy
    description: "Whoami test service"
    domains: ["localhost", "tailscale", "cloudflare"]
    application_slug: "whoami-app"
```

#### OAuth2 Services
For services that use OAuth2/OIDC authentication:

```yaml
protected_services:
  - name: openwebui
    type: oauth2
    description: "OpenWebUI application"
    domains: ["localhost", "tailscale", "cloudflare"]
    application_slug: "openwebui-app"
    oauth_config:
      client_id: "{{ openwebui_oauth_client_id }}"
      client_secret: "{{ openwebui_oauth_client_secret }}"
      redirect_uri: "/oauth/oidc/callback"
```

#### Basic Auth Services
For services that use simple username/password authentication:

```yaml
protected_services:
  - name: basic-auth-service
    type: basic
    description: "Basic authentication service"
    domains: ["localhost", "tailscale"]
    basic_auth:
      username: "admin"
      password: "{{ BASIC_AUTH_PASSWORD }}"
```

### Domain Configuration

#### Available Domains
- **localhost**: `http://service.localhost` (development)
- **tailscale**: `https://service.dog-pence.ts.net` (Tailscale MagicDNS)
- **cloudflare**: `https://service.urbalurba.no` (external domain)

#### Domain Selection
```yaml
# Use all available domains
domains: "auto"

# Use specific domains
domains: ["localhost", "tailscale"]

# Use only external domains
domains: ["tailscale", "cloudflare"]
```

## Workflow

### Adding a New Service

1. **Edit Configuration**
   ```bash
   # Add service to kubernetes-secrets.yml
   vim .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
   ```

2. **Deploy Configuration**
   ```bash
   # Run auth script
   ./scripts/packages/auth.sh
   ```

3. **Verify Protection**
   ```bash
   # Check if service is protected
   curl -I http://whoami.localhost
   # Should redirect to Authentik login
   ```

### Using the System

1. **Edit Configuration**
   ```bash
   vim .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
   ```

2. **Deploy Changes**
   ```bash
   ./scripts/packages/auth.sh
   ```

3. **Access Service**
   - Open browser to `http://whoami.localhost`
   - You'll be redirected to Authentik login
   - After login, you'll be redirected back to the service

## Examples

### Example 1: Simple Web Service
```yaml
protected_services:
  - name: my-app
    type: proxy
    description: "My web application"
    domains: ["localhost", "tailscale"]
    application_slug: "my-app"
```

### Example 2: OAuth2 Application
```yaml
protected_services:
  - name: dashboard
    type: oauth2
    description: "Admin dashboard"
    domains: ["localhost", "tailscale", "cloudflare"]
    application_slug: "dashboard-app"
    oauth_config:
      client_id: "{{ dashboard_oauth_client_id }}"
      client_secret: "{{ dashboard_oauth_client_secret }}"
      redirect_uri: "/auth/callback"
```

### Example 3: Basic Auth Service
```yaml
protected_services:
  - name: basic-auth-service
    type: basic
    description: "Basic authentication service"
    domains: ["localhost", "tailscale"]
    basic_auth:
      username: "admin"
      password: "{{ BASIC_AUTH_PASSWORD }}"
```

### Example 4: Development Only
```yaml
protected_services:
  - name: dev-tools
    type: proxy
    description: "Development tools"
    domains: ["localhost"]  # Only localhost
    application_slug: "dev-tools"
```

## Troubleshooting

### Common Issues

#### Service Not Protected
1. Check if service is in `protected_services` list
2. Verify domains are enabled
3. Check Ansible playbook logs

#### Authentication Loop
1. Check CSRF trusted origins
2. Verify provider configuration
3. Check IngressRoute configuration

#### Domain Not Working
1. Verify domain is enabled in `domains` section
2. Check DNS resolution
3. Verify IngressRoute configuration

### Debug Commands

```bash
# Check Authentik pods
kubectl get pods -n authentik

# Check Authentik logs
kubectl logs -n authentik -l app.kubernetes.io/name=authentik

# Check IngressRoutes
kubectl get ingressroute -n default

# Check providers in Authentik
kubectl exec -n authentik deployment/authentik-server -- python manage.py shell
```

### Logs and Monitoring

```bash
# Authentik server logs
kubectl logs -n authentik deployment/authentik-server

# Authentik worker logs
kubectl logs -n authentik deployment/authentik-worker

# Traefik logs
kubectl logs -n traefik deployment/traefik
```

## Advanced Configuration

### Custom Domains
To add a new domain type:

1. **Add to domains section**
   ```yaml
   domains:
     custom:
       enabled: true
       base_domain: "{{ CUSTOM_DOMAIN }}"
       protocol: "https"
       description: "Custom domain"
   ```

2. **Update service configuration**
   ```yaml
   protected_services:
     - name: my-service
       domains: ["localhost", "tailscale", "custom"]
   ```

### Custom OAuth2 Configuration
```yaml
protected_services:
  - name: custom-app
    type: oauth2
    oauth_config:
      client_id: "{{ custom_client_id }}"
      client_secret: "{{ custom_client_secret }}"
      redirect_uri: "/custom/callback"
      # Additional OAuth2 settings can be added here
```

## Best Practices

1. **Use descriptive names** for services and applications
2. **Test on localhost first** before deploying to external domains
3. **Keep domains minimal** - only enable what you need
4. **Use version control** for all configuration changes
5. **Monitor logs** for authentication issues
6. **Backup configuration** before making changes

## Application Integration

### Expected Authentication Headers

Applications receive these headers for authenticated users:
```
X-authentik-username: myapp-admin
X-authentik-email: admin@myapp.local
X-authentik-groups: myapp-admins,myapp-users
X-authentik-name: myapp Administrator
X-authentik-uid: unique-user-id
X-authentik-jwt: jwt-token-here
```

### Integration Examples

#### Next.js Application

```javascript
// middleware.js
export function middleware(request) {
  const user = request.headers.get('x-authentik-username')
  const groups = request.headers.get('x-authentik-groups')?.split(',') || []

  // Check if user has required permissions
  if (request.nextUrl.pathname.startsWith('/admin')) {
    if (!groups.includes('myapp-admins')) {
      return new Response('Forbidden', { status: 403 })
    }
  }

  if (request.nextUrl.pathname.startsWith('/dashboard')) {
    if (!groups.includes('myapp-users')) {
      return new Response('Forbidden', { status: 403 })
    }
  }
}
```

#### Node.js/Express Application

```javascript
// auth-middleware.js
function requireGroup(requiredGroup) {
  return (req, res, next) => {
    const userGroups = req.headers['x-authentik-groups']?.split(',') || []

    if (!userGroups.includes(requiredGroup)) {
      return res.status(403).json({ error: 'Insufficient permissions' })
    }

    next()
  }
}

// Usage
app.get('/admin/*', requireGroup('myapp-admins'), adminRoutes)
app.get('/dashboard/*', requireGroup('myapp-users'), userRoutes)
```

### Multi-Environment Testing

The system provides two parallel environments for each app:

1. **Authentication Testing**: `whoami-{app}.localhost`
   - Points to existing whoami service
   - Uses app-specific authentication
   - Perfect for testing user/group behaviors
   - Independent of actual app development

2. **Application Development**: `{app}.localhost`
   - Points to developer's actual application
   - Uses same authentication configuration
   - Real-world integration testing
   - Production-ready patterns

## System Verification Commands

```bash
# Check deployment status
kubectl get pods -n authentik                    # Should show 2+ running pods
kubectl get svc -n authentik                     # Services
kubectl get ingress -n authentik                 # Ingress configuration
kubectl get middleware -n default                # Forward auth middleware

# Check system health
kubectl logs -n authentik deployment/authentik-server --tail=10
kubectl logs -n authentik deployment/authentik-worker --tail=10
```

## Authentication Flow Testing

```bash
# Test external access to admin interface
curl -I http://authentik.localhost/if/admin/     # Should return 200 OK

# Test authentication flow (should redirect to login)
curl -L http://whoami.localhost

# Test from within cluster
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never --command -- \
  curl -s -H "Host: authentik.localhost" \
  http://traefik.kube-system.svc.cluster.local
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs for error messages
3. Check the configuration reference
4. Create an issue in the project repository
