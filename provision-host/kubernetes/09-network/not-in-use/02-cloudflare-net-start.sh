#!/bin/bash
# filename: 02-cloudflare-net-start.sh
# description: Deploy Cloudflare tunnel connector to Kubernetes cluster.
# 
# This script is a wrapper that calls 821-cloudflare-tunnel-deploy.sh to deploy
# the Cloudflare tunnel connector pod to the Kubernetes cluster.
#
# Prerequisites:
# - Run 820-cloudflare-tunnel-setup.sh first to create tunnel and store credentials
# - cloudflared-credentials secret must exist in cluster with domain metadata
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
#
# Usage: ./02-cloudflare-net-start.sh
#
# Related scripts:
# - 820-cloudflare-tunnel-setup.sh: Creates tunnel and stores credentials (requires human interaction)
# - 821-cloudflare-tunnel-deploy.sh: Deploys tunnel connector pod (this script)
# - 822-cloudflare-tunnel-delete.sh: Removes tunnel connector and cleans up
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute 821-cloudflare-tunnel-deploy.sh

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1  
fi  

# call the networking/cloudflare/821-cloudflare-tunnel-deploy.sh script
# we are in the provision-host/kubernetes/09-network directory so we go up two levels to reach root
../../networking/cloudflare/821-cloudflare-tunnel-deploy.sh
