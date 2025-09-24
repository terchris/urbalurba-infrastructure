# Spark Kubernetes Operator - Distributed Data Processing Engine

**Key Features**: Distributed Computing • SparkApplication CRDs • Kubernetes Native • ARM64 Support • Resource Management • Job Scheduling • Multi-Language Support

**File**: `doc/package-datascience-spark.md`
**Purpose**: Complete guide to Apache Spark Kubernetes Operator deployment and configuration in Urbalurba infrastructure
**Target Audience**: Data engineers, data scientists, platform architects, developers building distributed data processing applications
**Last Updated**: September 24, 2025

## 📋 Overview

The Spark Kubernetes Operator serves as the **distributed data processing engine** in the Urbalurba infrastructure, providing native Kubernetes integration for Apache Spark workloads. It enables declarative submission and management of Spark applications through custom Kubernetes resources, replacing traditional Spark cluster managers.

This implementation provides **100% Databricks compatibility** for PySpark, Spark SQL, and DataFrame operations, allowing seamless migration of existing Databricks workloads to a self-managed Kubernetes environment. The operator manages the complete lifecycle of Spark applications, from submission to cleanup, with automatic resource management and scaling.

**Key Features**:
- **Kubernetes Native**: Uses SparkApplication Custom Resource Definitions (CRDs) for declarative job management
- **Multi-Language Support**: Python (PySpark), Scala, Java, and R support with identical APIs to standard Spark
- **Resource Management**: Automatic pod scheduling, resource allocation, and cleanup
- **ARM64 Compatibility**: Native support for Apple Silicon and ARM-based infrastructure
- **JupyterHub Integration**: Seamless integration with notebook environments for interactive development
- **Databricks Compatibility**: 100% API compatibility for easy workload migration

## 🏗️ Architecture

### **Deployment Components**
```
Spark Kubernetes Operator Stack:
├── Helm Release (spark-kubernetes-operator/spark-kubernetes-operator)
├── Namespace (spark-operator)
├── Deployment (spark-kubernetes-operator pod)
├── Custom Resource Definitions (SparkApplication, ScheduledSparkApplication)
├── Service Account (spark-operator with RBAC permissions)
├── ClusterRole (spark-operator-role for pod management)
└── Driver/Executor Pods (created dynamically per job)
```

### **File Structure**
```
10-datascience/not-in-use/
├── 03-setup-spark.sh              # Main deployment script
└── 03-remove-spark.sh             # Removal script

ansible/playbooks/
├── 330-setup-spark.yml            # Main deployment logic
└── 330-remove-spark.yml           # Removal logic

manifests/
└── 331-sample-data-sparkapplication.yaml  # Example Spark job
```

## 🚀 Deployment

### **Manual Deployment**
The Spark Kubernetes Operator is available in the data science package and can be deployed individually:

```bash
# Deploy Spark Operator with verification
cd provision-host/kubernetes/10-datascience/not-in-use/
./03-setup-spark.sh rancher-desktop

# Deploy to specific Kubernetes context
./03-setup-spark.sh multipass-microk8s
./03-setup-spark.sh azure-aks
```

### **Prerequisites**
- **Kubernetes Cluster**: 1.19+ with sufficient resources (2+ CPU cores, 4+ GB RAM recommended)
- **kubectl**: Configured for target cluster access
- **Helm 3.x**: Required for operator installation
- **Container Runtime**: Docker or containerd with proper networking

## ⚙️ Configuration

### **Spark Operator Configuration**
The operator is deployed with production-ready settings optimized for Kubernetes environments:

```yaml
# Helm values configuration
webhook:
  enable: false  # Disabled for simplified deployment

image:
  repository: spark-kubernetes-operator/spark-operator
  tag: latest  # Uses stable release with ARM64 support

rbac:
  create: true  # Creates necessary service accounts and roles

serviceAccounts:
  spark:
    create: true
    name: spark
  sparkoperator:
    create: true
    name: spark-operator
```

### **Resource Configuration**
```yaml
# Operator pod resources
resources:
  requests:
    cpu: 100m
    memory: 300Mi
  limits:
    cpu: 200m
    memory: 512Mi

# Default Spark application resources (customizable per job)
spark:
  driver:
    cores: 1
    memory: 1g
  executor:
    cores: 1
    memory: 1g
    instances: 2
```

