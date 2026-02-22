# LiteLLM AI Proxy Setup Guide

This document explains how LiteLLM is configured in the Urbalurba infrastructure and how to add/configure AI models.

## Overview

LiteLLM is deployed as a unified AI model proxy that provides OpenAI-compatible API endpoints for multiple model sources including:
- Local Ollama instances (in-cluster and external)
- Cloud AI providers (OpenAI, Anthropic, Google, etc.)
- Custom model endpoints

## Architecture

```
Applications → LiteLLM Proxy → Model Sources
                   ↓
            Shared PostgreSQL
```

### Key Components
- **LiteLLM Pod**: Main proxy service (`ai` namespace)
- **Shared PostgreSQL**: Database for configuration, keys, and usage tracking
- **ConfigMap**: Model configuration and routing rules
- **Ingress**: External access via `http://litellm.localhost`

## Database Setup

LiteLLM uses a dedicated database on the shared PostgreSQL instance:
- Database: `litellm`
- User: `litellm`
- Host: `postgresql.default.svc.cluster.local:5432`

### Database Management

**Create database:**
```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/utility/u10-litellm-create-postgres.yml -e operation=create
```

**Delete database (⚠️ DESTRUCTIVE):**
```bash
ansible-playbook ansible/playbooks/utility/u10-litellm-create-postgres.yml -e operation=delete -e force_delete=true
```

## Configuration Management

LiteLLM configuration is managed via external ConfigMap in `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`. The Helm chart is configured to use this existing ConfigMap rather than creating its own.

**Helm Configuration (`manifests/220-litellm-config.yaml`):**
```yaml
# Use existing ConfigMap instead of inline config
configMapRef:
  name: litellm-config
  key: config.yaml

# Disable Helm-managed ConfigMap creation
proxyConfigMap:
  create: false
  name: litellm-config
```

**ConfigMap Definition (`.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`):**
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

## Adding New Models

### 1. Ollama Models (Local)

**In-cluster Ollama:**
```yaml
- model_name: qwen3-0.6b-incluster
  litellm_params:
    model: ollama/qwen3:0.6b
    api_base: "http://ollama.ai.svc.cluster.local:11434"
```

**External Ollama (Mac/Host):**
```yaml
- model_name: external-llama3
  litellm_params:
    model: ollama/llama3:8b
    api_base: "http://host.lima.internal:11434"
    temperature: 0.7
```

### 2. Cloud Providers

**OpenAI:**
```yaml
- model_name: gpt-4o
  litellm_params:
    model: gpt-4o
    api_key: "os.environ/OPENAI_API_KEY"
```

**Anthropic Claude:**
```yaml
- model_name: claude-3-sonnet
  litellm_params:
    model: anthropic/claude-3-sonnet-20240229
    api_key: "os.environ/ANTHROPIC_API_KEY"
```

**Google Gemini:**
```yaml
- model_name: gemini-pro
  litellm_params:
    model: gemini/gemini-pro
    api_key: "os.environ/GOOGLE_API_KEY"
```

### 3. Model Variants with Different Temperatures

```yaml
- model_name: mac-gpt-oss-creative
  litellm_params:
    model: ollama/gpt-oss:20b
    api_base: "http://host.lima.internal:11434"
    temperature: 0.9

- model_name: mac-gpt-oss-precise
  litellm_params:
    model: ollama/gpt-oss:20b
    api_base: "http://host.lima.internal:11434"
    temperature: 0.3
```

### 4. Fallback Configuration

```yaml
- model_name: gpt-4-with-fallback
  litellm_params:
    model: gpt-4
    api_key: "os.environ/OPENAI_API_KEY"
    fallbacks:
      - model: ollama/llama3:8b
        api_base: "http://host.lima.internal:11434"
```

## Deployment Process

### 1. Update Configuration
Edit the ConfigMap in `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`

### 2. Apply Changes
```bash
kubectl apply -f .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
```

### 3. Restart LiteLLM
```bash
kubectl rollout restart deployment/litellm -n ai
```

### 4. Verify Models
```bash
# Port forward to access API
kubectl port-forward svc/litellm 4000:4000 -n ai

# Get master key
MASTER_KEY=$(kubectl get secret urbalurba-secrets -n ai -o jsonpath="{.data.LITELLM_PROXY_MASTER_KEY}" | base64 --decode)

# List available models
curl -X GET http://localhost:4000/v1/models -H "Authorization: Bearer $MASTER_KEY"
```

## Full Installation

Use the Ansible playbook for complete setup:

```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/210-setup-litellm.yml
```

This playbook:
1. Creates the PostgreSQL database
2. Deploys LiteLLM via Helm
3. Applies ingress configuration
4. Verifies installation

## API Usage

### Authentication
All requests require the master key:
```bash
Authorization: Bearer $MASTER_KEY
```

