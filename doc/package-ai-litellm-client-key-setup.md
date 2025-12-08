# LiteLLM Client API Key Setup - Claude Code Integration

**File**: `doc/package-ai-litellm-client-key-setup.md`
**Purpose**: Guide for generating and managing LiteLLM client API keys for Claude Code DevContainer integration
**Target Audience**: Developers, DevOps engineers using Claude Code in DevContainers
**Last Updated**: November 23, 2025

## 📋 Overview

LiteLLM uses a **two-key system** for security and access management:

- **Master Key**: Stored in `urbalurba-secrets`, used for administrative operations (key generation, management)
- **Client Keys**: Generated via API, stored in LiteLLM's PostgreSQL database, scoped to specific models

This guide covers generating **client API keys** for developers using Claude Code in DevContainers.

**Why Client Keys:**
- ✅ Scoped access to specific models only
- ✅ Usage tracking per developer/client
- ✅ Cost attribution and monitoring
- ✅ Independent key rotation without affecting other users
- ✅ Revocable without impacting master key

## 🚀 Quick Setup

### Step 1: Get the Master Key

```bash
MASTER_KEY=$(kubectl get secret urbalurba-secrets -n ai -o jsonpath="{.data.LITELLM_PROXY_MASTER_KEY}" | base64 --decode)
echo "Master key retrieved: ${MASTER_KEY:0:10}..."
```

### Step 2: Port Forward to LiteLLM

```bash
kubectl port-forward -n ai svc/litellm 4000:4000 &
sleep 3
```

**Note**: Keep this running in the background. You can stop it later with `pkill -f "kubectl port-forward.*litellm"`.

### Step 3: Generate Client API Key

**IMPORTANT**: Replace `developer-name` with the actual developer's name (e.g., `john-doe`, `jane-smith`).

```bash
DEVELOPER_NAME="developer-name"  # CHANGE THIS

curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"models\": [\"claude-sonnet-4-5-20250929\", \"claude-3-opus-20240229\"],
    \"key_alias\": \"claude-code-${DEVELOPER_NAME}\",
    \"duration\": null
  }"
```

**Response Example:**
```json
{
  "key": "sk-xxxxxxxxxxxxxxxxxx",
  "key_alias": "claude-code-developer-name",
  "key_name": null,
  "expires": null,
  "models": ["claude-sonnet-4-5-20250929", "claude-3-opus-20240229"],
  "created_at": "2025-11-23T15:30:00.000000Z",
  "...": "..."
}
```

**⚠️ SAVE THE `key` VALUE!** This is the only time you'll see it. The developer needs this for their DevContainer.

### Step 4: Provide Key to Developer

Send the developer:
1. The `key` value (e.g., `sk-xxxxxxxxxxxxxxxxxx`)
2. Instructions to add it to their DevContainer

**Developer should run:**
```bash
# In their DevContainer
bash .devcontainer/additions/config-claude-code.sh
```

When prompted, they enter the client API key you generated.

### Step 5: Clean Up

```bash
# Stop the port-forward
pkill -f "kubectl port-forward.*litellm"
```

## 🔍 Verification

### Test the Client Key

**From cluster (Mac host):**
```bash
CLIENT_KEY="sk-xxxxxxxxxxxxxxxxxx"  # The generated key

# Port-forward if not already running
kubectl port-forward -n ai svc/litellm 4000:4000 &

# Test models endpoint
curl -H "Authorization: Bearer $CLIENT_KEY" \
  http://localhost:4000/v1/models

# Should return models list including:
# - claude-sonnet-4-5-20250929
# - claude-3-opus-20240229
```

**From DevContainer:**
```bash
# Test through nginx reverse proxy
curl -H "Authorization: Bearer $CLIENT_KEY" \
  http://localhost:8080/v1/models
```

**Expected Response:**
```json
{
  "data": [
    {"id": "claude-sonnet-4-5-20250929", "object": "model", ...},
    {"id": "claude-3-opus-20240229", "object": "model", ...}
  ],
  "object": "list"
}
```

## 🛠️ Key Management

### List All Client Keys

```bash
curl -H "Authorization: Bearer $MASTER_KEY" \
  http://localhost:4000/key/info
```

### View Specific Key Info

```bash
CLIENT_KEY_HASH="1ffd879a..."  # From key info response

curl -H "Authorization: Bearer $MASTER_KEY" \
  "http://localhost:4000/key/info?key=${CLIENT_KEY_HASH}"
```

### Delete a Client Key

**Use when:**
- Developer leaves the team
- Key is compromised
- Regular key rotation

