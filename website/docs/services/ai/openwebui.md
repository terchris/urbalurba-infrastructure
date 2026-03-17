---
title: Open WebUI
sidebar_label: Open WebUI
---

# Open WebUI

User-friendly chat interface for AI models with SSO integration.

| | |
|---|---|
| **Category** | AI |
| **Deploy** | `./uis deploy openwebui` |
| **Undeploy** | `./uis undeploy openwebui` |
| **Depends on** | postgresql |
| **Required by** | None |
| **Helm chart** | `open-webui/open-webui` (unpinned) |
| **Default namespace** | `ai` |

## What It Does

Open WebUI provides a ChatGPT-like interface for interacting with AI models. It connects to LiteLLM as its model backend, giving users access to both local (Ollama) and cloud (OpenAI, Anthropic, Google) models through a single UI.

Key capabilities:
- **Multi-model chat** — switch between models in the same conversation
- **SSO integration** — authenticates via Authentik (OAuth2/OIDC)
- **Model visibility control** — admins can set models as public or private
- **Group-based access** — control who can use expensive cloud models
- **Persistent history** — conversations stored in PostgreSQL
- **File uploads** — attach documents for context in conversations

## Deploy

```bash
# Deploy dependency first
./uis deploy postgresql

# Deploy Open WebUI
./uis deploy openwebui
```

Or use the AI stack:
```bash
./uis stack install ai-local
```

## Verify

```bash
# Quick check
./uis verify openwebui

# Manual check
kubectl get pods -n ai -l app.kubernetes.io/name=open-webui

# Test the UI
curl -s -o /dev/null -w "%{http_code}" http://openwebui.localhost
# Expected: 200
```

Access the interface at [http://openwebui.localhost](http://openwebui.localhost).

## Configuration

Open WebUI configuration is managed through Helm values and the deployment playbook.

| Setting | Value | Notes |
|---------|-------|-------|
| Port | `8080` | Web UI |
| Database | PostgreSQL | `openwebui` database with pgvector |
| Model backend | LiteLLM | Via internal service URL |
| Auth | Authentik SSO | OAuth2/OIDC when Authentik is deployed |

### Key Files

| File | Purpose |
|------|---------|
| `ansible/playbooks/200-setup-open-webui.yml` | Deployment playbook |
| `ansible/playbooks/200-remove-open-webui.yml` | Removal playbook |

## Undeploy

```bash
./uis undeploy openwebui
```

Conversation history is stored in PostgreSQL and preserved across redeploys.

## Troubleshooting

**Pod won't start:**
```bash
kubectl describe pod -n ai -l app.kubernetes.io/name=open-webui
kubectl logs -n ai -l app.kubernetes.io/name=open-webui
```

**No models available:**
Check that LiteLLM is running and accessible:
```bash
kubectl get pods -n ai -l app.kubernetes.io/name=litellm
```

**SSO login fails:**
If Authentik is deployed but login redirects fail, check the OAuth configuration:
```bash
kubectl get middleware -A | grep authentik
```

## Learn More

- [Official Open WebUI documentation](https://docs.openwebui.com/)
- [Model access configuration](./openwebui-model-access.md)
- [LiteLLM model proxy](./litellm.md)
- [Environment management](./environment-management.md)
