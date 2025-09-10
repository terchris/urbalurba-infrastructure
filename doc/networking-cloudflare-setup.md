# Cloudflare Tunnel Setup Guide

**Purpose**: Professional internet access with custom domains  
**Audience**: Users wanting production-ready setup with own domains  
**Time Required**: 15-20 minutes  
**Prerequisites**: Working cluster with Traefik ingress

## 🚀 Quick Summary

Transform your local cluster from `http://service.localhost` to `https://service.yourcompany.com` with enterprise-grade security. Uses your Cloudflare-managed domain to provide global CDN, DDoS protection, and professional appearance.

## ✅ Prerequisites

Before starting, ensure you have:
- [ ] Kubernetes cluster running (Rancher Desktop or similar)
- [ ] Traefik ingress controller deployed
- [ ] Services accessible locally (e.g., `http://whoami.localhost`)
- [ ] Domain already added to Cloudflare (e.g., `urbalurba.no`)
- [ ] Access to provision-host container
- [ ] Logged into Cloudflare dashboard before running setup

⚠️ **CRITICAL**: You MUST be logged into [dash.cloudflare.com](https://dash.cloudflare.com) before running the setup script!

## 🔄 How Cloudflare Tunnel Works

The Cloudflare tunnel creates a secure outbound connection from your cluster to Cloudflare's edge:

```
Internet → Cloudflare Edge → Tunnel → Traefik → Your Services
```

**Key Benefits:**
- No port forwarding or firewall configuration needed
- Automatic SSL/TLS certificates
- DDoS protection and global CDN
- Works behind NAT/firewalls

## 📋 Script Overview

Three scripts manage the complete tunnel lifecycle:

| Script | Purpose | When to Use | Parameters |
|--------|---------|-------------|------------|
| `820-cloudflare-tunnel-setup.sh` | Creates tunnel & configures DNS | First time setup | `<domain>` required |
| `821-cloudflare-tunnel-deploy.sh` | Deploys tunnel to Kubernetes | After setup or updates | None (auto-detects) |
| `822-cloudflare-tunnel-delete.sh` | Removes tunnel completely | Clean up / start over | None (auto-detects) |

## 🚀 Quick Start Guide

### Step 1: Copy Scripts to Provision Host
```bash
# From your Mac host
./copy2provisionhost.sh
```

### Step 2: Create Tunnel and Configure DNS
```bash
# Inside provision-host container
docker exec -it provision-host bash
cd /mnt/urbalurbadisk

# Create tunnel (interactive - will open browser for auth)
./networking/cloudflare/820-cloudflare-tunnel-setup.sh urbalurba.no
```

**What happens:**
- Checks if tunnel already exists (smart detection)
- Opens browser for Cloudflare authentication
- Creates tunnel with unique credentials
- Configures DNS: `*.urbalurba.no` → tunnel
- Stores credentials for persistence

### Step 3: Deploy Tunnel to Kubernetes
```bash
# Deploy to current cluster (no parameters needed)
./networking/cloudflare/821-cloudflare-tunnel-deploy.sh
```

**What happens:**
- Creates Kubernetes secret with credentials
- Deploys tunnel connector pod
- Routes traffic to Traefik ingress
- Establishes connection to Cloudflare edge

### Step 4: Configure Root Domain (Optional)
By default, only `*.domain` (wildcard) is configured. To also use the root domain:

1. Add DNS route for root domain:
```bash
cloudflared tunnel --origincert /mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem \
  route dns cloudflare-tunnel urbalurba.no
```

2. Ensure no Cloudflare Workers are intercepting the root domain:
   - Check **Workers & Pages** → Remove any custom domains
   - Check **Workers Routes** → Delete routes for your domain

### Step 5: Verify Setup
```bash
# Test subdomain routing
curl https://whoami.urbalurba.no
curl https://openwebui.urbalurba.no

# Test root domain (if configured)
curl https://urbalurba.no
```

## 🗑️ Complete Cleanup

To completely remove a tunnel and start over:

```bash
# Delete everything (no parameters needed)
./networking/cloudflare/822-cloudflare-tunnel-delete.sh
```

**What gets deleted:**
- Kubernetes deployment, configmap, and secrets
- Cloudflare DNS routes
- Cloudflare tunnel
- Local configuration files

## 🔧 Troubleshooting

### Common Issues and Solutions

| Problem | Cause | Solution |
|---------|-------|----------|
| "Worker is Running!" on root domain | Cloudflare Worker intercepting traffic | Check Workers & Pages for custom domains, remove Worker routes |
| 502 Bad Gateway | Tunnel can't reach service | Verify Traefik is running, check tunnel logs |
| DNS_PROBE_FINISHED_NXDOMAIN | Missing DNS record | Run setup script or manually add CNAME in Cloudflare DNS |
| Tunnel pod not starting | Missing credentials | Re-run setup script to generate credentials |
| Certificate error during setup | Not logged into Cloudflare | Login to dash.cloudflare.com first |
| "Cannot have more than 50 tokens" | Too many API tokens created | Clean up unused tokens (see below) |

### Cleaning Up API Tokens (50 Token Limit)

Cloudflare has a limit of 50 API tokens per account. Each tunnel creation attempt generates a new token, so repeated testing can hit this limit.

**To clean up unused tokens:**
1. Go to [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Look for tokens with names like:
   - `cloudflared-*` (from tunnel creation attempts)
   - Old/duplicate tokens from testing
   - Tokens you no longer use
3. Click the "Delete" button (trash icon) next to each unused token
4. Confirm the deletion

**Prevention tips:**
- Use `822-cloudflare-tunnel-delete.sh` to properly clean up tunnels
- Avoid repeatedly running setup without proper cleanup
- Delete test tunnels when done testing

### Checking Tunnel Status

```bash
# View tunnel pod status
kubectl get pods -n default -l app=cloudflared

# Check tunnel logs
kubectl logs -n default -l app=cloudflared --tail=50

# Verify DNS records in Cloudflare Dashboard
# DNS → Records → Look for CNAME entries pointing to .cfargotunnel.com
```

### Important Paths

| File | Path | Purpose |
|------|------|---------|
| Certificate | `/mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem` | Global Cloudflare auth |
| Credentials | `/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel.json` | Tunnel-specific secrets |
| Config | `/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel-config.yml` | Tunnel configuration |
| Manifest | `/mnt/urbalurbadisk/manifests/cloudflare-tunnel-manifest.yaml` | K8s deployment |

## 🏗️ Architecture

### Traffic Flow
```
User Request → Cloudflare Edge → Tunnel Pod → Traefik → Service
```

### Components
- **Cloudflare Edge**: Global CDN and security layer
- **Tunnel Connector**: Pod running `cloudflared` in your cluster
- **Traefik**: Ingress controller routing to services
- **Services**: Your applications with IngressRoute definitions

### DNS Configuration
- **Wildcard**: `*.domain` → All subdomains route to tunnel
- **Root (optional)**: `domain` → Root domain routes to tunnel
- **Proxied**: Orange cloud enabled for CDN and security

## 📚 Additional Resources

- **Domain setup**: [Adding a domain to Cloudflare](https://developers.cloudflare.com/fundamentals/setup/manage-domains/add-site/)
- **Tunnel docs**: [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- **Traefik integration**: [IngressRoute configuration](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)