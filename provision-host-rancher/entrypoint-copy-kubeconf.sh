#!/bin/bash
# File: provision-host-rancher/prepare-rancher-environment.sh
# Kubernetes Config File Copy Entrypoint Script
#
# Purpose:
# This entrypoint script solves a specific configuration transition challenge:
# We're moving from host-mounted Kubernetes config to a config stored on a
# Docker volume. On first container start, we need to initialize the volume
# with the host's kubeconfig, but on subsequent starts, we must preserve
# the evolved kubeconfig on the volume.
#
# Workflow:
# 1. Check if target kubeconfig already exists on the volume
# 2. If not present AND host kubeconfig is mounted, copy it as initial setup
# 3. Set proper ownership so the ansible user can access it
# 4. Switch to the ansible user and execute the main container command


set -e

# Target kubeconfig path on the volume
TARGET_KUBECONFIG="/mnt/urbalurbadisk/kubeconfig/kubeconf-all"
# Host-mounted kubeconfig path
HOST_KUBECONFIG="/tmp/host-kube/config"

# Log for visibility 
echo "* Starting entrypoint script for kubeconfig setup"

# Only copy if target doesn't exist yet AND host config is available
if [ ! -f "$TARGET_KUBECONFIG" ] && [ -f "$HOST_KUBECONFIG" ]; then
  echo "* Target kubeconfig does not exist yet - performing initial setup"
  echo "* Found host kubeconfig at $HOST_KUBECONFIG"
  
  # Create target directory structure on the volume
  echo "* Creating target directory structure"
  mkdir -p /mnt/urbalurbadisk/kubeconfig
  
  # Copy kubeconfig from host to the specified location on volume
  echo "* Copying initial kubeconfig to $TARGET_KUBECONFIG"
  cp "$HOST_KUBECONFIG" "$TARGET_KUBECONFIG"
  
  # Ensure ansible user can access the file
  echo "* Setting appropriate permissions for ansible user"
  chown -R ansible:ansible /mnt/urbalurbadisk/kubeconfig
  
  echo "* Successfully set up initial kubeconfig on volume"
else
  if [ -f "$TARGET_KUBECONFIG" ]; then
    echo "* Existing kubeconfig found on volume - preserving configurations"
  else
    echo "* No host kubeconfig available for initial setup"
    echo "* You may need to manually set up kubeconfig at $TARGET_KUBECONFIG"
  fi
fi

# Switch to ansible user before executing the main container command
if [ "$(id -u)" = "0" ]; then
  echo "* Switching to ansible user for container execution"
  exec sudo -u ansible "$@"
else
  exec "$@"
fi