```bash
curl -X DELETE http://localhost:4000/key/delete \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"keys": ["sk-key-to-delete"]}'
```

### Rotate Keys

**Best Practice**: Rotate keys quarterly or when a developer changes roles.

```bash
# 1. Generate new key (follow Step 3)
# 2. Provide new key to developer
# 3. Developer updates DevContainer configuration
# 4. Verify new key works
# 5. Delete old key (optional, for security)
```

## 🔧 Troubleshooting

### Error: "Key not allowed to access model"

**Symptom:**
```json
{
  "error": {
    "message": "key not allowed to access model. This key can only access models=['claude-sonnet-4.5', 'claude-3-opus']",
    ...
  }
}
```

**Cause:** Key was generated with short model names, but Claude Code requests full names.

**Solution:** Regenerate key with **full model names**:
```bash
# ❌ Wrong:
"models": ["claude-sonnet-4.5", "claude-3-opus"]

# ✅ Correct:
"models": ["claude-sonnet-4-5-20250929", "claude-3-opus-20240229"]
```

### Error: "Invalid model name"

**Symptom:**
```json
{
  "error": "completion: Invalid model name passed in model=claude-sonnet-4-5-20250929"
}
```

**Cause:** LiteLLM ConfigMap doesn't have model name aliases.

**Solution:** Verify ConfigMap has both short and full model names:
```bash
kubectl get configmap litellm-config -n ai -o yaml | grep "model_name:"
```

Should show:
- `claude-sonnet-4.5` (short name)
- `claude-sonnet-4-5-20250929` (full name)

If missing, apply the updated configuration.

### Error: "Authentication Error, No api key passed in"

**Cause:** Master key or client key not provided correctly.

**Solutions:**
- Verify key copied correctly (no extra spaces/newlines)
- Check Authorization header format: `Authorization: Bearer sk-xxxxx`
- Verify port-forward is running: `lsof -i :4000`

### Port-Forward Keeps Dying

**Cause:** Network interruption or kubectl timeout.

**Solution:** Run in persistent loop:
```bash
while true; do
  kubectl port-forward -n ai svc/litellm 4000:4000
  echo "Port forward died, restarting in 5 seconds..."
  sleep 5
done
```

## 🔒 Security Notes

### Best Practices

- ✅ **Generate unique keys per developer** - Use developer name in alias
- ✅ **Scope to minimum models needed** - Only add models developer will use
- ✅ **Set expiration for temporary access** - Use `duration` parameter (e.g., `"30d"`)
- ✅ **Rotate keys quarterly** - Regular rotation improves security
- ✅ **Revoke on developer departure** - Delete keys when team members leave
- ✅ **Monitor usage** - Check LiteLLM logs for unusual activity
- ✅ **Never commit keys to git** - Store in `.env` files (gitignored)

### What NOT to Do

- ❌ **Never share the master key** - Only use for admin operations
- ❌ **Don't reuse client keys** - Each developer gets unique key
- ❌ **Don't commit keys to repos** - Always gitignore `.env` files
- ❌ **Don't set unlimited duration without reason** - Use expiration when possible
- ❌ **Don't grant access to all models** - Scope to needed models only

### Key Storage

**Developer DevContainer:**
- Keys stored in gitignored `.env` files
- Loaded by DevContainer configuration scripts
- Never committed to version control

**LiteLLM Database:**
- Client keys stored in PostgreSQL
- Backed up with standard database backups
- Retrievable via master key API calls

## 📊 Usage Monitoring

### Track Key Usage

```bash
# Get spending per key
curl -H "Authorization: Bearer $MASTER_KEY" \
  http://localhost:4000/spend/tags
```

### View Request Logs

```bash
# Check LiteLLM logs for specific key
kubectl logs -n ai deployment/litellm | grep "claude-code-developer-name"
```

**Metrics Tracked:**
- Request count per model
- Token usage (input/output)
- Cost per request
- Success/failure rates
- Timestamp and model used

## 🔗 Related Documentation

- **[package-ai-litellm.md](./package-ai-litellm.md)** - Main LiteLLM documentation
- **[package-ai-readme.md](./package-ai-readme.md)** - AI services overview
- **DevContainer nginx configuration** - `.devcontainer/additions/nginx/`

## 📝 Notes

- Client keys are **independent of cluster rebuilds** - Stored in LiteLLM's PostgreSQL database
- Master key rotation requires **regenerating all client keys**
- DevContainer nginx auto-adds `Host: litellm.localhost` header for Traefik routing
- Claude Code bug #2182: Host header override workaround via nginx proxy

---

**Generated**: 2025-11-23
**Maintained by**: Platform Engineering Team
