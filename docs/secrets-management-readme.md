# Secrets Management System

## The Golden Rule

```
EDIT HERE:        secrets-config/           (your machine's values)
NEVER EDIT:       secrets-generated/        (auto-generated output)
NEVER EDIT:       kubernetes/               (final output for kubectl)
```

## How It Works

```
secrets-templates/     →     secrets-config/     →     kubernetes-secrets.yml
     ↑                            ↑                           ↑
  Git tracked              EDIT THIS ONE               Final output
  ${VARIABLES}             Your actual values          kubectl apply this
  Team shared              Machine-specific
```

**The script reads from `secrets-config/` and writes to `kubernetes/kubernetes-secrets.yml`.**

## Quick Start

```bash
cd topsecret/

# 1. Edit your values (the SOURCE)
nano secrets-config/00-common-values.env.template

# 2. Generate the output
./create-kubernetes-secrets.sh

# 3. Apply to cluster
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

## File Structure

```
topsecret/
├── secrets-templates/              # Git tracked - base templates with ${VARIABLES}
├── secrets-config/                 # Gitignored - EDIT THIS (your values)
├── secrets-generated/              # Gitignored - DO NOT EDIT (temp files)
└── kubernetes/kubernetes-secrets.yml  # Gitignored - DO NOT EDIT (final output)
```

| Directory | Edit? | Git | Purpose |
|-----------|-------|-----|---------|
| `secrets-templates/` | Only for new variables | Tracked | Base templates for team |
| `secrets-config/` | **YES - Edit this** | Ignored | Your machine's values |
| `secrets-generated/` | NO | Ignored | Temporary processing |
| `kubernetes/` | NO | Ignored | Final output |

## Common Tasks

### Change a password or value
```bash
nano secrets-config/00-common-values.env.template
./create-kubernetes-secrets.sh
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

### Add a new secret variable
```bash
# 1. Add to base template (for team)
nano secrets-templates/00-master-secrets.yml.template

# 2. ALSO add to your config (script prioritizes secrets-config/)
nano secrets-config/00-master-secrets.yml.template

# 3. Regenerate
./create-kubernetes-secrets.sh
```

### Reset to defaults
```bash
rm -rf secrets-config/
./create-kubernetes-secrets.sh
```

### Sync with updated templates
```bash
# Check what's different
diff secrets-templates/00-master-secrets.yml.template secrets-config/00-master-secrets.yml.template

# Copy new template structure (preserves your values if you re-add them)
cp secrets-templates/00-master-secrets.yml.template secrets-config/
```

## Multi-Machine Setup

Each machine has its own `secrets-config/` with machine-specific values:

```bash
# MacBook secrets-config/00-common-values.env.template
TAILSCALE_INTERNAL_HOSTNAME=k8s-terje

# iMac secrets-config/00-common-values.env.template
TAILSCALE_INTERNAL_HOSTNAME=k8s-imac
```

**Important**: `secrets-config/` is gitignored and must be maintained separately on each machine.

## Variable Substitution

Central values in `secrets-config/00-common-values.env.template`:
```bash
DEFAULT_DATABASE_PASSWORD=YourSecurePassword123
DEFAULT_ADMIN_EMAIL=admin@yourcompany.com
```

Used in templates:
```yaml
PGPASSWORD: "${DEFAULT_DATABASE_PASSWORD}"
AUTHENTIK_BOOTSTRAP_EMAIL: "${DEFAULT_ADMIN_EMAIL}"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Changes not appearing | Did you edit `secrets-config/` (not `secrets-generated/`)? |
| New template variables missing | Copy updated template to `secrets-config/` |
| YAML validation failed | `kubectl apply --dry-run=client -f kubernetes/kubernetes-secrets.yml` |
| Variable not substituted | Check spelling in `secrets-config/00-common-values.env.template` |

## Safety Rules

**DO:**
- Edit files in `secrets-config/`
- Run `./create-kubernetes-secrets.sh` after changes
- Verify with `kubectl apply --dry-run=client`

**DON'T:**
- Edit files in `secrets-generated/` or `kubernetes/`
- Put actual secrets in `secrets-templates/`
- Commit anything from gitignored directories

## Related Docs

- [rules-secrets-management.md](./rules-secrets-management.md) - Detailed rules and patterns
- [hosts-cloud-init-secrets.md](./hosts-cloud-init-secrets.md) - SSH key setup
