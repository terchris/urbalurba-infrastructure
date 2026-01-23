# UIS Secrets Directory

This directory contains sensitive configuration that should NOT be committed to version control.

**IMPORTANT**: This directory is automatically added to `.gitignore`.

## Directory Structure

| Directory | Description |
|-----------|-------------|
| `secrets-config/` | Service-specific secrets configuration |
| `kubernetes/` | Kubernetes secrets manifests |
| `.kube/` | Kubernetes config (if not using system default) |
| `api-keys/` | API keys for external services |

## Usage

### Store API Keys

Create files in `api-keys/` for each service:

```bash
echo "sk-your-openai-key" > api-keys/openai-api-key
echo "your-anthropic-key" > api-keys/anthropic-api-key
```

### Service-Specific Secrets

Create YAML files in `secrets-config/` following the pattern `<service-id>-secrets.yaml`:

```yaml
# secrets-config/postgresql-secrets.yaml
database_password: "your-secure-password"
admin_password: "your-admin-password"
```

## Security

- Never commit this directory to git
- Use strong, unique passwords for each service
- Consider using a password manager
- Regularly rotate sensitive credentials
