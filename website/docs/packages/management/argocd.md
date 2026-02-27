# ArgoCD - GitOps Continuous Delivery

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications from Git repositories to your Kubernetes cluster, ensuring that the cluster state matches the desired state defined in Git.

## Overview

ArgoCD provides:
- **GitOps Workflow**: Git as the single source of truth for deployments
- **Automated Sync**: Automatically sync applications when Git changes
- **Rollback Support**: Easy rollback to any previous Git commit
- **Health Monitoring**: Real-time application health status
- **Web UI**: GUI for monitoring and managing applications

## Quick Start

### Deploy ArgoCD

```bash
uis deploy argocd
```

### Register an Application

```bash
uis argocd register urb-dev-typescript-hello-world
```

This will:
1. Verify the repository exists and has a `manifests/` directory
2. Create a namespace for the application
3. Register it with ArgoCD for automatic deployment
4. Wait for the application to be synced and healthy

### Access Your Application

- **Local**: `http://urb-dev-typescript-hello-world.localhost`
- **External**: `https://urb-dev-typescript-hello-world.urbalurba.no` (when Cloudflare tunnel configured)

## Access Information

### Web Interface
- **Local**: http://argocd.localhost
- **External**: https://argocd.urbalurba.no (when Cloudflare tunnel configured)

### Login Credentials
- **Username**: `admin`
- **Password**: Configured in secrets (DEFAULT_ADMIN_PASSWORD)
- **Quick Check**:
  ```bash
  kubectl get secret urbalurba-secrets -n argocd -o jsonpath='{.data.ARGOCD_ADMIN_PASSWORD}' | base64 -d
  ```

## CLI Commands

### ArgoCD Server Management

```bash
uis deploy argocd        # Deploy ArgoCD server
uis undeploy argocd      # Remove ArgoCD server
uis argocd verify        # Run E2E health checks (API, login, UI, auth)
uis verify argocd        # Same as above (alias)
```

### Application Management

```bash
uis argocd register <repo_name>   # Register a GitHub repo as ArgoCD app
uis argocd remove <repo_name>     # Remove an ArgoCD-managed app
uis argocd list                   # List all registered applications
```

### Register Details

`uis argocd register` performs pre-flight checks before creating any resources:

1. **Repo check**: Verifies the GitHub repository exists and is accessible
2. **Manifests check**: Verifies a `manifests/` directory exists in the repo
3. **Deploy**: Creates namespace, credentials secret (private repos only), and ArgoCD Application
4. **Wait**: Monitors sync and health status until the app is running

If deployment fails after resources are created (e.g., broken image), the playbook automatically cleans up all created resources.

**Public repos** work without a GitHub token configured. Private repos require `GITHUB_ACCESS_TOKEN` in secrets.

### Remove Details

`uis argocd remove` cleanly removes:
- The ArgoCD Application resource
- The GitHub credentials secret
- The application namespace and all its resources

## GitOps Workflow

### How It Works

1. **Code Push**: Developer pushes code to GitHub
2. **CI/CD Pipeline**: GitHub Actions builds and pushes container image, updates manifest with new image tag
3. **ArgoCD Sync**: ArgoCD detects the manifest change in Git
4. **Deployment**: ArgoCD applies the updated Kubernetes manifests to the cluster
5. **Health Check**: ArgoCD monitors application health

The image tag in manifests is always explicit (e.g., `ghcr.io/user/app:abc1234-20250416`). ArgoCD detects changes because CI/CD updates the tag in the manifest file. This is the correct GitOps pattern — Git is the single source of truth.

### CI/CD Workflow (GitHub Actions)

