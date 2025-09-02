# OpenWebUI Model Access Setup Guide

TODO: In progress - we must now get the user data from authentik and decide what the user can have access to.

## OAuth User Model Access Configuration

### Problem
When OAuth users log in via Authentik, they cannot see models because newly discovered models default to "Private" visibility.

### Solution (Phase 1 - Local Models Only)
Manually configure model visibility through the admin interface:

### Steps:
1. **Login as admin user** (local account, not OAuth)
2. **Navigate to model settings** by clicking on any model in the interface
3. **For each Ollama model you want OAuth users to access:**
   - Change **"Visibility"** from **"Private"** to **"Public"**
   - Click **"Save & Update"**
4. **Test with OAuth user** - they should now see the models in dropdown

### Current Models to Configure:
- `qwen3:0.6b` (in-cluster Ollama)
- Any models from `host.lima.internal:11434` (external Ollama)

### Security Note:
This manual approach ensures that:
- ✅ Only free/local models are made public
- ✅ No risk of exposing expensive cloud models
- ✅ Future paid models (via LiteLLM) remain private by default

### Phase 2 Enhancement (Future):
When LiteLLM is added, we'll implement:
- Group-based model access control
- Automatic model visibility rules
- Cost-safe model access management

### Troubleshooting:
- **OAuth user still can't see models?** Check that model visibility is set to "Public"
- **New models not appearing?** They default to "Private" - admin must make them "Public"
- **Admin can see models but OAuth user cannot?** This is expected behavior with "Private" models