### List Models
```bash
curl -X GET http://localhost:4000/v1/models \
  -H "Authorization: Bearer $MASTER_KEY"
```

### Chat Completion
```bash
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{
    "model": "mac-gpt-oss-balanced",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Environment Variables

Required secrets in `urbalurba-secrets`:
- `LITELLM_PROXY_MASTER_KEY`: API authentication (secure random key)
- `LITELLM_POSTGRESQL__USER`: Database username (`litellm`)
- `LITELLM_POSTGRESQL__PASSWORD`: Database password (secure random password)
- `OPENAI_API_KEY`: OpenAI API access (if using OpenAI models)
- `ANTHROPIC_API_KEY`: Anthropic API access (if using Claude)
- `GOOGLE_API_KEY`: Google API access (if using Gemini)

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n ai
kubectl logs -f deployment/litellm -n ai
```

### Database Connection Issues
```bash
# Test database connectivity
kubectl exec -it litellm-xxx -n ai -- psql postgresql://litellm:$DB_PASSWORD@postgresql.default.svc.cluster.local:5432/litellm
```

### Model Not Available
1. Verify model configuration in ConfigMap
2. Check API keys for cloud providers
3. Ensure Ollama is running and accessible
4. Review LiteLLM logs for specific errors

### Configuration Reload
```bash
kubectl rollout restart deployment/litellm -n ai
kubectl rollout status deployment/litellm -n ai
```

## Access Points

- **Internal**: `http://litellm.ai.svc.cluster.local:4000`
- **External**: `http://litellm.localhost` (via Traefik)
- **Port Forward**: `kubectl port-forward svc/litellm 4000:4000 -n ai`

## LiteLLM Admin UI Access

**⚠️ IMPORTANT**: The LiteLLM Admin UI with authentication is an **Enterprise/Premium feature only**.

### Free Version (Current Setup):
- ✅ **API Access**: Full API functionality available
- ✅ **Model Management**: Via API calls and OpenWebUI interface
- ❌ **Web Admin UI**: No authentication available (requires Enterprise license)

### Enterprise Version (Paid):
- ✅ **Authenticated Web UI**: Username/password protection
- ✅ **Advanced Features**: SSO, RBAC, audit logging
- ✅ **Dashboard Access**: Full web-based management interface

### Alternative Access:
Since the web UI requires a paid license, use OpenWebUI (`http://openwebui.localhost`) as your primary interface for:
- Model selection and management
- Chat interface with all LiteLLM models
- User authentication via Authentik integration

## Best Practices

1. **Model Naming**: Use descriptive names indicating source and characteristics
2. **Temperature Variants**: Create separate model entries for different use cases
3. **Fallbacks**: Configure local models as fallbacks for cloud models
4. **API Keys**: Store sensitive keys in Kubernetes secrets, reference as `os.environ/KEY_NAME`
5. **Testing**: Always verify model availability after configuration changes
6. **Monitoring**: Check logs regularly for authentication and connectivity issues

## Complete AI Infrastructure Setup

### Using the Orchestration Script

For a complete AI infrastructure deployment with both LiteLLM and OpenWebUI:

```bash
# From host machine
scripts/packages/ai.sh

# This runs the complete orchestration inside provision-host container
```

**The orchestration performs:**
1. **LiteLLM Setup**: Database creation + Helm deployment + ConfigMap configuration
2. **OpenWebUI Setup**: Database setup + Tika deployment + OpenWebUI with LiteLLM integration
3. **Ingress Configuration**: External access via `openwebui.localhost` and `litellm.localhost`

### Manual Component Installation

**LiteLLM Only:**
```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/210-setup-litellm.yml
```

**OpenWebUI Only (requires LiteLLM running):**
```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/200-setup-open-webui.yml -e deploy_ollama_incluster=false
```

### Final Configuration

After deployment, configure OpenWebUI to use LiteLLM:

1. **Access OpenWebUI**: `http://openwebui.localhost`
2. **Create Admin User**: First login creates admin account
3. **Configure LiteLLM Connection**:
   - Go to Settings → Connections
   - URL: `http://litellm.ai.svc.cluster.local:4000/v1`
   - Auth: Bearer
   - API Key: `$(kubectl get secret urbalurba-secrets -n ai -o jsonpath="{.data.LITELLM_PROXY_MASTER_KEY}" | base64 --decode)`
4. **Save and Refresh**: All LiteLLM models will appear in OpenWebUI

## Integration with OpenWebUI

LiteLLM integrates seamlessly with OpenWebUI:
1. OpenWebUI configured to use LiteLLM as OpenAI-compatible backend
2. All LiteLLM models appear in OpenWebUI model dropdown
3. Arena mode available for model comparison
4. Single authentication point for all AI providers
5. Shared PostgreSQL database for both services
6. Unified ingress access via Traefik