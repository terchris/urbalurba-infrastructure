# UIS Secrets Directory

This directory contains your secrets and credentials. It is automatically added to `.gitignore`.

## How Passwords Work

UIS uses a **template-based secrets system**:

1. **Templates** in `secrets-config/` define all your credentials
2. **Generate** creates Kubernetes secrets from templates
3. **Apply** deploys secrets to your cluster

### Development Defaults (Zero-Friction Start)

On first run, UIS automatically sets development-friendly defaults:

| Variable | Default Value | Used By |
|----------|---------------|---------|
| `DEFAULT_ADMIN_EMAIL` | `admin@localhost` | All admin accounts |
| `DEFAULT_ADMIN_PASSWORD` | `LocalDev123!` | All admin accounts |
| `DEFAULT_DATABASE_PASSWORD` | `LocalDevDB456!` | PostgreSQL, MySQL, MongoDB |

**These defaults let you deploy services immediately without configuration.**

## Changing Passwords

### Step 1: Edit the common values file

```bash
nano .uis.secrets/secrets-config/00-common-values.env.template
```

Change these key variables:

```bash
# Change these to update ALL credentials at once:
DEFAULT_ADMIN_EMAIL=your-email@example.com
DEFAULT_ADMIN_PASSWORD=YourSecurePassword123!
DEFAULT_DATABASE_PASSWORD=YourSecureDatabasePassword456!
```

### Step 2: Regenerate secrets

```bash
./uis secrets generate
```

This creates a new `kubernetes-secrets.yml` from your templates.

### Step 3: Apply to cluster

```bash
./uis secrets apply
```

This deploys the updated secrets to Kubernetes.

### Step 4: Restart affected services

Services need to be restarted to pick up new secrets:

```bash
./uis undeploy postgresql
./uis deploy postgresql
```

## Directory Structure

| Directory | Description |
|-----------|-------------|
| `secrets-config/` | Template files - **edit these to change passwords** |
| `generated/kubernetes/` | Generated Kubernetes secrets (auto-created) |
| `ssh/` | SSH keys for VM provisioning |
| `api-keys/` | API keys for external services |

## Quick Reference

| Command | Description |
|---------|-------------|
| `./uis secrets status` | Show current secrets configuration |
| `./uis secrets generate` | Regenerate secrets from templates |
| `./uis secrets apply` | Apply secrets to Kubernetes cluster |

## Security Notes

- **Development**: The defaults are fine for local development
- **Production**: Always change `DEFAULT_ADMIN_PASSWORD` and `DEFAULT_DATABASE_PASSWORD`
- **Never commit** this directory to git (it's in `.gitignore`)
- **Backup** your `secrets-config/` files before major changes
