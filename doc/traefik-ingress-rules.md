# Traefik Ingress Rules - Cluster Standards Guide

**File**: `doc/traefik-ingress-rules.md`  
**Purpose**: Explain how ingress is configured in this Kubernetes cluster using Traefik  
**Target Audience**: Developers, DevOps engineers, and anyone working with cluster ingress  
**Last Updated**: August 25, 2025  

## 📋 **Overview**

This cluster uses **Traefik** as the primary Ingress Controller with **Traefik IngressRoute CRDs** as the standard pattern. This approach provides more flexibility and features than standard Kubernetes Ingress resources.

## 🏗️ **Cluster Ingress Architecture**

### **Components**:
- **Traefik**: Ingress Controller (runs as a DaemonSet)
- **IngressRoute CRDs**: Custom Resource Definitions for advanced routing
- **Entry Points**: HTTP (`web` port 80) and HTTPS (`websecure` port 443)
- **Priority System**: Determines route matching order

### **DNS and Localhost Routing**:
This cluster uses the **localhost feature** for seamless development:

- **No Hosts File Configuration Required**: Developers don't need to modify `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`
- **Automatic Routing**: Any hostname ending in `.localhost` automatically routes to `127.0.0.1` (localhost)
- **Traefik Handles the Rest**: Once traffic reaches localhost, Traefik routes it based on the hostname in the request

**Example Flow**:
```
1. Developer types: http://myapp.localhost
2. DNS resolves: myapp.localhost → 127.0.0.1 (localhost)
3. Request reaches: localhost:80 (Traefik)
4. Traefik matches: Host(`myapp.localhost`) rule
5. Traefik routes to: myapp-service:8080
```

**Benefits**:
- ✅ **Zero Configuration**: No hosts file editing needed
- ✅ **Instant Access**: New services immediately accessible
- ✅ **Consistent**: Same pattern for all developers
- ✅ **Clean**: No local machine pollution

### **Authentication in the Cluster**:
This cluster supports **optional authentication** using **Authentik** as the identity provider. Services can be configured as public (no auth) or protected (requires login). Protected services use Traefik middleware (`authentik-forward-auth`) that forwards authentication requests to Authentik before serving content. See `manifests/075-authentik-complete-hardcoded.yaml`, `manifests/077-authentik-forward-auth-middleware.yaml`, and `manifests/078-whoami-protected-ingressroute.yaml` for implementation examples.

### **External Traffic Access**:
For external access beyond localhost, this cluster supports **Cloudflare Tunnels** and **Tailscale Funnel** to securely route external traffic to Traefik. External domains can be configured to route through Cloudflare (with WAF/DDoS protection) or directly via Tailscale Funnel, while maintaining the same Traefik ingress rules. See `doc/networking-external-cloudflare-readme.md`, `doc/networking-external-cloudflare-tailscale-readme.md`, and `doc/networking-readme.md` for setup details.

### **Why Traefik IngressRoute CRDs?**
- **More Features**: Path rewriting, header manipulation, middleware
- **Better Performance**: Direct integration with Traefik
- **Cluster Standard**: Consistent with existing infrastructure
- **Advanced Routing**: Complex matching rules and conditions

## 🔧 **API Version and Standards**

### **Current Traefik Version**:
This cluster is running **Traefik 3.3.6** (Rancher Desktop distribution).

### **Available API Versions**:
```bash
# Current cluster has these Traefik API resources:
ingressroutes        traefik.io/v1alpha1     true    IngressRoute
ingressroutetcps     traefik.io/v1alpha1     true    IngressRouteTCP
ingressrouteudps     traefik.io/v1alpha1     true    IngressRouteUDP
middlewares          traefik.io/v1alpha1     true    Middleware
middlewaretcps       traefik.io/v1alpha1     true    MiddlewareTCP
serverstransports    traefik.io/v1alpha1     true    ServersTransport
serverstransporttcps traefik.io/v1alpha1     true    ServersTransportTCP
tlsoptions           traefik.io/v1alpha1     true    TLSOption
tlsstores            traefik.io/v1alpha1     true    TLSStore
traefikservices      traefik.io/v1alpha1     true    TraefikService
```

### **API Version Status**:
- **`traefik.io/v1alpha1`**: ✅ **Currently Supported** - This is the working version in Traefik 3.3.6
- **`traefik.io/v1`**: ❌ **Not Available** - This version is not yet available in Traefik 3.3.6
- **`hub.traefik.io/v1alpha1`**: ✅ **Available** - For newer Traefik Hub features (APIs, Portals, etc.)

