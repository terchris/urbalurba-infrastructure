---
title: LiteLLM
sidebar_label: LiteLLM
---

# LiteLLM

Unified API gateway for multiple LLM providers with OpenAI-compatible endpoints.

| | |
|---|---|
| **Category** | AI |
| **Deploy** | `./uis deploy litellm` |
| **Undeploy** | `./uis undeploy litellm` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Helm chart** | `oci://ghcr.io/berriai/litellm-helm` (unpinned) |
| **Default namespace** | `ai` |

## What It Does

LiteLLM is an AI model proxy that provides a single OpenAI-compatible API endpoint for multiple model providers. Applications (including Open WebUI) connect to LiteLLM instead of directly to model providers.

Key capabilities:
- **Unified API** — OpenAI-compatible endpoint for all providers
- **Multi-provider support** — OpenAI, Anthropic, Google, Ollama, and more
- **Model routing** — configure multiple models with different parameters
- **API key management** — two-key system (master key + client keys)
- **Fallback chains** — automatic failover between model providers
- **Cost tracking** — per-model usage stored in PostgreSQL

Supported providers:
- **Local**: Ollama (in-cluster or external)
- **Cloud**: OpenAI, Anthropic Claude, Google Gemini

## Deploy

```bash
# Deploy dependency first
./uis deploy postgresql

# Deploy LiteLLM
./uis deploy litellm
```

## Verify

```bash
# Quick check
./uis verify litellm

# Manual check
kubectl get pods -n ai -l app.kubernetes.io/name=litellm

# Test the API
curl -s http://litellm.localhost/health
```

Access the API at `http://litellm.localhost`.

## Configuration

Model configuration is stored in a ConfigMap (`ai-models-litellm`) that defines available models, their providers, and parameters.

| Setting | Value | Notes |
|---------|-------|-------|
| API port | `4000` | OpenAI-compatible endpoint |
| Database | PostgreSQL | `litellm` database for usage tracking |
| Models | ConfigMap | `ai-models-litellm` in the `ai` namespace |

### Secrets

| Variable | File | Purpose |
|----------|------|---------|
| `DEFAULT_LITELLM_MASTER_KEY` | `.uis.secrets/secrets-config/default-secrets.env` | Admin API key |
| Cloud API keys | `.uis.secrets/secrets-config/default-secrets.env` | OpenAI, Anthropic, Google keys (optional) |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/210-setup-litellm.yml` | Deployment playbook |
| `ansible/playbooks/210-remove-litellm.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy litellm
```

Open WebUI will lose access to models when LiteLLM is removed.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n ai -l app.kubernetes.io/name=litellm
kubectl logs -n ai -l app.kubernetes.io/name=litellm
```

**Models not appearing in Open WebUI:**
Check the model ConfigMap:
```bash
kubectl get configmap ai-models-litellm -n ai -o yaml
```

**Cloud provider returns 401:**
Verify API keys are configured in secrets:
```bash
./uis secrets status
```

## Learn More

- [Official LiteLLM documentation](https://docs.litellm.ai/)
- [Client API key setup](./litellm-client-keys.md)
- [Open WebUI integration](./openwebui.md)
- [Environment management](./environment-management.md)
