# Tailscale Tunnel Setup Guide

IMPORTANT:
Found out that tailscale does not support wildchard routing. eg *.k8s.dog-pence.ts.net so that 
jalla.k8s.dog-pence.ts.net and balla.k8s.dog-pence.ts.net is routed to the tunnel.
This is a big setback and i spent a full day trying to solve it until i found this url https://github.com/tailscale/tailscale/issues/1196

So the rest of the file here only works for routing https://k8s.dog-pence.ts.net to the cluster.




**Purpose**: Wildcard internet access with automatic .ts.net domains  
**Audience**: Users wanting secure, invite-based internet connectivity  
**Time Required**: 10-15 minutes  
**Prerequisites**: Working cluster with Traefik ingress

## 🚀 Quick Summary

Transform your local cluster from `http://service.localhost` to `https://k8s.dog-pence.ts.net` with public internet access. Tailscale provides automatic HTTPS, zero-config networking, and public Funnel capability.

## 🏗️ How Tailscale Tunnel Works

### Architecture Overview

Tailscale creates a secure mesh network with public internet access. All `k8s.dog-pence.ts.net` traffic routes to your cluster where Traefik handles internal routing:

```
External User → https://k8s.dog-pence.ts.net
    ↓
Tailscale MagicDNS → k8s (cluster ingress device)  
    ↓
Kubernetes cluster → Traefik ingress
    ↓  
Default backend → nginx catch-all or service routing
```

**Key Components:**
1. **Tailscale MagicDNS** - Provides automatic `k8s.dog-pence.ts.net` routing (single hostname only)
2. **k8s device** - Tailscale ingress point for your cluster (named from TAILSCALE_CLUSTER_HOSTNAME)
3. **Traefik** - Routes traffic based on HostRegexp patterns to services
4. **Your Services** - whoami, openwebui, authentik, etc.

**Security Benefits:**
- ✅ **End-to-end encryption** through Tailscale network
- ✅ **No public IP exposure** - services remain private
- ✅ **Invite-based access** - only your tailnet members can access
- ✅ **Zero-trust networking** - device authentication required

## ✅ Prerequisites

Before starting, ensure you have:
- [ ] Kubernetes cluster running (Rancher Desktop or similar)
- [ ] Traefik ingress controller deployed  
- [ ] Services accessible locally (e.g., `http://whoami.localhost`)
- [ ] Access to provision-host container
- [ ] Valid Tailscale account and credentials

## 📋 Script Overview

Five scripts manage the complete Tailscale setup:

| Script | Purpose | When to Use | Parameters |
|--------|---------|-------------|------------|
| `801-tailscale-tunnel-setup.sh` | Sets up Tailscale on provision-host | First time setup | None |
| `802-tailscale-tunnel-deploy.sh` | Deploys operator to cluster | After host setup | `[cluster-hostname]` |
| `803-tailscale-tunnel-addhost.sh` | Add individual service ingress | After operator deployed | `<service> [namespace] [port] [hostname]` |
| `804-tailscale-tunnel-deletehost.sh` | Remove individual service ingress | When removing a service | `<hostname>` |
| `805-tailscale-tunnel-delete.sh` | Removes everything | Clean up / start over | None |

## 🚀 Quick Start Guide

### Step 1: Create Tailscale Account

