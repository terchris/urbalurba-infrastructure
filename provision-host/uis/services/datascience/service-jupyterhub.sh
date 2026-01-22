#!/bin/bash
# service-jupyterhub.sh - JupyterHub service metadata
#
# JupyterHub is a multi-user server for Jupyter notebooks.

# === Service Metadata (Required) ===
SCRIPT_ID="jupyterhub"
SCRIPT_NAME="JupyterHub"
SCRIPT_DESCRIPTION="Multi-user Jupyter notebook server"
SCRIPT_CATEGORY="DATASCIENCE"

# === UIS-Specific (Optional) ===
SCRIPT_PLAYBOOK="350-setup-jupyterhub.yml"
SCRIPT_MANIFEST=""
SCRIPT_CHECK_COMMAND="kubectl get pods -n datascience -l app.kubernetes.io/name=jupyterhub --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK=""
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="92"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Multi-user server for Jupyter notebooks enabling collaborative data science"
SCRIPT_LOGO="jupyterhub-logo.webp"
SCRIPT_WEBSITE="https://jupyter.org/hub"
