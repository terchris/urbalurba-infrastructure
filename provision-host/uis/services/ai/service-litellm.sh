#!/bin/bash
# service-litellm.sh - LiteLLM service metadata
#
# LiteLLM provides a unified API for multiple LLM providers.

# === Service Metadata (Required) ===
SCRIPT_ID="litellm"
SCRIPT_NAME="LiteLLM"
SCRIPT_DESCRIPTION="Unified API gateway for LLM providers"
SCRIPT_CATEGORY="AI"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="210-setup-litellm.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n ai -l app=litellm --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="51"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Call 100+ LLM APIs using OpenAI format"
SCRIPT_LOGO="litellm-logo.webp"
SCRIPT_WEBSITE="https://litellm.ai"
