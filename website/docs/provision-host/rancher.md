# Provision Host Rancher Desktop Guide

**File**: `docs/provision-host-rancher.md`
**Purpose**: Rancher Desktop specific setup and MicroK8s compatibility
**Target Audience**: Users migrating from MicroK8s or troubleshooting Rancher Desktop issues

## Overview

While Rancher Desktop is now the default Kubernetes provider, the provision host includes a compatibility layer for existing MicroK8s-based scripts and configurations. This guide covers Rancher Desktop specifics and migration considerations.

## MicroK8s Compatibility Layer

The provision host automatically creates compatibility aliases so existing MicroK8s scripts work without modification:

### Context Aliasing
- **MicroK8s**: Uses `default` as the primary context name
- **Rancher Desktop**: Uses `rancher-desktop` as the primary context
- **Compatibility**: Creates a `default` context alias pointing to the `rancher-desktop` cluster

### Storage Class Mapping
- **MicroK8s**: Uses `microk8s-hostpath` storage class
- **Rancher Desktop**: Uses `local-path` storage class
- **Compatibility**: Creates `microk8s-hostpath` alias pointing to `local-path`

This allows scripts written for MicroK8s to run unchanged on Rancher Desktop.

## Installation Process

The `./install-rancher.sh` script automatically handles Rancher Desktop setup. Key log messages to watch for:

### Successful Compatibility Setup
```
Creating 'default' context alias for rancher-desktop...
'default' context is correctly set up
```

```
storageclass.storage.k8s.io/microk8s-hostpath created
```

These confirm the compatibility layer is working.

## Troubleshooting

### Context Issues
Check available contexts: `kubectl config get-contexts`

Manually create default context if missing:
```bash
kubectl config set-context default --cluster=rancher-desktop --user=rancher-desktop
```

### Storage Class Issues
Verify the alias exists: `kubectl get storageclass microk8s-hostpath`

Create manually if missing:
```bash
kubectl apply -f /mnt/urbalurbadisk/manifests/000-storage-class-alias.yaml
```

---

**Related Documentation:**
- [Provision Host Tools Guide](provision-host-tools.md) - Complete tool reference
- [Provision Host Kubernetes Guide](provision-host-kubernetes.md) - Service deployment