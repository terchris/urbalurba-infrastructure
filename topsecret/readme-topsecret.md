# Kubernetes Secrets Management

This directory contains scripts and configuration for managing secrets across different Kubernetes clusters.

## Directory Structure

```
topsecret/
├── kubeconf-copy2local.sh              # Script to copy kubeconfig to local machine
├── kubernetes/
│   ├── kubeconf-all                    # Merged kubeconfig file for all clusters (not in Git)
│   ├── kubernetes-secrets-template.yml # Template for Kubernetes secrets
│   └── kubernetes-secrets.yml          # Actual secrets file (not in Git)
├── readme-topsecret.md                 # This documentation file
├── update-kubernetes-secrets-rancher.sh # Script for initial setup of secrets on provision-host in Docker
└── update-kubernetes-secrets-v2.sh     # Script for pushing secrets to Kubernetes clusters
```

## Setting Up Secrets

### 1. Creating Your Secrets File

The secrets are stored in a Kubernetes Secret resource named `urbalurba-secrets` in the `default` namespace.

To set up your secrets:

```bash
cd topsecret
cp ./kubernetes/kubernetes-secrets-template.yml ./kubernetes/kubernetes-secrets.yml
```

Edit `kubernetes-secrets.yml` and add your secret values. This file should **never** be committed to Git (it's already in .gitignore).

### 2. Applying Secrets to Clusters

Use the update scripts to apply secrets to different Kubernetes clusters:

```bash
# Push secrets to the default cluster (from merged kubeconfig)
./update-kubernetes-secrets-v2.sh

# Push secrets to a specific cluster
./update-kubernetes-secrets-v2.sh azure-microk8s

# Initial setup of secrets on the provision-host in Docker environment
./update-kubernetes-secrets-rancher.sh
```

### 3. Kubeconfig Management

The `kubeconf-all` file contains merged configurations for all your Kubernetes clusters. This file is used by the scripts to access the appropriate cluster.

To copy kubeconfig to your local machine:

```bash
./kubeconf-copy2local.sh
```

## Security Guidelines

1. **Never commit** the `kubernetes-secrets.yml` file to version control
2. Limit access to the `topsecret` directory to authorized personnel only
3. Consider using a secrets management tool (like HashiCorp Vault) for production environments
4. Rotate secrets regularly following security best practices
5. Use `kubectl get secret urbalurba-secrets -o yaml` to verify secrets are properly applied

## Accessing Secrets in Kubernetes

Once applied, secrets can be accessed in your Kubernetes resources:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
spec:
  containers:
  - name: example-container
    env:
    - name: SECRET_VALUE
      valueFrom:
        secretKeyRef:
          name: urbalurba-secrets
          key: YOUR_SECRET_KEY
```

## Troubleshooting

If you encounter issues with secrets:

1. Verify the secret exists: `kubectl get secret urbalurba-secrets`
2. Check your current context: `kubectl config current-context`
3. Ensure kubeconfig is properly configured: `kubectl config view`
4. Look for script execution errors in logs
5. Verify secret permissions in Kubernetes

## Additional Notes

- Both `kubeconf-all` and `kubernetes-secrets.yml` are excluded from Git to protect sensitive information
- The `update-kubernetes-secrets-v2.sh` script is the primary tool for deploying secrets to your clusters
- Always verify that secrets are properly applied before deploying applications that depend on them