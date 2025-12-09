# Documentation Guide

This guide explains how documentation works in Urbalurba Infrastructure and how to contribute to it.

## Documentation Architecture

Documentation is deployed to three environments automatically:

| Environment | URL | Use Case |
|-------------|-----|----------|
| **Local Development** | `http://127.0.0.1:8000` | Live editing with instant preview |
| **GitHub Pages** | `https://terchris.github.io/urbalurba-infrastructure/` | Public documentation |
| **In-Cluster** | `http://localhost/docs/` | Documentation within K8s cluster |

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         docs/ folder                                │
│                    (Markdown source files)                          │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         mkdocs.yml                                  │
│                  (Navigation & theme config)                        │
└─────────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  mkdocs serve │      │ GitHub Action │      │ provision-host│
│  (local dev)  │      │ (on push)     │      │ (cluster)     │
└───────────────┘      └───────────────┘      └───────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│ localhost:8000│      │ GitHub Pages  │      │ nginx /docs/  │
└───────────────┘      └───────────────┘      └───────────────┘
```

## Writing Documentation

### Local Development Workflow

1. **Start the local server**:
   ```bash
   cd urbalurba-infrastructure
   mkdocs serve
   ```

2. **Open browser** at `http://127.0.0.1:8000`

3. **Edit markdown files** in `docs/` - changes appear instantly

4. **Commit and push** when ready - GitHub Pages updates automatically

### Prerequisites

Install MkDocs with Material theme locally:

```bash
pip install mkdocs-material
```

### File Naming Conventions

Documentation files follow a naming pattern:

| Pattern | Example | Description |
|---------|---------|-------------|
| `package-{category}-{name}.md` | `package-ai-litellm.md` | Service documentation |
| `hosts-{platform}.md` | `hosts-rancher-kubernetes.md` | Platform guides |
| `rules-{topic}.md` | `rules-git-workflow.md` | Standards and conventions |
| `networking-{topic}.md` | `networking-tailscale-setup.md` | Network configuration |
| `overview-{topic}.md` | `overview-getting-started.md` | Getting started guides |
| `troubleshooting-{topic}.md` | `troubleshooting-readme.md` | Problem solving |

### Adding a New Document

1. **Create the markdown file** in `docs/`:
   ```bash
   touch docs/package-databases-newdb.md
   ```

2. **Add to navigation** in `mkdocs.yml`:
   ```yaml
   nav:
     - Packages:
       - Databases:
         - NewDB: package-databases-newdb.md
   ```

3. **Write content** using the template below

4. **Preview locally** with `mkdocs serve`

5. **Commit and push** to deploy

### Document Template

```markdown
# Service Name

Brief description of what this service does and why it's included.

## Overview

- **Purpose**: What problem does it solve?
- **Port**: Internal port number
- **Namespace**: Kubernetes namespace (usually `default`)

## Quick Start

```bash
# How to access or test the service
kubectl port-forward svc/service-name 8080:80
```

## Configuration

Explain key configuration options.

## Troubleshooting

Common issues and solutions.

## Related Documentation

- [Related Service](package-category-related.md)
```

## Markdown Features

MkDocs Material supports rich formatting:

### Admonitions (Callout Boxes)

```markdown
!!! note "Optional Title"
    This is a note callout.

!!! warning
    This is a warning without a custom title.

!!! tip "Pro Tip"
    Helpful tips go here.

!!! danger "Critical"
    Important warnings about destructive operations.
```

### Code Blocks with Syntax Highlighting

````markdown
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: example
```

```bash
kubectl apply -f manifest.yaml
```

```python
def hello():
    print("Hello, World!")
```
````

### Tabs

```markdown
=== "Rancher Desktop"
    Instructions for Rancher Desktop users.

=== "Azure AKS"
    Instructions for Azure AKS users.

=== "MicroK8s"
    Instructions for MicroK8s users.
```

### Tables

```markdown
| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Value 1  | Value 2  | Value 3  |
```

### Links

```markdown
[Link to another doc](package-ai-litellm.md)
[External link](https://example.com)
```

## Technical Details

### GitHub Pages Deployment

The `.github/workflows/docs.yml` workflow:

- Triggers on push to `main` when `docs/` or `mkdocs.yml` changes
- Installs `mkdocs-material` (includes built-in tags plugin)
- Runs `mkdocs gh-deploy --force`
- Publishes to `gh-pages` branch

### In-Cluster Deployment

During cluster provisioning:

1. **`provision-host-05-builddocs.sh`** runs `mkdocs build`
2. Output goes to `testdata/docs/`
3. **`020-setup-web-files.yml`** copies docs to nginx PVC
4. Nginx serves documentation at `/docs/` path

To manually rebuild docs in the cluster:

```bash
# Inside provision-host container
cd /mnt/urbalurbadisk
./provision-host/provision-host-05-builddocs.sh

# Then re-run the nginx setup
cd ansible
ansible-playbook playbooks/020-setup-nginx.yml
```

### Configuration Files

| File | Purpose |
|------|---------|
| `mkdocs.yml` | Site name, theme, navigation, plugins |
| `docs/index.md` | Homepage content |
| `.github/workflows/docs.yml` | GitHub Pages deployment |
| `provision-host/provision-host-05-builddocs.sh` | In-cluster build script |

## Best Practices

### Content Guidelines

1. **Be concise** - Get to the point quickly
2. **Use examples** - Show, don't just tell
3. **Include troubleshooting** - Anticipate common problems
4. **Link related docs** - Help users navigate
5. **Keep current** - Update when code changes

### Structure Guidelines

1. **Start with overview** - What is this? Why use it?
2. **Quick start first** - Let users try it immediately
3. **Details after** - Deep dive for those who need it
4. **Troubleshooting last** - Problem solving at the end

### Technical Writing Tips

- Use active voice: "Run the command" not "The command should be run"
- Use present tense: "This creates" not "This will create"
- Be specific: "Port 5432" not "the default port"
- Use consistent terminology throughout

## Troubleshooting

### Local Preview Not Working

```bash
# Check if mkdocs is installed
mkdocs --version

# Install if missing
pip install mkdocs-material
```

### GitHub Pages Not Updating

1. Check GitHub Actions tab for failed workflows
2. Verify changes are in `docs/` or `mkdocs.yml`
3. Ensure push is to `main` branch

### In-Cluster Docs Missing

```bash
# Check if docs were built
ls /mnt/urbalurbadisk/testdata/docs/

# Rebuild if needed
./provision-host/provision-host-05-builddocs.sh

# Re-deploy nginx content
ansible-playbook playbooks/020-setup-nginx.yml
```

### Navigation Not Showing New Page

Ensure the file is added to `nav:` section in `mkdocs.yml`:

```yaml
nav:
  - Section:
    - Page Title: filename.md  # Add this line
```
