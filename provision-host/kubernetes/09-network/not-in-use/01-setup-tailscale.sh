#!/bin/bash
# filename: 01-setup-tailscale.sh
# description: Start Tailscale network on a cluster using the unified deployment script.
# 
# This script is a wrapper that calls 802-tailscale-tunnel-deploy.sh to set up
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
# - 802-tailscale-tunnel-deploy.sh: The unified script that sets up Tailscale operator and cluster ingress
# - 802-tailscale-tunnel-deploy.sh <service>: Used to expose individual services after this setup
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute 802-tailscale-tunnel-deploy.sh

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1  
fi  

# call the networking/tailscale/802-tailscale-tunnel-deploy.sh script
# we are in the provision-host/kubernetes/09-network directory so we go up two levels to reach root
../../networking/tailscale/802-tailscale-tunnel-deploy.sh


