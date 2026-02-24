# Cloudflare Tunnel Setup Guide

**Purpose**: Professional internet access with custom domains
**Audience**: Users wanting production-ready setup with own domains
**Time Required**: 15-20 minutes
**Prerequisites**: Working cluster with Traefik ingress

## Quick Summary

Transform your local cluster from `http://service.localhost` to `https://service.yourcompany.com` with enterprise-grade security. Uses your Cloudflare-managed domain to provide global CDN, DDoS protection, and professional appearance.

## Prerequisites

Before starting, ensure you have:
- [ ] Kubernetes cluster running (Rancher Desktop or similar)
- [ ] Traefik ingress controller deployed
- [ ] Services accessible locally (e.g., `http://whoami.localhost`)
- [ ] A Cloudflare account ([sign up](https://dash.cloudflare.com/sign-up))
- [ ] A domain added to Cloudflare with nameservers pointing to Cloudflare

## How Cloudflare Tunnel Works

The Cloudflare tunnel creates a secure outbound connection from your cluster to Cloudflare's edge:

```
Internet User → Cloudflare Edge (CDN/WAF) → Tunnel → Traefik → Your Services
```

**Key Benefits:**
- No port forwarding or firewall configuration needed
- Automatic SSL/TLS certificates (no rate limits like Let's Encrypt)
- DDoS protection and global CDN
- Works behind NAT/firewalls
- Wildcard routing: `*.yourdomain.com` routes all subdomains through one tunnel

**How it differs from Tailscale:**
- Cloudflare exposes ALL services with Traefik IngressRoutes automatically (one tunnel pod)
- Tailscale exposes services individually (one pod per service)
- See [Networking Overview](index.md) for a full comparison

## Setup Overview

The token-based approach follows the same pattern as all other UIS services:

1. **Configure in Cloudflare dashboard** (one-time): Create tunnel, get token, configure routes
2. **Add token to secrets**: Put `CLOUDFLARE_TUNNEL_TOKEN` in `.uis.secrets/config/00-common-values.env`
3. **Deploy**: `./uis deploy cloudflare-tunnel`

No interactive browser auth from the container. No generated credential files.

---

## Step 1: Add Your Domain to Cloudflare

*Skip this if your domain is already in Cloudflare.*

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **"Add a domain"**
3. Enter your domain (e.g., `urbalurba.no`)
4. Select the **Free** plan
5. Cloudflare will scan existing DNS records — review and confirm
6. Update your domain registrar's nameservers to the Cloudflare nameservers shown (e.g., `sandy.ns.cloudflare.com` and `terry.ns.cloudflare.com`)
7. Wait for nameserver propagation (usually 5-30 minutes, can take up to 24 hours)

**Verify**: Your domain should show "Active" status in the Cloudflare dashboard.

## Step 2: Create a Tunnel in Cloudflare Zero Trust

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com)
2. In the left sidebar, click **Networks → Connectors**
3. Under "Cloudflare Tunnels", click **"Create a tunnel"**
4. Select **Cloudflared** as the connector type
5. Give your tunnel a name (e.g., `urbalurba-no`) and click **Save tunnel**

### Copy the tunnel token

After creating the tunnel, Cloudflare shows installation instructions. Look for the command:

```
cloudflared tunnel run --token eyJhIjoiOT...
```

**Copy the entire token** (the long `eyJ...` string). This is the only secret you need.

Save it somewhere safe — you'll put it in the UIS secrets config in Step 4.

## Step 3: Configure Public Hostname Routes

After saving the tunnel, you'll be on the tunnel configuration page. Navigate to the **Hostname routes** tab (or "Published application routes").

### Add wildcard route (all subdomains)

Click **"Add a published application route"**:

| Field | Value |
|-------|-------|
| **Subdomain** | `*` |
| **Domain** | Select your domain (e.g., `urbalurba.no`) |
| **Path** | *(leave empty)* |
| **Type** | HTTP |
| **URL** | `traefik.default.svc.cluster.local:80` |

Click **Save**.

### Add root domain route

Click **"Add a published application route"** again:

| Field | Value |
|-------|-------|
| **Subdomain** | *(leave empty)* |
| **Domain** | Select your domain (e.g., `urbalurba.no`) |
| **Path** | *(leave empty)* |
| **Type** | HTTP |
| **URL** | `traefik.default.svc.cluster.local:80` |

Click **Save**.

### DNS record conflict error

If you see: *"Error: An A, AAAA, or CNAME record with that host already exists"*

This means an old DNS record exists (e.g., from a previously deleted tunnel). Fix it:

1. Go to the main Cloudflare dashboard: `dash.cloudflare.com`
2. Select your domain → **DNS → Records**
3. Find the conflicting record (CNAME or Tunnel type pointing to the old tunnel)
4. Click **Edit** → **Delete** the old record
5. Go back to the tunnel config and try adding the route again

Cloudflare will automatically create the correct DNS record when the route is saved.

### Verify your routes

Your tunnel should now show two published application routes:

| # | Route | Path | Service |
|---|-------|------|---------|
| 1 | `*.urbalurba.no` | `*` | `http://traefik.default.svc.cluster.local:80` |
| 2 | `urbalurba.no` | `*` | `http://traefik.default.svc.cluster.local:80` |

## Step 4: Configure UIS Secrets

Add the tunnel token to your secrets config:

```bash
# Edit the secrets file
nano .uis.secrets/config/00-common-values.env
```

Add or update these lines:

```bash
BASE_DOMAIN_CLOUDFLARE=urbalurba.no
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiOT...your-full-token-here
```

Then regenerate secrets:

```bash
./uis secrets generate
```

## Step 5: Deploy the Tunnel

```bash
./uis deploy cloudflare-tunnel
```

This deploys a `cloudflared` pod that connects to Cloudflare using the token. All routing is managed by Cloudflare's dashboard — no local configuration files needed.

## Step 6: Verify

```bash
# Check tunnel pod is running
./uis cloudflare verify

# Test from outside (or use curl)
curl https://whoami.urbalurba.no
curl https://urbalurba.no
```

The tunnel status in the Cloudflare dashboard should change from **Inactive** to **Healthy**.

---

## Managing the Tunnel

### Undeploy (keep tunnel for redeployment)

```bash
./uis undeploy cloudflare-tunnel
```

This removes the Kubernetes resources but keeps the tunnel configured in Cloudflare. Redeploy anytime with `./uis deploy cloudflare-tunnel`.

### Full teardown

```bash
./uis cloudflare teardown
```

This removes Kubernetes resources and prints instructions for deleting the tunnel in the Cloudflare dashboard.

---

## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Tunnel stays "Inactive" | Pod not running or can't connect | Check pod logs: `kubectl logs -l app=cloudflared --tail=50` |
| 502 Bad Gateway | Traefik not running or wrong service URL | Verify Traefik: `kubectl get pods -l app.kubernetes.io/name=traefik` |
| Connection timeout | Port 7844 blocked by network | See "Port 7844 Blocked" below |
| DNS record conflict | Old CNAME from deleted tunnel | Delete old DNS record, re-add route |
| "Worker is Running!" on root domain | Cloudflare Worker intercepting traffic | Check Workers & Pages, remove Worker routes |

### Port 7844 Blocked (Corporate Networks)

Cloudflare tunnels use **port 7844** (TCP and UDP) for the tunnel connection, not standard HTTPS port 443. Corporate and school networks often block this port.

**Symptoms:**
- Tunnel pod starts but stays in "connecting" state
- Logs show connection timeouts to Cloudflare edge
- `./uis cloudflare verify` reports port 7844 as blocked

**Solutions:**
1. **Switch networks**: Use home WiFi or mobile hotspot
2. **Use VPN**: Route traffic through a VPN that allows port 7844
3. **Ask IT**: Request outbound access to port 7844 TCP/UDP

**Reference**: [Cloudflare tunnel firewall requirements](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/)

### Checking Tunnel Status

```bash
# View tunnel pod status
kubectl get pods -l app=cloudflared

# Check tunnel logs
kubectl logs -l app=cloudflared --tail=50

# In Cloudflare dashboard: Zero Trust → Networks → Connectors
# Your tunnel should show "Healthy" status
```

---

## Architecture

### Traffic Flow
```
User Request → Cloudflare Edge (CDN/WAF/TLS) → Tunnel Pod → Traefik → Service
```

### Components
- **Cloudflare Edge**: Global CDN, DDoS protection, TLS termination
- **Tunnel Connector**: Single `cloudflared` pod in your cluster
- **Traefik**: Ingress controller routing to services via IngressRoutes
- **Services**: Your applications with HostRegexp IngressRoute patterns

### DNS Configuration
When you add published application routes, Cloudflare automatically creates:
- **Root domain**: `urbalurba.no` → Tunnel type DNS record
- **Wildcard**: `*.urbalurba.no` → Tunnel type DNS record
- **Proxied**: Orange cloud enabled for CDN and security

### How Wildcard Routing Works

With the wildcard route (`*.urbalurba.no`), ALL subdomains automatically reach your cluster:

```
whoami.urbalurba.no    → Cloudflare → cloudflared pod → Traefik → whoami service
openwebui.urbalurba.no → Cloudflare → cloudflared pod → Traefik → openwebui service
grafana.urbalurba.no   → Cloudflare → cloudflared pod → Traefik → grafana service
```

Traefik routes to the correct service using its HostRegexp IngressRoute rules (e.g., `HostRegexp('whoami\..+')`). No per-service tunnel configuration needed.

---

## Legacy: Interactive Setup Scripts

Previous versions used interactive shell scripts that required `cloudflared login` (browser auth) inside the container. These scripts have been moved to `legacy/` directories for reference:

| Script | Location |
|--------|----------|
| `820-cloudflare-tunnel-setup.sh` | `networking/cloudflare/legacy/` |
| `821-cloudflare-tunnel-deploy.sh` | `networking/cloudflare/legacy/` |
| `822-cloudflare-tunnel-delete.sh` | `networking/cloudflare/legacy/` |

The token-based approach is simpler and follows the same secrets pattern as all other UIS services.

## Additional Resources

- **Cloudflare Tunnel docs**: [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)
- **K8s deployment guide**: [Cloudflare Tunnel Kubernetes deployment](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/deployment-guides/kubernetes/)
- **Firewall requirements**: [Tunnel with firewall](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-with-firewall/)
- **Domain setup**: [Adding a domain to Cloudflare](https://developers.cloudflare.com/fundamentals/setup/manage-domains/add-site/)
- **Networking overview**: [Tailscale vs Cloudflare comparison](index.md)
