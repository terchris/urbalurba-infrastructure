#!/bin/bash
# filename: 01-tailscale-net-start.sh
# description: Start Tailscale network on a cluster using Ansible playbook.
# 
# This script is a wrapper that calls net2-setup-tailscale-cluster.sh to set up
# the base Tailscale infrastructure for the Kubernetes cluster.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Tailscale API credentials in urbalurba-secrets
#
# Usage: ./01-tailscale-net-start.sh
#
# Related scripts:
# - net2-setup-tailscale-cluster.sh: The main script that sets up Tailscale
# - net2-expose-tailscale-service.sh: Used to expose individual services after this setup
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute net2-setup-tailscale-cluster.sh

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1  
fi  

# call the networking/net2-setup-tailscale-cluster.sh script
# we are in the provision-host/kubernetes/09-network directory so we go up two levels to reach root
../../networking/net2-setup-tailscale-cluster.sh


