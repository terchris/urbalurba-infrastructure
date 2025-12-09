# Networking Overview

**Status**: 🌐 Dual-Tunnel Internet Access Architecture  
**Updated**: September 8, 2025  
**Architecture**: HostRegexp routing with Tailscale + Cloudflare support





## 🚀 Quick Start - Connect Your Cluster to the Internet

Your cluster works perfectly on `.localhost` domains for development. Ready to connect to the internet?

**You have two options** - both are supported by your existing manifests:

### Option A: Tailscale Funnel 🔵 (Quick & Free)
- **Get online in**: 15 minutes
- **Cost**: Free 
- **URLs**: `https://whoami.your-device.ts.net`
- **Perfect for**: Personal projects, demos, team development

### Option B: Cloudflare Tunnel ⚡ (Professional)  
- **Get online in**: 45 minutes
- **Cost**: ~$10-15/year (domain)
- **URLs**: `https://whoami.your-domain.com`
- **Perfect for**: Business sites, production apps, custom branding

**👉 [Jump to tunnel selection guide](#-internet-access-options-tailscale-vs-cloudflare)**

---

## Introduction

This document provides a complete guide to:
* **Internet access options** - Choose between Tailscale Funnel and Cloudflare Tunnel
* **Architecture overview** - How the dual-tunnel system works
* **Setup guidance** - Get your services online quickly
* **DevOps access** - Secure administration with Tailscale VPN

---

## 🌐 Internet Access Options: Tailscale vs Cloudflare

### Your Current Status ✅

You have successfully deployed your cluster and everything works on development domains:
- ✅ `http://whoami.localhost` - Working great  
- ✅ `http://openwebui.localhost` - AI chat accessible
- ✅ `http://authentik.localhost` - Authentication ready
- ✅ All services running smoothly

**Next Step**: Connect to the internet so others can access your services.

### 🤔 Which Option Should You Choose?

### Choose **Tailscale Funnel** if you want:

✅ **Quick & Free Setup**
- No domain purchase required
- Automatic HTTPS certificates  
- Working in 15 minutes

✅ **Personal/Learning Projects**
- Perfect for demos and testing
- Share with friends easily
- No ongoing domain costs

✅ **Built-in Security**
- Only people you invite can access
- VPN-level security by default
- Fine-grained access controls

✅ **Simple Management**
- One dashboard for everything
- No DNS configuration needed
- Automatic updates and renewal

**Best for**: Personal projects, learning, demos, team development, secure internal tools

### Choose **Cloudflare Tunnel** if you want:

✅ **Professional Domains**
- Your own custom domain (`yourcompany.com`)
- Professional appearance for clients
- Brand consistency

✅ **Production-Ready Features**
- Global CDN and caching
- DDoS protection included
- Web Application Firewall (WAF)
- Analytics and monitoring

✅ **Public Access**
- Anyone can access (no VPN needed)
- Perfect for public-facing services
- SEO-friendly URLs

✅ **Scalability**
- Handle high traffic loads
- Multiple domains supported
- Enterprise-grade infrastructure

**Best for**: Business websites, public services, client demos, production applications

### 📊 Quick Comparison

| Feature | Tailscale | Cloudflare |
|---------|-----------|------------|
| **Setup Time** | 15 minutes | 45 minutes |
| **Domain Cost** | Free | $10-15/year |
| **Custom Domain** | No | Yes |
| **Security** | VPN-style (invite only) | Public + WAF protection |
| **Performance** | Direct connection | Global CDN |
| **Maintenance** | Minimal | Minimal |
| **Production Ready** | Personal/team use | Enterprise grade |
| **Access Control** | Tailscale accounts | Internet + optional auth |

### 🚀 Can You Use Both?

**Yes!** Your **HostRegexp routing architecture** supports both simultaneously:

- **Development**: `service.localhost` (local testing)
- **Team Access**: `service.your-device.ts.net` (secure team sharing)  
- **Public Access**: `service.yourcompany.com` (customer-facing)

**Technical Implementation**:
```yaml
# Your manifests use HostRegexp patterns like this:
match: HostRegexp(`whoami\..+`)

# This automatically handles:
# - whoami.localhost (development)
# - whoami.provision-host.dog-pence.ts.net (Tailscale Funnel)  
# - whoami.yourcompany.com (Cloudflare Tunnel)
```

**Common Pattern**:
1. Start with **Tailscale** for immediate internet access
2. Add **Cloudflare** later when you need custom domains
3. Use both for different purposes (internal vs external)

*See [Traefik Ingress Rules](rules-ingress-traefik.md) for complete technical details on HostRegexp routing.*

### 🎯 Recommended Decision Path

#### Quick Decision Questions:

1. **Do you need a custom domain (yourcompany.com)?**
   - Yes → Cloudflare
   - No → Tailscale

2. **Is this for business/client use?**
   - Yes → Cloudflare  
   - No → Tailscale

3. **Do you want to spend money on a domain?**
   - Yes → Cloudflare
   - No → Tailscale

4. **Do you need public internet access?**
   - Yes → Cloudflare
   - Team only → Tailscale

**When in doubt, start with Tailscale** - you can always add Cloudflare later!



---

## 🏗️ Architecture Overview

### Microsoft Cloud Adoption Framework (CAF) principles

The networking architecture follows Microsoft Cloud Adoption Framework (CAF) principles for enterprise-grade infrastructure design.

Kubernetes clusters can be defined as Landing Zones - either standalone or within larger Azure/cloud Landing Zones, providing isolation, governance, and security boundaries.

### Dual-Tunnel Architecture Benefits

Your cluster uses **HostRegexp routing patterns** in Traefik IngressRoutes that automatically work with both tunnel types:

```yaml
# Example from your working manifests:
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
spec:
  routes:
    - match: HostRegexp(`whoami\..+`)  # Matches any domain starting with "whoami."
      kind: Rule
      services:
        - name: whoami
          port: 80

# This pattern automatically handles:
# - whoami.localhost (development - auto-routes to 127.0.0.1)
# - whoami.provision-host.dog-pence.ts.net (Tailscale Funnel)  
# - whoami.yourcompany.com (Cloudflare Tunnel)
```

**Key Technical Advantages**:
- ✅ **Unified Routing**: Single IngressRoute handles multiple domains
- ✅ **Zero Configuration**: No manifest changes when adding tunnel types
- ✅ **Internal DNS Support**: CoreDNS resolves `.localhost` for pod-to-pod communication  
- ✅ **Authentication Ready**: Works with Authentik forward auth middleware
- ✅ **Future-Proof**: Automatically supports any new domains

*Technical details: [Traefik Ingress Rules Guide](rules-ingress-traefik.md)*

### External Access with Cloudflare

Cloudflare provides secure, scalable exposure of services to the internet:

- **Purpose**: Professional public access with custom domains
- **Benefits**: Global CDN, DDoS protection, WAF, rate limiting, zero-trust access
- **Implementation**: Cloudflare Tunnels connect to Kubernetes without inbound ports
- **URLs**: `https://service.yourcompany.com`

### Internet Access with Tailscale Funnel

Tailscale Funnel provides quick, secure internet access without custom domains:

- **Purpose**: Fast internet access for personal/team projects
- **Benefits**: Zero configuration, automatic HTTPS, invite-based security
- **Implementation**: Tailscale Funnel exposes services via .ts.net domains
- **URLs**: `https://service.your-device.ts.net`

### Internal Networking with Tailscale VPN

Tailscale VPN provides secure DevOps access to clusters:

- **Purpose**: Private communication for administration and maintenance
- **Benefits**: Works across any environment (local, cloud, multi-cloud)
- **Security**: Zero-trust networking with MagicDNS and ACL-based access control

## High-Level Architecture for Internet Access

The diagram below shows how external traffic reaches your services through either tunnel type:

:::mermaid
flowchart TD
    User["External User"]
    User2["Team Member"]
    Dev["Developer"]
    
    subgraph Internet_Access ["Internet Access Options"]
        Tailscale_Funnel["Tailscale Funnel<br>service.device.ts.net"]
        CF_Tunnel["Cloudflare Tunnel<br>service.domain.com"]
        Localhost["Localhost<br>service.localhost"]
    end
    
    subgraph Your_Cluster ["Your Kubernetes Cluster"]
        subgraph Traefik_Layer ["Traefik Layer"]
            Traefik["Traefik 3.3.6<br>IngressRoute CRDs"]
            HostRegexp["HostRegexp Routing<br>`service\..+`"]
            Internal_DNS["Internal DNS<br>CoreDNS Rewrites"]
        end
        
        subgraph Services_Layer ["Services Layer"]
            Services["Your Services<br>(whoami, openwebui, authentik)"]
            Auth["Authentik Forward Auth<br>(Optional)"]
        end
    end
    
    User --> CF_Tunnel
    User2 --> Tailscale_Funnel
    Dev --> Localhost
    
    CF_Tunnel --> Traefik
    Tailscale_Funnel --> Traefik
    Localhost --> Traefik
    
    Traefik --> HostRegexp
    HostRegexp --> Auth
    HostRegexp --> Services
    Auth --> Services
    
    Internal_DNS -.-> Services
:::

**Key Technical Features**:
- **HostRegexp routing**: `match: HostRegexp('service\..+')` patterns handle all domain types
- **Traefik IngressRoute CRDs**: Using `traefik.io/v1alpha1` API (current stable version)
- **Internal DNS**: CoreDNS rewrites enable pod-to-pod communication on same hostnames
- **Authentication**: Optional Authentik forward auth middleware for protected services
- **Zero Configuration**: No manifest changes needed when adding/switching tunnels

## High-Level Architecture for DevOps Access

The diagram below shows how DevOps engineers securely connect to clusters:

:::mermaid
flowchart TD
    subgraph DevOps["DevOps Engineer's Machine"]
        subgraph provision_host_container ["provision-host container"]
            kubectl["kubectl"]
            tools["SSH<br>Ansible<br>Cloud CLIs"]
            Tailscale_Client["Tailscale Client"]
            
            kubectl --- tools --- Tailscale_Client
            linkStyle 0 stroke-width:0,stroke-opacity:0,fill-opacity:0
            linkStyle 1 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    subgraph Tailscale_Network ["Tailscale Secure Network"]
        TS_Cloud["Tailscale Control Plane<br>(Authentication & ACLs)"]
    end
    
    subgraph Your_Infrastructure ["Your Infrastructure"]
        subgraph Cluster_VM["Cluster Host"]
            Tailscale_Agent["Tailscale Client"]
            K8s_Cluster["Kubernetes Cluster"]
            
            Tailscale_Agent --- K8s_Cluster
            linkStyle 3 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    Tailscale_Client -- "Secure Connection" --> TS_Cloud
    Tailscale_Agent -- "Secure Connection" --> TS_Cloud
    
    Tailscale_Client -. "Encrypted P2P<br>Administration" .-> Tailscale_Agent
:::

---

## Technology Choices for Optimal Security and Performance

### Why Cloudflare?

Cloudflare provides enterprise-grade security and performance for public-facing services:

**Security Features**:
- Advanced Web Application Firewall (WAF) blocks malicious traffic
- DDoS protection mitigates attacks of any size
- Zero-trust tunnel approach - no inbound ports needed
- SSL/TLS termination with automatic certificate management

**Performance Features**:
- Global network spans 300+ cities for low latency
- Intelligent edge caching reduces server load
- Cloudflare Workers enable custom routing logic
- Analytics and monitoring for traffic insights

**Implementation**:
- Cloudflare Tunnels create secure outbound-only connections
- No public IP addresses or firewall ports needed
- Programmable routing based on domain, path, or headers
- Automatic failover and load balancing

For detailed setup instructions, see [Cloudflare Tunnel Setup Guide](networking-cloudflare-setup.md).

### Why Tailscale?

Tailscale provides zero-configuration secure networking for both internet access and DevOps administration:

**For Internet Access (Tailscale Funnel)**:
- Instant HTTPS endpoints on .ts.net domains
- No domain purchase or DNS configuration required
- Invite-based access control for security
- Perfect for personal projects and team development

**For DevOps Access (Tailscale VPN)**:
- WireGuard-based encrypted peer-to-peer connections
- Works seamlessly across NATs and firewalls
- Identity-based access control with fine-grained ACLs
- "Zero config" approach eliminates traditional VPN complexity

**Architecture Benefits**:
- True zero-trust networking model
- Eliminates central VPN server points of failure
- Automatic key rotation and device management
- Cross-platform support for all environments

For detailed setup instructions, see [Tailscale Funnel Setup Guide](networking-tailscale-setup.md).

---

## Next Steps

### Ready to Connect to the Internet?

Choose your tunnel type and follow the setup guide:

1. **🔵 [Tailscale Funnel Setup](networking-tailscale-setup.md)** - Get online in 15 minutes (free)
2. **⚡ [Cloudflare Tunnel Setup](networking-cloudflare-setup.md)** - Professional setup with custom domain




---

*Your HostRegexp architecture makes switching between tunnel types seamless - the same manifests work for localhost development, Tailscale team access, and Cloudflare production without any modifications.*

