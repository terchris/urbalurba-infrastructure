#!/bin/bash
# filename: 01-remove-tailscale.sh
# description: Remove Tailscale network from a cluster using the unified removal script.
#
# This script is a wrapper that calls 804-tailscale-tunnel-delete.sh to remove
# the Tailscale infrastructure from the Kubernetes cluster.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Tailscale operator and resources already deployed
#
# Usage: ./01-remove-tailscale.sh
#
# Related scripts:
# - 01-setup-tailscale.sh: Sets up Tailscale infrastructure
# - 804-tailscale-tunnel-delete.sh: The unified script that removes Tailscale operator and resources
# - 803-tailscale-tunnel-deletehost.sh: Removes specific host endpoints
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute 804-tailscale-tunnel-delete.sh

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# call the networking/tailscale/804-tailscale-tunnel-delete.sh script
# we are in the provision-host/kubernetes/09-network directory so we go up two levels to reach root
../../networking/tailscale/804-tailscale-tunnel-delete.sh

