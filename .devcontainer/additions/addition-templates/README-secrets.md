# Top Secret Folder

This folder stores **sensitive files for local development only**.

## ⚠️ CRITICAL: Never Commit These Files

- This folder is in `.gitignore` (double protection with local `.gitignore`)
- **NEVER** remove from `.gitignore`
- **NEVER** commit any files from this folder

## What to Store Here

### Kubernetes Credentials
- `.kube/config` - Kubernetes cluster access (see `.kube/README.md` for setup)


### API Keys & Tokens
- `env-vars/` - Environment variable files
- `api-keys.env` - API keys and tokens
- `secrets.env` - Environment-specific secrets

### Development Tools
- `.claude-code-env` - Claude Code configuration
- Personal configuration files


## Protection Mechanism

**Root `.gitignore`:**
```
.devcontainer.secrets/
```

This ensures the entire folder is never committed to version control.

**Local `.devcontainer.secrets/.gitignore`:**
```
*
```

Everything inside this folder is ignored - no exceptions.

## Container Networking

When accessing services running on your host machine from inside the devcontainer, use `host.docker.internal` instead of `localhost` or `127.0.0.1`.

Example:
- Host: `https://127.0.0.1:6443`
- Container: `https://host.docker.internal:6443`

This is especially important for Kubernetes configurations and local database connections.
