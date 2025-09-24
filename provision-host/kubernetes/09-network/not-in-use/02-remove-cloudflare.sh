#!/bin/bash
# filename: 02-remove-cloudflare.sh
# description: Remove Cloudflare tunnel connector from Kubernetes cluster.
#
# This script is a wrapper that calls 822-cloudflare-tunnel-delete.sh to remove
# the Cloudflare tunnel connector pod from the Kubernetes cluster.
#
# Prerequisites:
# - Kubernetes cluster with kubectl configured
# - Valid kubeconfig file
# - Cloudflare tunnel connector already deployed
#
# Usage: ./02-remove-cloudflare.sh
#
# Related scripts:
# - 02-setup-cloudflare.sh: Sets up Cloudflare tunnel connector
# - 820-cloudflare-tunnel-setup.sh: Creates tunnel and stores credentials
# - 821-cloudflare-tunnel-deploy.sh: Deploys tunnel connector pod
# - 822-cloudflare-tunnel-delete.sh: Removes tunnel connector (this script calls it)
#
# Exit codes:
# 0 - Success
# 1 - Script must be run with Bash
# 2 - Failed to execute 822-cloudflare-tunnel-delete.sh

# Ensure the script is run with Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script must be run with Bash"
    exit 1
fi

# call the networking/cloudflare/822-cloudflare-tunnel-delete.sh script
# we are in the provision-host/kubernetes/09-network directory so we go up two levels to reach root
../../networking/cloudflare/822-cloudflare-tunnel-delete.sh
