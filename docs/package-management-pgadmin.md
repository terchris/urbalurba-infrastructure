# pgAdmin - PostgreSQL Database Administration Interface

**Web Interface**: PostgreSQL Management • Multi-Database Support • SQL Editor • Visual Query Builder • User Management • Backup/Restore • Performance Monitoring

**File**: `docs/package-management-pgadmin.md`
**Purpose**: Complete guide to pgAdmin deployment and configuration in Urbalurba infrastructure
**Target Audience**: Database administrators, developers needing database management tools, PostgreSQL users
**Last Updated**: September 23, 2024

## 📋 Overview

pgAdmin provides a **comprehensive web-based administration interface** for PostgreSQL databases in the Urbalurba infrastructure. It's designed as an optional management service that offers full database administration capabilities through a modern web interface.

**Key Features**:
- **Web-Based Interface**: Full-featured PostgreSQL administration via browser
- **Auto-Connected to PostgreSQL**: Pre-configured connection to cluster PostgreSQL instance
- **Helm-Based Deployment**: Uses runix/pgadmin4 chart for reliable deployment
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **DNS-Based Routing**: Accessible via `pgadmin.localhost` with multi-domain support
- **10GB Storage**: Persistent storage for query history, preferences, and configurations
- **Production Ready**: Includes proper security context and resource limits

## 🏗️ Architecture

### **Deployment Components**
```
pgAdmin Service Stack:
├── Helm Release (runix/pgadmin4 with custom configuration)
├── Deployment (pgadmin container with security context)
├── Service (ClusterIP on port 80)
├── IngressRoute (Traefik routing for pgadmin.localhost)
├── ConfigMap (PostgreSQL server definitions)
├── PersistentVolumeClaim (10GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (pgadmin4 container with auto-configured PostgreSQL connection)
```

### **File Structure**
```
06-management/
└── not-in-use/                    # Inactive by default
    ├── 03-setup-pgadmin.sh        # Main deployment script
    └── 03-remove-pgadmin.sh       # Removal script

manifests/
├── 641-adm-pgadmin.yaml           # pgAdmin Helm configuration
└── 741-pgadmin-ingressroute.yaml  # Traefik routing configuration

ansible/playbooks/
├── 641-adm-pgadmin.yml            # Main deployment logic
└── 641-remove-pgadmin.yml         # Removal logic
```

## 🚀 Deployment

### **Service Activation**
pgAdmin is inactive by default. To activate and deploy:

```bash
# Move script from not-in-use to activate
cd provision-host/kubernetes/06-management/
mv not-in-use/03-setup-pgadmin.sh ./

# Deploy pgAdmin
./03-setup-pgadmin.sh rancher-desktop
```

### **Manual Deployment**
```bash
# Deploy to specific Kubernetes context
./03-setup-pgadmin.sh multipass-microk8s
./03-setup-pgadmin.sh azure-aks

# Direct Ansible playbook execution
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/641-adm-pgadmin.yml -e target_host=rancher-desktop
```

### **Prerequisites**
Before deploying pgAdmin, ensure PostgreSQL is running and the required secrets are configured in `urbalurba-secrets`:

- `PGADMIN_DEFAULT_EMAIL`: pgAdmin login email address
- `PGADMIN_DEFAULT_PASSWORD`: pgAdmin login password

## ⚙️ Configuration

### **Helm Configuration**
pgAdmin uses the runix/pgadmin4 Helm chart with comprehensive configuration:

```bash
# Deployment command (from Ansible playbook)
helm install pgadmin runix/pgadmin4 \
  --namespace default \
  -f manifests/641-adm-pgadmin.yaml \
  --set env.email="$PGADMIN_USERNAME" \
  --set env.password="$PGADMIN_PASSWORD"
```

### **Auto-Connection Configuration**
pgAdmin is pre-configured to automatically connect to the cluster PostgreSQL instance:

```yaml
# From manifests/641-adm-pgadmin.yaml
serverDefinitions:
  enabled: true
  resourceType: ConfigMap
  servers:
    postgresql-server:
      Name: "PostgreSQL Database"
      Group: "Servers"
      Username: "postgres"
      Host: "postgresql.default.svc.cluster.local"
      Port: 5432
      SSLMode: "prefer"
      MaintenanceDB: "postgres"
      Comment: "Pre-configured PostgreSQL server connection"
```