1. Visit [tailscale.com](https://tailscale.com) and sign up
2. Your tailnet will be created (e.g., `yourusername.github`) → **Note this as `TAILSCALE_TAILNET`**

### Step 2: Configure Access Control Tags (Prepare for auth key)

1. Go to [Tailscale Access Controls](https://login.tailscale.com/admin/acls)
2. Click **"JSON editor"** (top right of the policy editor)
3. **Replace the entire content with this clean configuration:**
   ```json
   {
     "tagOwners": {
       "tag:k8s-operator": ["autogroup:admin"]
     },
     "nodeAttrs": [
       {
         "target": ["tag:k8s-operator"],
         "attr": ["funnel"]
       }
     ],
     "acls": [
       {"action": "accept", "src": ["*"], "dst": ["*:*"]}
     ]
   }
   ```
4. Click "Save"

**What this does:**
- `tagOwners`: Allows admins to assign `tag:k8s-operator` tags
- `nodeAttrs`: Enables **Funnel** capability for devices with `tag:k8s-operator` (public internet access)
- `acls`: Allows all devices to communicate with each other (simple setup)

### Step 3: Create Auth Key (for provision-host authentication with Funnel)

1. Go to [Auth Keys page](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key" 
3. **Description:** `urbalurba-k8s-funnel`
4. **Reusable:** ✅ Check this box (allows multiple devices)
5. **Expiration:** `90` days 
6. **Ephemeral:** ❌ Leave unchecked (permanent infrastructure)
7. **Tags:** Type `tag:k8s-operator` and click "Add tags" 
   - The `tag:k8s-operator` is required for Funnel capability (public internet access)
8. Click "Generate key"
9. Copy the **auth key** → **This becomes `TAILSCALE_SECRET`**

**Why tag:k8s-operator?** 
- The ACL policy grants Funnel capability only to devices with `tag:k8s-operator`
- This allows the device to expose services to the public internet
- Without this tag, you'll only get internal tailnet connectivity

### Step 4: Create OAuth Client (for cluster operations)

1. Go to [OAuth clients page](https://login.tailscale.com/admin/settings/oauth) 
2. Click "Generate OAuth client"
3. **Description:** `urbalurba-k8s-oauth`
4. **Select required scopes**
   - **DNS:** Select **Write** (enable MagicDNS features if needed)
   - **Devices → Core:** Select **Write** (create/delete cluster devices)
     - **Tags (required for write scope):** Click "Add tags" and add `tag:k8s-operator`
     - This allows the OAuth client to create devices with the k8s-operator tag
   - **Auth keys:** Select **Write** ← **REQUIRED** (allows operator to create internal auth keys)
     - **Tags (required for write scope):** Click "Add tags" and add `tag:k8s-operator`   
   - **Feature Settings:** Select **Write** (enable HTTPS/Funnel features)
   - Leave all other scopes **unselected** (principle of least privilege)
5. Click "Generate client"
6. Copy the **Client ID** → **This becomes `TAILSCALE_CLIENTID`**
7. Copy the **Client Secret** → **This becomes `TAILSCALE_CLIENTSECRET`**
   
   ⚠️ **Important:** Save these values immediately - you can't view the secret again!

**Why these scopes?**
- **Auth keys (Write)**: **CRITICAL** - Allows Tailscale operator to create internal auth keys (without this you get 403 errors)
- **Devices Core (Write)**: Allows Tailscale operator to create/delete cluster ingress devices
- **DNS (Write)**: Enables MagicDNS configuration for wildcard routing
- **Feature Settings (Write)**: Allows enabling HTTPS/Funnel for internet access

### Step 5: Configure MagicDNS Domain

1. Go to [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)
2. Enable **MagicDNS** 
3. Note your **MagicDNS domain** (e.g., `dog-pence.ts.net`) → **This becomes `TAILSCALE_DOMAIN`**

### Step 6: Update Kubernetes Secrets

Edit `topsecret/kubernetes/kubernetes-secrets.yml` with your values:
```bash
# Update these Tailscale variables with values from Steps 1-5:
TAILSCALE_SECRET: tskey-auth-YOUR-AUTH-KEY           # From Step 3: Auth Key
TAILSCALE_TAILNET: your-tailnet-name                # From Step 1: Your tailnet name
TAILSCALE_DOMAIN: your-magic-dns-domain             # From Step 5: MagicDNS domain  
TAILSCALE_CLUSTER_HOSTNAME: k8s                     # Becomes: *.k8s.[your-domain].ts.net
TAILSCALE_CLIENTID: YOUR-OAUTH-CLIENT-ID            # From Step 4: OAuth Client ID
TAILSCALE_CLIENTSECRET: tskey-client-YOUR-OAUTH-CLIENT-SECRET  # From Step 4: OAuth Client Secret
```

**Important: TAILSCALE_CLUSTER_HOSTNAME:**
- This becomes the base hostname for ALL your cluster services
- Example: If set to `k8s` and your domain is `dog-pence.ts.net`:
  - `whoami.k8s.dog-pence.ts.net` → Routes to whoami service
  - `grafana.k8s.dog-pence.ts.net` → Routes to Grafana
  - `*.k8s.dog-pence.ts.net` → Routes to any service via Traefik

### Step 7: Apply Secrets to Kubernetes
```bash
# Apply updated secrets to cluster
kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml

# Verify secrets are applied
kubectl get secret urbalurba-secrets -o yaml | grep TAILSCALE
```

### Step 8: Setup Tailscale on Provision-Host
```bash
# From your Mac host, copy scripts and access provision-host
./copy2provisionhost.sh
docker exec -it provision-host bash
cd /mnt/urbalurbadisk

# Setup Tailscale daemon and authenticate
./networking/tailscale/801-tailscale-tunnel-setup.sh
```

### Step 9: Deploy Tailscale Operator to Cluster  
```bash
# Deploy operator (uses TAILSCALE_CLUSTER_HOSTNAME from secrets, or specify your own)
./networking/tailscale/802-tailscale-tunnel-deploy.sh
# Or override with custom hostname:
# ./networking/tailscale/802-tailscale-tunnel-deploy.sh my-custom-name
```

## ⚠️ Important Limitation: No Wildcard DNS Support

**Tailscale does not support wildcard DNS routing.** This means:

- ✅ **Works**: `https://k8s.dog-pence.ts.net` (exact hostname)
- ❌ **Does NOT work**: `https://whoami.k8s.dog-pence.ts.net` (subdomain)
- ❌ **Does NOT work**: `https://SERVICE.k8s.dog-pence.ts.net` (wildcard pattern)

**Reference**: [Tailscale GitHub Issue #1196](https://github.com/tailscale/tailscale/issues/1196) - This feature was requested but intentionally not implemented.

**Workaround Options**:
1. **Path-based routing**: Access services via `https://k8s.dog-pence.ts.net/SERVICE`
2. **Individual ingresses**: Create separate Tailscale devices for each service
3. **External DNS**: Use CNAME records with your own domain provider

### Step 10: Add Individual Services (Workaround for No Wildcard Support)

Since Tailscale doesn't support wildcard DNS, you can create individual public URLs for each service:

```bash
# Add a service with default settings (hostname = service name)
./networking/tailscale/803-tailscale-tunnel-addhost.sh whoami

# Add a service with custom hostname for cleaner URLs
./networking/tailscale/803-tailscale-tunnel-addhost.sh authentik-server authentik 80 authentik

# Remove a service
./networking/tailscale/804-tailscale-tunnel-deletehost.sh whoami
```

Each service gets:
- Its own Tailscale pod (resource overhead)
- Its own public URL (e.g., https://whoami.dog-pence.ts.net)
- Routing through Traefik to maintain existing patterns
- Public internet access via Funnel

### Step 11: Test Public Internet Access
```bash
# Your cluster is now publicly accessible from anywhere on the internet:
curl https://k8s.dog-pence.ts.net

# ⚠️ IMPORTANT: Wildcard DNS does not work with Tailscale
# URLs like https://whoami.k8s.dog-pence.ts.net will NOT work
# See: https://github.com/tailscale/tailscale/issues/1196

# For service access, you need to use:
# - Path-based routing: https://k8s.dog-pence.ts.net/whoami
# - Individual Tailscale ingresses (separate devices)
# - External DNS with CNAME records

# Test from any computer (not just tailnet members):
# - Anyone can access https://k8s.dog-pence.ts.net from any browser
# - No Tailscale client needed for visitors
# - Full public internet exposure via Funnel
```

## 🗑️ Complete Cleanup

To completely remove Tailscale and start over:
```bash
# Delete everything
./networking/tailscale/805-tailscale-tunnel-delete.sh
```

**What gets deleted:**
- All Tailscale ingresses and services
- Tailscale operator from cluster  
- Tailscale devices from your tailnet
- Tailscale daemon on provision-host
- Local configuration files

## 🔧 Troubleshooting

### Error: "requested tags [tag:k8s-operator] are invalid or not permitted"

This error means your OAuth client doesn't have permission for `tag:k8s-operator`. To fix:

1. Go to [OAuth clients page](https://login.tailscale.com/admin/settings/oauth)
2. Edit your `urbalurba-k8s-oauth` client
3. In **Devices → Core** scope, ensure `tag:k8s-operator` is added
4. In **Auth keys** scope, ensure `tag:k8s-operator` is added
5. Generate a new client secret (required after scope changes)
6. Update `TAILSCALE_CLIENTSECRET` in your secrets file
7. Apply with `kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml`
8. Run the script again

**Key Point:** The operator uses `tag:k8s-operator` for all devices, including itself and cluster ingress devices with Funnel capability.

### Expired Tailscale Keys

If you get authentication errors, create new keys at [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys):

**Create OAuth Client:**
1. Click "Generate auth key" → "OAuth client"
2. Name: `urbalurba-k8s`  
3. Scopes: `device:create`, `device:delete`, `device:read`
4. Copy Client ID and Client Secret

**Create Auth Key:**
1. Click "Generate auth key" → "Auth key"
2. Tags: `tag:provision-host` (optional)
3. Expiry: 90 days
4. Copy the auth key

**Update secrets file:**
```bash
# Edit topsecret/kubernetes/kubernetes-secrets.yml
TAILSCALE_SECRET: tskey-auth-YOUR-NEW-AUTH-KEY
TAILSCALE_CLIENTID: YOUR-NEW-CLIENT-ID
TAILSCALE_CLIENTSECRET: tskey-client-YOUR-NEW-CLIENT-SECRET

# Apply to cluster
kubectl apply -f topsecret/kubernetes/kubernetes-secrets.yml
```

### Script Execution Issues

**Check Tailscale status in provision-host:**
```bash
# Access provision-host container
docker exec -it provision-host bash

# Check Tailscale daemon
tailscale status

# Check cluster operator
kubectl get pods -n tailscale
kubectl logs -n tailscale -l app=operator
```

**Check cluster connectivity:**
```bash
# From provision-host container
kubectl get ingressroute -A
kubectl describe ingress -n kube-system
```

### Tailscale Installation Issues

Tailscale is pre-installed in the provision-host container. If missing:
```bash
# From provision-host container
curl -fsSL https://tailscale.com/install.sh | sh
```

## 📚 Architecture Details

### Wildcard Routing Flow
```
1. External request: https://whoami.k8s.dog-pence.ts.net
2. Tailscale MagicDNS resolves *.dog-pence.ts.net to k8s device
3. k8s device forwards to Traefik in Kubernetes
4. Traefik matches HostRegexp(`whoami\..+`) and routes to whoami service
```

### Script Dependencies
- **801** → **802** → **803** (sequential execution required)
- **804** can be run anytime for cleanup

### Integration with Other Systems
- Works alongside Cloudflare tunnels (different domains)
- Leverages existing Traefik IngressRoute configurations
- Uses HostRegexp patterns for automatic service discovery

## ✅ Verification

After setup, verify your cluster is accessible:

```bash
# Test main services via wildcard routing
curl https://whoami.k8s.dog-pence.ts.net
curl https://openwebui.k8s.dog-pence.ts.net
curl https://authentik.k8s.dog-pence.ts.net

# Check Tailscale device status
tailscale status | grep k8s

# Verify k8s device is online
kubectl get pods -n tailscale
```

## 🎉 Benefits Achieved

✅ **Public Internet Access**: All services accessible via `*.dog-pence.ts.net` from anywhere  
✅ **Automatic HTTPS**: Zero-configuration SSL certificates  
✅ **Wildcard Routing**: Single ingress handles all services via Traefik  
✅ **No Port Forwarding**: Works behind NAT/firewalls via Tailscale Funnel  
✅ **Consistent Pattern**: Mirrors Cloudflare tunnel approach with public access

Your cluster is now publicly accessible on the internet via Tailscale Funnel with wildcard routing!
