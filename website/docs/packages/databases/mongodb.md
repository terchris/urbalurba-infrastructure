# MongoDB Database - Optional NoSQL Database Service

**File**: `docs/package-databases-mongodb.md`
**Purpose**: Complete guide to MongoDB deployment and configuration in Urbalurba infrastructure
**Target Audience**: Database administrators, developers working with MongoDB and NoSQL applications
**Last Updated**: September 22, 2024

## 📋 Overview

MongoDB provides a NoSQL document database option in the Urbalurba infrastructure. It's designed as an optional service (located in `not-in-use/` folder) that can be activated when needed for applications requiring document-based storage, particularly for the Gravitee API Management platform.

**Key Features**:
- **Document Database**: Full MongoDB 8.0.5 compatibility with ARM64 support
- **Manifest-Based Deployment**: Uses direct Kubernetes manifests with StatefulSet
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Gravitee Integration**: Pre-configured for Gravitee API Management platform
- **Persistent Storage**: 8GB persistent volume with automatic user initialization
- **Easy Activation**: Move script from `not-in-use/` to activate service

TODO: mongodb was set up for gravitee. Change it so it is not coupled tight to gravitee


## 🏗️ Architecture

### **Deployment Components**
```
MongoDB Service Stack:
├── StatefulSet (mongo:8.0.5)
├── ConfigMap (mongod.conf configuration)
├── ConfigMap (user initialization script)
├── Service (ClusterIP on port 27017)
├── PersistentVolumeClaim (8GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (mongodb container)
```

### **File Structure**
```
02-databases/
└── not-in-use/                 # Inactive by default
    ├── 04-setup-mongodb.sh     # Main deployment script
    └── 04-remove-mongodb.sh    # Removal script

manifests/
└── 040-mongodb-config.yaml     # Complete MongoDB configuration

ansible/playbooks/
├── 040-setup-mongodb.yml       # Main deployment logic
└── 040-remove-database-mongodb.yml  # Removal logic
```

## 🚀 Deployment

### **Service Activation**
MongoDB is inactive by default. To activate:

```bash
# Move script from not-in-use to activate
cd provision-host/kubernetes/02-databases/
mv not-in-use/04-setup-mongodb.sh ./

# Deploy MongoDB
./04-setup-mongodb.sh rancher-desktop
```

### **Manual Deployment**
```bash
# Deploy to specific Kubernetes context
./04-setup-mongodb.sh multipass-microk8s
./04-setup-mongodb.sh azure-aks
```

### **Prerequisites**
Before deploying MongoDB, ensure the required secrets are configured in `urbalurba-secrets`:

- `MONGODB_ROOT_USER`: Root username for MongoDB admin
- `MONGODB_ROOT_PASSWORD`: Root password for MongoDB admin
- `GRAVITEE_MONGODB_DATABASE_USER`: Application user for Gravitee
- `GRAVITEE_MONGODB_DATABASE_PASSWORD`: Application password for Gravitee
- `GRAVITEE_MONGODB_DATABASE_NAME`: Database name for Gravitee (typically 'graviteedb')

## ⚙️ Configuration

### **StatefulSet Configuration**
MongoDB uses a StatefulSet deployment with ARM64-compatible image:

```yaml
# From manifests/040-mongodb-config.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  template:
    spec:
      containers:
      - name: mongodb
        image: mongo:8.0.5
        ports:
        - containerPort: 27017
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

### **Service Configuration**
```yaml
# MongoDB service
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  ports:
  - port: 27017
    targetPort: 27017
    protocol: TCP
  selector:
    app: mongodb
  type: ClusterIP
```

### **Custom MongoDB Configuration**
```yaml
# Custom mongod.conf configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
data:
  mongod.conf: |
    storage:
      dbPath: /data/db
    systemLog:
      destination: file
      path: /data/log/mongod.log
      logAppend: true
    net:
      port: 27017
      bindIp: 0.0.0.0
    security:
      authorization: enabled
```

### **User Initialization Script**
MongoDB automatically creates Gravitee users during startup:

```javascript
// From init script ConfigMap
db = db.getSiblingDB('admin');

const dbName = process.env.GRAVITEE_MONGODB_DATABASE_NAME || 'graviteedb';
const username = process.env.GRAVITEE_MONGODB_DATABASE_USER || 'gravitee_user';
const password = process.env.GRAVITEE_MONGODB_DATABASE_PASSWORD || 'gravitee';

db.createUser({
  user: username,
  pwd: password,
  roles: [
    { role: 'readWrite', db: dbName },
    { role: 'dbAdmin', db: dbName },
    { role: 'readWrite', db: 'admin' }
  ]
});
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app=mongodb

# Check StatefulSet status
kubectl get statefulset mongodb

# Check service status
kubectl get svc mongodb

# View MongoDB logs
kubectl logs -l app=mongodb
```

### **Database Connection Testing**
```bash
# Test connection from within cluster using mongosh
kubectl run mongodb-client --image=mongo:8.0.5 --rm -it --restart=Never -- \
  mongosh --host mongodb.default.svc.cluster.local --port 27017

# Check if MongoDB is ready (using root credentials)
kubectl exec -it mongodb-0 -- mongosh --quiet --eval "db.adminCommand('ping')"