### **Storage Configuration**
```yaml
# Persistent storage for pgAdmin data
persistentVolume:
  enabled: true
  size: 10Gi
```

### **Security Configuration**
```yaml
# Security context for production deployment
securityContext:
  runAsUser: 5050
  runAsGroup: 5050
  fsGroup: 5050

containerSecurityContext:
  allowPrivilegeEscalation: false
```

### **Network Configuration**
```yaml
# Traefik IngressRoute configuration
# From manifests/741-pgadmin-ingressroute.yaml
spec:
  entryPoints:
    - web
  routes:
    - match: HostRegexp(`pgadmin\..+`)
      kind: Rule
      services:
        - name: pgadmin-pgadmin4
          port: 80
```

## 🌐 Access & Usage

### **Web Interface Access**
```bash
# Primary access via DNS routing
http://pgadmin.localhost

# Port-forward access (alternative)
kubectl port-forward svc/pgadmin-pgadmin4 8080:80
# Then access: http://localhost:8080
```

### **Login Credentials**
Use the credentials configured in urbalurba-secrets:
- **Email**: Value from `PGADMIN_DEFAULT_EMAIL`
- **Password**: Value from `PGADMIN_DEFAULT_PASSWORD`

### **Database Connection**
pgAdmin comes pre-configured with a PostgreSQL server connection:
- **Server Name**: PostgreSQL Database
- **Host**: postgresql.default.svc.cluster.local
- **Port**: 5432
- **Username**: postgres
- **Database**: postgres (maintenance database)

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=pgadmin4

# Check service status
kubectl get svc pgadmin-pgadmin4

# Check IngressRoute
kubectl get ingressroute pgadmin

# View pgAdmin logs
kubectl logs -l app.kubernetes.io/name=pgadmin4
```

### **Connection Testing**
```bash
# Test HTTP response from within cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -w "HTTP_CODE:%{http_code}" http://pgadmin-pgadmin4:80/

# Test DNS routing
curl -H "Host: pgadmin.localhost" http://localhost/
```

### **pgAdmin Interface Testing**
1. **Login Test**: Access `http://pgadmin.localhost` and verify login
2. **Server Connection**: Check pre-configured PostgreSQL server connection
3. **Database Operations**: Create test database and verify functionality
4. **Query Editor**: Test SQL query execution and results display

## 🛠️ Management Operations

### **Database Administration**
```bash
# Access pgAdmin web interface
open http://pgadmin.localhost

# Create new database via pgAdmin UI:
# 1. Right-click "PostgreSQL Database" server
# 2. Create -> Database...
# 3. Enter database name and save
```

### **User Management**
Through pgAdmin web interface:
1. Navigate to Login/Group Roles
2. Right-click to create new roles
3. Configure permissions and database access
4. Set passwords and connection limits

### **Backup Operations**
Through pgAdmin web interface:
1. Right-click database
2. Select "Backup..."
3. Configure backup options
4. Download backup file

### **Advanced Operations**
```bash
# View pgAdmin configuration
kubectl exec -it deployment/pgadmin-pgadmin4 -- cat /pgadmin4/pgadmin4.db

# Check pgAdmin storage usage
kubectl exec -it deployment/pgadmin-pgadmin4 -- df -h /var/lib/pgadmin

# View pgAdmin process status
kubectl exec -it deployment/pgadmin-pgadmin4 -- ps aux
```

### **Service Removal**
```bash
# Remove pgAdmin service completely
cd provision-host/kubernetes/06-management/not-in-use/
./03-remove-pgadmin.sh rancher-desktop

# Direct Ansible playbook removal
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/641-remove-pgadmin.yml -e target_host=rancher-desktop
```

**Removal Process**:
- Uninstalls pgAdmin Helm release
- Removes IngressRoute configuration
- Deletes persistent volume claims and data
- Waits for pods to terminate
- Preserves urbalurba-secrets and namespace structure

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=pgadmin4
kubectl logs -l app.kubernetes.io/name=pgadmin4

# Check storage issues
kubectl describe pvc -l app.kubernetes.io/name=pgadmin4
```

**Cannot Access Web Interface**:
```bash
# Verify service endpoints
kubectl describe svc pgadmin-pgadmin4
kubectl get endpoints pgadmin-pgadmin4

