# ArgoCD - GitOps Continuous Delivery

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications from Git repositories to your Kubernetes cluster, ensuring that the cluster state matches the desired state defined in Git.

## Overview

ArgoCD provides:
- **GitOps Workflow**: Git as the single source of truth for deployments
- **Automated Sync**: Automatically sync applications when Git changes
- **Rollback Support**: Easy rollback to any previous Git commit
- **Multi-Cluster Support**: Manage applications across multiple clusters
- **Health Monitoring**: Real-time application health status
- **Web UI & CLI**: Both GUI and command-line interfaces

## Access Information

### Web Interface
- **Primary Access**: http://argocd.localhost
- **Port Forward Access**:
  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:80
  # Then access: http://localhost:8080
  ```
- **External Access**: https://argocd.urbalurba.no (when Cloudflare tunnel configured)

### Login Credentials
- **Username**: `admin`
- **Password**: `SecretPassword2` (same as DEFAULT_ADMIN_PASSWORD)
- **Quick Check**:
  ```bash
  kubectl get secret urbalurba-secrets -n argocd -o jsonpath='{.data.ARGOCD_ADMIN_PASSWORD}' | base64 -d
  ```

## Deployment Scripts

### Setup ArgoCD
```bash
cd provision-host/kubernetes/08-development/not-in-use
./02-setup-argocd.sh
```

### Remove ArgoCD
```bash
cd provision-host/kubernetes/08-development/not-in-use
./02-remove-argocd.sh
```

## Application Management

ArgoCD integrates with the development templates from the [urbalurba-dev-templates](https://github.com/terchris/urbalurba-dev-templates) repository.

### Register an Application

Register a GitHub repository with ArgoCD for automatic deployment:

```bash
# From provision-host container
cd /mnt/urbalurbadisk/scripts/argocd

GITHUB_USERNAME=your_username \
REPO_NAME=your_repo \
GITHUB_PAT=your_token \
./argocd-register-app.sh
```

This will:
1. Create a namespace with the repository name
2. Store GitHub credentials securely
3. Create an ArgoCD Application resource
4. Automatically sync and deploy the application
5. Monitor health status

### Remove an Application

Remove an application and clean up resources:

```bash
# From provision-host container
cd /mnt/urbalurbadisk/scripts/argocd

REPO_NAME=your_repo \
./argocd-remove-app.sh
```

This will:
1. Delete the ArgoCD Application
2. Remove GitHub credentials
3. Delete the namespace and all resources

## GitOps Workflow

### How It Works

1. **Code Push**: Developer pushes code to GitHub
2. **CI/CD Pipeline**: GitHub Actions builds and pushes container image
3. **ArgoCD Sync**: ArgoCD detects changes in the Git repository
4. **Deployment**: ArgoCD applies the Kubernetes manifests to the cluster
5. **Health Check**: ArgoCD monitors application health

### Application Structure

Your repository should contain Kubernetes manifests in one of these locations:
- Root directory
- `/k8s` directory
- `/manifests` directory
- `/deploy` directory

Example structure:
```
your-repo/
├── src/           # Application source code
├── Dockerfile     # Container definition
├── k8s/           # Kubernetes manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── .github/
    └── workflows/
        └── deploy.yml  # GitHub Actions workflow
```

## Integration with Development Templates

The development templates in [urbalurba-dev-templates](https://github.com/terchris/urbalurba-dev-templates) are pre-configured for ArgoCD deployment:

1. **Select Template**: Use `.devcontainer/dev/dev-template.sh` to choose a template
2. **Develop**: Write your code using the devcontainer toolbox
3. **Push**: Commit and push to GitHub
4. **Deploy**: ArgoCD automatically deploys your application

Supported languages:
- TypeScript/Node.js
- Python
- Java
- C#
- Go
- PHP

## Architecture

### Components

- **ArgoCD Server**: API server and web UI
- **ArgoCD Repo Server**: Manages Git repositories
- **ArgoCD Application Controller**: Monitors applications and syncs state
- **ArgoCD Redis**: Cache layer for improved performance
- **ArgoCD ApplicationSet Controller**: Manages multiple applications

### Security

- **Standardized Credentials**: Uses urbalurba-secrets for consistency
- **GitHub PAT Storage**: Secure storage of GitHub credentials
- **RBAC**: Role-based access control for multi-user environments
- **TLS**: HTTPS support for external access

## Troubleshooting

### Check ArgoCD Status
```bash
# Check pods
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd

# View logs
kubectl logs -f deployment/argocd-server -n argocd
```

### Common Issues

**Login Failed**
- Clear browser cache/cookies
- Use incognito/private window
- Verify password: `kubectl get secret urbalurba-secrets -n argocd -o jsonpath='{.data.ARGOCD_ADMIN_PASSWORD}' | base64 -d`

**Application Not Syncing**
- Check GitHub credentials are correct
- Verify repository structure has Kubernetes manifests
- Check ArgoCD Application status in web UI

**Port Forward Not Working**
- Ensure no other process is using the port
- Try a different port: `kubectl port-forward svc/argocd-server -n argocd 8081:80`

### Reset Admin Password
If you need to reset the admin password:

```bash
# Generate new bcrypt hash
echo "YourNewPassword" | htpasswd -niBC 10 admin | cut -d ':' -f 2

# Update secret (create a file with the hash)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  admin.password: "YOUR_BCRYPT_HASH_HERE"
  admin.passwordMtime: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

# Restart server
kubectl rollout restart deployment/argocd-server -n argocd
```

## Related Documentation

- [Development Templates](./package-development-templates.md) - Pre-configured application templates
- [DevContainer Toolbox](https://github.com/terchris/devcontainer-toolbox) - Development environment setup
- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/) - Comprehensive ArgoCD documentation

## Summary

ArgoCD provides GitOps-based continuous delivery for the Urbalurba Infrastructure, enabling:
- Automated deployments from Git repositories
- Consistent application state across environments
- Easy rollback and version control
- Integration with development templates for rapid prototyping
- Standardized credentials for novice-friendly access

The combination of ArgoCD with the development templates creates a complete CI/CD pipeline from development to deployment on your local Kubernetes cluster.