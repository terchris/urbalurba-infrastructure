#!/bin/bash
# service-tailscale-tunnel.sh - Tailscale tunnel service metadata
#
# Tailscale tunnel provides secure network access via WireGuard VPN.

# === Service Metadata (Required) ===
SCRIPT_ID="tailscale-tunnel"
SCRIPT_NAME="Tailscale Tunnel"
SCRIPT_DESCRIPTION="Secure mesh VPN tunnel"
SCRIPT_CATEGORY="NETWORK"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="801-setup-network-tailscale-tunnel.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n network -l app.kubernetes.io/name=tailscale --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="100"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Zero-config WireGuard-based mesh VPN for secure remote access"
SCRIPT_LOGO="tailscale-logo.webp"
SCRIPT_WEBSITE="https://tailscale.com"
