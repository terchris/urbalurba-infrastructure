# Tailscale Internal Access Setup Guide

**Purpose**: Internal-only Tailnet access for SovereignSky developers
**Audience**: Developers needing secure access to cluster services without public internet exposure
**Time Required**: 5-10 minutes
**Prerequisites**: Working cluster with Traefik ingress, Tailscale account with OAuth credentials

## Overview

This guide explains how to deploy **internal-only** Tailscale access to your Kubernetes cluster using a LoadBalancer Service. Unlike the Funnel-based setup (see `networking-tailscale-setup.md`), this deployment:

- **NO public internet access** (internal Tailnet only)
- **Accessible ONLY from devices on the same Tailnet**
- **Works with HTTP** (no HTTPS requirement on tailnet)
- **Designed for SovereignSky developers** using devcontainers with Tailscale VPN

## Architecture

### How It Works

```
SovereignSky Devcontainer (with Tailscale)
    |
    v
Tailnet (private network)
    |
    v
k8s-terje (Tailscale LoadBalancer)  <-- internal URL: http://k8s-terje.taile269d.ts.net
    |
    v
Traefik Ingress Controller
    |
    +-> grafana.sovereignsky.no
    +-> otel.sovereignsky.no
    +-> litellm.sovereignsky.no
```

### Tailscale Devices Per Cluster

Each cluster creates **two devices** in Tailscale Admin Console:

| Device Name | Purpose | Description |
|-------------|---------|-------------|
| `k8s-terje-tailscale-operator` | Controller | Manages Tailscale resources in the cluster |
| `k8s-terje` | LoadBalancer proxy | Routes HTTP traffic to Traefik |

**Multi-cluster naming convention:**
```
MacBook cluster:    k8s-terje-tailscale-operator, k8s-terje
iMac cluster:       k8s-imac-tailscale-operator, k8s-imac
tecmacdev cluster:  k8s-tecmacdev-tailscale-operator, k8s-tecmacdev
```

