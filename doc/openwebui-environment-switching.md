# OpenWebUI Environment Switching Guide

**File**: `doc/openwebui-environment-switching.md`  
**Purpose**: Guide for developers to switch between OpenWebUI environments  
**Target Audience**: Developers working with OpenWebUI and authentication  
**Last Updated**: August 26, 2025

## 📋 **Overview**

This cluster provides two OpenWebUI environments that developers can choose between:

- **`openwebui.localhost`** - Existing environment (no authentication, always available)
- **`openwebui-dev.localhost`** - Development environment (OAuth2 with Authentik, deploy on-demand)

The authenticated environment follows the **official Authentik integration documentation** exactly and provides a separate OpenWebUI instance for testing authentication workflows.

## 🎯 **Environment Comparison**

| **Feature** | **openwebui.localhost** | **openwebui-dev.localhost** |
|-------------|-------------------------|------------------------------|
| **Authentication** | None | OAuth2 with Authentik |
| **Deployment** | Always running | Deploy on-demand |
| **Data Storage** | Existing conversations | Separate conversations |
| **User Management** | Direct access | Authentik users auto-created |
| **Resource Usage** | Existing resources | Additional pod when deployed |
| **Use Case** | Quick development/testing | Authentication testing |

## 🚀 **Quick Start Commands**

### **Deploy Authenticated Environment**
```bash
# Deploy all components for OAuth authentication
kubectl apply -f manifests/211-openwebui-dev-oauth-secret.yaml
kubectl apply -f manifests/213-openwebui-dev-statefulset.yaml
kubectl apply -f manifests/215-openwebui-dev-service.yaml
kubectl apply -f manifests/212-openwebui-dev-auth-ingress.yaml

# Verify deployment
kubectl get statefulset,service,ingressroute,secret -n ai -l environment=development

# Test authentication
open http://openwebui-dev.localhost
```

### **Remove Authenticated Environment (Save Resources)**
```bash
# Remove all components in reverse order
kubectl delete -f manifests/212-openwebui-dev-auth-ingress.yaml
kubectl delete -f manifests/215-openwebui-dev-service.yaml
kubectl delete -f manifests/213-openwebui-dev-statefulset.yaml
kubectl delete -f manifests/211-openwebui-dev-oauth-secret.yaml

# Verify removal
kubectl get pods -n ai -l environment=development  # Should show no resources
```

## 🔧 **Prerequisites**

Before deploying the authenticated environment, ensure:

### **1. Authentik Configuration**
Complete OAuth2 application setup in Authentik UI (`authentik.localhost`):
- **Application Name**: `openwebui-dev`
- **Provider Type**: `OAuth2/OpenID Connect`
- **Client Type**: `Confidential`
- **Redirect URI**: `https://openwebui-dev.localhost/oauth/oidc/callback`
- **Note**: Client ID and Client Secret (already configured in secret)

### **2. Required Files**
Ensure these manifest files exist and are properly configured:
- `211-openwebui-dev-oauth-secret.yaml` - OAuth credentials
- `212-openwebui-dev-auth-ingress.yaml` - IngressRoute with authentication
- `213-openwebui-dev-statefulset.yaml` - OpenWebUI instance with OAuth config
- `215-openwebui-dev-service.yaml` - Service for authenticated instance

## 🔄 **Developer Workflows**

### **Workflow 1: No Authentication Development**
```bash
# Use existing environment (always available)
open http://openwebui.localhost

# Benefits:
# ✅ Instant access
# ✅ No resource overhead
# ✅ Familiar environment
# ✅ No authentication barriers
```

### **Workflow 2: Authentication Development**
```bash
# Deploy authenticated environment
kubectl apply -f manifests/211-openwebui-dev-oauth-secret.yaml
kubectl apply -f manifests/213-openwebui-dev-statefulset.yaml
kubectl apply -f manifests/215-openwebui-dev-service.yaml
kubectl apply -f manifests/212-openwebui-dev-auth-ingress.yaml

# Use authenticated environment
open http://openwebui-dev.localhost

# When done, clean up resources
kubectl delete -f manifests/212-openwebui-dev-auth-ingress.yaml
kubectl delete -f manifests/215-openwebui-dev-service.yaml
kubectl delete -f manifests/213-openwebui-dev-statefulset.yaml
kubectl delete -f manifests/211-openwebui-dev-oauth-secret.yaml

# Benefits:
# ✅ Official OAuth2 integration
# ✅ Proper user management
# ✅ Authentication testing
# ✅ Resource efficient (deploy only when needed)
```

