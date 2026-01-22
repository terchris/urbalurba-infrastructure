#!/bin/bash
# service-argocd.sh - ArgoCD service metadata
#
# ArgoCD is a GitOps continuous delivery tool for Kubernetes.

# === Service Metadata (Required) ===
SCRIPT_ID="argocd"
SCRIPT_NAME="ArgoCD"
SCRIPT_DESCRIPTION="GitOps continuous delivery for Kubernetes"
SCRIPT_CATEGORY="MANAGEMENT"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="220-setup-argocd.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="80"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Declarative GitOps CD for Kubernetes"
SCRIPT_LOGO="argocd-logo.webp"
SCRIPT_WEBSITE="https://argo-cd.readthedocs.io"
