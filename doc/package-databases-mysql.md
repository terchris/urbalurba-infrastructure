# MySQL Database - Optional Database Service

**File**: `doc/package-databases-mysql.md`
**Purpose**: Complete guide to MySQL deployment and configuration in Urbalurba infrastructure
**Target Audience**: Database administrators, developers working with MySQL
**Last Updated**: September 22, 2024

## 📋 Overview

MySQL provides an alternative relational database option in the Urbalurba infrastructure. It's designed as an optional service (located in `not-in-use/` folder) that can be activated when needed for applications requiring MySQL-specific features or compatibility.

**Key Features**:
- **Standard SQL Database**: Full MySQL 8.x compatibility
- **Helm-Based Deployment**: Uses Bitnami MySQL chart for reliable deployment
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes CRUD verification and health checks
- **Easy Activation**: Move script from `not-in-use/` to activate service

## 🏗️ Architecture

### **Deployment Components**
```
MySQL Service Stack:
├── Helm Release (bitnami/mysql)
├── ConfigMap (custom MySQL configuration)
├── Service (ClusterIP on port 3306)
├── urbalurba-secrets (authentication credentials)
└── Pod (mysql container)
```

### **File Structure**
```
02-databases/
└── not-in-use/                 # Inactive by default
    ├── 06-setup-mysql.sh       # Main deployment script
    └── 06-remove-mysql.sh      # Removal script

manifests/
└── 043-database-mysql-config.yaml  # MySQL service and configuration

ansible/playbooks/
├── 040-database-mysql.yml      # Main deployment logic
├── 040-remove-database-mysql.yml   # Removal logic
└── utility/
    └── u08-verify-mysql.yml    # CRUD testing and verification
```

## 🚀 Deployment

### **Service Activation**
MySQL is inactive by default. To activate:

```bash
# Move script from not-in-use to activate
cd provision-host/kubernetes/02-databases/
mv not-in-use/06-setup-mysql.sh ./

# Deploy MySQL
./06-setup-mysql.sh rancher-desktop
```

### **Manual Deployment**
```bash
# Deploy to specific Kubernetes context
./06-setup-mysql.sh multipass-microk8s
./06-setup-mysql.sh azure-aks
```

### **Prerequisites**
Before deploying MySQL, ensure the required secrets are configured in `urbalurba-secrets`:

- `MYSQL_ROOT_PASSWORD`: Root user password
- `MYSQL_USER`: Application user name
- `MYSQL_PASSWORD`: Application user password
- `MYSQL_DATABASE`: Default database name
- `MYSQL_HOST`: Database host (typically service name)

## ⚙️ Configuration

### **Helm Configuration**
MySQL uses the Bitnami Helm chart with the following setup:

```bash
# Deployment command (from Ansible playbook)
helm install mysql bitnami/mysql \
  --namespace default \
  -f manifests/043-database-mysql-config.yaml \
  --set auth.rootPassword="$MYSQL_ROOT_PASSWORD" \
  --set auth.username="$MYSQL_USER" \
  --set auth.password="$MYSQL_PASSWORD" \
  --set auth.database="$MYSQL_DATABASE"
```

### **Service Configuration**
```yaml
# manifests/043-database-mysql-config.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: default
spec:
  ports:
    - port: 3306
      targetPort: 3306
  selector:
    app.kubernetes.io/name: mysql
```

### **Custom MySQL Configuration**
```yaml
# Optional custom configuration in ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-custom-config
data:
  my.cnf: |
    [mysqld]
    max_connections=200
    sql_mode=STRICT_ALL_TABLES
```


### **Database Connection Testing**
```bash
# Test connection from within cluster
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h mysql.default.svc.cluster.local -u root -p

# Check if MySQL is ready
kubectl exec -it mysql-pod -- mysqladmin ping -uroot -p
```

### **Automated Verification**
The deployment includes automated CRUD testing:

```bash
# Run verification playbook manually
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/utility/u08-verify-mysql.yml
```

**Verification Process**:
1. Connects to MySQL server using root credentials
2. Creates test database and table
3. Inserts and retrieves test data
4. Verifies data integrity
5. Cleans up test database

## 🛠️ Management Operations

### **Database Administration**
```bash
# Access MySQL shell
kubectl exec -it mysql-pod -- mysql -uroot -p

# Create new database
kubectl exec -it mysql-pod -- mysql -uroot -p -e "CREATE DATABASE myapp;"

# Show databases
kubectl exec -it mysql-pod -- mysql -uroot -p -e "SHOW DATABASES;"

# Run SQL script
kubectl cp script.sql mysql-pod:/tmp/
kubectl exec -it mysql-pod -- mysql -uroot -p < /tmp/script.sql
```

### **Backup Operations**
```bash
# Create database backup
kubectl exec mysql-pod -- mysqldump -uroot -p myapp > backup.sql

# Restore from backup
kubectl exec -i mysql-pod -- mysql -uroot -p myapp < backup.sql
```

### **Service Removal**
```bash
# Remove MySQL service
cd provision-host/kubernetes/02-databases/not-in-use/
./06-remove-mysql.sh rancher-desktop
```

**Removal Process**:
- Uninstalls MySQL Helm release
- Waits for pods to terminate
- Preserves urbalurba-secrets and namespace structure
- Does not remove persistent data (if configured)


### **Backup Procedures**
```bash
# Full backup of all databases
kubectl exec mysql-pod -- mysqldump -uroot -p --all-databases > full-backup.sql

# Backup specific database
kubectl exec mysql-pod -- mysqldump -uroot -p myapp > myapp-backup.sql

# Backup with compression
kubectl exec mysql-pod -- mysqldump -uroot -p myapp | gzip > myapp-backup.sql.gz
```

### **Disaster Recovery**
```bash
# Restore full backup
kubectl exec -i mysql-pod -- mysql -uroot -p < full-backup.sql

# Restore specific database
kubectl exec -i mysql-pod -- mysql -uroot -p myapp < myapp-backup.sql

# Restore from compressed backup
gunzip -c myapp-backup.sql.gz | kubectl exec -i mysql-pod -- mysql -uroot -p myapp
```

---

**💡 Key Insight**: MySQL serves as an optional alternative to PostgreSQL in the Urbalurba infrastructure. Activate it when you need MySQL-specific features or have applications that require MySQL compatibility.