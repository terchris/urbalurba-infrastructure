# Networking Overview

TODO: I have not been able to set up redirect from an external DNS to the tunnels. 
I can set up CNAME that points to the tunnel like this:

```plaintext
a) jalla2.skryter.no	10800	CNAME	jalla.skryter.no.urbalurba.no	
b) jalla3.skryter.no	10800	CNAME	f68c1459-8b12-4b2b-b566-c2f68d538a19.cfargotunnel.com	
c) jalla4.skryter.no	10800	CNAME	urbalurba.no	
d) jalla5.skryter.no	10800	CNAME	proxy-worker.terje-97e.workers.dev
```

```plaintext
a is pointing directly to a tunnel in cloudflare using the cname name in urbalurba dns.
b is pointing directly to the tunnel id in cloudflare.
c is pointing to the root domain and to a worker that redirects to the tunnel (using alias name).
d is pointing to the same worker but uses the full name of the worker.
```

All of the redirects from the skryter.no DNS works. So that is not the problem.
The problem is how cloudflare is not sending the request to the tunnel.
curl -i http://jalla4.skryter.no and curl -i http://jalla2.skryter.no gives a `error code: 1001`

The tunnels are working and I can do direct curl to the tunnel and get a response.
eg curl http://jalla2.skryter.no.urbalurba.no and curl http://jalla4.ublalurba.no





## Introduction

This document provides an overview of: 
* The networking setup that makes the services reachable from the Internet.
* How DevOps admins connect to the clusters for administration and maintenance.

### Microsoft Cloud Adoption Framework (CAF) principles

The networking architecture follow the Microsoft Cloud Adoption Framework (CAF) principles.

TODO: The CAF principles are:

TODO: explain how the kubernetes custers can be defined as Landing Zones. A kubernetes cluster can it self be defined as a Landing Zone, but it can also be placed in a Azure Landing zone.

### External Access with Cloudflare

We use Cloudflare to safely and securely expose the services to the Internet.

Cloudflare provides secure exposure of services to the internet:

- **Purpose**: Allow external users to access services without exposing infrastructure
- **Benefits**: DDoS protection, WAF, rate limiting, and zero-trust access
- **Implementation**: Cloudflare Tunnels connect to Kubernetes clusters without inbound ports

### Internal Networking with Tailscale

We use Tailscale to securely connect the DevOps team to the Kubernetes clusters.

Tailscale provides a secure mesh VPN that connects all infrastructure components:

- **Purpose**: Private communication between provision host and Kubernetes clusters
- **Benefits**: Works across any environment (local, cloud, multi-cloud)
- **Security**: Zero-trust networking with MagicDNS and ACL-based access control



## High-Level Architecture for exposing services to the Internet

1) The figure below shows how traffic is routed to the CloudFlare account for urbalurba.no
2) The CloudFlare worker then routes the traffic based on the domain name to the defined tunnel.
3) The tunnel is terminated in in the kubernetes cluster and handed ower to the ingress router (traefik) which then routes the traffic to the appropriate service.

:::mermaid
flowchart TD
    User["External User calling<br>web.urb.skryter.no"]
    User2["External User calling<br>api.bylab.no"]
    DNS["External DNS<br> *.urb.skryter.no -><br> urbalurba.no"]
    DNS2["External DNS<br> *.bylab.no -><br> urbalurba.no"]
    
    subgraph Cloudflare_Layer ["Cloudflare Layer"]
        CF_Security["urbalurba.no<br>Cloudflare Security Layer<br>(WAF, DDoS)"]
        CF_Worker["Cloudflare Worker<br>(Routing Logic)"]
        Azure_Tunnel["azure-microk8s-tunnel"]
        Rancher_Tunnel["rancher-k3s-tunnel"]
    end
    
    subgraph Azure_Cluster ["azure-microk8s cluster"]
        Azure_Pod["azure-microk8s-tunnel-pod"]
        Azure_Traefik["Traefik<br>Ingress router"]
        Azure_Web["Web Services"]
        Azure_API["API Services"]
    end
    
    subgraph Rancher_Cluster ["rancher-k3s cluster"]
        Rancher_Pod["rancher-k3s-tunnel-pod"]
        Rancher_Traefik["Traefik<br>Ingress router"]
        Rancher_Web["Web Services"]
        Rancher_API["API Services"]
    end
    
    User --> DNS
    User2 --> DNS2
    DNS --> CF_Security
    DNS2 --> CF_Security
    CF_Security --> CF_Worker
    CF_Worker --> Azure_Tunnel
    CF_Worker --> Rancher_Tunnel
    Azure_Tunnel --> Azure_Pod
    Rancher_Tunnel --> Rancher_Pod
    Azure_Pod --> Azure_Traefik
    Rancher_Pod --> Rancher_Traefik
    Azure_Traefik --> Azure_Web
    Azure_Traefik --> Azure_API
    Rancher_Traefik --> Rancher_Web
    Rancher_Traefik --> Rancher_API
:::