### **Workflow 3: Side-by-Side Comparison**
```bash
# Deploy authenticated environment
kubectl apply -f manifests/211-openwebui-dev-oauth-secret.yaml
kubectl apply -f manifests/213-openwebui-dev-statefulset.yaml
kubectl apply -f manifests/215-openwebui-dev-service.yaml
kubectl apply -f manifests/212-openwebui-dev-auth-ingress.yaml

# Compare both environments
open http://openwebui.localhost          # No auth
open http://openwebui-dev.localhost      # With auth

# Benefits:
# ✅ Direct comparison of auth vs no-auth UX
# ✅ Test authentication flow
# ✅ Validate user management features
```

## 🔍 **Verification Commands**

### **Check Environment Status**
```bash
# Check which environments are deployed
kubectl get pods -n ai --show-labels

# Existing environment (always present)
kubectl get pod -l app=open-webui -l '!environment' -n ai

# Authenticated environment (only when deployed)
kubectl get pod -l app=open-webui -l environment=development -n ai
```

### **Check Authentication Configuration**
```bash
# Verify OAuth secret exists
kubectl get secret openwebui-dev-oauth -n ai

# Check OAuth environment variables in StatefulSet
kubectl get statefulset open-webui-dev -n ai -o yaml | grep -A 10 -B 10 OAUTH

# View OpenWebUI logs for OAuth debugging
kubectl logs -n ai -l environment=development --tail=50
```

## 🐛 **Troubleshooting**

### **Common Issues and Solutions**

#### **Issue: openwebui-dev.localhost shows 404**
```bash
# Check if authenticated environment is deployed
kubectl get ingressroute open-webui-dev-auth -n ai

# If not found, deploy the environment:
kubectl apply -f manifests/211-openwebui-dev-oauth-secret.yaml
kubectl apply -f manifests/213-openwebui-dev-statefulset.yaml
kubectl apply -f manifests/215-openwebui-dev-service.yaml
kubectl apply -f manifests/212-openwebui-dev-auth-ingress.yaml
```

#### **Issue: No \"Continue with authentik\" button**
```bash
# Check OAuth environment variables
kubectl describe statefulset open-webui-dev -n ai | grep -A 10 Environment

# Verify secret is mounted correctly
kubectl get secret openwebui-dev-oauth -n ai -o yaml
```

#### **Issue: OAuth redirect error**
```bash
# Check Authentik application configuration
# Redirect URI must be: https://openwebui-dev.localhost/oauth/oidc/callback

# Verify OpenWebUI OIDC configuration
kubectl logs -n ai -l environment=development --tail=100 | grep -i oauth
```

#### **Issue: Resource conflicts**
```bash
# If StatefulSet won't start, check for port conflicts
kubectl describe statefulset open-webui-dev -n ai

# Check if volumes are properly created
kubectl get pvc -n ai -l environment=development
```

## 📚 **Additional Resources**

### **Official Documentation**
- [Authentik OpenWebUI Integration](https://integrations.goauthentik.io/miscellaneous/open-webui/)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [Traefik IngressRoute Documentation](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)

### **Related Cluster Documentation**
- **Traefik Ingress Rules**: `doc/traefik-ingress-rules.md`
- **Authentik Setup**: `manifests/075-authentik-complete-hardcoded.yaml`
- **Infrastructure Overview**: `doc/infrastructure-readme.md`

## 🎯 **Summary**

This environment switching approach provides:

### **✅ Benefits**
- **Official compliance** - follows Authentik documentation exactly
- **Resource efficiency** - deploy authentication only when needed
- **Developer choice** - use authenticated or non-authenticated environments
- **Clean separation** - separate data and configurations per environment
- **Easy switching** - simple kubectl commands to deploy/remove

### **🔄 Recommended Workflow**
1. **Start** with `openwebui.localhost` for general development
2. **Deploy** authenticated environment when testing OAuth features
3. **Compare** both environments to validate authentication UX
4. **Remove** authenticated environment when not needed to save resources
5. **Re-deploy** as needed for authentication development

This approach balances resource efficiency with authentication testing capabilities while following official documentation standards.
