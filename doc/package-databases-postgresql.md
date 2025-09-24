# PostgreSQL Database - Primary Database Service

**Pre-Built Extensions**: Vector Search (pgvector) • Geospatial (PostGIS) • Key-Value (hstore) • Hierarchical (ltree) • UUID Generation • Fuzzy Search • Advanced Indexing • Cryptography

**File**: `doc/package-databases-postgresql.md`
**Purpose**: Complete guide to PostgreSQL deployment and configuration in Urbalurba infrastructure
**Target Audience**: Database administrators, developers working with PostgreSQL, AI/ML developers
**Last Updated**: September 22, 2024

## 📋 Overview

PostgreSQL serves as the **primary database service** in the Urbalurba infrastructure. It's designed as an active service that provides a powerful, production-ready relational database with advanced extensions for AI, geospatial, and modern data-intensive applications.

> **🔧 IMPORTANT**: This PostgreSQL deployment uses a **custom container** with pre-built AI and geospatial extensions. For detailed information about the custom container, its extensions, and CI/CD pipeline, see **[package-databases-postgresql-container.md](./package-databases-postgresql-container.md)**.

**Key Features**:
- **Advanced SQL Database**: Full PostgreSQL 16 compatibility with 8 pre-built extensions
- **Custom Container**: Uses `ghcr.io/terchris/urbalurba-postgresql` with AI/ML and geospatial extensions
- **Helm-Based Deployment**: Uses Bitnami PostgreSQL chart with custom image override
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes comprehensive CRUD and extension verification
- **AI-Ready**: Pre-configured with pgvector for vector search and embeddings

## 🏗️ Architecture

### **Deployment Components**
```
PostgreSQL Service Stack:
├── Helm Release (bitnami/postgresql with custom image)
├── StatefulSet (custom urbalurba-postgresql container)
├── ConfigMap (PostgreSQL configuration)
├── Service (ClusterIP on port 5432)
├── PersistentVolumeClaim (8GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (postgresql container with 8 extensions)
```

### **File Structure**
```
02-databases/
├── 05-setup-postgres.sh        # Main deployment script (active)
└── not-in-use/
    └── 05-remove-postgres.sh   # Removal script

manifests/
└── 042-database-postgresql-config.yaml  # PostgreSQL Helm configuration

ansible/playbooks/
├── 040-database-postgresql.yml     # Main deployment logic
├── 040-remove-database-postgresql.yml  # Removal logic
└── utility/
    └── u02-verify-postgres.yml     # Extension and CRUD testing
```

## 🚀 Deployment

### **Automatic Deployment**
PostgreSQL deploys automatically during cluster provisioning as it's the primary database:

```bash
# Full cluster provisioning (includes PostgreSQL)
./provision-kubernetes.sh rancher-desktop
```

### **Manual Deployment**
```bash
# Deploy PostgreSQL with default settings
cd provision-host/kubernetes/02-databases/
./05-setup-postgres.sh rancher-desktop

# Deploy to specific Kubernetes context
./05-setup-postgres.sh multipass-microk8s
./05-setup-postgres.sh azure-aks
```

### **Prerequisites**
Before deploying PostgreSQL, ensure the required secrets are configured in `urbalurba-secrets`:

- `PGPASSWORD`: PostgreSQL admin password
- `PGHOST`: PostgreSQL service hostname (typically `postgresql.default.svc.cluster.local`)

## ⚙️ Configuration

### **Custom Container Configuration**
PostgreSQL uses a custom container with pre-built extensions:

```yaml
# From manifests/042-database-postgresql-config.yaml
image:
  registry: ghcr.io
  repository: terchris/urbalurba-postgresql
  tag: latest
  pullPolicy: Always

# Enable insecure images for custom container
global:
  security:
    allowInsecureImages: true
```

### **Pre-Built Extensions**
The custom container includes 8 pre-built extensions automatically enabled:

```sql
-- AI and Vector Search Extensions
CREATE EXTENSION IF NOT EXISTS vector;        -- Vector similarity search

-- Geospatial Extensions
CREATE EXTENSION IF NOT EXISTS postgis;       -- Geospatial data types

-- Advanced Data Type Extensions
CREATE EXTENSION IF NOT EXISTS hstore;        -- Key-value pairs
CREATE EXTENSION IF NOT EXISTS ltree;         -- Hierarchical data

-- Utility Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";   -- UUID generation
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- Fuzzy text search
CREATE EXTENSION IF NOT EXISTS btree_gin;     -- Additional indexing
CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- Cryptographic functions
```

### **Helm Configuration**
```bash
# Deployment command (from Ansible playbook)
helm install postgresql bitnami/postgresql \
  --namespace default \
  -f manifests/042-database-postgresql-config.yaml \
  --set auth.postgresPassword="$PGPASSWORD"
```

### **Resource Configuration**
```yaml
# Resource limits and requests
resources:
  requests:
    memory: 240Mi
    cpu: 250m
  limits:
    memory: 512Mi
    cpu: 500m

# Storage configuration
primary:
  persistence:
    enabled: true
    size: 8Gi
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=postgresql

# Check StatefulSet status
kubectl get statefulset postgresql

# Check service status
kubectl get svc postgresql

# View PostgreSQL logs
kubectl logs -l app.kubernetes.io/name=postgresql
```

### **Database Connection Testing**
```bash
# Test connection from within cluster
kubectl run postgresql-client --image=postgres:16 --rm -it --restart=Never -- \
  psql postgresql://postgres:password@postgresql.default.svc.cluster.local:5432/postgres

# Check if PostgreSQL is ready
kubectl exec -it postgresql-0 -- pg_isready -U postgres

# Test with authentication
kubectl exec -it postgresql-0 -- psql -U postgres
```

