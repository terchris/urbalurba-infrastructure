# Database Services - Complete Data Layer

**File**: `doc/package-databases-readme.md`
**Purpose**: Overview of all database services in Urbalurba infrastructure
**Target Audience**: Database administrators, developers, architects
**Last Updated**: September 22, 2024

## 📋 Overview

Urbalurba infrastructure provides a comprehensive suite of database services supporting various data models and use cases. From traditional relational databases to NoSQL document stores, the platform offers production-ready database solutions with automated deployment, backup capabilities, and monitoring.

**Available Database Services**:
- **PostgreSQL**: Primary SQL database with AI/ML and geospatial extensions
- **MySQL**: Alternative SQL database for traditional relational workloads
- **MongoDB**: Document-based NoSQL database for flexible schemas

## 🗄️ Database Services

### **PostgreSQL - Primary Database Service** 🥇
**Status**: Active | **Port**: 5432 | **Type**: SQL Relational

**Pre-Built Extensions**: Vector Search (pgvector) • Geospatial (PostGIS) • Key-Value (hstore) • Hierarchical (ltree) • UUID Generation • Fuzzy Search • Advanced Indexing • Cryptography

PostgreSQL serves as the **primary database service** with enterprise-grade features and AI/ML capabilities. Uses a custom container with 8 pre-built extensions for advanced data processing, vector search, and geospatial operations.

**Key Features**:
- **AI-Ready**: pgvector for embeddings and vector similarity search
- **Geospatial**: PostGIS for location-based applications
- **Custom Container**: Pre-built extensions for immediate use
- **Production-Ready**: Bitnami Helm chart with persistent storage

📚 **[Complete Documentation →](./package-databases-postgresql.md)**
🐳 **[Custom Container Details →](./package-databases-postgresql-container.md)**

---

### **MySQL - Alternative SQL Database** 🔄
**Status**: Optional | **Port**: 3306 | **Type**: SQL Relational

Traditional MySQL database service for applications requiring MySQL-specific features or legacy compatibility. Provides reliable relational database capabilities with standard MySQL functionality.

**Key Features**:
- **Standard MySQL**: Full MySQL 8.0 compatibility
- **Helm Deployment**: Bitnami MySQL chart
- **Persistent Storage**: 8GB storage with automatic backups
- **Easy Migration**: Standard MySQL tools and procedures

📚 **[Complete Documentation →](./package-databases-mysql.md)**

---

### **MongoDB - NoSQL Document Database** 📄
**Status**: Optional (not-in-use) | **Port**: 27017 | **Type**: NoSQL Document

Document-based NoSQL database for applications requiring flexible schemas and JSON-like data structures. Pre-configured for Gravitee API Management platform but suitable for any document-based applications.

**Key Features**:
- **Document Storage**: JSON-like documents with flexible schemas
- **MongoDB 8.0**: Latest version with ARM64 compatibility
- **User Management**: Automated user provisioning and permissions
- **Gravitee Integration**: Pre-configured for API management platform

📚 **[Complete Documentation →](./package-databases-mongodb.md)**

## 🏗️ Deployment Architecture

### **Service Activation**
```
Database Deployment Status:
├── PostgreSQL (ACTIVE) - Primary database service
├── MySQL (OPTIONAL) - Available for activation
└── MongoDB (INACTIVE) - Located in not-in-use/ folder
```

### **Storage & Persistence**
All database services use Kubernetes PersistentVolumeClaims for data persistence:
- **PostgreSQL**: 8GB persistent storage
- **MySQL**: 8GB persistent storage
- **MongoDB**: 8GB persistent storage

### **Secret Management**
Database authentication managed through `urbalurba-secrets`:
```
Database Credentials:
├── PGPASSWORD / PGHOST (PostgreSQL)
├── MYSQL_ROOT_PASSWORD / MYSQL_PASSWORD (MySQL)
└── MONGODB_ROOT_PASSWORD / GRAVITEE_MONGODB_* (MongoDB)
```

## 🚀 Quick Start

### **Deploy Primary Database (PostgreSQL)**
```bash
# Automatic deployment during cluster provisioning
./provision-kubernetes.sh rancher-desktop

# Manual deployment
cd provision-host/kubernetes/02-databases/
./05-setup-postgres.sh rancher-desktop
```

