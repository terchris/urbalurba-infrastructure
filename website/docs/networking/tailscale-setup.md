# Tailscale Tunnel Setup Guide

**Purpose**: Public internet access with automatic .ts.net domains
**Audience**: Users wanting secure, public internet connectivity
**Time Required**: 10-15 minutes
**Prerequisites**: Working cluster with Traefik ingress

## ⚠️ Critical Limitation: No Wildcard DNS Support

**Tailscale Funnel does not support wildcard DNS routing.** This means patterns like `*.k8s.dog-pence.ts.net` will NOT work for public internet access.

**Reference**: [Tailscale GitHub Issue #15434](https://github.com/tailscale/tailscale/issues/15434) (Funnel wildcard support — still open as of Feb 2026)

Throughout this document we use the tailscale domain `dog-pence.ts.net` as an example. You get your own domain in the form `<something>.ts.net` when signing up to Tailscale.

### What This Means:
- ❌ **Does NOT work**: `https://whoami.k8s.dog-pence.ts.net` (subdomain pattern)
- ❌ **Does NOT work**: `https://*.k8s.dog-pence.ts.net` (wildcard routing)
- ✅ **DOES work**: `https://whoami.dog-pence.ts.net` (individual service via 803 script)
- ✅ **DOES work**: `https://authentik.dog-pence.ts.net` (each service gets its own URL)

### The Solution: Individual Service Ingresses
We use the `802-tailscale-tunnel-deploy.sh` script to create individual Tailscale ingresses for each service. Each service gets its own public URL directly on your tailscale domain.

## 🚀 Quick Summary

Transform your local cluster from `http://service.localhost` to public URLs like `https://whoami.dog-pence.ts.net` with automatic HTTPS. Each service gets its own public URL via individual Tailscale ingresses.

## 🏗️ How Tailscale Tunnel Works

### Architecture Overview

Due to Tailscale's lack of wildcard DNS support, each service requires its own Tailscale ingress:

```
External User → https://whoami.dog-pence.ts.net
    ↓
Tailscale MagicDNS → whoami-ingress (dedicated Tailscale pod)
    ↓
Kubernetes Service → whoami pod
```

**Key Components:**
1. **Tailscale MagicDNS** - Provides automatic DNS for each service (e.g., `whoami.dog-pence.ts.net`)
2. **Individual Ingresses** - Each service gets its own Tailscale pod/device
3. **Direct Service Routing** - Traffic goes directly to each service
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

## 📋 Commands Overview

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `./uis deploy tailscale-tunnel` | Deploy Tailscale operator to cluster | After secrets are configured |
| `./uis undeploy tailscale-tunnel` | Remove Tailscale operator and ingresses | Clean up / start over |
| `./networking/tailscale/802-tailscale-tunnel-deploy.sh <service>` | Add individual service ingress | After operator deployed |
| `./networking/tailscale/803-tailscale-tunnel-deletehost.sh <hostname>` | Remove individual service ingress | When removing a service |

The one-time verification playbook (`801-setup-network-tailscale-tunnel.yml`) can be run manually via `./uis shell` to test your Tailscale credentials before deploying.

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

1. Go to [Trust credentials page](https://login.tailscale.com/admin/settings/trust-credentials)
2. Click "Generate OAuth client" (this opens a 2-step wizard)
3. **Step 1 - Settings:** Select "OAuth client", add description `urbalurba-k8s-oauth`
4. **Step 2 - Select required scopes:**
   - **General → DNS:** Select **Write** (enable MagicDNS features if needed)
   - **Devices → Core:** Select **Write** (create/delete cluster devices)
     - **Tags (required for write scope):** Click "Add tags" and add `tag:k8s-operator`
     - This allows the OAuth client to create devices with the k8s-operator tag
   - **Keys → Auth Keys:** Select **Write** ← **REQUIRED** (allows operator to create internal auth keys)
     - **Tags (required for write scope):** Click "Add tags" and add `tag:k8s-operator`
   - **Settings → Feature Settings:** Select **Write** (enable HTTPS/Funnel features)
   - Leave all other scopes **unselected** (principle of least privilege)
5. Click "Generate client"
6. Copy the **Client ID** → **This becomes `TAILSCALE_CLIENTID`**
7. Copy the **Client Secret** → **This becomes `TAILSCALE_CLIENTSECRET`**
   
   ⚠️ **Important:** Save these values immediately - you can't view the secret again!

**Why these scopes?**
- **Keys → Auth Keys (Write)**: **CRITICAL** - Allows Tailscale operator to create internal auth keys (without this you get 403 errors)
- **Devices → Core (Write)**: Allows Tailscale operator to create/delete cluster ingress devices
- **General → DNS (Write)**: Enables MagicDNS configuration
- **Settings → Feature Settings (Write)**: Allows enabling HTTPS/Funnel for internet access

### Step 5: Configure MagicDNS Domain

1. Go to [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)
2. Enable **MagicDNS** 
3. Note your **MagicDNS domain** (e.g., `dog-pence.ts.net`) → **This becomes `TAILSCALE_DOMAIN`**

### Step 6: Configure Tailscale Secrets

Edit the secrets source file with your Tailscale values from Steps 1-5:
```bash
nano .uis.secrets/config/00-common-values.env
```

Update these variables:
```bash
TAILSCALE_SECRET=tskey-auth-YOUR-AUTH-KEY           # From Step 3: Auth Key
TAILSCALE_TAILNET=your-tailnet-name                 # From Step 1: Your tailnet name
TAILSCALE_DOMAIN=your-magic-dns-domain              # From Step 5: MagicDNS domain
TAILSCALE_CLUSTER_HOSTNAME=k8s                      # Becomes: k8s.[your-domain].ts.net (cluster ingress only)
TAILSCALE_CLIENTID=YOUR-OAUTH-CLIENT-ID             # From Step 4: OAuth Client ID
TAILSCALE_CLIENTSECRET=tskey-client-YOUR-SECRET      # From Step 4: OAuth Client Secret
```

Then regenerate the Kubernetes secrets:
```bash
./uis secrets generate
```

**Important: TAILSCALE_CLUSTER_HOSTNAME:**
- This is used for the cluster-wide ingress only (when no service parameter is provided)
- Example: If set to `k8s` and your domain is `dog-pence.ts.net`:
  - `k8s.dog-pence.ts.net` → Routes to Traefik's default backend (nginx catch-all)
  - Individual services get their own URLs: `whoami.dog-pence.ts.net`, `grafana.dog-pence.ts.net`
  - **Note**: Tailscale does NOT support wildcard DNS, so `*.k8s.dog-pence.ts.net` patterns won't work

### Step 7: Verify Tailscale Connection (one-time)

This optional step verifies your Tailscale credentials work before deploying to the cluster:
```bash
./uis shell
cd /mnt/urbalurbadisk

# Run the verification playbook (connects, tests funnel, then cleans up)
ansible-playbook ansible/playbooks/801-setup-network-tailscale-tunnel.yml
```

### Step 8: Deploy Tailscale Operator to Cluster
```bash
# Deploy the Tailscale operator (secrets are applied automatically)
./uis deploy tailscale-tunnel
```

### Step 9: Add Individual Services (The Working Solution)

Since Tailscale doesn't support wildcard DNS, use the `802-tailscale-tunnel-deploy.sh` script to expose each service individually:

```bash
# Basic usage: ./802-tailscale-tunnel-deploy.sh <service-name> [hostname]

# Add whoami service (uses default hostname=whoami)
./networking/tailscale/802-tailscale-tunnel-deploy.sh whoami
# Result: https://whoami.dog-pence.ts.net

# Add OpenWebUI with custom hostname
./networking/tailscale/802-tailscale-tunnel-deploy.sh open-webui openwebui
# Result: https://openwebui.dog-pence.ts.net

# Add Authentik with clean hostname
./networking/tailscale/802-tailscale-tunnel-deploy.sh authentik-server authentik
# Result: https://authentik.dog-pence.ts.net

# Add Grafana
./networking/tailscale/802-tailscale-tunnel-deploy.sh grafana grafana
# Result: https://grafana.dog-pence.ts.net
```

**What the script does:**
1. Deploys Tailscale operator (if not already running)
2. Creates a Tailscale ingress pod for that specific service
3. Configures public internet access via Funnel
4. Traefik handles routing to the appropriate service
5. Sets up DNS entry at `[hostname].[your-domain].ts.net`

**To remove a service:**
```bash
# Remove by hostname
./networking/tailscale/803-tailscale-tunnel-deletehost.sh whoami
```

**Important notes:**
- Each service requires its own Tailscale pod (slight resource overhead)
- Services are directly accessible from the public internet
- No authentication by default - add Authentik protection if needed
- DNS propagation takes 1-5 minutes globally after adding a service

### Step 10: Test Public Internet Access
```bash
# Test your exposed services (replace with your actual domain):
curl https://whoami.dog-pence.ts.net
curl https://openwebui.dog-pence.ts.net
curl https://authentik.dog-pence.ts.net

# These URLs work from:
# - Any browser on any computer
# - No Tailscale client needed for visitors
# - Full public internet exposure via Funnel

# To see all your active Tailscale ingresses:
kubectl get pods -n tailscale -l app.kubernetes.io/name=tailscale-ingress
```

### Step 11: DNS Troubleshooting

If services are not immediately accessible, use these commands to check DNS resolution:

```bash
# Check basic DNS resolution
nslookup whoami.dog-pence.ts.net

# Get detailed DNS information
dig whoami.dog-pence.ts.net

# Test connectivity with verbose output
curl -v https://whoami.dog-pence.ts.net
```

**Expected Results:**
- `nslookup` should return a Tailscale Funnel IP (e.g., `185.40.234.37`)
- `dig` should show the A record with TTL information
- `curl -v` should show successful TLS handshake and HTTP response

**Common Issues:**
- **"Could not resolve host"** - DNS propagation still in progress (wait 1-5 minutes)
- **"Connection timeout"** - Check if service is running in cluster
- **"404 Not Found"** - Service exists but Traefik routing needs adjustment

## 🗑️ Complete Cleanup

To completely remove Tailscale and start over:
```bash
# Remove Tailscale operator, ingresses, and namespace from cluster
./uis undeploy tailscale-tunnel
```

**What gets deleted:**
- All Tailscale ingresses (cluster and per-service)
- Tailscale operator Helm release
- Tailscale namespace and pods

To also remove devices from your Tailnet via API, run the playbook directly:
```bash
./uis shell
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/801-remove-network-tailscale-tunnel.yml -e remove_tailnet_devices=true
```

## 🔧 Troubleshooting

### Error: "requested tags [tag:k8s-operator] are invalid or not permitted"

This error means your OAuth client doesn't have permission for `tag:k8s-operator`. To fix:

1. Go to [Trust credentials page](https://login.tailscale.com/admin/settings/trust-credentials)
2. Edit your `urbalurba-k8s-oauth` client
3. In **Devices → Core** scope, ensure `tag:k8s-operator` is added
4. In **Keys → Auth Keys** scope, ensure `tag:k8s-operator` is added
5. Generate a new client secret (required after scope changes)
6. Update `TAILSCALE_CLIENTSECRET` in `.uis.secrets/config/00-common-values.env`
7. Regenerate secrets: `./uis secrets generate`
8. Redeploy: `./uis deploy tailscale-tunnel`

**Key Point:** The operator uses `tag:k8s-operator` for all devices, including itself and cluster ingress devices with Funnel capability.

### Expired Tailscale Keys

If you get authentication errors, create new keys at [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys):

**Create OAuth Client:**
1. Go to [Trust credentials page](https://login.tailscale.com/admin/settings/trust-credentials)
2. Click "Generate OAuth client", name: `urbalurba-k8s`
3. Scopes: Devices → Core (Write), Keys → Auth Keys (Write) — both with `tag:k8s-operator`
4. Copy Client ID and Client Secret

**Create Auth Key:**
1. Click "Generate auth key" → "Auth key"
2. Tags: `tag:provision-host` (optional)
3. Expiry: 90 days
4. Copy the auth key

**Update secrets file:**
```bash
# Edit .uis.secrets/config/00-common-values.env
TAILSCALE_SECRET=tskey-auth-YOUR-NEW-AUTH-KEY
TAILSCALE_CLIENTID=YOUR-NEW-CLIENT-ID
TAILSCALE_CLIENTSECRET=tskey-client-YOUR-NEW-CLIENT-SECRET

# Regenerate and redeploy
./uis secrets generate
./uis deploy tailscale-tunnel
```

### Script Execution Issues

**Check Tailscale status in provision-host:**
```bash
# Access provision-host container
./uis shell

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

### Per-Service Routing Flow
```
1. External request: https://whoami.dog-pence.ts.net
2. Tailscale MagicDNS resolves to specific whoami-ingress device
3. whoami-ingress pod forwards directly to whoami service
4. No Traefik involvement - direct service connection
```

### Setup Flow
- **Configure secrets** → `./uis deploy tailscale-tunnel` → **Add services** (sequential)
- The per-service script can be run multiple times to add different services
- `./uis undeploy tailscale-tunnel` removes operator and all ingresses

### Integration with Other Systems
- Works alongside Cloudflare tunnels (different domains)
- Each service gets independent public URL
- Can add Authentik protection per service if needed

## ✅ Verification

After setup, verify your services are accessible:

```bash
# Test individual service URLs (after running 803 for each)
curl https://whoami.dog-pence.ts.net
curl https://openwebui.dog-pence.ts.net
curl https://authentik.dog-pence.ts.net

# Check all Tailscale ingress pods
kubectl get pods -n tailscale

# View Tailscale device status
tailscale status

# List all service ingresses
kubectl get pods -n tailscale -l app.kubernetes.io/name=tailscale-ingress
```

## 🎉 Benefits Achieved

✅ **Public Internet Access**: Each service accessible via its own `.ts.net` URL from anywhere
✅ **Automatic HTTPS**: Zero-configuration SSL certificates
✅ **No Port Forwarding**: Works behind NAT/firewalls via Tailscale Funnel
✅ **Flexible Service Exposure**: Choose exactly which services to make public
✅ **Simple Management**: Add/remove services with single command

## 📝 Summary

While Tailscale doesn't support wildcard DNS (limiting us from using patterns like `*.k8s.dog-pence.ts.net`), the `802-tailscale-tunnel-deploy.sh` script provides a practical workaround. Each service gets its own public URL like `https://whoami.dog-pence.ts.net`, giving you full control over which services are exposed to the internet.

⚠️ **Authentication Note**: Services exposed via Tailscale are publicly accessible by default. If you need authentication, consider adding Authentik protection. See `docs/rules-ingress-traefik.md` for authentication setup details.