# Test with authentication
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin
```

### **Automated Verification**
The deployment includes automated testing of database functionality:

```bash
# Run verification manually (check playbook for details)
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/040-setup-mongodb.yml -e kube_context=rancher-desktop
```

**Verification Process**:
1. Connects to MongoDB server using root credentials
2. Verifies Gravitee user creation and permissions
3. Tests database operations and connectivity
4. Validates initialization script execution
5. Creates test documents to verify functionality

## 🛠️ Management Operations

### **Database Administration**
```bash
# Access MongoDB shell with authentication
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin

# Switch to Gravitee database
kubectl exec -it mongodb-0 -- mongosh --username gravitee_user --password --authenticationDatabase admin graviteedb

# Show databases
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin --eval "show dbs"

# Show collections in graviteedb
kubectl exec -it mongodb-0 -- mongosh --username gravitee_user --password --authenticationDatabase admin graviteedb --eval "show collections"
```

### **Backup Operations**
```bash
# Create database backup using mongodump
kubectl exec mongodb-0 -- mongodump --authenticationDatabase admin --username root --password --out /tmp/backup

# Copy backup from pod to local machine
kubectl cp mongodb-0:/tmp/backup ./mongodb-backup

# Restore from backup using mongorestore
kubectl cp ./mongodb-backup mongodb-0:/tmp/restore
kubectl exec mongodb-0 -- mongorestore --authenticationDatabase admin --username root --password /tmp/restore
```

### **Service Removal**
```bash
# Remove MongoDB service
cd provision-host/kubernetes/02-databases/not-in-use/
./04-remove-mongodb.sh rancher-desktop
```

**Removal Process**:
- Removes MongoDB StatefulSet and pods
- Deletes MongoDB service
- Removes persistent volume claims and data
- Preserves urbalurba-secrets and namespace structure
- Provides complete cleanup verification

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod mongodb-0
kubectl logs mongodb-0

# Check StatefulSet status
kubectl describe statefulset mongodb

# Verify PVC is bound
kubectl get pvc mongodb-data-mongodb-0
kubectl describe pvc mongodb-data-mongodb-0
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc mongodb
kubectl get endpoints mongodb

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup mongodb.default.svc.cluster.local

# Check MongoDB logs for connection errors
kubectl logs mongodb-0 | grep -i error
```

**Authentication Problems**:
```bash
# Check if secrets are properly configured
kubectl get secret urbalurba-secrets -o yaml

# Verify secret keys exist
kubectl get secret urbalurba-secrets -o jsonpath='{.data}' | jq 'keys'

# Test root user authentication
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin --eval "db.runCommand({connectionStatus:1})"
```

**Initialization Issues**:
```bash
# Check if init script was executed
kubectl logs mongodb-0 | grep "initialization"

# Verify Gravitee user was created
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin --eval "db.getUsers()"

# Check if test collection exists
kubectl exec -it mongodb-0 -- mongosh --username gravitee_user --password --authenticationDatabase admin graviteedb --eval "db.test.find({})"
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod mongodb-0

# View MongoDB process status
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin --eval "db.serverStatus()"

# Check slow operations
kubectl exec -it mongodb-0 -- mongosh --username root --password --authenticationDatabase admin --eval "db.currentOp()"
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **Backup Schedule**: Implement regular database backups using mongodump
3. **Log Monitoring**: Monitor MongoDB logs for errors and performance issues
4. **Security Updates**: Update MongoDB image tags regularly

### **Backup Procedures**
```bash
# Full backup of all databases
kubectl exec mongodb-0 -- mongodump --authenticationDatabase admin --username root --password --out /tmp/full-backup

# Backup specific database (Gravitee)
kubectl exec mongodb-0 -- mongodump --authenticationDatabase admin --username gravitee_user --password --db graviteedb --out /tmp/gravitee-backup

# Backup with compression
kubectl exec mongodb-0 -- mongodump --authenticationDatabase admin --username root --password --gzip --out /tmp/compressed-backup
```

### **Disaster Recovery**
```bash
# Restore full backup
kubectl exec mongodb-0 -- mongorestore --authenticationDatabase admin --username root --password /tmp/full-backup

# Restore specific database
kubectl exec mongodb-0 -- mongorestore --authenticationDatabase admin --username root --password --db graviteedb /tmp/gravitee-backup/graviteedb

# Restore from compressed backup
kubectl exec mongodb-0 -- mongorestore --authenticationDatabase admin --username root --password --gzip /tmp/compressed-backup
```


### **Gravitee Integration**
1. **User Permissions**: Ensure Gravitee user has proper read/write access to graviteedb
2. **Connection String**: Use the format: `mongodb://gravitee_user:password@mongodb.default.svc.cluster.local:27017/graviteedb?authSource=admin`
3. **Database Monitoring**: Monitor Gravitee-specific collections for growth and performance
4. **Backup Coordination**: Coordinate MongoDB backups with Gravitee maintenance windows

---

**💡 Key Insight**: MongoDB serves as the document database backend for Gravitee API Management and other NoSQL applications in the Urbalurba infrastructure. It provides ARM64 compatibility and automated user provisioning for seamless integration with the platform.