# Troubleshooting Guide

**File**: `docs/troubleshooting-readme.md`
**Purpose**: Comprehensive troubleshooting guide for common issues and solutions
**Target Audience**: All users, developers, and administrators
**Last Updated**: September 22, 2024

## 📋 Overview

This guide covers common issues encountered in the Urbalurba Infrastructure platform and their solutions. Problems are organized by category to help you quickly find relevant troubleshooting steps.

## 🚀 Quick Diagnostic Commands

Before diving into specific issues, these commands help identify the problem area:

### Automated Debugging (Recommended)
```bash
# Complete cluster analysis (from provision-host)
./troubleshooting/debug-cluster.sh

# Service-specific debugging
./troubleshooting/debug-traefik.sh        # Ingress issues
./troubleshooting/debug-ai-litellm.sh     # AI platform issues
```

### Manual Commands
```bash
# Check overall cluster health
kubectl get nodes
kubectl get pods -A --field-selector=status.phase!=Running

# Check provision host
docker ps | grep provision-host
docker logs provision-host --tail=50

# Check ingress and services
kubectl get ingressroute -A
kubectl get svc -A

# Check storage
kubectl get pvc -A
kubectl get pv
```

## 🔧 Installation & Setup Issues

### Rancher Desktop Not Starting

**Symptoms**: Rancher Desktop fails to start or Kubernetes is not available

**Solutions**:
1. **Reset Rancher Desktop**:
   - Settings → Troubleshooting → Reset Kubernetes
   - Wait for complete reset, then restart

2. **Check system resources**:
   ```bash
   # Ensure sufficient memory (minimum 8GB recommended)
   free -h
   # Check disk space
   df -h
   ```

3. **Verify Docker context**:
   ```bash
   docker context list
   docker context use rancher-desktop
   ```

### Provision Host Container Issues

**Symptoms**: Cannot access provision-host or container not running

**Solutions**:
1. **Check container status**:
   ```bash
   docker ps | grep provision-host
   docker logs provision-host --tail=20
   ```

2. **Restart provision host**:
   ```bash
   docker stop provision-host
   docker start provision-host
   ```

3. **Volume mount issues**:
   ```bash
   # Verify mount point exists
   ls -la /mnt/urbalurbadisk/
   # Check Docker volume mounts
   docker inspect provision-host | grep Mounts -A 20
   ```

### Kubeconfig Issues

**Symptoms**: kubectl commands fail with connection errors

**Solutions**:
1. **Verify kubeconfig location**:
   ```bash
   echo $KUBECONFIG
   ls -la ~/.kube/config
   ```

2. **Test connection**:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

3. **Reset kubeconfig** (from provision-host):
   ```bash
   cp ~/.kube/config ~/.kube/config.backup
   # Re-run cluster connection setup
   ```

## 🏗️ Service Deployment Issues

### Pod Stuck in Pending State

**Symptoms**: Pods remain in Pending status

**Diagnosis**:
```bash
kubectl describe pod -n <namespace> <pod-name>
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp
```

**Common Causes & Solutions**:

1. **Resource constraints**:
   ```bash
   kubectl top nodes
   kubectl describe node
   ```

2. **Storage issues**:
   ```bash
   kubectl get pvc -A
   kubectl describe pvc -n <namespace> <pvc-name>
   ```

3. **Image pull problems**:
   ```bash
   # Check image availability
   docker pull <image-name>
   # Check image pull secrets
   kubectl get secrets -n <namespace>
   ```

### Pod CrashLoopBackOff

**Symptoms**: Pods continuously restart

**Diagnosis**:
```bash
kubectl logs -n <namespace> <pod-name> --previous
kubectl describe pod -n <namespace> <pod-name>
```

**Solutions**:
1. **Check application logs**:
   ```bash
   kubectl logs -n <namespace> <pod-name> -f
   ```

2. **Review resource limits**:
   ```bash
   kubectl get pod -n <namespace> <pod-name> -o yaml | grep -A 5 resources
   ```

3. **Inspect configuration**:
   ```bash
   kubectl get configmap -n <namespace>
   kubectl get secrets -n <namespace>
   ```