### **Required API Version for Ingress**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
```

**⚠️ Important**: Use `traefik.io/v1alpha1` - this is the current working version in Traefik 3.3.6. While `traefik.io/v1` may be available in future Traefik versions, it's not yet available in this cluster.

### **Standard Structure**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <service-name>
  namespace: default
  labels:
    app: <application-name>
    component: <component-type>
    protection: <auth-level>
spec:
  entryPoints:
    - web  # HTTP port 80
  routes:
    - match: <routing-rule>
      kind: Rule
      services:
        - name: <service-name>
          port: <port-number>
```

## 🎯 **Priority System**

### **How Priorities Work**:
- **Lower numbers = Higher priority** (checked first)
- **Higher numbers = Lower priority** (checked last)
- **No priority specified = Default higher priority**

### **Priority Guidelines**:
```yaml
# High Priority (1-10): Critical services, authentication
priority: 1

# Medium Priority (10-50): Application services
priority: 25

# Low Priority (50+): Fallback, catch-all
priority: 100
```

### **Example - Nginx Catch-All**:
```yaml
# File: manifests/020-nginx-root-ingress.yaml
spec:
  routes:
    - match: PathPrefix(`/`)
      kind: Rule
      priority: 1  # LOWEST priority - ensures all other routes are checked first
      services:
        - name: nginx
          port: 80
```

**Purpose**: Acts as a fallback for any unmatched requests. **Priority 1** ensures it's checked last.

## 🌐 **Routing Patterns**

### **1. Simple Host-Based Routing** (Recommended)
```yaml
# File: manifests/071-whoami-public-ingressroute.yaml
spec:
  routes:
    - match: Host(`whoami-public.localhost`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

**Best For**: Simple services, reliable routing, easy debugging

### **2. Path-Based Routing**
```yaml
spec:
  routes:
    - match: PathPrefix(`/api`)
      kind: Rule
      services:
        - name: api-service
          port: 8080
```

**Best For**: API endpoints, path-specific routing

### **3. Complex Matching** (Use Sparingly)
```yaml
spec:
  routes:
    - match: Host(`service.localhost`) && PathPrefix(`/admin`)
      kind: Rule
      services:
        - name: admin-service
          port: 8080
```

**Best For**: Advanced routing needs, but can cause debugging issues

## 📁 **Working Examples**

### **File Organization**:
All ingress configuration files are located in the **`manifests/`** folder and follow a consistent naming convention:

- **File Naming**: Ingress files should end with `-ingress.yaml`
- **Examples**: 
  - `020-nginx-root-ingress.yaml`
  - `071-whoami-public-ingressroute.yaml`
  - `091-gravitee-ingress.yaml`
- **Numbering**: Files are numbered to indicate deployment order and dependencies

### **Example 1: Nginx Catch-All**
```yaml
# File: manifests/020-nginx-root-ingress.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-root-catch-all
  namespace: default
  labels:
    app: nginx
    component: catch-all-routing
spec:
  entryPoints:
    - web
  routes:
    - match: PathPrefix(`/`)
      kind: Rule
      priority: 1  # Lowest priority - fallback
      services:
        - name: nginx
          port: 80
```

**Purpose**: Fallback for unmatched requests  
**Priority**: 1 (lowest - checked last)  
**Pattern**: `PathPrefix(/)` - matches everything

### **Example 2: Whoami Public Service**
```yaml
# File: manifests/071-whoami-public-ingressroute.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: whoami-public
  namespace: default
  labels:
    app: whoami
    component: public-routing
    protection: none
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`whoami-public.localhost`)
      kind: Rule
      services:
        - name: whoami
          port: 80
```

**Purpose**: Simple host-based routing  
**Priority**: None specified (defaults to higher than catch-all)  
**Pattern**: `Host(whoami-public.localhost)` - simple and reliable

## 🚫 **Common Mistakes to Avoid**

### **1. Wrong API Version**
```yaml
# ❌ WRONG - Will cause "no matches for kind" error
apiVersion: traefik.io/v1

# ✅ CORRECT - This is the working version
apiVersion: traefik.io/v1alpha1
```

### **2. Over-Complex Routing**
```yaml
# ❌ AVOID - Complex matching can cause issues
match: Host(`service.localhost`) && PathPrefix(`/api`) && Header(`Content-Type`, `application/json`)