### **Security Configuration**
```yaml
# RBAC Configuration
clusterRole:
  create: true  # Allows operator to manage pods cluster-wide

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Network policies (if needed)
networkPolicy:
  enabled: false  # Can be enabled for additional network security
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check operator pod status
kubectl get pods -n spark-operator

# Verify operator deployment
kubectl get deployment -n spark-operator spark-kubernetes-operator

# Check custom resource definitions
kubectl get crd | grep spark

# View operator logs
kubectl logs -n spark-operator deployment/spark-kubernetes-operator
```

### **Service Verification**
```bash
# Test SparkApplication CRD availability
kubectl api-resources | grep sparkapplications

# Check RBAC permissions
kubectl auth can-i create pods --as=system:serviceaccount:spark-operator:spark

# Verify webhook configuration (if enabled)
kubectl get validatingwebhookconfigurations | grep spark
```

### **Spark Application Testing**
```bash
# Submit sample Spark application
kubectl apply -f manifests/331-sample-data-sparkapplication.yaml

# Monitor application status
kubectl get sparkapplications -A

# Check driver pod logs
kubectl logs -n spark-operator spark-pi-driver

# View application details
kubectl describe sparkapplication spark-pi -n spark-operator
```

### **Automated Verification**
The deployment includes automatic verification of:
- ✅ **Operator Readiness**: Confirms operator pod is running and ready
- ✅ **CRD Registration**: Validates SparkApplication custom resources are available
- ✅ **RBAC Configuration**: Ensures proper service account permissions
- ✅ **Helm Deployment**: Verifies successful chart installation

## 🛠️ Management Operations

### **Spark Application Administration**
```bash
# List all Spark applications
kubectl get sparkapplications -A

# Get application status
kubectl describe sparkapplication <app-name> -n <namespace>

# View driver logs
kubectl logs <driver-pod-name> -n <namespace>

# Monitor executor pods
kubectl get pods -l spark-role=executor -n <namespace>

# Delete application
kubectl delete sparkapplication <app-name> -n <namespace>
```

### **Operator Management**
```bash
# Scale operator (if needed)
kubectl scale deployment spark-kubernetes-operator -n spark-operator --replicas=1

# Update operator configuration
helm upgrade spark-operator spark-kubernetes-operator/spark-kubernetes-operator -n spark-operator

# Check operator metrics (if enabled)
kubectl port-forward -n spark-operator svc/spark-operator-webhook 8080:443
```

### **Service Removal**
```bash
# Remove Spark Operator and all applications
cd provision-host/kubernetes/10-datascience/not-in-use/
./03-remove-spark.sh rancher-desktop

# Manual cleanup if needed
helm uninstall spark-operator -n spark-operator
kubectl delete namespace spark-operator
```

## 🔧 Troubleshooting

### **Common Issues**

**Operator Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -n spark-operator -l app.kubernetes.io/name=spark-operator
kubectl logs -n spark-operator deployment/spark-kubernetes-operator

# Verify RBAC permissions
kubectl auth can-i create pods --as=system:serviceaccount:spark-operator:spark-operator
```

**SparkApplication Stuck in Pending**:
```bash
# Check resource availability
kubectl describe nodes
kubectl get pods -A | grep Pending

# Verify service account permissions
kubectl get serviceaccount spark -n spark-operator
kubectl describe clusterrole spark-operator-role
```

**Driver Pod Failures**:
```bash
# Check driver pod logs
kubectl logs <driver-pod> -n <namespace>

# Verify image pull and resources
kubectl describe pod <driver-pod> -n <namespace>

# Check network connectivity
kubectl exec <driver-pod> -n <namespace> -- nslookup kubernetes.default.svc.cluster.local
```

**Executor Connection Issues**:
```bash
# Check executor pod logs
kubectl logs <executor-pod> -n <namespace>

# Verify driver service
kubectl get svc -n <namespace> | grep <driver-svc>