### Service Connection Issues

**Symptoms**: Services unreachable or timing out

**Diagnosis**:
```bash
kubectl get svc -A
kubectl get endpoints -n <namespace>
kubectl describe svc -n <namespace> <service-name>
```

**Solutions**:
1. **Test internal connectivity**:
   ```bash
   kubectl run test-pod --image=curlimages/curl -it --rm -- sh
   # From inside pod:
   curl <service-name>.<namespace>:port
   ```

2. **Check service selectors**:
   ```bash
   kubectl get pod -n <namespace> --show-labels
   kubectl describe svc -n <namespace> <service-name>
   ```

## 🌐 Networking & Ingress Issues

### Traefik Ingress Not Working

**Symptoms**: Services not accessible via ingress URLs

**Diagnosis**:
```bash
kubectl get ingressroute -A
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
kubectl describe ingressroute -n <namespace> <route-name>
```

**Solutions**:
1. **Verify IngressRoute configuration**:
   ```bash
   # Check host patterns and rules
   kubectl get ingressroute -n <namespace> <route-name> -o yaml
   ```

2. **Test Traefik dashboard**:
   ```bash
   kubectl port-forward -n kube-system svc/traefik 8080:8080
   # Access http://localhost:8080
   ```

3. **Check DNS resolution**:
   ```bash
   nslookup <service>.localhost
   # Should resolve to 127.0.0.1
   ```

### localhost Domain Issues

**Symptoms**: `http://service.localhost` not accessible

**Solutions**:
1. **Check /etc/hosts** (macOS/Linux):
   ```bash
   cat /etc/hosts | grep localhost
   # Should include: 127.0.0.1 localhost
   ```

2. **Verify port forwarding**:
   ```bash
   kubectl get svc -n kube-system traefik
   # Should show ports 80:xxxxx and 443:xxxxx
   ```

3. **Test with IP directly**:
   ```bash
   curl -H "Host: service.localhost" http://127.0.0.1/
   ```

## 🔐 Authentication Issues

### Authentik SSO Problems

**Symptoms**: Cannot access Authentik or authentication loops

**Diagnosis**:
```bash
kubectl logs -n authentik -l app.kubernetes.io/name=authentik
kubectl get pod -n authentik
kubectl describe ingressroute -n authentik authentik
```

**Solutions**:
1. **Reset Authentik password**:
   ```bash
   kubectl exec -n authentik <authentik-pod> -- ak create_admin_token
   ```

2. **Check Authentik configuration**:
   ```bash
   kubectl get configmap -n authentik authentik-config -o yaml
   ```

3. **Verify database connectivity**:
   ```bash
   kubectl logs -n authentik <authentik-pod> | grep -i database
   ```

### Forward Auth Middleware Issues

**Symptoms**: Protected services show authentication errors

**Diagnosis**:
```bash
kubectl get middleware -A
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep -i auth
```

**Solutions**:
1. **Check middleware configuration**:
   ```bash
   kubectl describe middleware -n <namespace> authentik-forward-auth
   ```

2. **Test whoami service**:
   ```bash
   # Should work: http://whoami-public.localhost
   # Should redirect: http://whoami.localhost
   ```

## 💾 Database Issues

### PostgreSQL Connection Problems

**Symptoms**: Applications cannot connect to PostgreSQL

**Diagnosis**:
```bash
kubectl logs -n postgresql -l app=postgresql
kubectl get svc -n postgresql
kubectl exec -n postgresql <postgres-pod> -- pg_isready
```

**Solutions**:
1. **Test database connection**:
   ```bash
   kubectl exec -n postgresql <postgres-pod> -- psql -U postgres -c "SELECT version();"
   ```

2. **Check connection limits**:
   ```bash
   kubectl exec -n postgresql <postgres-pod> -- psql -U postgres -c "SHOW max_connections;"
   kubectl exec -n postgresql <postgres-pod> -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
   ```

3. **Review configuration**:
   ```bash
   kubectl get configmap -n postgresql postgresql-config -o yaml
   ```

