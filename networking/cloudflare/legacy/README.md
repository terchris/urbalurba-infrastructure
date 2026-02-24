# Legacy Cloudflare Tunnel Scripts

These scripts used the **interactive credential-file-based approach** for Cloudflare tunnels:
- Browser-based authentication (`cloudflared tunnel login`)
- Generated JSON credential files
- Local ConfigMap-based routing configuration

They have been replaced by the **token-based approach** where:
- User creates the tunnel in the Cloudflare dashboard
- Copies a single token into `00-common-values.env`
- Deploys with `./uis deploy cloudflare-tunnel`
- All routing is configured in the Cloudflare dashboard

## Files

- `820-cloudflare-tunnel-setup.sh` - Interactive tunnel creation via browser auth
- `821-cloudflare-tunnel-deploy.sh` - Deploy tunnel using generated credentials
- `822-cloudflare-tunnel-delete.sh` - Delete tunnel and clean up credentials

## Current Approach

See the main deploy/remove playbooks:
- `ansible/playbooks/820-deploy-network-cloudflare-tunnel.yml`
- `ansible/playbooks/821-remove-network-cloudflare-tunnel.yml`