### **Extension Verification**
```bash
# List all installed extensions
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT extname, extversion FROM pg_extension ORDER BY extname;"

# Test vector extension (pgvector)
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT '[1,2,3]'::vector;"

# Test geospatial extension (PostGIS)
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT ST_Point(1, 2);"
```

### **Automated Verification**
The deployment includes comprehensive testing of all extensions:

```bash
# Run verification playbook manually
cd /mnt/urbalurbadisk/ansible
ansible-playbook playbooks/utility/u02-verify-postgres.yml
```

**Verification Process**:
1. Connects to PostgreSQL server using admin credentials
2. Tests all 8 pre-built extensions
3. Performs CRUD operations and data integrity checks
4. Validates vector search, geospatial, and NoSQL capabilities
5. Verifies performance and connection pooling

## 🛠️ Management Operations

### **Database Administration**
```bash
# Access PostgreSQL shell
kubectl exec -it postgresql-0 -- psql -U postgres

# Create new database with extensions
kubectl exec -it postgresql-0 -- psql -U postgres -c "CREATE DATABASE myapp;"
kubectl exec -it postgresql-0 -- psql -U postgres -d myapp -c "CREATE EXTENSION vector;"

# Show databases
kubectl exec -it postgresql-0 -- psql -U postgres -c "\l"

# Show extensions in database
kubectl exec -it postgresql-0 -- psql -U postgres -c "\dx"
```

### **Advanced Operations**
```bash
# Create vector search table
kubectl exec -it postgresql-0 -- psql -U postgres -c "
CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(1536)
);
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);"

# Create geospatial table
kubectl exec -it postgresql-0 -- psql -U postgres -c "
CREATE TABLE locations (
  id SERIAL PRIMARY KEY,
  name TEXT,
  coordinates GEOMETRY(POINT, 4326)
);
CREATE INDEX ON locations USING gist(coordinates);"
```

### **Backup Operations**
```bash
# Create database backup using pg_dump
kubectl exec postgresql-0 -- pg_dump -U postgres myapp > backup.sql

# Restore from backup
kubectl exec -i postgresql-0 -- psql -U postgres myapp < backup.sql

# Backup all databases
kubectl exec postgresql-0 -- pg_dumpall -U postgres > full-backup.sql
```

### **Service Removal**
```bash
# Remove PostgreSQL service (preserves data by default)
cd provision-host/kubernetes/02-databases/not-in-use/
./05-remove-postgres.sh rancher-desktop

# Completely remove including data
ansible-playbook ansible/playbooks/040-remove-database-postgresql.yml \
  -e target_host=rancher-desktop -e remove_pvc=true
```

**Removal Process**:
- Uninstalls PostgreSQL Helm release
- Waits for pods to terminate
- Optionally removes persistent volume claims
- Preserves urbalurba-secrets and namespace structure
- Provides data retention options and recovery instructions

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=postgresql
kubectl logs -l app.kubernetes.io/name=postgresql

# Check custom image pull
kubectl describe pod postgresql-0 | grep -A 5 "Events:"
```

**Custom Image Issues**:
```bash
# Verify custom image is accessible
kubectl run test-pg --image=ghcr.io/terchris/urbalurba-postgresql:latest --rm -it -- \
  psql --version

# Check image pull policy
kubectl get pod postgresql-0 -o yaml | grep -A 3 "image:"
```

**Extension Problems**:
```bash
# Check if extensions are installed
kubectl exec -it postgresql-0 -- psql -U postgres -c "\dx"

# Test specific extension
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT * FROM pg_available_extensions WHERE name='vector';"

# Reinstall extension if needed
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "DROP EXTENSION IF EXISTS vector; CREATE EXTENSION vector;"
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc postgresql
kubectl get endpoints postgresql

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup postgresql.default.svc.cluster.local

# Check PostgreSQL configuration
kubectl exec -it postgresql-0 -- psql -U postgres -c "SHOW all;"
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod postgresql-0

# View PostgreSQL statistics
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT * FROM pg_stat_activity;"

# Check slow queries
kubectl exec -it postgresql-0 -- psql -U postgres -c \
  "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **Extension Updates**: Monitor custom container updates for new extension versions
3. **Backup Schedule**: Implement regular database backups using pg_dump
4. **Performance Monitoring**: Monitor query performance and resource usage

### **Backup Procedures**
```bash
# Full backup of all databases
kubectl exec postgresql-0 -- pg_dumpall -U postgres > full-backup.sql

# Backup specific database
kubectl exec postgresql-0 -- pg_dump -U postgres myapp > myapp-backup.sql

# Backup with compression
kubectl exec postgresql-0 -- pg_dump -U postgres -Fc myapp > myapp-backup.dump

# Schema-only backup
kubectl exec postgresql-0 -- pg_dump -U postgres --schema-only myapp > schema-backup.sql
```

### **Disaster Recovery**
```bash
# Restore full backup
kubectl exec -i postgresql-0 -- psql -U postgres < full-backup.sql

# Restore specific database
kubectl exec -i postgresql-0 -- psql -U postgres myapp < myapp-backup.sql

# Restore from compressed backup
kubectl exec -i postgresql-0 -- pg_restore -U postgres -d myapp myapp-backup.dump
```

## 📚 Related Documentation

- **[package-databases-postgresql-container.md](./package-databases-postgresql-container.md)** - **Custom container details, extensions, and CI/CD**

---

**💡 Key Insight**: PostgreSQL serves as the primary database service with advanced AI and geospatial capabilities through a custom container. For production AI applications requiring vector search, this setup provides enterprise-grade performance with pgvector and other modern extensions pre-configured and ready to use.