The `-tailscale-operator` suffix matches the default naming from [Tailscale Kubernetes Operator documentation](https://tailscale.com/kb/1236/kubernetes-operator), making it clear this is the official Tailscale component.

## Quick Start

### Step 1: Configure Secrets

Ensure your `00-common-values.env` (or Kubernetes secrets) includes:

```bash
# Tailscale OAuth credentials (from https://login.tailscale.com/admin/settings/trust-credentials)
TAILSCALE_CLIENTID=k7Gdhr7mdf11CNTRL
TAILSCALE_CLIENTSECRET=tskey-client-k7Gdhr7mdf11CNTRL-xxxxx

# Tailnet info
TAILSCALE_TAILNET=businessmodel.io
TAILSCALE_DOMAIN=taile269d.ts.net

# Internal hostname - UNIQUE PER CLUSTER
TAILSCALE_OPERATOR_PREFIX=k8s-terje   # k8s-imac for iMac, k8s-tecmacdev for tecmacdev
```

### Step 2: Deploy Internal Ingress

From the provision-host container:

```bash
./uis shell
cd /mnt/urbalurbadisk

# Deploy Tailscale internal ingress
ansible-playbook ansible/playbooks/805-deploy-tailscale-internal-ingress.yml
```

### Step 3: Verify Deployment

```bash
# Check pods in tailscale namespace
kubectl get pods -n tailscale

# Expected output:
# NAME                                              READY   STATUS
# operator-84987b6fc7-xxxxx                         1/1     Running
# ts-tailscale-internal-ingress-xxxxx-0             1/1     Running

# Check Tailscale Admin Console for devices:
# - k8s-terje-tailscale-operator
# - k8s-terje
```

## Configuration Files

### Manifests

| File | Purpose |
|------|---------|
| `manifests/800-tailscale-operator-config.yaml.j2` | Helm values for Tailscale operator (Jinja2 template) |
| `manifests/805-tailscale-internal-ingress.yaml.j2` | LoadBalancer Service for Tailnet-only access (Jinja2 template) |

### Ansible Playbooks

| File | Purpose |
|------|---------|
| `ansible/playbooks/805-deploy-tailscale-internal-ingress.yml` | Deploy internal ingress |
| `ansible/playbooks/806-remove-tailscale-internal-ingress.yml` | Remove internal ingress |

### Setup Scripts

| File | Purpose |
|------|---------|
| `provision-host/kubernetes/network/03-setup-tailscale-internal.sh` | Setup script |
| `provision-host/kubernetes/network/03-remove-tailscale-internal.sh` | Removal script |

## Technical Details

### Why Two Devices?

The Tailscale Kubernetes Operator **always** registers itself as a device on the Tailnet. This cannot be disabled. Per the [official documentation](https://tailscale.com/kb/1236/kubernetes-operator):

> The Tailscale Kubernetes operator creates a tailnet device for itself when deployed.

This is expected behavior, not a bug. Each cluster needs:
1. **Operator device** - Manages Tailscale resources
2. **Ingress device** - Routes actual traffic

### LoadBalancer Service Configuration Key Points

The LoadBalancer Service uses `loadBalancerClass: tailscale` which enables HTTP traffic:

```yaml
# From 805-tailscale-internal-ingress.yaml.j2
apiVersion: v1
kind: Service
metadata:
  name: traefik-tailscale
  namespace: kube-system
  annotations:
    tailscale.com/hostname: "{{ TAILSCALE_OPERATOR_PREFIX }}"  # Device name
    tailscale.com/tags: "tag:k8s-operator"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    app.kubernetes.io/name: traefik
    app.kubernetes.io/instance: traefik-kube-system
  ports:
    - name: http
      port: 80
      targetPort: web
    - name: https
      port: 443
      targetPort: websecure
```

This approach:
- Works with HTTP (no HTTPS requirement on tailnet)
- Does NOT use Funnel (internal Tailnet access only)
- Exposes both HTTP (80) and HTTPS (443) ports to Traefik

### Operator Configuration Key Points

The operator gets a unique hostname per cluster:

```yaml
# From 800-tailscale-operator-config.yaml.j2
operatorConfig:
  hostname: "{{ TAILSCALE_OPERATOR_PREFIX }}-tailscale-operator"
  tags: "tag:k8s-operator"
  logging: "info"
```

## Developer Access

### From SovereignSky Devcontainer

1. Devcontainer has Tailscale VPN configured
2. DNS resolves `*.sovereignsky.no` to the cluster's Tailscale IP
3. Access services directly: `http://grafana.sovereignsky.no`

```bash
# From inside a devcontainer with Tailscale
curl http://grafana.sovereignsky.no
curl http://otel.sovereignsky.no
curl http://litellm.sovereignsky.no
```

### Direct Tailscale Access

You can also access the cluster directly via Tailscale (HTTP works now):

```bash
# Direct Tailscale URL (HTTP, internal only)
curl http://k8s-terje.taile269d.ts.net

# With Host header for service routing
curl -H "Host: grafana.localhost" http://k8s-terje.taile269d.ts.net
```

## Removal

To remove the internal ingress:

```bash
./uis shell
cd /mnt/urbalurbadisk

# Remove ingress only (keep operator)
ansible-playbook ansible/playbooks/806-remove-tailscale-internal-ingress.yml

# Remove everything (ingress + operator)
ansible-playbook ansible/playbooks/806-remove-tailscale-internal-ingress.yml \
  -e remove_operator=true
```

## Comparison: Internal vs Funnel

| Feature | Internal LoadBalancer (805) | Funnel Ingress (802-803) |
|---------|----------------------|-------------------------|
| Public internet access | No | Yes |
| Requires Tailscale on client | Yes | No |
| Use case | Developer access | Public services |
| Security | Tailnet-only | Public with HTTPS |
| HTTP support | Yes | No (HTTPS only) |
| HTTPS requirement on tailnet | No | Yes |
| Kubernetes resource type | LoadBalancer Service | Ingress |
| Setup scripts | 805/806 | 801-804 |

## Troubleshooting

### Device Not Appearing in Tailscale Admin

1. Check operator pod logs:
   ```bash
   kubectl logs -n tailscale -l app=operator
   ```

2. Verify OAuth credentials are correct in secrets

3. Check that `tag:k8s-operator` exists in your Tailnet ACL policy

### Connection Refused

1. Verify Traefik is running:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
   ```

2. Check LoadBalancer Service configuration:
   ```bash
   kubectl get svc traefik-tailscale -n kube-system -o yaml
   ```

3. Check if the service has a Tailscale IP assigned:
   ```bash
   kubectl get svc traefik-tailscale -n kube-system -o jsonpath='{.status.loadBalancer.ingress}'
   ```

### Wrong Device Name

If the operator device shows as generic `tailscale-operator` instead of `k8s-terje-tailscale-operator`:

1. Remove the deployment:
   ```bash
   ./uis shell
   cd /mnt/urbalurbadisk
   ansible-playbook ansible/playbooks/806-remove-tailscale-internal-ingress.yml \
     -e remove_operator=true
   ```

2. Redeploy - the Helm chart will use the templated operator config with the correct hostname

### Helm Chart Default Behavior

The Tailscale Helm chart has a default `operatorConfig.hostname: "tailscale-operator"`. Our Jinja2 template (`800-tailscale-operator-config.yaml.j2`) overrides this with `{{ TAILSCALE_OPERATOR_PREFIX }}-tailscale-operator` to give each cluster a unique name.

## See Also

- [networking-tailscale-setup.md](networking-tailscale-setup.md) - Funnel-based public internet access
- [Tailscale Kubernetes Operator documentation](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale Cluster Ingress documentation](https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress)
