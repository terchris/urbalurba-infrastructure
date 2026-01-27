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
SCRIPT_CHECK_COMMAND="kubectl get pods -n jupyterhub -l app=jupyterhub --no-headers 2>/dev/null | grep -q Running"
SCRIPT_REMOVE_PLAYBOOK="350-remove-jupyterhub.yml"
SCRIPT_REQUIRES=""
SCRIPT_PRIORITY="92"

# === Website Metadata (Optional) ===
SCRIPT_ABSTRACT="Multi-user server for Jupyter notebooks enabling collaborative data science"
SCRIPT_LOGO="jupyterhub-logo.webp"
SCRIPT_WEBSITE="https://jupyter.org/hub"
SCRIPT_TAGS="notebooks,jupyter,python,data-science,collaboration"
SCRIPT_SUMMARY="JupyterHub is a multi-user server that manages and proxies multiple instances of Jupyter notebooks. It enables teams to share computational environments and collaborate on data science projects."
SCRIPT_DOCS="/docs/packages/datascience/jupyterhub"