Each application repo includes a GitHub Actions workflow (`.github/workflows/urbalurba-build-and-push.yaml`) that closes the GitOps loop. The workflow is included in all [development templates](https://github.com/terchris/urbalurba-dev-templates).

**What the workflow does:**

1. **Triggers on push to `main`** — but ignores changes to `manifests/` (prevents infinite loops)
2. **Builds the application** — installs dependencies and compiles (language-specific)
3. **Generates a unique image tag** — combines short commit SHA + timestamp (e.g., `abc1234-20250416143022`)
4. **Builds and pushes the Docker image** — pushes to GitHub Container Registry (`ghcr.io`) with both the unique tag and `latest`
5. **Updates the Kubernetes manifest** — uses `sed` to replace the image tag in `manifests/deployment.yaml`
6. **Commits the manifest change** — pushes back to the repo with a `[ci-skip]` commit message

**Infinite loop prevention:**

The workflow has two safeguards to prevent triggering itself in a loop:

- `paths-ignore: ['manifests/**']` — the workflow doesn't trigger when only manifests change
- Author check — skips the manifest update step if the last commit was made by GitHub Actions

**Required permissions:**

```yaml
permissions:
  contents: write    # Push manifest updates back to the repo
  packages: write    # Push container images to ghcr.io
```

These permissions use the built-in `GITHUB_TOKEN` — no additional secrets are needed for public repos.

**Image tag format:**

```
ghcr.io/<github-username>/<repo-name>:<short-sha>-<timestamp>
```

Example: `ghcr.io/terchris/urb-dev-typescript-hello-world:a1b2c3d-20250416143022`

Every image gets a unique, traceable tag. The `latest` tag is also updated for convenience, but ArgoCD always uses the explicit tag from the manifest.

### Application Structure

Your repository must contain Kubernetes manifests in a `manifests/` directory:

```
your-repo/
├── app/               # Application source code
├── Dockerfile         # Container definition
├── manifests/         # Kubernetes manifests (required by ArgoCD)
│   ├── deployment.yaml      # Deployment + Service
│   ├── ingress.yaml         # Traefik IngressRoute for routing
│   └── kustomization.yaml   # Ties everything together
└── .github/
    └── workflows/
        └── urbalurba-build-and-push.yaml  # CI/CD: build image + update manifest
```

### Manifests Reference

The `manifests/` directory contains three files. All examples use the repo name as the application name — this is set automatically by the [development templates](https://github.com/terchris/urbalurba-dev-templates).

#### deployment.yaml — Deployment + Service

Contains both the Deployment (how to run the container) and the Service (how to expose it inside the cluster):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "my-app-deployment"
  labels:
    app: "my-app"
    owner: "your-github-username"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: "my-app"
  template:
    metadata:
      labels:
        app: "my-app"
    spec:
      containers:
        - name: "my-app"
          image: ghcr.io/your-github-username/my-app:abc1234-20250416
          ports:
            - containerPort: 3000
          resources:
            limits:
              cpu: "100m"
              memory: "128Mi"
            requests:
              cpu: "50m"
              memory: "64Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: "my-app-service"
spec:
  selector:
    app: "my-app"
  ports:
    - port: 80
      targetPort: 3000
```

Key points:
- The **image tag** is a specific commit hash (e.g., `abc1234-20250416`), not `latest`. GitHub Actions updates this tag when new images are built.
- The **Service** maps port 80 (external) to the container port (e.g., 3000 for Node.js).
- **Resource limits** prevent a single app from consuming all cluster resources.

#### ingress.yaml — Traefik IngressRoute

Uses `HostRegexp` so the app works across all domain suffixes (localhost, Cloudflare, Tailscale):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: "my-app-ingressroute"
  labels:
    app: "my-app"
    owner: "your-github-username"
spec:
  entryPoints:
    - web
  routes:
    - match: HostRegexp(`my-app\..+`)
      kind: Rule
      services:
        - name: "my-app-service"
          port: 80
```

Key points:
- `HostRegexp(`my-app\..+`)` matches **any domain suffix**: `my-app.localhost`, `my-app.urbalurba.no`, `my-app.your-tailnet.ts.net`
- The service name must match the Service defined in `deployment.yaml`
- Uses Traefik's `IngressRoute` CRD (not standard Kubernetes Ingress) for compatibility with the UIS routing setup

#### kustomization.yaml — Ties Everything Together

Tells ArgoCD which files to apply and adds common labels:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - ingress.yaml

commonLabels:
  app: "my-app"
  owner: "your-github-username"
  managed-by: argocd

commonAnnotations:
  description: "Deployed via Urbalurba infrastructure"
  repository: "https://github.com/your-github-username/my-app"
```

Key points:
- **resources** lists all manifest files — ArgoCD applies them in order
- **commonLabels** are added to all resources, making it easy to query with `kubectl get all -l app=my-app`
- **managed-by: argocd** identifies resources managed by ArgoCD

### Naming Convention

Everything derives from the repo name:

| Resource | Name |
|----------|------|
| Namespace | `my-app` |
| Deployment | `my-app-deployment` |
| Service | `my-app-service` |
| IngressRoute | `my-app-ingressroute` |
| Hostname | `my-app.localhost` / `my-app.urbalurba.no` |
| Container image | `ghcr.io/username/my-app:tag` |

When you create a repo from a [development template](https://github.com/terchris/urbalurba-dev-templates), all these names are set automatically based on your repo name.

## Integration with Development Templates

The development templates in [urbalurba-dev-templates](https://github.com/terchris/urbalurba-dev-templates) are pre-configured for ArgoCD deployment with the correct manifest structure and CI/CD workflows.

Supported languages:
- TypeScript/Node.js
- Python
- Java
- C#
- Go
- PHP
- React (Designsystemet)

## Architecture

### Components

- **ArgoCD Server**: API server and web UI
- **ArgoCD Repo Server**: Manages Git repositories
- **ArgoCD Application Controller**: Monitors applications and syncs state
- **ArgoCD Redis**: Cache layer for improved performance
- **ArgoCD ApplicationSet Controller**: Manages multiple applications

## Troubleshooting

### Run E2E Tests

```bash
uis argocd verify
```

This runs 4 tests: API health, admin login, UI access via Traefik, and wrong credentials rejection.

### Check ArgoCD Status
```bash
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl logs -f deployment/argocd-server -n argocd
```

### Common Issues

**Application Not Syncing**
- Run `uis argocd list` to check sync and health status
- Verify the repository has a `manifests/` directory
- Check the ArgoCD UI at http://argocd.localhost for detailed error messages

**Registration Fails at Pre-flight**
- "Repository not found": Check the repo name and your GitHub username in secrets
- "No manifests/ directory": The repo needs Kubernetes manifests in `manifests/`
- For private repos: Configure `GITHUB_ACCESS_TOKEN` in secrets

**Login Failed**
- Clear browser cache/cookies
- Verify password: `kubectl get secret urbalurba-secrets -n argocd -o jsonpath='{.data.ARGOCD_ADMIN_PASSWORD}' | base64 -d`

## Related Documentation

- [Development Templates](./package-development-templates.md) - Pre-configured application templates
- [DevContainer Toolbox](https://github.com/terchris/devcontainer-toolbox) - Development environment setup
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/) - Comprehensive ArgoCD documentation