# ✅ PREFER - Simple, reliable routing
match: Host(`api.localhost`)
```

### **3. Missing Priority for Catch-All**
```yaml
# ❌ WRONG - Will interfere with other routes
match: PathPrefix(`/`)
priority: 100  # Too high - other routes won't work

# ✅ CORRECT - Low priority for fallback
match: PathPrefix(`/`)
priority: 1  # Lowest - checked last
```

### **4. Port Mismatches**
```yaml
# ❌ WRONG - Service port doesn't match
services:
  - name: my-service
    port: 8080  # But service actually runs on port 80

# ✅ CORRECT - Verify actual service port
services:
  - name: my-service
    port: 80  # Match actual service port
```

## 🔍 **Debugging Ingress Issues**

### **Check IngressRoute Status**:
```bash
# List all IngressRoutes
kubectl get ingressroute

# Describe specific IngressRoute
kubectl describe ingressroute <name>

# Get YAML configuration
kubectl get ingressroute <name> -o yaml
```

### **Test Service Directly**:
```bash
# Port-forward to service
kubectl port-forward svc/<service-name> <local-port>:<service-port>

# Test locally
curl -i http://localhost:<local-port>/
```

### **Check Traefik Logs**:
```bash
# Get Traefik pod name
kubectl get pods -l app.kubernetes.io/name=traefik

# View logs
kubectl logs <traefik-pod-name> -f
```

### **Verify Service Health**:
```bash
# Check service endpoints
kubectl get endpoints <service-name>

# Check pod status
kubectl get pods -l app=<app-label>
```

## 📝 **Best Practices**

### **1. Use Simple Host-Based Routing**
```yaml
# ✅ RECOMMENDED
match: Host(`myapp.localhost`)

# ❌ AVOID
match: Host(`myapp.localhost`) && PathPrefix(`/api`) && Header(`X-API-Key`)
```

### **2. Set Appropriate Priorities**
```yaml
# High priority for critical services
priority: 10

# Medium priority for applications
priority: 25

# Low priority for fallbacks
priority: 100
```

### **3. Use Descriptive Names and Labels**
```yaml
metadata:
  name: myapp-api-ingress
  labels:
    app: myapp
    component: api
    protection: public
    environment: production
```

### **4. Test Before Production**
```yaml
# Test with simple routing first
match: Host(`test.localhost`)

# Then add complexity if needed
match: Host(`test.localhost`) && PathPrefix(`/api`)
```

## 🔄 **Migration from Standard Ingress**

### **Before (Standard Kubernetes Ingress)**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: "web"
spec:
  ingressClassName: traefik
  rules:
  - host: myapp.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

### **After (Traefik IngressRoute)**:
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: myapp-ingress
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`myapp.localhost`)
      kind: Rule
      services:
        - name: myapp-service
          port: 80
```

## 📚 **Additional Resources**

### **Official Documentation**:
- [Traefik IngressRoute Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [Traefik Routing Rules](https://doc.traefik.io/traefik/routing/routers/)

### **Cluster-Specific Files**:
- **Nginx Catch-All**: `manifests/020-nginx-root-ingress.yaml`
- **Whoami Public**: `manifests/071-whoami-public-ingressroute.yaml`
- **Gravitee Examples**: `manifests/091-gravitee-ingress.yaml`

### **Related Documentation**:
- **Networking Overview**: `doc/networking-readme.md`
- **Infrastructure Guide**: `doc/infrastructure-readme.md`

## 🎯 **Summary**

### **Key Points**:
1. **Use `traefik.io/v1alpha1`** - this is the current working version in Traefik 3.3.6
2. **Prefer simple `Host()` matching** over complex path routing
3. **Set appropriate priorities** (1 = lowest, 100+ = highest)
4. **Test services directly** before troubleshooting ingress
5. **Follow the working examples** in the manifests folder

### **Traefik Version Information**:
- **Current Version**: Traefik 3.3.6 (Rancher Desktop)
- **API Version**: `traefik.io/v1alpha1` is current and supported
- **Future Versions**: `traefik.io/v1` may be available in newer Traefik releases
- **Cluster Status**: Using the latest stable API version available

### **Remember**:
- **Traefik IngressRoute CRDs** are the cluster standard
- **Simple routing** is more reliable than complex routing
- **Priority system** determines route matching order
- **Test incrementally** to avoid debugging complexity

This approach ensures consistent, maintainable ingress configuration across the cluster.
