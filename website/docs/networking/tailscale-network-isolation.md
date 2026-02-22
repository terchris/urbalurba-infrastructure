# Tailscale Funnel Security Setup for Rancher Desktop

TODO: This is not implemented - it is a potential solution that isolates the cluster when connected to the internet using tailscale funnel or cloudfrale tunnel.


## Overview

This document describes how to securely expose services from a local Rancher Desktop Kubernetes cluster to the internet while protecting your local network from potential security threats.

### The Challenge

When you expose services to the internet, you create a potential security risk. Without proper configuration, a compromised service could potentially access your local network, including other computers, printers, and sensitive resources on your home or office network.

### The Solution

We implement **network isolation** that creates a secure barrier between internet-facing services and your local network, while preserving the development workflow you're already using.

---

## Architecture Overview

### Current Setup
- **Rancher Desktop**: Running Kubernetes cluster on your computer
- **provision-host**: A Docker container for managing the cluster (accessed via `docker exec`)
- **Services**: Web applications running in Kubernetes that you want to expose to the internet

### Security Model

Our setup creates **two separate network zones**:

#### Zone 1: Management (Trusted)
- **provision-host container**: Used for development and cluster management
- **Network access**: Can reach the internet through your computer's network
- **Why it's safe**: Isolated from internet-facing services, only accessed by developers

#### Zone 2: Public Services (Restricted)
- **Kubernetes cluster services**: Applications exposed to the internet
- **Network access**: Can ONLY reach the internet through Tailscale secure tunnels
- **Why it's safe**: Completely blocked from accessing your local network

---

## Network Flow Diagrams

### Secure Inbound Traffic (From Internet to Your Services)
```
Internet Users
    ↓
Tailscale Funnel (Secure Gateway)
    ↓
Traefik (Load Balancer)
    ↓
Your Application (e.g., whoami service)
```

### Secure Outbound Traffic (From Your Services to Internet)
```
Your Application (needs to fetch data)
    ↓
Tailscale Exit Node (Secure Gateway)
    ↓
Internet
```
**✅ SECURE**: Cannot access your local network (printers, other computers, etc.)

### Development Workflow (Unchanged)
```
Developer
    ↓
docker exec provision-host
    ↓
kubectl commands / scripts
    ↓
Manage Kubernetes cluster
```
**✅ PRESERVED**: Your existing development process works exactly the same

---

## Security Benefits

### For Non-Technical Users

1. **Complete Network Protection**: Even if a web service gets hacked, attackers cannot access your local computers, printers, or other devices
2. **Zero Configuration Changes**: Your development workflow stays exactly the same
3. **Internet Access Maintained**: Your services can still access the internet when needed (for updates, APIs, etc.)
4. **No Performance Impact**: Local development and management tasks run at full speed

### For Technical Users

1. **Network Isolation**: All cluster egress traffic routes through Tailscale exit nodes, preventing access to RFC1918 private networks
2. **Container-Level Security**: provision-host remains isolated from Kubernetes network namespace
3. **Defense in Depth**: Multiple layers of protection (network policies + routing + container isolation)
4. **Minimal Attack Surface**: Only explicitly exposed services accessible via Funnel

---

## Implementation Details

### Prerequisites

1. **Tailscale Account**: With admin access to create OAuth credentials
2. **Rancher Desktop**: Running with Kubernetes enabled
3. **provision-host**: Docker container for cluster management
4. **Traefik**: Ingress controller running in the cluster

### Step 1: Tailscale Configuration

