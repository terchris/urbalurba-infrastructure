---
title: AI & Machine Learning
sidebar_label: AI & ML
---

# AI & Machine Learning

The AI package provides a self-hosted AI platform with a chat interface and unified model gateway. It supports both local models (via Ollama) and cloud providers (OpenAI, Anthropic, Google).

## Services

| Service | Description | Deploy |
|---------|-------------|--------|
| [Open WebUI](./openwebui.md) | ChatGPT-like interface for AI models | `./uis deploy openwebui` |
| [LiteLLM](./litellm.md) | Unified API gateway for multiple LLM providers | `./uis deploy litellm` |

## Quick Start

```bash
./uis stack install ai-local
```

Or deploy individually:

```bash
./uis deploy postgresql   # Required dependency
./uis deploy litellm
./uis deploy openwebui
```

## How It Works

```
Users → Open WebUI → LiteLLM → Ollama (local models)
                              → OpenAI API
                              → Anthropic API
                              → Google Gemini API
```

1. Users interact with Open WebUI's chat interface
2. Open WebUI sends requests to LiteLLM's OpenAI-compatible API
3. LiteLLM routes to the appropriate model provider
4. Conversations are stored in PostgreSQL

All services deploy to the `ai` namespace.

## Guides

- [Model access configuration](./openwebui-model-access.md) — control which models users can see
- [LiteLLM client keys](./litellm-client-keys.md) — generate API keys for external tools
- [Environment management](./environment-management.md) — manage the AI infrastructure
