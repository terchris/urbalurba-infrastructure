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
We use the `./uis network expose tailscale <service>` command to create individual Tailscale ingresses for each service. Each service gets its own public URL directly on your tailscale domain.

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
| `./uis network up tailscale` | Deploy Tailscale operator to cluster | After secrets are configured |
| `./uis network down tailscale` | Remove Tailscale operator and ingresses | Clean up / start over |
| `./uis network expose tailscale <service>` | Expose a service via Tailscale Funnel | After operator deployed |
| `./uis network unexpose tailscale <service>` | Remove a service from Tailscale Funnel | When removing a service |
| `./uis network verify tailscale` | Check Tailscale secrets, API, devices, and operator | Diagnostics / pre-deploy checks |

## 🚀 Quick Start Guide

### Step 1: Create Tailscale Account

1. Visit [tailscale.com](https://tailscale.com) and sign up
2. Tailscale gives you a tailnet identifier (e.g., `yourusername.github`). The value UIS needs is your **MagicDNS domain** — the `<words>.ts.net` form, captured in Step 5 below. Don't note the org-handle form for `TAILSCALE_TAILNET`.

### Step 2: Configure the tailnet ACL

1. Go to [Tailscale Access Controls](https://login.tailscale.com/admin/acls)
2. Click **"JSON editor"** (top right of the policy editor)
3. **Replace the entire content with this minimum configuration:**

   ```jsonc
   {
     // Identity tag for every device UIS registers (operator pod + cluster
     // Funnel device + per-service Funnel devices). Owned by autogroup:admin
     // so the OAuth client (configured with this tag in Step 4) can apply it.
     "tagOwners": {
       "tag:k8s-operator": ["autogroup:admin"]
     },

     // Grants the Funnel capability to tag:k8s-operator devices. Without this,
     // the operator registers devices fine but Funnel never activates and
     // https://<device>.<tailnet>.ts.net returns "not configured".
     // Funnel must also be enabled at the tailnet level:
     // https://login.tailscale.com/admin/settings/funnel
     "nodeAttrs": [
       {
         "target": ["tag:k8s-operator"],
         "attr":   ["funnel"]
       }
     ],

     "acls": [
       // You (admin) can reach everything — needed for kubectl/curl/debug
       // from your laptop or any other personal device on the tailnet.
       {
         "action": "accept",
         "src":    ["autogroup:admin"],
         "dst":    ["*:*"]
       },

       // K8s operator devices can talk to each other. The operator pod and
       // the per-service Funnel ingress devices coordinate over tailnet IPs;
       // without this, intra-tag traffic is ACL-denied and exposes break.
       {
         "action": "accept",
         "src":    ["tag:k8s-operator"],
         "dst":    ["tag:k8s-operator:*"]
       }
     ]
   }
   ```

4. Click **Save**.

**What this does:**
- `tagOwners` — defines who can apply `tag:k8s-operator`. The OAuth client you create in Step 4 needs the same tag so it can register operator devices.
- `nodeAttrs` — grants the Funnel attribute to tagged devices, allowing public-internet exposure.
- `acls` — the minimum two rules: admin can reach anything (for debugging from your laptop), and tagged devices can talk among themselves (required for operator ↔ ingress traffic).

**Note on Funnel and ACLs**: Funnel (public internet → tailnet) is **not** governed by these ACL rules. Anyone on the internet can reach a Funnel-exposed device's HTTPS endpoint. To restrict, the service itself must enforce auth (Tailscale Funnel bypasses Traefik, so Authentik forward-auth doesn't apply — see [Tailscale Funnel](./tailscale.md)).

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
9. Copy the **auth key** → **This becomes `TAILSCALE_VM_AUTH_KEY`**

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

### Step 5: Configure MagicDNS Domain and HTTPS

1. Go to [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns)
2. Enable **MagicDNS**
3. Enable **HTTPS Certificates** (separate toggle on the same DNS page). Without this, Funnel cannot issue TLS certs and exposed services will fail the HTTPS handshake — see Troubleshooting → "TLS errors / no certificate" below.
4. Note your **MagicDNS domain** (e.g., `dog-pence.ts.net`) → **This becomes `TAILSCALE_TAILNET`**

### Step 6: Configure Tailscale Secrets

Run the wizard — it prompts for each value you collected in Steps 3-5, validates `TAILSCALE_OWNER_ID`, surfaces the **Tailscale Funnel bypasses Traefik** caveat up-front, and writes both `.uis.secrets/service-keys/tailscale.env` and the matching lines in `00-common-values.env.template` atomically:

```bash
./uis network init tailscale
```

The wizard prompts in order:
- `TAILSCALE_TAILNET` — From Step 5: MagicDNS domain (e.g. `dog-pence.ts.net`)
- `TAILSCALE_CLIENTID` — From Step 4: OAuth Client ID
- `TAILSCALE_CLIENTSECRET` — From Step 4: OAuth Client Secret
- `TAILSCALE_OWNER_ID` — Your identity on the tailnet; cluster Funnel device + operator prefix

`TAILSCALE_VM_AUTH_KEY` from Step 3 is only needed for the cloud-init / VM-bootstrap path — laptop / rancher-desktop users can skip Step 3 entirely.

<details>
<summary>Fallback: manual edit (advanced users only)</summary>

If you prefer to edit the secrets source file directly instead of running the wizard:

```bash
# From the host:
vi .uis.secrets/secrets-config/00-common-values.env.template
# Or from inside the provision-host container:
./uis secrets edit
```

Update these variables:
```bash
TAILSCALE_TAILNET=your-magic-dns-domain     # From Step 5: MagicDNS domain (e.g. dog-pence.ts.net)
TAILSCALE_OWNER_ID=k8s-yourname             # Your identity on the tailnet; cluster Funnel device + operator prefix
TAILSCALE_CLIENTID=YOUR-OAUTH-CLIENT-ID     # From Step 4: OAuth Client ID
TAILSCALE_CLIENTSECRET=tskey-client-YOUR-SECRET   # From Step 4: OAuth Client Secret
TAILSCALE_VM_AUTH_KEY=tskey-auth-YOUR-AUTH-KEY    # Only needed for VM/cloud-init provisioning
```

Then regenerate the Kubernetes secrets:
```bash
./uis secrets generate
```

The wizard does the same two-file write atomically and surfaces the Traefik-bypass caveat — recommended for first-time setup.

</details>

**Important: TAILSCALE_OWNER_ID:**
- This is used for the cluster-wide ingress only (when no service parameter is provided)
- Example: If set to `k8s` and your domain is `dog-pence.ts.net`:
  - `k8s.dog-pence.ts.net` → Routes to Traefik's default backend (nginx catch-all)
  - Individual services get their own URLs: `whoami.dog-pence.ts.net`, `grafana.dog-pence.ts.net`
  - **Note**: Tailscale does NOT support wildcard DNS, so `*.k8s.dog-pence.ts.net` patterns won't work

### Step 7: Verify Tailscale Configuration

Verify your Tailscale secrets and API connectivity before deploying:
```bash
./uis network verify tailscale
```

This checks:
- Secrets are present and not placeholder values
- API connectivity (OAuth authentication test)
- Stale device report (flags devices with `-N` suffixes)
- Operator status (running/not deployed)

### Step 8: Deploy Tailscale Operator to Cluster
```bash
# Deploy the Tailscale operator (secrets are applied automatically)
./uis network up tailscale
```

### Step 9: Expose Services via Tailscale Funnel

Since Tailscale doesn't support wildcard DNS, expose each service individually:

```bash
# Expose whoami (uses service name as hostname)
./uis network expose tailscale whoami
# Result: https://whoami.dog-pence.ts.net

# Expose other services
./uis network expose tailscale open-webui
# Result: https://open-webui.dog-pence.ts.net

./uis network expose tailscale authentik-server
# Result: https://authentik-server.dog-pence.ts.net

./uis network expose tailscale grafana
# Result: https://grafana.dog-pence.ts.net
```

**What happens:**
1. Creates a Tailscale ingress pod for that specific service
2. Configures public internet access via Funnel
3. Sets up DNS entry at `[service].[your-domain].ts.net`
4. Verifies connectivity and reports the public URL
5. Detects hostname mismatches (warns if a stale device caused a `-N` suffix)

**To remove a service from Funnel:**
```bash
./uis network unexpose tailscale whoami
```

This removes the Tailscale ingress and cleans up the device from your Tailnet via API.

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
# Remove Tailscale operator, ingresses, and all cluster devices from Tailnet
./uis network down tailscale
```

**What gets deleted:**
- All Tailscale ingresses (cluster and per-service)
- Tailscale operator Helm release
- Tailscale namespace and pods
- All cluster devices from your Tailnet (via API, enabled by default)

## 🔧 Troubleshooting

### Error: "requested tags [tag:k8s-operator] are invalid or not permitted"

This error means your OAuth client doesn't have permission for `tag:k8s-operator`. To fix:

1. Go to [Trust credentials page](https://login.tailscale.com/admin/settings/trust-credentials)
2. Edit your `urbalurba-k8s-oauth` client
3. In **Devices → Core** scope, ensure `tag:k8s-operator` is added
4. In **Keys → Auth Keys** scope, ensure `tag:k8s-operator` is added
5. Generate a new client secret (required after scope changes)
6. Update `TAILSCALE_CLIENTSECRET` in `.uis.secrets/secrets-config/00-common-values.env.template`
7. Regenerate secrets: `./uis secrets generate`
8. Redeploy: `./uis network up tailscale`

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
# Edit .uis.secrets/secrets-config/00-common-values.env.template
TAILSCALE_VM_AUTH_KEY=tskey-auth-YOUR-NEW-AUTH-KEY
TAILSCALE_CLIENTID=YOUR-NEW-CLIENT-ID
TAILSCALE_CLIENTSECRET=tskey-client-YOUR-NEW-CLIENT-SECRET

# Regenerate and redeploy
./uis secrets generate
./uis network up tailscale
```

### TLS errors / no certificate

If `curl https://<service>.<tailnet>.ts.net` returns a TLS handshake error (e.g. `SSL_ERROR_SYSCALL`, `unable to get local issuer certificate`, or the connection just hangs), the playbook reported success, and the Tailscale proxy pod is Running but the URL never serves traffic, check the proxy pod log first:

```bash
./uis shell
kubectl logs -n tailscale -l tailscale.com/parent-resource=<service> --tail=100 | grep -i "getCertPEM\|got cert"
```

Two distinct failure modes share this surface — the log line tells you which:

**1. HTTPS Certificates not enabled on the tailnet** — log shows no `getCertPEM` line at all (cert request never starts).

This is a separate toggle from MagicDNS and is required for Funnel to issue TLS certificates. Verify on the [Tailscale Admin Console → DNS](https://login.tailscale.com/admin/dns) page that both toggles are ON:

1. **MagicDNS** — ON
2. **HTTPS Certificates** — ON

If HTTPS Certificates was off and you've just turned it on, `unexpose` and re-`expose` the affected service so the proxy pod re-requests a cert.

**2. Let's Encrypt rate-limit (5 certs per exact hostname per 7 days)** — log shows a `429 urn:ietf:params:acme:error:rateLimited` line with a `retry after <timestamp>` and a pointer to `letsencrypt.org/docs/rate-limits/#new-certificates-per-exact-set-of-identifiers`.

Every `unexpose` + `expose` cycle on the same hostname burns one Let's Encrypt issuance — the operator deletes the device on unexpose, a fresh device on re-expose requests a fresh cert. After 5 such cycles in 168 hours, ACME returns 429 until the oldest issuance ages out. In this state the proxy pod is Running, the Ingress is applied, the Tailscale device registers fine — but `getCertPEM` keeps failing → no cert installed → TLS handshake aborts at Server Hello → `curl` reports `SSL_ERROR_SYSCALL`.

**Options:**

1. **Wait** — the `retry after` timestamp in the log tells you when the oldest issuance ages out.
2. **Use a different hostname** — expose the service under a different name (`./uis network unexpose tailscale <svc>` then `./uis network expose tailscale <svc-alt>`, where `<svc-alt>` is a fresh Kubernetes Service name) so a new ACME identifier is requested.
3. **Avoid expose/unexpose churn** during testing — once exposed, leave it; `down`/`up` of the operator preserves cert state better than per-service expose/unexpose cycles.

### TLS Handshake Timeout (Let's Encrypt Rate Limiting)

If `./uis network up tailscale` or `./uis network expose tailscale <service>` reports a TLS handshake timeout, check the Tailscale proxy pod logs:

```bash
./uis shell
kubectl logs -n tailscale -l tailscale.com/parent-resource=traefik-ingress --tail=50
```

If you see an error like:
```
cert("k8s.dog-pence.ts.net"): getCertPEM: 429 urn:ietf:params:acme:error:rateLimited:
too many certificates (5) already issued for this exact set of identifiers
```

This means **Let's Encrypt ACME rate limiting** is blocking TLS certificate issuance. The limit is **5 certificates per exact hostname per 7 days**. This typically happens when you repeatedly deploy/undeploy the same hostname during testing.

**Solutions:**
1. **Wait** for the rate limit to reset (the error message includes the retry-after timestamp)
2. **Use a different hostname** — change `TAILSCALE_OWNER_ID` in `.uis.secrets/secrets-config/00-common-values.env.template` (e.g., `k8s-2` instead of `k8s`), then `./uis secrets generate` and redeploy
3. **Avoid repeated deploy/undeploy cycles** with the same hostname during testing

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
- **Configure secrets** → `./uis network up tailscale` → `./uis network expose tailscale <service>` (sequential)
- Run `./uis network expose tailscale` for each service you want to make public
- `./uis network unexpose tailscale <service>` removes a single service from Funnel
- `./uis network down tailscale` removes operator and all ingresses

### Integration with Other Systems
- Works alongside Cloudflare tunnels (different domains)
- Each service gets independent public URL
- Can add Authentik protection per service if needed

## ✅ Verification

After setup, verify your services are accessible:

```bash
# Run Tailscale diagnostics
./uis network verify tailscale

# Test individual service URLs
curl https://whoami.dog-pence.ts.net
curl https://openwebui.dog-pence.ts.net
curl https://authentik.dog-pence.ts.net
```

## 🎉 Benefits Achieved

✅ **Public Internet Access**: Each service accessible via its own `.ts.net` URL from anywhere
✅ **Automatic HTTPS**: Zero-configuration SSL certificates
✅ **No Port Forwarding**: Works behind NAT/firewalls via Tailscale Funnel
✅ **Flexible Service Exposure**: Choose exactly which services to make public
✅ **Simple Management**: Add/remove services with single command

## 📝 Summary

While Tailscale doesn't support wildcard DNS (limiting us from using patterns like `*.k8s.dog-pence.ts.net`), the `./uis network expose tailscale` command provides a practical workaround. Each service gets its own public URL like `https://whoami.dog-pence.ts.net`, giving you full control over which services are exposed to the internet.

⚠️ **Authentication Note**: Services exposed via Tailscale are publicly accessible by default. If you need authentication, consider adding Authentik protection. See `docs/rules-ingress-traefik.md` for authentication setup details.