# Test service connectivity
kubectl run test-pod --image=curlimages/curl --rm -it -- \
  curl http://pgadmin-pgadmin4.default.svc.cluster.local:80/misc/ping

# Check IngressRoute configuration
kubectl describe ingressroute pgadmin
```

**Login Issues**:
```bash
# Verify credentials in secrets
kubectl get secret urbalurba-secrets -o jsonpath='{.data.PGADMIN_DEFAULT_EMAIL}' | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath='{.data.PGADMIN_DEFAULT_PASSWORD}' | base64 -d

# Check pgAdmin configuration
kubectl exec -it deployment/pgadmin-pgadmin4 -- \
  grep -r "PGADMIN_DEFAULT_EMAIL" /etc/pgadmin/
```

**PostgreSQL Connection Issues**:
```bash
# Test PostgreSQL connectivity from pgAdmin pod
kubectl exec -it deployment/pgadmin-pgadmin4 -- \
  nc -zv postgresql.default.svc.cluster.local 5432

# Verify PostgreSQL is running
kubectl get pods -l app.kubernetes.io/name=postgresql
kubectl logs -l app.kubernetes.io/name=postgresql --tail=20

# Test PostgreSQL authentication
kubectl exec -it postgresql-0 -- psql -U postgres -c "SELECT version();"
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod -l app.kubernetes.io/name=pgadmin4

# View detailed pod specifications
kubectl describe pod -l app.kubernetes.io/name=pgadmin4

# Check storage performance
kubectl exec -it deployment/pgadmin-pgadmin4 -- iostat -x 1 3
```

**DNS Resolution Issues**:
```bash
# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup pgadmin-pgadmin4.default.svc.cluster.local

# Verify IngressRoute host matching
kubectl get ingressroute pgadmin -o yaml | grep -A 5 "match:"

# Test with different domain patterns
curl -H "Host: pgadmin.localhost" http://127.0.0.1/
curl -H "Host: pgadmin.urbalurba.no" http://127.0.0.1/
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status regularly
2. **Storage Monitoring**: Monitor disk usage for query history and configurations
3. **Access Review**: Regularly review user access and permissions
4. **Connection Testing**: Verify PostgreSQL connectivity and performance

### **Backup Procedures**
```bash
# Backup pgAdmin configuration and user data
kubectl exec -it deployment/pgadmin-pgadmin4 -- \
  tar -czf /tmp/pgadmin-backup.tar.gz /var/lib/pgadmin

# Copy backup to local system
kubectl cp deployment/pgadmin-pgadmin4:/tmp/pgadmin-backup.tar.gz ./pgadmin-backup.tar.gz

# Backup database configurations
kubectl get configmap -l app.kubernetes.io/name=pgadmin4 -o yaml > pgadmin-config-backup.yaml
```

### **Updates and Upgrades**
```bash
# Update Helm repository
helm repo update runix

# Check for chart updates
helm search repo runix/pgadmin4

# Upgrade pgAdmin (if new chart version available)
helm upgrade pgadmin runix/pgadmin4 \
  -f manifests/641-adm-pgadmin.yaml \
  --set env.email="$PGADMIN_USERNAME" \
  --set env.password="$PGADMIN_PASSWORD"
```

### **Disaster Recovery**
```bash
# Restore pgAdmin configuration from backup
kubectl cp ./pgadmin-backup.tar.gz deployment/pgadmin-pgadmin4:/tmp/
kubectl exec -it deployment/pgadmin-pgadmin4 -- \
  tar -xzf /tmp/pgadmin-backup.tar.gz -C /

# Restore ConfigMaps
kubectl apply -f pgadmin-config-backup.yaml

# Restart pgAdmin to apply changes
kubectl rollout restart deployment/pgadmin-pgadmin4
```

## 📚 Related Documentation

- **[package-databases-postgresql.md](./package-databases-postgresql.md)** - PostgreSQL database setup and configuration
- **[package-databases-postgresql-container.md](./package-databases-postgresql-container.md)** - PostgreSQL custom container details
- **[rules-ingress-traefik.md](./rules-ingress-traefik.md)** - Traefik IngressRoute configuration standards

---

**💡 Key Insight**: pgAdmin provides a powerful web-based interface for PostgreSQL administration with automatic server configuration and DNS-based routing. The pre-configured connection to the cluster PostgreSQL instance allows novice users to immediately start database administration without needing to know internal DNS names or connection details.