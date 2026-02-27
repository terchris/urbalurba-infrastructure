# Unity Catalog - Data Governance and Cataloging ❌

**Key Features**: Data Governance • Metadata Management • Access Control • Schema Registry • Data Lineage • Three-Level Namespace • NOT WORKING

**File**: `docs/package-datascience-unitycatalog.md`
**Purpose**: Documentation of Unity Catalog deployment issues and alternatives for data governance
**Target Audience**: Data engineers, platform architects, developers working with data catalogs
**Last Updated**: September 24, 2025

## ❌ **CRITICAL ISSUE: SERVICE NOT FUNCTIONAL**

**Unity Catalog is currently NOT WORKING due to universal container image issues affecting all available Docker images.**

## 📋 Overview

Unity Catalog is designed to serve as an **enterprise data governance solution** providing centralized metadata management, access control, and data lineage tracking. However, **all available Docker container images are broken** due to fundamental permission issues that prevent the service from starting.

**Intended Key Features** (Not Available):
- **Data Governance**: Centralized data access policies and permissions
- **Metadata Management**: Schema registry and table discovery
- **Access Control**: Fine-grained permissions on databases, schemas, and tables
- **Three-Level Namespace**: catalog.schema.table hierarchical organization
- **Data Lineage**: Track data flow and transformations
- **Spark Integration**: Native support for Spark SQL and DataFrame operations

## 🚫 **Root Cause Analysis**

### **Universal Container Issue**
ALL available Unity Catalog Docker images suffer from the same critical flaw:

```
Error: failed to start container "unity-catalog-server":
exec: "bin/start-uc-server": stat bin/start-uc-server: permission denied
```

### **Affected Images**
- ❌ **`unitycatalog/unitycatalog:latest`** (Official image)
- ❌ **`godatadriven/unity-catalog:latest`** (Community image, 1.1GB)
- ❌ **`datacatering/unitycatalog`** (Alternative image)

### **Technical Details**
1. **Permission Problem**: The `bin/start-uc-server` shell script lacks execute permissions
2. **Build Process Bug**: All Dockerfiles fail to include `RUN chmod +x /app/bin/start-uc-server`
3. **Universal Failure**: This affects the entire Unity Catalog container ecosystem
4. **Unfixable in Kubernetes**: Cannot fix permissions post-deployment due to security policies

## 🏗️ Architecture (Intended but Non-Functional)

### **Deployment Components** (All Broken)
```
Unity Catalog Stack (BROKEN):
├── Helm Release (FAILS - container won't start)
├── Deployment (FAILS - permission denied)
├── ConfigMap (Working - but unused due to startup failure)
├── Service (Working - but no backend)
├── PersistentVolumeClaims (Working - but unused)
├── urbalurba-secrets (Working - all secrets configured correctly)
└── Pod (FAILS - CrashLoopBackOff due to exec permission denied)
```

### **File Structure**
```
10-datascience/not-in-use/
├── 07-setup-unity-catalog.sh        # Deployment script (fails due to container)
└── 07-remove-unity-catalog.sh       # Removal script (works)

manifests/
├── 320-unity-catalog-deployment.yaml # Kubernetes manifests (correct but ineffective)
└── 321-unity-catalog-ingress.yaml    # Ingress configuration (unused)

ansible/playbooks/
├── 320-setup-unity-catalog.yml       # Ansible playbook (infrastructure works, container fails)
└── utility/u07-setup-unity-catalog-database.yml # Database setup (works correctly)
```

## 🔍 **Verification Results**

### **What's Working** ✅
- **Database**: PostgreSQL `unity_catalog` database created successfully
- **User**: `unity_catalog_user` with proper permissions
- **Secrets**: All Unity Catalog secrets correctly configured
- **Kubernetes Resources**: Deployments, services, ingresses all apply correctly
- **Infrastructure**: Complete Kubernetes setup is functional

### **What's Broken** ❌
- **Container Startup**: All Unity Catalog images fail with permission denied
- **Service Availability**: No working endpoint due to container failure
- **API Access**: No functional REST API for catalog operations
- **Spark Integration**: Cannot connect to non-existent service

