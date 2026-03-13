# UIS Secrets Directory

This directory contains your secrets and credentials. It is automatically added to `.gitignore`.

## How Passwords Work

UIS uses a **template-based secrets system**:

1. **Templates** in `secrets-config/` define all your credentials
2. **Generate** creates Kubernetes secrets from templates
3. **Apply** deploys secrets to your cluster

### Development Defaults (Zero-Friction Start)

On first run, UIS automatically sets development-friendly defaults:

These defaults let you deploy services immediately without configuration.

To avoid drift, this README does not duplicate the literal default values.

Check these files instead:

- `provision-host/uis/templates/default-secrets.env` for the shipped built-in development defaults
- `.uis.secrets/secrets-config/00-common-values.env.template` for the active values on the current machine after initialization

If you have just started UIS and have not changed any secrets yet, you can use those development defaults to log in and explore the system.

Important rule:

- if you want to know what UIS ships with, check `default-secrets.env`
- if you want to know what this machine is actually using, check `.uis.secrets/secrets-config/00-common-values.env.template`

## Changing Passwords

### Step 1: Edit the common values file

```bash
nano .uis.secrets/secrets-config/00-common-values.env.template
```

Change these key variables:

```bash
# Change these to update ALL credentials at once:
DEFAULT_ADMIN_EMAIL=your-email@example.com
DEFAULT_ADMIN_PASSWORD=YourSecurePassword123
DEFAULT_DATABASE_PASSWORD=YourSecureDatabasePassword456
```

> **Password restriction:** Do NOT use `!`, `$`, `` ` ``, `\`, or `"` in passwords.
> Bitnami Helm charts pass passwords through bash during container initialization,
> which escapes these characters. For example, `Pass!` becomes `Pass\!` in the
> database, causing authentication failures.

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

## First Start Reminder

If a user starts UIS and has not changed anything yet, they need an easy way to discover the login credentials:

- start by checking `.uis.secrets/secrets-config/00-common-values.env.template`
- if needed, compare with `provision-host/uis/templates/default-secrets.env`
- if the files differ, the machine-local `.uis.secrets` file is the one that matters