#### OAuth Client Setup
1. Go to [Trust credentials page](https://login.tailscale.com/admin/settings/trust-credentials)
2. Create OAuth client with:
   - **Scopes**: `Devices → Core` and `Keys → Auth Keys` (write access)
   - **Tags**: `tag:k8s-operator`

#### ACL Policy Configuration
Add to your Tailscale ACL policy:
```json
{
  "tagOwners": {
    "tag:k8s-operator": [],
    "tag:k8s": ["tag:k8s-operator"]
  }
}
```

### Step 2: Kubernetes Operator Installation

Install the Tailscale Kubernetes operator using Helm:

```bash
# Add Tailscale Helm repository
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

# Install operator with OAuth credentials
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  --namespace=tailscale --create-namespace \
  --set-string oauth.clientId="<your-oauth-client-id>" \
  --set-string oauth.clientSecret="<your-oauth-client-secret>" \
  --wait
```

### Step 3: Network Security Implementation

#### Force All Cluster Traffic Through Tailscale
```yaml
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: cluster-exit-node
  namespace: tailscale
spec:
  subnetRoutes:
    - "0.0.0.0/0"
  exitNode: true
```

#### Block Access to Local Networks
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-local-networks
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow internet access via Tailscale only
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 10.0.0.0/8      # Block private class A
        - 172.16.0.0/12   # Block private class B
        - 192.168.0.0/16  # Block private class C
        - 169.254.0.0/16  # Block link-local
        - 127.0.0.0/8     # Block loopback
  # Allow DNS resolution
  - to: []
    ports:
    - protocol: UDP
      port: 53
  # Allow cluster-internal traffic
  - to: []
    ports:
    - protocol: TCP
    - protocol: UDP
```

### Step 4: Service Exposure

#### Expose Service to Internet via Funnel
```yaml
apiVersion: v1
kind: Service
metadata:
  name: whoami
  annotations:
    tailscale.com/expose: "true"
spec:
  selector:
    app: whoami
  ports:
  - port: 443
    targetPort: 80
```

#### Enable Funnel for Public Access
```bash
# Find your service's Tailscale hostname
tailscale status

# Enable Funnel (replace with actual hostname)
tailscale funnel --bg https://whoami-default-xyz.tail-scale.ts.net:443
```

### Step 5: Validation

#### Test Network Isolation
```bash
# Deploy test pod
kubectl run network-test --image=busybox -it --rm -- /bin/sh

# Inside pod - these should FAIL (timeout):
ping 192.168.1.1          # Your router
ping 10.0.0.1             # Docker gateway
wget -T 5 http://192.168.1.100  # Local services

# This should WORK (via Tailscale):
ping 8.8.8.8              # Internet via exit node
```

#### Test Development Workflow
```bash
# This should work exactly as before:
docker exec -it provision-host /bin/bash
kubectl get pods
kubectl apply -f your-manifests.yaml
```

---

## Operational Considerations

### Monitoring
- **Tailscale Admin Console**: Monitor device connections and traffic
- **Kubernetes Logs**: Check operator and connector pod logs
- **Network Policies**: Use `kubectl describe networkpolicy` to verify rules

### Troubleshooting
1. **Service Not Accessible**: Check Funnel configuration and DNS resolution
2. **No Internet from Pods**: Verify exit node is running and connected
3. **Network Policy Issues**: Test with temporary policy removal

### Performance
- **Latency**: Outbound traffic routes through Tailscale exit nodes
- **Bandwidth**: Limited by Tailscale plan and exit node capacity
- **Local Traffic**: Cluster-internal communication unaffected

### Backup Procedures
- **Configuration Backup**: Export Tailscale and Kubernetes configurations
- **Recovery Plan**: Document steps to restore connectivity if issues arise

---

## Cost and Resource Implications

### Tailscale Costs
- **Personal Use**: Free tier supports up to 3 devices
- **Business Use**: Paid plans for larger deployments
- **Exit Node Bandwidth**: May affect plan selection

### Resource Usage
- **Memory**: ~100MB for operator pod
- **CPU**: Minimal impact on cluster performance
- **Network**: Additional overhead for encrypted tunneling

---

## Security Checklist

### Pre-Deployment
- [ ] OAuth client created with minimal required scopes
- [ ] ACL policies configured for least-privilege access
- [ ] Network policies tested in development environment
- [ ] Backup procedures documented

### Post-Deployment
- [ ] Network isolation verified with test pods
- [ ] Funnel access confirmed from external network
- [ ] Development workflow validated
- [ ] Monitoring and alerting configured
- [ ] Incident response procedures documented

### Ongoing Maintenance
- [ ] Regular security updates for Tailscale operator
- [ ] Periodic review of exposed services
- [ ] Monitoring of unusual network patterns
- [ ] Backup configuration updates

---

## Conclusion

This setup provides **enterprise-grade security** for exposing local Kubernetes services to the internet while maintaining the **development workflow you're already comfortable with**.

**Key Benefits**:
- ✅ Complete network isolation prevents lateral movement
- ✅ Zero impact on existing development processes
- ✅ Secure internet access for services when needed
- ✅ Simple to maintain and monitor

**The Result**: You can confidently expose services to the internet knowing that even if they're compromised, your local network remains completely protected.