### Database Migration Issues

**Symptoms**: Applications report database schema problems

**Solutions**:
1. **Check migration logs**:
   ```bash
   kubectl logs -n <namespace> <app-pod> | grep -i migration
   ```

2. **Manual migration** (if needed):
   ```bash
   kubectl exec -it -n <namespace> <app-pod> -- <migration-command>
   ```

## 🤖 AI Platform Issues

### OpenWebUI Not Loading

**Symptoms**: OpenWebUI interface shows errors or won't load

**Diagnosis**:
```bash
kubectl logs -n openwebui -l app=openwebui
kubectl get svc -n openwebui
kubectl describe pod -n openwebui
```

**Solutions**:
1. **Check OpenWebUI configuration**:
   ```bash
   kubectl get configmap -n openwebui openwebui-config -o yaml
   ```

2. **Verify LiteLLM connectivity**:
   ```bash
   kubectl exec -n openwebui <openwebui-pod> -- curl http://litellm.litellm:4000/health
   ```

### LiteLLM API Issues

**Symptoms**: AI models not responding or API errors

**Diagnosis**:
```bash
kubectl logs -n litellm -l app=litellm
kubectl exec -n litellm <litellm-pod> -- curl http://localhost:4000/health
```

**Solutions**:
1. **Check API keys**:
   ```bash
   kubectl get secrets -n litellm litellm-secrets
   ```

2. **Test model availability**:
   ```bash
   kubectl exec -n litellm <litellm-pod> -- curl -X POST http://localhost:4000/v1/models
   ```

## 📊 Monitoring Issues

### Grafana Dashboard Problems

**Symptoms**: Grafana not accessible or missing data

**Diagnosis**:
```bash
kubectl logs -n grafana -l app.kubernetes.io/name=grafana
kubectl get svc -n grafana
```

**Solutions**:
1. **Reset Grafana admin password**:
   ```bash
   kubectl get secrets -n grafana grafana-admin-secret
   ```

2. **Check data sources**:
   ```bash
   # Access Grafana and verify Prometheus connection
   # URL: http://grafana.localhost
   ```

## ☁️ Cloud Deployment Issues

### Azure AKS Connection Problems

**Symptoms**: Cannot connect to AKS cluster

**Solutions**:
1. **Update kubeconfig**:
   ```bash
   az aks get-credentials --resource-group <rg> --name <cluster>
   ```

2. **Check Azure CLI authentication**:
   ```bash
   az account show
   az aks list
   ```

### Tailscale VPN Issues

**Symptoms**: Cannot access remote hosts via Tailscale

**Solutions**:
1. **Check Tailscale status**:
   ```bash
   tailscale status
   tailscale ping <host>
   ```

2. **Restart Tailscale**:
   ```bash
   sudo systemctl restart tailscaled  # Linux
   # Or restart Tailscale app on macOS/Windows
   ```

## 🔄 Recovery Procedures

### Complete Cluster Reset

When multiple issues persist, a complete reset may be needed:

1. **Backup important data**:
   ```bash
   # Export important configurations
   kubectl get secrets -A -o yaml > secrets-backup.yaml
   kubectl get configmap -A -o yaml > configmaps-backup.yaml
   ```

2. **Reset Rancher Desktop**:
   - Settings → Troubleshooting → Reset Kubernetes
   - Wait for complete reset

3. **Restore provision-host**:
   ```bash
   # Restart provision-host container
   docker stop provision-host
   docker start provision-host
   ```

4. **Re-provision services**:
   ```bash
   docker exec -it provision-host bash
   cd /mnt/urbalurbadisk/
   ./provision-host/kubernetes/provision-kubernetes.sh
   ```

### Data Recovery

If persistent data is lost:

1. **Check persistent volumes**:
   ```bash
   kubectl get pv
   kubectl describe pv <volume-name>
   ```

2. **Restore from backups** (if available):
   ```bash
   # Restore database backups
   kubectl exec -i -n postgresql <postgres-pod> -- psql -U postgres < backup.sql
   ```

## 🆘 Getting Additional Help

### Log Collection

When reporting issues, include these logs:

