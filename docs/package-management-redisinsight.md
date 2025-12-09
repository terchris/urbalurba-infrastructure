# RedisInsight - Redis Database Administration Interface

**Web Interface**: Redis Management • Multi-Database Support • Memory Analysis • Performance Monitoring • CLI Integration • Data Visualization • Query Builder

**File**: `docs/package-management-redisinsight.md`
**Purpose**: Complete guide to RedisInsight deployment and configuration in Urbalurba infrastructure
**Target Audience**: Database administrators, developers needing Redis management tools, Redis users
**Last Updated**: September 23, 2024

## 📋 Overview

RedisInsight provides a **comprehensive web-based administration interface** for Redis databases in the Urbalurba infrastructure. It's designed as an optional management service that offers full Redis administration capabilities through a modern web interface.

**Key Features**:
- **Web-Based Interface**: Full-featured Redis administration via browser
- **Manual Redis Connection**: Configure connections to cluster Redis instances via web UI
- **Helm-Based Deployment**: Uses redisinsight/redisinsight chart for reliable deployment
- **First-Time Setup**: Create your own user account on initial access
- **DNS-Based Routing**: Accessible via `redisinsight.localhost` with multi-domain support
- **5GB Storage**: Persistent storage for connection configurations, query history, and user data
- **Production Ready**: Includes proper security context and resource limits

