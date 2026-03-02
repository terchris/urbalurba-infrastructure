# Rancher Desktop

Rancher Desktop is the default Kubernetes environment for UIS. It provides a single-node Kubernetes cluster (k3s) with Docker on your laptop — no cloud account needed.

## Quick Start

1. Install [Rancher Desktop](https://rancherdesktop.io/) and enable Kubernetes
2. Download the `uis` script and start:

```bash
./uis start
./uis deploy postgresql
```

That's it. The provision host connects to Rancher Desktop's cluster automatically.

## Prerequisites

### Install Rancher Desktop

Download from [rancherdesktop.io](https://rancherdesktop.io/) and configure:

- **Kubernetes**: Enabled
- **Container runtime**: dockerd (moby)
- **Memory**: At least 8GB (16GB recommended for full stack)
- **CPU**: 4+ cores

Verify it's ready:

```bash
kubectl get nodes
```

You should see one node in `Ready` state.

### Linux: Enable Privileged Ports

On Linux, ports 80 and 443 require extra configuration for `*.localhost` URLs to work:

```bash
# Enable port 80/443 (temporary — until reboot)
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80

# Make permanent (survives reboot)
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.conf
```

Restart Rancher Desktop after running this.

## Cluster Configuration

| Setting | Value |
|---------|-------|
| **Cluster type** | Single-node (k3s) |
| **Ingress** | Traefik (built-in) |
| **Storage** | Local path provisioner |
| **Container runtime** | Docker (default) or containerd |
| **Service access** | `http://<service>.localhost` |

## Deploying Services

```bash
# Deploy individual services
./uis deploy grafana
./uis deploy postgresql

# Deploy a full package
./uis stack install observability

# List all services and their status
./uis list

# Remove a service
./uis undeploy grafana
```

## Service Access

All services are accessible in your browser via `*.localhost` URLs:

| Service | URL |
|---------|-----|
| Grafana | [http://grafana.localhost](http://grafana.localhost) |
| Prometheus | [http://prometheus.localhost](http://prometheus.localhost) |
| Authentik | [http://authentik.localhost](http://authentik.localhost) |
| OpenWebUI | [http://openwebui.localhost](http://openwebui.localhost) |
| pgAdmin | [http://pgadmin.localhost](http://pgadmin.localhost) |
| ArgoCD | [http://argocd.localhost](http://argocd.localhost) |

## Context Switching

If you manage multiple clusters, switch between them:

```bash
./uis shell
kubectl config use-context rancher-desktop   # Local development
kubectl config use-context azure-aks         # Cloud production
kubectl config current-context               # Verify current
```

## Factory Reset

To completely reset and start fresh:

:::warning
All data, configurations, and certificates will be permanently lost. If you manage multiple clusters, back up your kubeconfig first: `cp ~/.kube/config ~/.kube/config.backup`
:::

1. Open Rancher Desktop
2. Go to **Troubleshooting > Factory Reset**
3. Confirm — this deletes all data
4. Restart Rancher Desktop and enable Kubernetes
5. Re-run `./uis start` and deploy services

## Performance Tips

- Allocate at least **8GB RAM** for the full UIS stack (16GB recommended)
- Use **4+ CPU cores** for responsive performance
- Ensure **50GB+ free disk space** for container images and persistent volumes
- Close memory-intensive applications when running the full stack

## Related Documentation

- **[Hosts Overview](./index.md)** — All supported platforms
- **[Getting Started](../getting-started/overview.md)** — First steps with UIS
- **[Services Overview](../getting-started/services.md)** — Available services
