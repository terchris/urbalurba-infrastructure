# AI Package Environment Management Guide

**File**: `docs/package-ai-environment-management.md`
**Purpose**: Guide for managing the complete AI infrastructure environment
**Target Audience**: Developers and administrators working with AI infrastructure
**Last Updated**: September 19, 2024

## 📋 **Overview**

This cluster provides OpenWebUI integrated with LiteLLM proxy for unified model access:

- **`openwebui.localhost`** - Main OpenWebUI environment with Authentik authentication
- **Model Provider**: LiteLLM proxy serving multiple model sources
- **Authentication**: OAuth2 with Authentik for user management
- **Configuration**: External ConfigMap management in `topsecret/kubernetes/kubernetes-secrets.yml`

The environment provides a single, production-ready OpenWebUI instance with enterprise authentication and centralized model management.

## 🎯 **Current Architecture**

| **Component** | **Configuration** | **Purpose** |
|---------------|-------------------|-------------|
| **OpenWebUI** | StatefulSet with persistent storage | Web interface for AI interactions |
| **LiteLLM Proxy** | ConfigMap in topsecret/kubernetes/kubernetes-secrets.yml | Unified model provider and API gateway |
| **Authentication** | OAuth2 with Authentik | Enterprise user management and SSO |
| **Models** | Multiple sources via LiteLLM | Local Ollama + Cloud providers |
| **Database** | Shared PostgreSQL | User data, conversations, model configs |
| **Document Processing** | Apache Tika + Qdrant | RAG pipeline for knowledge bases |

## 🚀 **Quick Start Commands**

### **Deploy Complete AI Infrastructure**

#### **Automatic Deployment (During Cluster Rebuild)**
The AI infrastructure is **automatically deployed** during cluster provisioning via:
```bash
# This runs automatically via provision-kubernetes.sh
provision-host/kubernetes/07-ai/01-setup-litellm-openwebui.sh
```

**⚠️ IMPORTANT**: During automatic cluster rebuild:
- ✅ **USE**: `01-setup-litellm-openwebui.sh` (combined deployment)
- ❌ **DO NOT USE**: Individual scripts (`02-setup-open-webui.sh`, `03-setup-litellm.sh`)
- These individual scripts are kept in `not-in-use/` for manual troubleshooting only

#### **Manual Deployment Options**
```bash
# Option 1: Deploy using Ansible directly (RECOMMENDED for manual deployment)
cd /mnt/urbalurbadisk

# Step 1: Deploy LiteLLM first (required dependency)
ansible-playbook ansible/playbooks/210-setup-litellm.yml
# ⏳ Wait: ~2-3 minutes for LiteLLM to be verified as working

# Step 2: Deploy OpenWebUI (depends on LiteLLM)
ansible-playbook ansible/playbooks/200-setup-open-webui.yml
# ⏳ Wait: ~5-10 minutes for OpenWebUI component setup

# Option 2: Use orchestration script (automated sequencing)
./scripts/packages/ai.sh
```

### **Access OpenWebUI**
```bash
# Access the web interface
open http://openwebui.localhost

# Create admin account on first login
# Configure OAuth users via Authentik admin panel
```

### **Manage LiteLLM Models**
```bash
# Edit model configuration
vim topsecret/kubernetes/kubernetes-secrets.yml

# Apply changes
./copy2provisionhost.sh
docker exec -it provision-host bash -c "cd /mnt/urbalurbadisk && kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml"

# Restart LiteLLM to reload models
kubectl rollout restart deployment/litellm -n ai
```

## 🔧 **Configuration Management**

### **1. LiteLLM Model Configuration**
Edit `topsecret/kubernetes/kubernetes-secrets.yml` to manage models:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config
  namespace: ai
data:
  config.yaml: |
    general_settings:
      master_key: os.environ/LITELLM_PROXY_MASTER_KEY
    model_list:
      - model_name: mac-gpt-oss-balanced
        litellm_params:
          model: ollama/gpt-oss:20b
          api_base: "http://host.lima.internal:11434"
          temperature: 0.7
```

### **2. Required Secrets**
Ensure these secrets exist in `urbalurba-secrets`:
- `LITELLM_PROXY_MASTER_KEY` - LiteLLM API authentication
- `LITELLM_POSTGRESQL__USER` - Database username (`litellm`)
- `LITELLM_POSTGRESQL__PASSWORD` - Database password
- `OPENAI_API_KEY` - OpenAI API access (if using GPT models)
- `ANTHROPIC_API_KEY` - Anthropic API access (if using Claude)
- `AZURE_API_KEY` - Azure OpenAI access (if using Azure models)

## 🔄 **Developer Workflows**

### **Workflow 1: Model Development and Testing**
```bash
# Access OpenWebUI
open http://openwebui.localhost