**Project Homepage**: [https://github.com/redis/RedisInsight](https://github.com/redis/RedisInsight)

## 🏗️ Architecture

### **Deployment Components**
```
RedisInsight Service Stack:
├── Helm Release (redisinsight/redisinsight with custom configuration)
├── Deployment (redisinsight container with security context)
├── Service (ClusterIP on port 5540)
├── IngressRoute (Traefik routing for redisinsight.localhost)
├── PersistentVolumeClaim (5GB storage)
├── urbalurba-secrets (Redis authentication credentials)
└── Pod (redisinsight container with web interface)
```

### **File Structure**
```
06-management/
└── not-in-use/                         # Inactive by default
    ├── 05-setup-redisinsight.sh        # Main deployment script
    └── 05-remove-redisinsight.sh       # Removal script

manifests/
├── 651-adm-redisinsight.yaml           # RedisInsight Helm configuration
└── 751-redisinsight-ingressroute.yaml  # Traefik routing configuration

ansible/playbooks/
├── 651-adm-redisinsight.yml            # Main deployment logic
└── 651-remove-redisinsight.yml         # Removal logic
```

## 🚀 Deployment

### **Service Activation**
RedisInsight is inactive by default. To activate and deploy:

```bash
# Move script from not-in-use to activate
cd provision-host/kubernetes/06-management/
mv not-in-use/05-setup-redisinsight.sh ./

# Deploy RedisInsight
./05-setup-redisinsight.sh rancher-desktop
```

### **Manual Deployment**
```bash
# Deploy to specific Kubernetes context
./05-setup-redisinsight.sh multipass-microk8s
./05-setup-redisinsight.sh azure-aks

# Direct Ansible playbook execution
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/651-adm-redisinsight.yml -e target_host=rancher-desktop
```

### **Prerequisites**
RedisInsight does not require pre-configured credentials. Redis connections are added manually through the web interface after deployment.

## ⚙️ Configuration

### **Helm Configuration**
RedisInsight uses the redisinsight/redisinsight Helm chart with comprehensive configuration:

```bash
# Deployment command (from Ansible playbook)
helm upgrade --install redisinsight redisinsight/redisinsight \
  -f manifests/651-adm-redisinsight.yaml \
  --set persistence.storageClassName="$STORAGE_CLASS_NAME" \
  --namespace default
```

### **Storage Configuration**
```yaml
# From manifests/651-adm-redisinsight.yaml
persistence:
  enabled: true
  accessMode: ReadWriteOnce
  size: 5Gi
  # storageClassName omitted for cross-platform compatibility
```

### **Security Configuration**
```yaml
# Security context for production deployment
podSecurityContext:
  fsGroup: 1001

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 1001
  runAsGroup: 1001
  allowPrivilegeEscalation: false
```

### **Network Configuration**
```yaml
# Traefik IngressRoute configuration
# From manifests/751-redisinsight-ingressroute.yaml
spec:
  entryPoints:
    - web
  routes:
    - match: HostRegexp(`redisinsight\..+`)
      kind: Rule
      services:
        - name: redisinsight
          port: 5540
```

## 🌐 Access & Usage

### **Web Interface Access**
```bash
# Primary access via DNS routing
http://redisinsight.localhost

# Port-forward access (alternative)
kubectl port-forward svc/redisinsight 8080:5540
# Then access: http://localhost:8080
```

### **First-Time Setup**
1. **Access RedisInsight**: Navigate to `http://redisinsight.localhost`
2. **Create Account**: RedisInsight will prompt you to create a user account
3. **Choose Credentials**: Enter your preferred username and password
4. **Account Storage**: Credentials are stored locally in RedisInsight's persistent storage

### **Adding Redis Database Connections**

After logging into RedisInsight, you need to manually add Redis database connections:

#### **Add Redis Connection (If Redis is deployed in cluster)**
1. Click **"Add Redis Database"**
2. Fill in connection details:
   - **Database Alias**: `redis-master.default.svc.cluster.local`
   - **Host**: `redis-master.default.svc.cluster.local`
   - **Port**: `6379`
   - **Username**: `default` (if Redis has authentication enabled)
   - **Password**: Get from urbalurba-secrets (see below)
   - **Timeout**: `30` seconds
3. Click **"Test Connection"** to verify
4. Click **"Add Redis Database"** to save

#### **Getting Redis Credentials**
Redis credentials are configured in `urbalurba-secrets` based on the secrets-templates:

```bash
# Get Redis password from urbalurba-secrets
kubectl get secret urbalurba-secrets -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d

# Get Redis host (should match connection host)
kubectl get secret urbalurba-secrets -o jsonpath='{.data.REDIS_HOST}' | base64 -d
```

**From secrets-templates configuration:**
- **REDIS_PASSWORD**: `SecretPassword1` (or your configured password)
- **REDIS_HOST**: `redis-master.default.svc.cluster.local`

**Note**: If Redis is deployed without authentication, the password field can be left empty in RedisInsight.

#### **Connection Settings Screenshot Reference**
Based on your screenshot, the connection form includes:
- **General Tab**: Database Alias, Host, Port, Username, Password, Timeout
- **Security Tab**: SSL/TLS configuration options
- **Decompression & Formatters Tab**: Data handling options
- **Select Logical Database**: Choose Redis database number (default: 0)
- **Force Standalone Connection**: For cluster bypass if needed

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=redisinsight

# Check service status
kubectl get svc redisinsight

# Check IngressRoute
kubectl get ingressroute redisinsight

# View RedisInsight logs
kubectl logs -l app.kubernetes.io/name=redisinsight
```

### **Connection Testing**
```bash
# Test HTTP response from within cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -w "HTTP_CODE:%{http_code}" http://redisinsight:5540/

# Test DNS routing
curl -H "Host: redisinsight.localhost" http://localhost/
```

### **RedisInsight Interface Testing**
1. **Login Test**: Access `http://redisinsight.localhost` and verify account creation/login
2. **Database Connection**: Add Redis server connection and test connectivity
3. **Data Operations**: Browse keys, execute commands, and verify functionality
4. **Memory Analysis**: Check memory usage and key distribution features

## 🛠️ Management Operations

### **Database Administration**
```bash
# Access RedisInsight web interface
open http://redisinsight.localhost

# Through RedisInsight UI:
# 1. Navigate to connected Redis database
# 2. Use Browser to explore keys and data structures
# 3. Use Workbench for command execution
# 4. Use Memory Analysis for optimization insights
```

### **Key Management**
Through RedisInsight web interface:
1. **Browser Tab**: Navigate and search Redis keys
2. **Key Details**: View key types, values, and TTL
3. **Edit Values**: Modify string, hash, list, set, and sorted set values
4. **Key Operations**: Delete, rename, and set expiration

### **Performance Monitoring**
Through RedisInsight web interface:
1. **Dashboard**: View real-time Redis metrics
2. **Memory Analysis**: Analyze memory usage patterns
3. **Slow Log**: Monitor slow-running commands
4. **Command Timeline**: Track command execution patterns

### **Advanced Operations**
```bash
# View RedisInsight configuration
kubectl exec -it deployment/redisinsight -- ls -la /data

# Check RedisInsight storage usage
kubectl exec -it deployment/redisinsight -- df -h /data

# View RedisInsight process status
kubectl exec -it deployment/redisinsight -- ps aux
```

### **Service Removal**
```bash
# Remove RedisInsight service completely
cd provision-host/kubernetes/06-management/not-in-use/
./05-remove-redisinsight.sh rancher-desktop

# Direct Ansible playbook removal
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/651-remove-redisinsight.yml -e target_host=rancher-desktop
```

**Removal Process**:
- Uninstalls RedisInsight Helm release
- Removes IngressRoute configuration
- Deletes persistent volume claims and data
- Waits for pods to terminate
- Preserves urbalurba-secrets and namespace structure

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=redisinsight
kubectl logs -l app.kubernetes.io/name=redisinsight

# Check storage issues
kubectl describe pvc -l app.kubernetes.io/name=redisinsight
```

**Cannot Access Web Interface**:
```bash
# Verify service endpoints
kubectl describe svc redisinsight
kubectl get endpoints redisinsight

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- \
  curl http://redisinsight.default.svc.cluster.local:5540/

# Check IngressRoute configuration
kubectl describe ingressroute redisinsight
```

**Cannot Connect to Redis**:
```bash
# Test Redis connectivity from RedisInsight pod
kubectl exec -it deployment/redisinsight -- \
  nc -zv redis-master.default.svc.cluster.local 6379

# Verify Redis is running
kubectl get pods -l app.kubernetes.io/name=redis
kubectl logs -l app.kubernetes.io/name=redis --tail=20

# Test Redis authentication
kubectl exec -it redis-master-0 -- redis-cli -a "$REDIS_PASSWORD" ping
```

**First-Time Setup Issues**:
```bash
# Check if RedisInsight data directory is writable
kubectl exec -it deployment/redisinsight -- ls -la /data

# Verify storage permissions
kubectl exec -it deployment/redisinsight -- id

# Check RedisInsight initialization logs
kubectl logs -l app.kubernetes.io/name=redisinsight --tail=50
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod -l app.kubernetes.io/name=redisinsight

# View detailed pod specifications
kubectl describe pod -l app.kubernetes.io/name=redisinsight

# Check storage performance
kubectl exec -it deployment/redisinsight -- iostat -x 1 3
```

**DNS Resolution Issues**:
```bash
# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup redisinsight.default.svc.cluster.local

# Verify IngressRoute host matching
kubectl get ingressroute redisinsight -o yaml | grep -A 5 "match:"

# Test with different domain patterns
curl -H "Host: redisinsight.localhost" http://127.0.0.1/
curl -H "Host: redisinsight.urbalurba.no" http://127.0.0.1/
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status regularly
2. **Storage Monitoring**: Monitor disk usage for connection data and query history
3. **Access Review**: Regularly review user accounts and Redis connections
4. **Connection Testing**: Verify Redis connectivity and performance

### **Backup Procedures**
```bash
# Backup RedisInsight configuration and user data
kubectl exec -it deployment/redisinsight -- \
  tar -czf /tmp/redisinsight-backup.tar.gz /data

# Copy backup to local system
kubectl cp deployment/redisinsight:/tmp/redisinsight-backup.tar.gz ./redisinsight-backup.tar.gz

# Backup Helm values
kubectl get configmap -l app.kubernetes.io/name=redisinsight -o yaml > redisinsight-config-backup.yaml
```

### **Updates and Upgrades**
```bash
# Update Helm repository
helm repo update redisinsight

# Check for chart updates
helm search repo redisinsight/redisinsight

# Upgrade RedisInsight (if new chart version available)
helm upgrade redisinsight redisinsight/redisinsight \
  -f manifests/651-adm-redisinsight.yaml \
  --set persistence.storageClassName="$STORAGE_CLASS_NAME"
```

### **Disaster Recovery**
```bash
# Restore RedisInsight configuration from backup
kubectl cp ./redisinsight-backup.tar.gz deployment/redisinsight:/tmp/
kubectl exec -it deployment/redisinsight -- \
  tar -xzf /tmp/redisinsight-backup.tar.gz -C /

# Restart RedisInsight to apply changes
kubectl rollout restart deployment/redisinsight
```


---

**💡 Key Insight**: RedisInsight provides a powerful web-based interface for Redis administration with first-time user setup and manual database connections. Unlike pgAdmin, RedisInsight requires users to manually configure Redis connections through the web interface, providing flexibility to connect to multiple Redis instances while maintaining security through manual credential entry.