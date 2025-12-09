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

### Step 1: Create Tunnel and Configure DNS
```bash
# Inside provision-host container
docker exec -it provision-host bash
cd /mnt/urbalurbadisk

# Create tunnel (interactive - will open browser for auth)
./networking/cloudflare/820-cloudflare-tunnel-setup.sh urbalurba.no
```

**What happens:**
- Checks if tunnel already exists (smart detection)
- Opens browser for Cloudflare authentication (see authentication steps below)
- Creates tunnel with unique credentials
- Configures DNS: `urbalurba.no` AND `*.urbalurba.no` → tunnel
- Stores credentials for persistence
- Updates `kubernetes-secrets.yml` with tunnel credentials

#### Browser Authentication Process

When the script runs, you'll need to complete a 2-step browser authentication:

**Step 1: Select Domain Zone**
- A browser URL will appear in the terminal - click or copy it to your browser
- You'll see "Authorize Cloudflare Tunnel" page with all your domains
- **ACTION**: Click on the row for your specific domain (e.g., urbalurba.no)
- All domains should show "Active" status with green checkmarks

**Step 2: Authorize Tunnel Creation**
- You'll see a confirmation dialog: "Authorize Tunnel for [your-domain]"
- Message: "To finish configuring Tunnel for your zone, click Authorize below"
- **ACTION**: Click the blue "Authorize" button (NOT "Cancel")

**Step 3: Success Confirmation**
- You'll see a "Success" page
- Message: "Cloudflared has installed a certificate allowing your origin to create a Tunnel on this zone"
- **ACTION**: Close the browser window and return to the terminal

⚠️ **Important**: You must complete BOTH browser steps (select domain AND authorize) or you'll get "Unauthorized" errors. The authentication link has a timeout, so complete it quickly.

### Step 2: Deploy Tunnel to Kubernetes
```bash
# Deploy to current cluster (no parameters needed)
./networking/cloudflare/821-cloudflare-tunnel-deploy.sh
```

**What happens:**
- Creates Kubernetes secret with credentials
- Deploys tunnel connector pod
- Routes traffic to Traefik ingress
- Establishes connection to Cloudflare edge

### Step 3: Root Domain Configuration (Automatic)
The setup script now automatically configures both:
- **Root domain**: `urbalurba.no` → tunnel
- **Wildcard subdomains**: `*.urbalurba.no` → tunnel

No manual configuration needed! Both domains are set up automatically during the tunnel creation process.

**Note**: If you have Cloudflare Workers intercepting the root domain, you may need to:
   - Check **Workers & Pages** → Remove any custom domains
   - Check **Workers Routes** → Delete routes for your domain

### Step 4: Verify Setup
```bash
# Test both root domain and subdomain routing
curl https://urbalurba.no
curl https://test.urbalurba.no
curl https://whoami.urbalurba.no
curl https://openwebui.urbalurba.no
```

Both root domain and subdomains should work automatically!

⚠️ **Authentication Note**: If you want to protect services with Authentik authentication on external domains, see `docs/rules-ingress-traefik.md` section "External Domain Authentication Limitations" for important manual configuration requirements.

## 🗑️ Complete Cleanup

To completely remove a tunnel and start over:

```bash
# Delete everything (no parameters needed)
./networking/cloudflare/822-cloudflare-tunnel-delete.sh
```

**What gets deleted:**
- Kubernetes deployment, configmap, and secrets
- Cloudflare tunnel
- Local configuration files
- TODO: Cloudflare DNS routes (you must do it manually )
- TODO: Cloudflare API tokens (you must do it manually )

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
| REST API unauthorized errors | Incomplete browser authentication | Complete BOTH steps: select domain AND click Authorize |
| Authentication timeout | Took too long to complete browser steps | Run script again for fresh link, complete quickly |
| Wrong domain selected | Multiple domains in account | Ensure you click the correct domain row that matches script parameter |
| Permission denied errors | File ownership issues | Script now automatically fixes ownership using `docker exec -u root` |
| "Unauthorized: Failed to get tunnel" | Credentials mismatch | Script now properly updates both Kubernetes secret and ConfigMap |

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
| Certificate | `/mnt/urbalurbadisk/cloudflare/cloudflare-certificate.pem` | Global Cloudflare auth (created during browser auth) |
| Credentials | `/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel.json` | Tunnel-specific secrets (encrypted) |
| Config | `/mnt/urbalurbadisk/cloudflare/cloudflare-tunnel-config.yml` | Tunnel configuration |
| Manifest | `/mnt/urbalurbadisk/manifests/cloudflare-tunnel-manifest.yaml` | K8s deployment |

⚠️ **Security Note**: Never share the certificate or credential files. They provide access to your Cloudflare account and tunnel.

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
- **Root domain**: `urbalurba.no` → tunnel (automatically configured)
- **Wildcard**: `*.urbalurba.no` → All subdomains route to tunnel
- **Proxied**: Orange cloud enabled for CDN and security

## 📚 Additional Resources

- **Domain setup**: [Adding a domain to Cloudflare](https://developers.cloudflare.com/fundamentals/setup/manage-domains/add-site/)
- **Tunnel docs**: [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- **Traefik integration**: [IngressRoute configuration](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)