# Login with Authentik OAuth (or create admin account)
# Test different models from LiteLLM proxy
# Upload documents for RAG testing

# Benefits:
# ✅ Multiple model access via LiteLLM
# ✅ Enterprise authentication
# ✅ Document processing with Tika + Qdrant
# ✅ Persistent conversations and knowledge bases
```

### **Workflow 2: Model Configuration Changes**
```bash
# Edit LiteLLM models
vim topsecret/kubernetes/kubernetes-secrets.yml

# Apply configuration
./copy2provisionhost.sh
docker exec -it provision-host bash -c "cd /mnt/urbalurbadisk && kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml"

# Restart LiteLLM to reload models
kubectl rollout restart deployment/litellm -n ai

# Test new models in OpenWebUI
open http://openwebui.localhost

# Benefits:
# ✅ Centralized model configuration
# ✅ Quick model addition/removal
# ✅ Support for multiple providers
# ✅ Configuration persistence
```

### **Workflow 3: Complete Infrastructure Management**
```bash
# Remove entire AI infrastructure (from provision-host container)
docker exec -it provision-host bash -c "cd /mnt/urbalurbadisk/provision-host/kubernetes/07-ai/not-in-use && ./01-remove-litellm-openwebui.sh"

# Redeploy with new configuration
./scripts/packages/ai.sh

# Benefits:
# ✅ Clean slate deployment
# ✅ Configuration validation
# ✅ Full integration testing
# ✅ Infrastructure consistency
```

## 🔍 **Verification Commands**

### **Check AI Infrastructure Status**
```bash
# Check all AI pods
kubectl get pods -n ai

# Check LiteLLM deployment
kubectl get deployment litellm -n ai

# Check OpenWebUI StatefulSet
kubectl get statefulset open-webui -n ai

# Check shared PostgreSQL databases
kubectl exec -n default postgresql-0 -- psql -U postgres -c '\l' | grep -E '(openwebui|litellm)'
```

### **Verify LiteLLM Configuration**
```bash
# Check ConfigMap exists
kubectl get configmap litellm-config -n ai

# View current model configuration
kubectl get configmap litellm-config -n ai -o yaml

# Test LiteLLM API
kubectl port-forward svc/litellm 4000:4000 -n ai &
MASTER_KEY=$(kubectl get secret urbalurba-secrets -n ai -o jsonpath="{.data.LITELLM_PROXY_MASTER_KEY}" | base64 --decode)
curl -X GET http://localhost:4000/v1/models -H "Authorization: Bearer $MASTER_KEY"
```

### **Check OpenWebUI Integration**
```bash
# View OpenWebUI logs
kubectl logs -f statefulset/open-webui -n ai

# Check OpenWebUI environment variables
kubectl get statefulset open-webui -n ai -o yaml | grep -A 5 -B 5 LITELLM

# Test OpenWebUI access
open http://openwebui.localhost
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
- **Traefik Ingress Rules**: `docs/rules-ingress-traefik.md`
- **Authentik Setup**: `manifests/075-authentik-config.yaml`
- **Infrastructure Overview**: `docs/infrastructure-readme.md`

## 🎯 **Summary**

This AI infrastructure management approach provides:

### **✅ Benefits**
- **Unified architecture** - single production-ready environment with LiteLLM + OpenWebUI
- **Centralized configuration** - all model management through ConfigMap in kubernetes-secrets.yml
- **Enterprise authentication** - OAuth2 with Authentik for user and group management
- **Multi-provider support** - local Ollama + cloud providers through LiteLLM proxy
- **Clean deployment** - complete removal and reinstallation capabilities

### **🔄 Recommended Workflow**
1. **Start** with complete AI infrastructure deployment via `./scripts/packages/ai.sh`
2. **Configure models** by editing `topsecret/kubernetes/kubernetes-secrets.yml`
3. **Manage user access** through OpenWebUI admin panel and Authentik groups
4. **Test changes** by restarting LiteLLM deployment after configuration updates
5. **Clean reinstall** when needed using removal scripts + redeploy

This approach provides a production-ready AI platform with enterprise features while maintaining developer-friendly configuration management.
