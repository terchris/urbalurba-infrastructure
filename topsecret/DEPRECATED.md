# Deprecated: topsecret/ Directory

> **This directory is deprecated.** The scripts and structure here have been replaced by the new UIS secrets management system.

## Why This Change?

The old `topsecret/` approach had several problems:

1. **Manual copying** - Required running scripts to sync secrets between host and container
2. **No structure** - All secrets in one large file, hard to manage
3. **Easy to lose** - Secrets could be lost if container was rebuilt without copying
4. **Not portable** - Path hardcoded, difficult to use in different environments

## New System: `.uis.secrets/`

The new system solves these problems:

1. **Direct mounts** - Secrets directory mounted directly into container, changes sync automatically
2. **Organized structure** - Separate files for different secret types
3. **Persistent** - Secrets stored on host, survive container rebuilds
4. **Portable** - Works the same way across different setups

## Migration Guide

### Step 1: Set Up New Structure

Run the UIS setup wizard:

```bash
./uis
```

This creates the new `.uis.secrets/` directory structure.

### Step 2: Move Your Secrets

The wizard will help migrate your existing secrets, or you can do it manually:

| Old Location | New Location |
|-------------|--------------|
| `topsecret/kubernetes/kubernetes-secrets.yml` | `.uis.secrets/generated/kubernetes/kubernetes-secrets.yml` |
| `secrets/id_rsa_ansible` | `.uis.secrets/ssh/id_rsa_ansible` |
| `secrets/id_rsa_ansible.pub` | `.uis.secrets/ssh/id_rsa_ansible.pub` |

### Step 3: Update Your Workflow

**Old workflow:**
```bash
# Edit secrets
nano topsecret/kubernetes/kubernetes-secrets.yml

# Copy to container
./copy2provisionhost.sh

# After changes in container, copy back
./topsecret/copy-secrets2host.sh
```

**New workflow:**
```bash
# Edit secrets (changes sync automatically)
nano .uis.secrets/generated/kubernetes/kubernetes-secrets.yml

# Apply to cluster
kubectl apply -f .uis.secrets/generated/kubernetes/kubernetes-secrets.yml

# No copying needed - changes are already on your host!
```

## Script Replacements

### `update-kubernetes-secrets-rancher.sh`

**Old:**
```bash
cd topsecret
./update-kubernetes-secrets-rancher.sh rancher-desktop
```

**New:**
```bash
kubectl apply -f .uis.secrets/generated/kubernetes/kubernetes-secrets.yml
```

Or from inside the container:
```bash
kubectl apply -f /mnt/urbalurbadisk/.uis.secrets/generated/kubernetes/kubernetes-secrets.yml
```

### `kubeconf-copy2local.sh`

**Old:**
```bash
cd topsecret
./kubeconf-copy2local.sh
```

**New:**
No replacement needed! Your `~/.kube` directory is mounted directly into the container. Kubeconfig changes sync automatically in both directions.

### `copy-secrets2host.sh`

**Old:**
```bash
./topsecret/copy-secrets2host.sh
```

**New:**
No replacement needed! The `.uis.secrets/` directory is mounted directly. Any changes made inside the container are immediately saved to your host.

## New Directory Structure

```
.uis.secrets/
├── ssh/
│   ├── id_rsa_ansible          # SSH private key
│   └── id_rsa_ansible.pub      # SSH public key
├── service-keys/
│   ├── tailscale.env           # Tailscale credentials
│   └── cloudflare.env          # Cloudflare credentials
├── cloud-accounts/
│   ├── azure-default.env       # Azure credentials
│   └── gcp-default.env         # GCP credentials
├── network/
│   └── wifi.env                # WiFi credentials (for Raspberry Pi)
└── generated/
    ├── kubernetes/
    │   └── kubernetes-secrets.yml
    ├── kubeconfig/
    │   └── kubeconf-all
    └── ubuntu-cloud-init/
        └── *.yml               # Generated cloud-init files
```

## Backwards Compatibility

The old `topsecret/` path will continue to work during the transition period:

- Scripts check for `.uis.secrets/` first, then fall back to `topsecret/`
- Deprecation warnings are shown when using old paths
- The `topsecret/` directory will be removed in a future release

## Questions?

If you have issues migrating, check:
- The UIS setup wizard: `./uis`
- Documentation: `docs/` directory
- Script help: `./uis --help`