## 🛠️ **Attempted Solutions**

### **Tried and Failed**
1. **Permission Workaround**: `chmod +x ./bin/start-uc-server` fails (permission denied on chmod itself)
2. **Alternative Images**: All community images have same issue
3. **Direct Java Execution**: JAR files not at expected locations in containers
4. **Security Context Changes**: Running as root still fails due to script permissions

### **Why Solutions Don't Work**
- **Read-Only Filesystem**: Container filesystems prevent chmod operations
- **Universal Bug**: All Unity Catalog container builds have same flaw
- **Kubernetes Security**: Cannot override container entrypoint permissions

## 🔧 Troubleshooting

### **Error Patterns**
```bash
# Container logs show:
exec: "bin/start-uc-server": permission denied

# Pod status shows:
CrashLoopBackOff   3 (45s ago)

# Events show:
Error: failed to start container "unity-catalog-server"
```

### **Diagnostic Commands**
```bash
# Check pod status (will show CrashLoopBackOff)
kubectl get pods -n unity-catalog

# View error logs (will be empty due to startup failure)
kubectl logs -n unity-catalog -l app=unity-catalog

# Check pod events (shows permission denied error)
kubectl describe pod -n unity-catalog -l app=unity-catalog

# Verify infrastructure (database, secrets work)
kubectl get secret urbalurba-secrets -n unity-catalog -o jsonpath='{.data}' | jq 'keys'
```

## 🔄 **Alternative Solutions**

Since Unity Catalog is non-functional, consider these working alternatives:

### **Apache Hive Metastore** ✅
- **Status**: Available and working
- **Features**: Schema registry, metadata management
- **Integration**: Native Spark support
- **Deployment**: Standard Helm charts work correctly

### **Apache Atlas** ✅
- **Status**: Available and working
- **Features**: Data governance, lineage tracking
- **Integration**: Spark, Kafka, HBase support
- **Deployment**: Stable container images available

### **DataHub** ✅
- **Status**: Available and working
- **Features**: Modern metadata platform
- **Integration**: GraphQL API, web UI
- **Deployment**: Well-maintained Docker images

### **PostgreSQL + Custom Metadata Tables** ✅
- **Status**: Always works (uses existing PostgreSQL)
- **Features**: Custom schema registry
- **Integration**: Direct SQL access from Spark
- **Deployment**: No additional containers needed

## 📋 Current Recommendations

### **Immediate Actions**
1. **Do NOT attempt to deploy Unity Catalog** - it will fail universally
2. **Use Apache Hive Metastore** for immediate data catalog needs
3. **Consider DataHub** for modern metadata platform features
4. **Monitor Unity Catalog project** for container image fixes

### **Long-Term Strategy**
1. **Wait for Upstream Fix**: Unity Catalog team needs to fix container builds
2. **Custom Image Build**: Build corrected Docker image with proper permissions
3. **Alternative Implementation**: Use working data catalog solutions
4. **Hybrid Approach**: PostgreSQL metadata + custom tools

## 🚀 **Status Timeline**

- **September 2025**: Unity Catalog containers discovered broken
- **Issue Reported**: Community aware of permission problems
- **Expected Fix**: Unknown - depends on Unity Catalog team
- **Current Status**: **ALL IMAGES BROKEN - AVOID DEPLOYMENT**

## 💡 **Key Insight**

Unity Catalog represents an excellent data governance solution **in theory**, but **all container implementations are fundamentally broken**. The issue is not with the Urbalurba infrastructure, Kubernetes configuration, or secrets management - all of those work perfectly. The problem is with the Unity Catalog project's Docker build process, which fails to set proper executable permissions on critical startup scripts.

**Recommendation**: Use working alternatives (Hive Metastore, Atlas, DataHub) until Unity Catalog fixes their container images.

---

**⚠️ WARNING**: Do not attempt to deploy Unity Catalog until container permission issues are resolved upstream. Deployment will always fail with permission denied errors regardless of configuration changes.