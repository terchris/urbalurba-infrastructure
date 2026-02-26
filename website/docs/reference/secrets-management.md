# Secrets Management System

## The Golden Rule

```
EDIT HERE:        .uis.secrets/secrets-config/           (your machine's values)
NEVER EDIT:       .uis.secrets/generated/                (auto-generated output)
```

## How It Works

```
Container image templates  →  secrets-config/  →  generated/kubernetes/kubernetes-secrets.yml
        ↑                          ↑                           ↑
  Shipped with image         EDIT THIS ONE               Final output
  ${VARIABLES}               Your actual values          Applied to cluster
  Updated on image upgrade   Machine-specific
```

**On first `./uis start`**, templates are copied to `.uis.secrets/secrets-config/` with development defaults.
**`./uis secrets generate`** reads `secrets-config/` and writes `generated/kubernetes/kubernetes-secrets.yml`.
**`./uis secrets apply`** runs `kubectl apply` to push secrets into the cluster.

## Quick Start

```bash
# 1. Edit your values
nano .uis.secrets/secrets-config/00-common-values.env.template

# 2. Generate Kubernetes secrets from your values
./uis secrets generate

# 3. Apply to cluster
./uis secrets apply
```

## File Structure

```
.uis.secrets/
├── secrets-config/                          # EDIT THIS (your values)
│   ├── 00-common-values.env.template        # All your credentials
│   ├── 00-master-secrets.yml.template       # Kubernetes YAML with ${VARIABLES}
│   └── configmaps/                          # Non-secret configuration
├── generated/                               # DO NOT EDIT (auto-generated)
│   ├── kubernetes/kubernetes-secrets.yml     # Final output for kubectl
│   ├── kubeconfig/                          # Cluster connection config
│   └── ubuntu-cloud-init/                   # VM provisioning
├── ssh/                                     # SSH keys for VM provisioning
├── service-keys/                            # Service-specific key files
├── api-keys/                                # API keys for external services
├── cloud-accounts/                          # Cloud provider credentials
├── network/                                 # Network configuration
└── README.md
```

| Directory | Edit? | Purpose |
|-----------|-------|---------|
| `secrets-config/` | **YES - Edit this** | Your machine's values |
| `generated/` | NO | Auto-generated output |
| `ssh/` | Generated once | SSH keys for VM provisioning |
| `service-keys/` | Optional | Service-specific key files |

## Common Tasks

### Change a password or value

```bash
# 1. Edit the value
nano .uis.secrets/secrets-config/00-common-values.env.template

# 2. Regenerate
./uis secrets generate

# 3. Apply to cluster
./uis secrets apply

# 4. Restart affected services to pick up new secrets
./uis undeploy postgresql
./uis deploy postgresql
```

### Check current secrets status

```bash
./uis secrets status
```

### Add a new secret variable

New variables are added by updating the container image. When a new image version adds variables to the master template, `./uis start` automatically syncs the updated `00-master-secrets.yml.template` to your `secrets-config/`. Your existing values in `00-common-values.env.template` are preserved.

To add a custom variable:

```bash
# 1. Add the variable to your common values
nano .uis.secrets/secrets-config/00-common-values.env.template

# 2. Add ${VARIABLE} reference in the master template
nano .uis.secrets/secrets-config/00-master-secrets.yml.template

# 3. Regenerate
./uis secrets generate
```

### Reset to defaults

```bash
# Remove your config (next ./uis start will recreate with defaults)
rm .uis.secrets/secrets-config/00-common-values.env.template

# Restart container to regenerate
./uis stop
./uis start
```

## Development Defaults

On first run, UIS sets development-friendly defaults so services work immediately:

| Variable | Default Value | Used By |
|----------|---------------|---------|
| `DEFAULT_ADMIN_EMAIL` | `admin@example.com` | All admin accounts |
| `DEFAULT_ADMIN_PASSWORD` | `LocalDev123` | All admin accounts |
| `DEFAULT_DATABASE_PASSWORD` | `LocalDevDB456` | PostgreSQL, MySQL, MongoDB |

> **Password restriction:** Do NOT use `!`, `$`, `` ` ``, `\`, or `"` in passwords.
> Bitnami Helm charts pass passwords through bash during container initialization,
> which escapes these characters and causes authentication failures.

## Multi-Machine Setup

Each machine has its own `secrets-config/` with machine-specific values:

```bash
# MacBook secrets-config/00-common-values.env.template
TAILSCALE_OPERATOR_PREFIX=k8s-terje

# iMac secrets-config/00-common-values.env.template
TAILSCALE_OPERATOR_PREFIX=k8s-imac
```

**Important**: `secrets-config/` is never committed to git and must be maintained separately on each machine.

## Variable Substitution

Central values in `secrets-config/00-common-values.env.template`:
```bash
DEFAULT_DATABASE_PASSWORD=YourSecurePassword123
DEFAULT_ADMIN_EMAIL=admin@yourcompany.com
```

Referenced in `00-master-secrets.yml.template`:
```yaml
PGPASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
AUTHENTIK_BOOTSTRAP_EMAIL: "${DEFAULT_ADMIN_EMAIL}"
```

`./uis secrets generate` uses `envsubst` to replace `${VARIABLES}` with your actual values.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Changes not appearing in cluster | Did you run `./uis secrets generate` then `./uis secrets apply`? |
| Service still uses old password | Restart the service: `./uis undeploy <service>` then `./uis deploy <service>` |
| Variable not substituted | Check spelling in `secrets-config/00-common-values.env.template` |
| Template missing after image update | Run `./uis stop` then `./uis start` to sync new templates |

## Quick Reference

| Command | Description |
|---------|-------------|
| `./uis secrets status` | Show current secrets configuration |
| `./uis secrets generate` | Regenerate secrets from templates |
| `./uis secrets apply` | Apply secrets to Kubernetes cluster |
| `./uis secrets edit` | Open secrets config in editor |

## Safety Rules

**DO:**
- Edit files in `secrets-config/`
- Run `./uis secrets generate` after changes
- Run `./uis secrets apply` to push to cluster
- Restart services after changing their secrets

**DON'T:**
- Edit files in `generated/`
- Put actual secret values in the container image templates
- Commit `.uis.secrets/` to git

## Related Docs

- [Secrets Management Rules](../rules/secrets-management.md) - Detailed rules and patterns
