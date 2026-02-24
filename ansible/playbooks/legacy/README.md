# Legacy Cloudflare Tunnel Playbooks

These playbooks used the **interactive credential-file-based approach** for Cloudflare tunnels.
They have been replaced by token-based playbooks in the parent directory.

## Files

- `820-setup-network-cloudflare-tunnel.yml` - Setup tunnel via interactive browser auth
- `821-deploy-network-cloudflare-tunnel.yml` - Deploy using generated JSON credentials

## Current Playbooks

- `../820-deploy-network-cloudflare-tunnel.yml` - Token-based deploy
- `../821-remove-network-cloudflare-tunnel.yml` - Remove tunnel
- `../822-verify-cloudflare.yml` - Verify configuration
