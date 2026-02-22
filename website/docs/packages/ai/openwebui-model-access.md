# OpenWebUI Model Access Setup Guide

This guide covers how to configure model access for users in the OpenWebUI environment that integrates with LiteLLM proxy and Authentik authentication.

## LiteLLM Integration Model Access

### Overview
OpenWebUI is configured to use LiteLLM as the primary model provider, which gives access to multiple model sources through a unified interface. Models are configured in the LiteLLM ConfigMap and automatically discovered by OpenWebUI.

### Model Sources Available:
- **Local Ollama models** (in-cluster and external)
- **Cloud providers** (OpenAI, Anthropic, Azure, Google)
- **Custom model configurations** with different parameters

### Current Model Configuration:
Available models from LiteLLM ConfigMap (`.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`):
- `mac-gpt-oss-balanced` - Local Ollama model with balanced temperature
- `mac-gpt-oss-creative` - Local Ollama model with high temperature
- `mac-gpt-oss-precise` - Local Ollama model with low temperature
- `external-ollama-gemma3` - External Ollama Gemma model
- `gpt-4o` - OpenAI GPT-4 Omni
- `azure-gpt-4` - Azure OpenAI GPT-4
- `claude-3-opus` - Anthropic Claude 3 Opus

## OAuth User Model Access Configuration

### Default Behavior
When OAuth users log in via Authentik, newly discovered models from LiteLLM proxy default to "Private" visibility for security reasons.

### Admin Configuration Steps:
1. **Login as admin user** (local account, not OAuth)
2. **Navigate to Admin Panel** → **Settings** → **Models**
3. **For each LiteLLM model you want OAuth users to access:**
   - Find the model in the list (e.g., `mac-gpt-oss-balanced`)
   - Change **"Visibility"** from **"Private"** to **"Public"**
   - Configure **"Whitelist"** if specific user groups should have access
   - Click **"Save & Update"**
4. **Test with OAuth user** - they should now see the models in dropdown

### Security Recommendations:
- ✅ **Local models**: Safe to make public (free, no API costs)
- ⚠️ **Cloud models**: Carefully control access (paid API usage)
- 🔒 **Premium models**: Keep private or whitelist specific groups
- 📊 **Cost tracking**: Monitor usage through LiteLLM admin interface

### Group-Based Access Control:
Configure model access by Authentik groups:
1. **Admin Panel** → **Settings** → **Models**
2. **Select model** → **Advanced Settings**
3. **Whitelist specific groups** (matches Authentik group names)
4. **Apply group restrictions** for cost-sensitive models

## LiteLLM Model Management

### Adding New Models
To add new models to the system:

1. **Edit ConfigMap** in `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml`:
   ```yaml
   model_list:
     - model_name: new-model-name
       litellm_params:
         model: provider/model-id
         api_key: "os.environ/API_KEY_NAME"
   ```

2. **Apply changes**:
   ```bash
   kubectl apply -f .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
   ```

3. **Restart LiteLLM**:
   ```bash
   kubectl rollout restart deployment/litellm -n ai
   ```

4. **Configure model visibility** in OpenWebUI admin panel

### Cost Management
- **Free models**: Local Ollama models have no ongoing costs
- **Paid models**: Cloud provider models charge per token/request
- **Monitoring**: Check LiteLLM logs for usage and costs
- **Budget control**: Use model whitelisting for expensive models

### Troubleshooting:
- **OAuth user still can't see models?** Check that model visibility is set to "Public"
- **New models not appearing?** They default to "Private" - admin must make them "Public"
- **Admin can see models but OAuth user cannot?** This is expected behavior with "Private" models
- **Models not loading from LiteLLM?** Check ConfigMap format and restart LiteLLM deployment
- **API errors for cloud models?** Verify API keys are set correctly in secrets
