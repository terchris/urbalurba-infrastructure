# Devcontainer Extensions

This folder contains **project-specific** customizations that are shared with your team (committed to git).

**Note:** You typically don't need to edit the `.conf` files manually. Use `dev-setup` to install tools and manage services - it updates these files automatically.

## Files

| File | Purpose |
|------|---------|
| `enabled-tools.conf` | Tools to auto-install when container is created |
| `enabled-services.conf` | Services to auto-start when container starts |
| `project-installs.sh` | Custom project setup (npm install, database setup, etc.) |

## Quick Reference

### enabled-tools.conf

Add tool IDs (one per line) to auto-install them:

```bash
dev-python
dev-typescript
tool-kubernetes
```

Run `dev-setup` to see available tools and their IDs.

### enabled-services.conf

Add service IDs (one per line) to auto-start them:

```bash
service-nginx
service-otel
```

### project-installs.sh

Add your project-specific setup here. Runs after all tools are installed:

```bash
#!/bin/bash
cd /workspace
npm install
pip install -r requirements.txt
```

## More Information

- **Available tools:** See [website/docs/tools](../website/docs/tools/index.mdx)
- **Adding new tools:** See [docs/contributors/adding-tools.md](../docs/contributors/adding-tools.md)
- **System architecture:** See [docs/contributors/architecture.md](../docs/contributors/architecture.md)
