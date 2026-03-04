# Rancher Desktop Integration

Rancher Desktop is the default Kubernetes provider for UIS. The provision host includes a compatibility layer so scripts written for MicroK8s also work on Rancher Desktop without modification.

## MicroK8s Compatibility Layer

### Context Aliasing
- **MicroK8s** uses `default` as the primary context
- **Rancher Desktop** uses `rancher-desktop` as the primary context
- UIS creates a `default` context alias pointing to the `rancher-desktop` cluster

### Storage Class Mapping
- **MicroK8s** uses `microk8s-hostpath` storage class
- **Rancher Desktop** uses `local-path` storage class
- UIS creates a `microk8s-hostpath` alias pointing to `local-path`

This is set up automatically when the provision host starts.

## Troubleshooting

### Context Issues

Check available contexts:

```bash
./uis shell
kubectl config get-contexts
```

Manually create default context if missing:

```bash
kubectl config set-context default --cluster=rancher-desktop --user=rancher-desktop
```

### Storage Class Issues

Verify the alias exists:

```bash
kubectl get storageclass microk8s-hostpath
```

## Related Documentation

- **[Rancher Desktop Host](../hosts/rancher-kubernetes.md)** — Full Rancher Desktop setup guide
- **[Provision Host Tools](../../contributors/architecture/tools.md)** — Tools available in the container
- **[Kubernetes Deployment](../../contributors/architecture/deploy-system.md)** — How services are deployed