```bash
# Cluster overview
kubectl get all -A > cluster-overview.txt

# Pod issues
kubectl describe pod -n <namespace> <pod-name> > pod-details.txt
kubectl logs -n <namespace> <pod-name> --previous > pod-logs.txt

# Events
kubectl get events -A --sort-by=.metadata.creationTimestamp > events.txt

# Provision host logs
docker logs provision-host > provision-host.log
```

### System Information

Include system details when requesting help:

```bash
# Kubernetes version
kubectl version

# Node information
kubectl get nodes -o wide

# Docker information
docker version
docker system info

# Host system
uname -a
df -h
free -h
```

## 🤖 Automated Debugging Scripts

The platform includes comprehensive debugging scripts in the `troubleshooting/` folder:

### Cluster-Wide Debugging

**`debug-cluster.sh`** - Complete cluster health analysis:
```bash
# Run from provision-host
./troubleshooting/debug-cluster.sh [namespace]
```

**Features**:
- Collects all resource information across namespaces
- Identifies unhealthy pods and retrieves their logs
- Analyzes resource usage and storage issues
- Generates timestamped output files with cleanup
- Provides actionable recommendations

**`export-cluster-status.sh`** - Full cluster snapshot:
```bash
# Export complete cluster configuration
./troubleshooting/export-cluster-status.sh [cluster-name]
```

**Creates**:
- Individual files for each Kubernetes resource type
- Compressed archive for easy sharing with support
- Version information for key services
- Complete cluster configuration snapshot

### Service-Specific Debugging

**Traefik Ingress** (`debug-traefik.sh`):
```bash
./troubleshooting/debug-traefik.sh
```
- IngressRoute and Middleware analysis
- Traefik pod and service diagnostics
- Custom resource validation
- Network connectivity checks

**AI Platform** (`debug-ai-litellm.sh`):
```bash
./troubleshooting/debug-ai-litellm.sh [namespace]
```
- LiteLLM configuration and API health
- Model availability and routing
- Secret and ConfigMap validation
- API connectivity testing

**Other Service Scripts**:
- `debug-ai-openwebui.sh` - OpenWebUI diagnostics
- `debug-ai-ollama-cluster.sh` - Ollama cluster debugging
- `debug-ai-qdrant.sh` - Vector database diagnostics
- `debug-redis.sh` - Redis connectivity and performance
- `debug-mongodb.sh` - MongoDB cluster analysis
- `debug-elasticsearch.sh` - Elasticsearch cluster health

### Using the Debug Scripts

1. **Access provision-host**:
   ```bash
   docker exec -it provision-host bash
   cd /mnt/urbalurbadisk/
   ```

2. **Run appropriate debug script**:
   ```bash
   # For general cluster issues
   ./troubleshooting/debug-cluster.sh

   # For specific service issues
   ./troubleshooting/debug-traefik.sh
   ./troubleshooting/debug-ai-litellm.sh
   ```

3. **Review generated output**:
   ```bash
   # Output saved to troubleshooting/output/
   ls troubleshooting/output/
   cat troubleshooting/output/debug-cluster-*.txt
   ```

### Debug Output Features

- **Timestamped files** - Each run creates uniquely named output
- **Automatic cleanup** - Keeps only the 3 most recent debug files
- **Structured sections** - Organized by problem area
- **Status tracking** - Success/failure indicators for each check
- **Log extraction** - Automatic collection from problematic pods
- **Recommendations** - Specific next steps based on findings

### Contact and Resources

- **📖 Documentation**: Start with the [documentation home](../index.md)
- **🏗️ Architecture**: Review the [system architecture](../getting-started/architecture.md)
- **🔧 Commands**: See the [UIS CLI reference](./uis-cli-reference.md)
- **🤖 Debug Scripts**: Use automated tools in `troubleshooting/` folder
- **🐛 Issues**: Report at GitHub repository issues

---

**💡 Remember**: Most issues can be resolved by checking logs, verifying configuration, and ensuring services are running. When in doubt, start with the automated debugging scripts or the basic diagnostic commands at the top of this guide.