# Test connectivity
kubectl exec <executor-pod> -n <namespace> -- telnet <driver-svc> 7077
```

## 📋 Maintenance

### **Regular Tasks**
1. **Monitor Resource Usage**: Check CPU/memory consumption of running Spark applications
2. **Clean up Completed Jobs**: Remove old SparkApplication resources
3. **Update Operator**: Keep operator version current for security and features
4. **Review Logs**: Monitor operator logs for errors or performance issues

### **Backup Procedures**
```bash
# Backup SparkApplication definitions
kubectl get sparkapplications -A -o yaml > spark-applications-backup.yaml

# Backup operator configuration
helm get values spark-operator -n spark-operator > spark-operator-values.yaml

# Export custom configurations
kubectl get configmap -n spark-operator -o yaml > spark-configs-backup.yaml
```

### **Disaster Recovery**
```bash
# Restore operator
helm install spark-operator spark-kubernetes-operator/spark-kubernetes-operator -n spark-operator -f spark-operator-values.yaml

# Restore applications
kubectl apply -f spark-applications-backup.yaml

# Verify restoration
kubectl get sparkapplications -A
kubectl get pods -n spark-operator
```

## 🚀 Use Cases

### **Batch Data Processing**
```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: data-processing-job
  namespace: spark-operator
spec:
  type: Python
  mode: cluster
  image: "apache/spark-py:v3.5.0"
  imagePullPolicy: Always
  mainApplicationFile: "s3a://data-bucket/jobs/process_data.py"
  arguments:
    - "--input-path"
    - "s3a://data-bucket/raw/2025/09/24/"
    - "--output-path"
    - "s3a://data-bucket/processed/2025/09/24/"
  sparkVersion: "3.5.0"
  driver:
    cores: 2
    memory: "2g"
    serviceAccount: spark
  executor:
    cores: 2
    memory: "2g"
    instances: 4
```

### **Scheduled ETL Pipeline**
```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: ScheduledSparkApplication
metadata:
  name: daily-etl-pipeline
  namespace: spark-operator
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    type: Python
    mode: cluster
    image: "apache/spark-py:v3.5.0"
    mainApplicationFile: "local:///opt/spark/work-dir/etl_pipeline.py"
    sparkVersion: "3.5.0"
    driver:
      cores: 1
      memory: "1g"
      serviceAccount: spark
    executor:
      cores: 1
      memory: "1g"
      instances: 3
```

### **Interactive PySpark in JupyterHub**
```python
# In JupyterHub notebook
from pyspark.sql import SparkSession

# Create Spark session (automatically connects to operator-managed cluster)
spark = SparkSession.builder \
    .appName("InteractiveAnalysis") \
    .config("spark.kubernetes.container.image", "apache/spark-py:v3.5.0") \
    .config("spark.executor.instances", "2") \
    .config("spark.executor.memory", "1g") \
    .config("spark.executor.cores", "1") \
    .getOrCreate()

# Load and process data
df = spark.read.parquet("s3a://data-bucket/dataset.parquet")
result = df.groupBy("category").count().orderBy("count", ascending=False)
result.show()

# SQL operations
df.createOrReplaceTempView("data")
spark.sql("SELECT category, AVG(value) as avg_value FROM data GROUP BY category").show()
```

### **ML Pipeline with Spark MLlib**
```python
# Machine learning pipeline
from pyspark.ml import Pipeline
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.classification import RandomForestClassifier

# Prepare features
indexer = StringIndexer(inputCol="category", outputCol="categoryIndex")
assembler = VectorAssembler(inputCols=["feature1", "feature2", "categoryIndex"], outputCol="features")
rf = RandomForestClassifier(featuresCol="features", labelCol="label")

# Create and fit pipeline
pipeline = Pipeline(stages=[indexer, assembler, rf])
model = pipeline.fit(training_data)

# Make predictions
predictions = model.transform(test_data)
predictions.select("features", "label", "prediction").show()
```

---

**💡 Key Insight**: The Spark Kubernetes Operator provides enterprise-grade distributed computing capabilities that fully replace Databricks' processing engine. Combined with JupyterHub, it delivers 100% API compatibility for PySpark workloads while providing superior resource management through Kubernetes-native orchestration. This enables seamless migration of existing Databricks applications to a self-managed, cloud-independent infrastructure.