### **Activate Optional Databases**
```bash
# Activate MySQL (move from not-in-use if needed)
cd provision-host/kubernetes/02-databases/
./06-setup-mysql.sh rancher-desktop

# Activate MongoDB
mv not-in-use/04-setup-mongodb.sh ./
./04-setup-mongodb.sh rancher-desktop
```

## 🔍 Database Selection Guide

### **When to Use PostgreSQL** ✅
- **Primary choice** for new applications
- AI/ML applications requiring vector search
- Geospatial applications with location data
- Applications needing advanced SQL features
- Need for JSONB, arrays, or custom data types

### **When to Use MySQL** 🔄
- Legacy applications built for MySQL
- Applications requiring MySQL-specific features
- Teams with existing MySQL expertise
- Applications using MySQL-only tools

### **When to Use MongoDB** 📄
- Applications with frequently changing schemas
- Rapid prototyping and development
- Applications storing JSON-like documents
- Gravitee API Management platform
- Applications requiring horizontal scaling

## 🛠️ Management Operations

### **Common Operations**
```bash
# Check database status
kubectl get pods -l app.kubernetes.io/component=database

# View database logs
kubectl logs -l app.kubernetes.io/name=postgresql
kubectl logs -l app.kubernetes.io/name=mysql
kubectl logs -l app=mongodb

# Connect to databases
kubectl exec -it postgresql-0 -- psql -U postgres
kubectl exec -it mysql-0 -- mysql -u root -p
kubectl exec -it mongodb-0 -- mongosh --username root --password
```

### **Backup Procedures**
```bash
# PostgreSQL backup
kubectl exec postgresql-0 -- pg_dumpall -U postgres > backup.sql

# MySQL backup
kubectl exec mysql-0 -- mysqldump -u root -p --all-databases > backup.sql

# MongoDB backup
kubectl exec mongodb-0 -- mongodump --authenticationDatabase admin --username root --password
```

## 🔧 Troubleshooting

### **Common Issues**
- **Pod Won't Start**: Check PVC binding and resource limits
- **Connection Refused**: Verify service endpoints and DNS resolution
- **Authentication Failed**: Check urbalurba-secrets configuration
- **Storage Issues**: Verify PVC status and node storage capacity

### **Diagnostic Commands**
```bash
# Check service endpoints
kubectl get endpoints postgresql mysql mongodb

# Verify storage
kubectl get pvc -l app.kubernetes.io/component=database

# Test connectivity
kubectl run test-pod --image=postgres:16 --rm -it -- \
  psql postgresql://postgres:password@postgresql:5432/postgres
```

## 📋 Maintenance

### **Regular Tasks**
1. **Monitor Storage**: Check PVC usage and growth trends
2. **Backup Schedule**: Implement automated backup procedures
3. **Security Updates**: Update container images regularly
4. **Performance Monitoring**: Monitor query performance and resource usage
5. **Extension Updates**: Monitor PostgreSQL custom container updates

### **Service Removal**
```bash
# Remove services (preserves data by default)
cd provision-host/kubernetes/02-databases/not-in-use/
./05-remove-postgres.sh rancher-desktop
./06-remove-mysql.sh rancher-desktop
./04-remove-mongodb.sh rancher-desktop
```

## 📚 Related Documentation

- **[PostgreSQL Documentation](./package-databases-postgresql.md)** - Primary database service
- **[PostgreSQL Container](./package-databases-postgresql-container.md)** - Custom container details
- **[MySQL Documentation](./package-databases-mysql.md)** - Alternative SQL database
- **[MongoDB Documentation](./package-databases-mongodb.md)** - NoSQL document database
- **[Secrets Management](./secrets-management-readme.md)** - Database credential configuration
- **[Troubleshooting Guide](./troubleshooting-readme.md)** - Database troubleshooting procedures

---

**💡 Key Insight**: The database layer provides comprehensive data storage solutions with PostgreSQL as the primary choice due to its advanced features, AI/ML capabilities, and extensive extension ecosystem. MySQL and MongoDB serve as specialized alternatives for specific use cases and legacy requirements.