The setup enables us to create as many clusters as we want and connect them to the same CloudFlare account. Each cluster just needs a place to run and a tunnel to CloudFlare. The clusters can run on Azure, AWS, or on-premises. And even on a Raspberry Pi in the corner of a room.

## High-Level Architecture for connecting to the clusters

The figure below shows how the DevOps engineers connect to the clusters using Tailscale.
* On the DevOps machine a container named provisoin-host is runing.
* In the container all the tools needed to admin and maintain the kubernetes cluster and the infrastructure is installed.
* In the container and on the Azure VM a tailscale client is running so that these machines are on the same network.
* The tailscale network is a Zero Trust network and the ACL rules are configured to allow the DevOps team to connect to the VMs running the clusters. But the Clusters cannot connect to eachother.


:::mermaid
flowchart TD
    subgraph DevOps["DevOps Engineer's Machine"]
    
        subgraph provision_host_container ["provision-host container"]
            kubectl["kubectl"]
            tools["SSH<br>Ansible<br>AZ CLI"]
            Tailscale_Client["Tailscale Client"]
            
            %% Force vertical stacking with invisible connections
            kubectl --- tools --- Tailscale_Client
            linkStyle 0 stroke-width:0,stroke-opacity:0,fill-opacity:0
            linkStyle 1 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    subgraph Tailscale_Network ["Tailscale Secure Network"]
        TS_Cloud["Tailscale Control Plane<br>(Authentication & Coordination)"]
        ACL_Rules["ACL Rules<br>(Access Control Policies)"]
        
        TS_Cloud --- ACL_Rules        
    end
    
    subgraph Azure_Landing_Zone ["Azure Landing Zone"]
        subgraph Azure_VM["Azure VM"]
            Azure_Tailscale["Tailscale Client"]
            MicroK8s["azure-microk8s Cluster"]
            
            %% Force vertical stacking with invisible connections
            Azure_Tailscale --- MicroK8s
            linkStyle 3 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    Tailscale_Client -- "Establishes encrypted<br>WireGuard connection" --> TS_Cloud
    Azure_Tailscale -- "Establishes encrypted<br>WireGuard connection" --> TS_Cloud
    
    Tailscale_Client -. "Secure peer-to-peer connection<br>via Tailscale network" .-> Azure_Tailscale
:::

By using a container that contains all the tools needed to admin and maintain the kubernetes cluster and the infrastructure we can easily connect to any cluster from any machine.
The devops machine can be a laptop or a desktop computer. A windows or mac machine. A ARM or X86 machine.

The Tailscale network is a Zero Trust network and the ACL rules are configured so that we can specify which machines that can connect to which clusters.

## Technology choices for optimal security and networking performance

### Why CloudFlare?

Cloudflare was selected as our external-facing security and networking solution because it provides a comprehensive platform for protecting and optimizing our services. Acting as a protective shield between our infrastructure and the internet, Cloudflare offers enterprise-grade security features without the traditional complexity.

Cloudflare's global network spans over 300 cities worldwide, ensuring low-latency connections for users regardless of their location. Its advanced Web Application Firewall (WAF) actively blocks malicious traffic, SQL injections, and other common attack vectors before they ever reach our infrastructure. The built-in DDoS protection system can mitigate attacks of any size, protecting our services from volumetric attacks that would otherwise overwhelm traditional defenses.

The Cloudflare Tunnel technology (formerly Argo Tunnel) creates secure outbound-only connections from our Kubernetes clusters to Cloudflare's edge, eliminating the need to expose our infrastructure directly to the internet. This zero-trust approach means we don't need to manage public IP addresses, open inbound firewall ports, or worry about traditional network attack surfaces.

Cloudflare Workers provide us with programmable routing logic at the edge, allowing us to intelligently direct traffic based on domain names, paths, or other request attributes to the appropriate backend services and clusters. This edge computing capability also enables us to implement custom access policies, perform request transformations, and handle specialized routing needs without modifying our core applications.

For detailed Cloudflare setup and configuration instructions, refer to the [Cloudflare configuration guide](external-cloudflare-readme.md).

To learn more about Cloudflare technology, visit [cloudflare.com](https://www.cloudflare.com/learning/).

### Why Tailscale?

Tailscale is a network platform that provides secure, private connections between devices. It allows DevOps admins to connect to the clusters from anywhere, while ensuring that only authorized devices can access the clusters.

Tailscale was chosen as our internal networking solution because it eliminates the complexity of traditional VPNs while providing superior security. Based on WireGuard, it offers encrypted peer-to-peer connections, removing the need for a central VPN server.

Tailscale's "zero config" approach means it works seamlessly across NATs and firewalls without port forwarding or complex routing rules. Its identity-based access control model ensures that only authorized devices and users can access specific resources, following a true zero-trust architecture model. This makes it ideal for connecting distributed infrastructure components across different environments and cloud providers.

For detailed Tailscale setup and configuration instructions, refer to the [Tailscale VPN readme](vpn-tailscale-readme.md).
To learn more about Tailscale technology, visit [tailscale.com](https://tailscale.com/learn).

