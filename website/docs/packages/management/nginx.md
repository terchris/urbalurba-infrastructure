# Nginx Web Server - Core Infrastructure

**File**: `docs/package-core-nginx.md`
**Purpose**: Complete guide to Nginx deployment and configuration in Urbalurba infrastructure
**Target Audience**: Infrastructure engineers, developers working with web services
**Last Updated**: September 22, 2024

## 📋 Overview

Nginx serves as the **catch-all web server** in the Urbalurba infrastructure. It acts as the default fallback for any hostname or path not specifically defined in Traefik IngressRoutes, displaying "Hello World" content to users who access undefined routes.

**Key Function**: When someone accesses a hostname or path that doesn't match any specific service route (like `whoami.localhost` or `authentik.localhost`), Traefik routes the request to nginx, which serves the default content from `testdata/website/`.

**Catch-All Behavior**:
- **Priority 1** (lowest) in Traefik routing - ensures all other routes are checked first
- Serves as safety net for undefined routes and testing
- Displays "Hello World" page from `testdata/website/index.html`
- Prevents 404 errors for cluster domain access

For detailed ingress routing rules, see [rules-ingress-traefik.md](./rules-ingress-traefik.md).


## 🏗️ Architecture

### **Deployment Components**
```
Nginx Service Stack:
├── Helm Release (bitnami/nginx)
├── Persistent Volume (nginx-content-pvc)
├── ConfigMap (nginx configuration)
├── Service (ClusterIP)
├── IngressRoute (external access)
└── Pod (nginx container)
```

### **File Structure**
```
01-core/
├── 020-setup-nginx.sh          # Main deployment script
└── not-in-use/
    └── 020-remove-nginx.sh     # Removal script

manifests/
├── 020-nginx-config.yaml       # Nginx configuration
└── 020-nginx-root-ingress.yaml # Ingress routing

ansible/playbooks/
├── 020-setup-nginx.yml         # Main deployment logic
├── 020-setup-web-files.yml     # Content preparation
└── 020-remove-nginx.yml        # Removal logic
```

## ⚙️ Catch-All Routing Configuration

Nginx uses Traefik IngressRoute for catch-all routing:

```yaml
# manifests/020-nginx-root-ingress.yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx-root-catch-all
spec:
  entryPoints:
    - web
  routes:
    - match: PathPrefix(`/`)
      kind: Rule
      priority: 1  # Lowest priority - ensures all other routes checked first
      services:
        - name: nginx
          port: 80
```

**How It Works**:
1. User accesses undefined hostname (e.g., `random.localhost`)
2. Traefik checks all IngressRoutes with higher priorities first
3. No specific route matches, so nginx catch-all rule (priority 1) is used
4. Request routed to nginx service
5. Nginx serves "Hello World" content from PVC


## 📁 Content Management

### **Web Content Structure**
```
nginx-content-pvc/
├── index.html              # "Hello World" homepage (from testdata/website/)
└── urbalurba-test.html     # Generated test page for verification
```

**Content Source**: Files are copied from `testdata/website/` directory, which contains:
```
testdata/website/
└── index.html              # Simple "Hello World" page
```

### **Content Deployment Process**
1. **Source Content**: Copies files from `testdata/website/` directory (contains `index.html` with "Hello World")
2. **PVC Creation**: `020-setup-web-files.yml` creates PVC and uploads content
3. **Nginx Deployment**: Helm chart deploys with volume mounted to serve the content
4. **Catch-All Routing**: IngressRoute configured with priority 1 for fallback routing

### **Adding Custom Content**

TODO: test these commands
```bash
# Copy files to nginx content volume
kubectl cp ./my-website.html nginx-pod:/usr/share/nginx/html/

# Or update via ConfigMap for smaller files
kubectl create configmap nginx-content --from-file=./content/
```


### **Catch-All Testing**
```bash
# Test catch-all behavior with undefined hostnames
curl http://undefined.localhost        # Should show "Hello World"
curl http://random-name.localhost      # Should show "Hello World"
curl http://localhost/test             # Should show "Hello World"

# Test specific content
curl http://localhost                  # Shows "Hello World" from index.html
curl http://localhost/urbalurba-test.html  # Shows generated test page

# Compare with defined routes (these should NOT go to nginx)
curl http://whoami.localhost           # Goes to whoami service, not nginx
curl http://authentik.localhost        # Goes to authentik service, not nginx
```



---

**💡 Key Insight**: Nginx serves as the catch-all safety net for undefined routes in your cluster. When users access hostnames or paths not configured in Traefik, they see a friendly "Hello World" instead of an error page.