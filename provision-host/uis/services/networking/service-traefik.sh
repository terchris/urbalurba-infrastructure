#!/bin/bash
# service-traefik.sh - Traefik ingress controller service metadata
#
# Traefik is the cluster ingress controller across all UIS platforms.
# - rancher-desktop: bundled by k3s; the deploy playbook detects this and skips.
# - AKS / GCP / AWS / bare k8s: deploy playbook installs via helm with pinned chart.

# === Service Metadata (Required) ===
SCRIPT_ID="traefik"
SCRIPT_NAME="Traefik"
SCRIPT_DESCRIPTION="Cluster ingress controller and reverse proxy"
SCRIPT_CATEGORY="NETWORKING"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="003-setup-traefik.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="003-remove-traefik.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="3"

# === Deployment Details (Optional) ===
SCRIPT_HELM_CHART="traefik/traefik"
SCRIPT_NAMESPACE="kube-system"
SCRIPT_IMAGE="traefik:v3.6.13"

# === Extended Metadata (Optional) ===
SCRIPT_KIND="Component"        # Component | Resource
SCRIPT_TYPE="service"          # service | tool | library | database | cache | message-broker
SCRIPT_OWNER="platform-team"   # platform-team | app-team

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="IngressRoute-driven cluster ingress, pinned to chart v39.0.7 + proxy v3.6.13 for rancher-desktop k3s parity"
SCRIPT_LOGO="traefik-logo.svg"
SCRIPT_WEBSITE="https://traefik.io/"
SCRIPT_TAGS="ingress,reverse-proxy,traefik,networking,ingressroute"
SCRIPT_SUMMARY="Traefik is a cloud-native edge router that exposes services via Kubernetes Ingress and the IngressRoute CRD. UIS pins the chart and proxy versions to match the bundled k3s chart that rancher-desktop ships, so local-dev and cloud clusters run the same Traefik."
SCRIPT_DOCS="/docs/services/networking/traefik"
