# JupyterHub - Interactive Notebook Environment for Data Science

**Key Features**: Interactive Notebooks • PySpark Integration • Web-based Interface • Multi-user Support • Kubernetes-native • Secret Authentication • Distributed Computing

**File**: `docs/package-datascience-jupyterhub.md`
**Purpose**: Complete guide to JupyterHub deployment and configuration for data science workflows in Urbalurba infrastructure
**Target Audience**: Data scientists, ML engineers, developers working with notebooks and distributed computing
**Last Updated**: September 23, 2025

## 📋 Overview

JupyterHub serves as the **interactive notebook environment** in the Urbalurba infrastructure, providing a **Databricks replacement** for data science and machine learning workflows. It offers web-based Jupyter notebooks with PySpark integration for distributed data processing.

**Key Features**:
- **Interactive Notebooks**: Web-based Jupyter interface with Python, Scala, and SQL support
- **PySpark Integration**: Built-in Apache Spark connectivity for distributed data processing
- **Multi-user Environment**: Secure isolated user sessions with persistent storage
- **Helm-Based Deployment**: Uses official JupyterHub chart with custom PySpark configuration
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes comprehensive readiness and connectivity verification
- **Databricks Replacement**: Phase 2 of complete Databricks alternative solution

## 🏗️ Architecture

### **Deployment Components**
```
JupyterHub Service Stack:
├── Helm Release (jupyterhub/jupyterhub)
├── Hub Pod (quay.io/jupyterhub/k8s-hub:4.2.0)
├── Proxy Pod (configurable-http-proxy)
├── User Scheduler Pods (2 replicas for HA)
├── Continuous Image Puller (pre-loads notebook images)
├── Service (proxy-public on port 80)
├── PersistentVolumeClaim (user data storage)
├── urbalurba-secrets (authentication credentials)
└── Singleuser Notebook Pods (jupyter/pyspark-notebook:spark-3.5.0)
```

### **File Structure**
```
10-datascience/
├── not-in-use/
    ├── 05-setup-jupyterhub.sh         # Main deployment script
    └── 05-remove-jupyterhub.sh        # Removal script

manifests/
├── 310-jupyterhub-config.yaml        # JupyterHub Helm configuration
└── 311-jupyterhub-ingress.yaml       # Ingress routing configuration

ansible/playbooks/
├── 350-setup-jupyterhub.yml          # Main deployment logic
└── 350-remove-jupyterhub.yml         # Removal logic
```

### **Databricks Replacement Architecture**
```
Phase 1: Processing Engine
├── Spark Kubernetes Operator (330-setup-spark.yml)
└── Distributed job execution and resource management

Phase 2: Notebook Interface ← THIS COMPONENT
├── JupyterHub (350-setup-jupyterhub.yml)
├── Web-based notebook environment
├── PySpark integration with Phase 1
└── Multi-user collaborative workspace
```

## 🚀 Deployment

### **Manual Deployment**
JupyterHub is currently in the `10-datascience/not-in-use` category and can be deployed manually:

```bash
# Deploy JupyterHub with default settings
cd provision-host/kubernetes/10-datascience/not-in-use/
./05-setup-jupyterhub.sh rancher-desktop

# Deploy to specific Kubernetes context
./05-setup-jupyterhub.sh multipass-microk8s
./05-setup-jupyterhub.sh azure-aks
```

### **Prerequisites**
Before deploying JupyterHub, ensure the required secrets are configured in `urbalurba-secrets`:

- `JUPYTERHUB_AUTH_PASSWORD`: JupyterHub admin authentication password

**Secrets Generation** (following rules-secrets-management.md):
```bash
# 1. Update user config with base template
cd /mnt/urbalurbadisk/topsecret
cp secrets-templates/00-master-secrets.yml.template secrets-config/00-master-secrets.yml.template

# 2. Generate and apply secrets
./create-kubernetes-secrets.sh
kubectl apply -f kubernetes/kubernetes-secrets.yml
```

## ⚙️ Configuration

### **JupyterHub Configuration**
JupyterHub uses the official JupyterHub Helm chart with PySpark-enabled notebook images:

```yaml
# From manifests/310-jupyterhub-config.yaml
hub:
  extraEnv:
    JUPYTERHUB_AUTH_PASSWORD:
      valueFrom:
        secretKeyRef:
          name: urbalurba-secrets
          key: JUPYTERHUB_AUTH_PASSWORD

  extraConfig:
    dummy-auth-config: |
      import os
      c.DummyAuthenticator.password = os.environ.get('JUPYTERHUB_AUTH_PASSWORD', 'fallback-password')

  config:
    JupyterHub:
      authenticator_class: "dummy"

singleuser:
  image:
    name: jupyter/pyspark-notebook
    tag: "spark-3.5.0"
```

### **PySpark Integration**
```yaml
# Notebook container configuration
singleuser:
  lifecycleHooks:
    postStart:
      exec:
        command:
          - "bash"
          - "-c"
          - |
            pip install --user pyspark==3.5.0 findspark plotly seaborn scikit-learn
            echo "✅ PySpark installed successfully"

  extraEnv:
    PYSPARK_PYTHON: /opt/conda/bin/python
    PYSPARK_DRIVER_PYTHON: /opt/conda/bin/python
```

### **Helm Configuration**
```bash
# Deployment command (from Ansible playbook)
helm upgrade --install jupyterhub jupyterhub/jupyterhub \
  -f manifests/310-jupyterhub-config.yaml \
  --namespace jupyterhub \
  --timeout 300s
```

### **Resource Configuration**
```yaml
# Hub resources
hub:
  resources:
    requests:
      cpu: "200m"
      memory: "512Mi"
    limits:
      cpu: "2"
      memory: "1Gi"

# Proxy resources
proxy:
  chp:
    resources:
      requests:
        cpu: "200m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "1Gi"

# User notebook resources
singleuser:
  cpu:
    limit: 2
    guarantee: 0.1
  memory:
    limit: "2G"
    guarantee: "512M"
```

### **Storage Configuration**
```yaml
# User persistent storage
singleuser:
  storage:
    dynamic:
      storageClass: local-path
    capacity: 10Gi
    homeMountPath: /home/jovyan
```

### **Authentication Configuration**
```yaml
# DummyAuthenticator for development
# Username: admin (or any username)
# Password: from JUPYTERHUB_AUTH_PASSWORD secret
hub:
  config:
    JupyterHub:
      authenticator_class: "dummy"

    DummyAuthenticator:
      # Password set via extraConfig from environment variable
      password: # Loaded from urbalurba-secrets
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -n jupyterhub

# Check hub pod specifically
kubectl get pods -n jupyterhub -l component=hub

# Check proxy pod
kubectl get pods -n jupyterhub -l component=proxy

# Check user scheduler
kubectl get pods -n jupyterhub -l component=user-scheduler

# View JupyterHub logs
kubectl logs -n jupyterhub -l component=hub
kubectl logs -n jupyterhub -l component=proxy
```

### **Service Verification**
```bash
# Check JupyterHub service
kubectl get svc -n jupyterhub proxy-public

# Check service endpoints
kubectl get endpoints -n jupyterhub proxy-public

# Check ingress status
kubectl get ingress -n jupyterhub jupyterhub

# Verify ingress configuration
kubectl describe ingress -n jupyterhub jupyterhub
```

### **JupyterHub Access Testing**
```bash
# Test cluster-internal connectivity
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n jupyterhub -- \
  curl -s -w "HTTP_CODE:%{http_code}" http://proxy-public:80

# Test authentication endpoint
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never -n jupyterhub -- \
  curl -s -w "HTTP_CODE:%{http_code}" http://proxy-public:80/hub/login
```

### **Web Interface Access**

**Primary Method - Cluster Ingress (Recommended)**:
```bash
# Access via cluster ingress (no port-forward needed)
# URL: http://jupyterhub.localhost
# Username: admin (or any username with DummyAuthenticator)
# Password: SecretPassword2 (from urbalurba-secrets)
```

**Alternative Method - Port Forward**:
```bash
# Port forward for local access
kubectl port-forward -n jupyterhub svc/proxy-public 8888:80

# Access via browser
# URL: http://localhost:8888
# Username: admin
# Password: SecretPassword2
```

**External Access** (when configured):
- URL: `https://jupyterhub.urbalurba.no` (via Cloudflare tunnel)
- Same credentials as internal access

### **Automated Verification**
The deployment includes comprehensive testing of JupyterHub functionality:

**Verification Process**:
1. **Namespace and secrets creation**: Ensures proper environment setup
2. **Helm repository management**: Adds and updates JupyterHub chart repository
3. **Two-stage pod readiness**: Waits for hub and proxy pods to be Running and Ready
4. **Service connectivity**: Verifies internal cluster communication
5. **Ingress configuration**: Applies and validates routing rules
6. **Authentication validation**: Confirms secret-based password authentication works

## 🛠️ Management Operations

### **JupyterHub Administration**
```bash
# Access JupyterHub admin panel
# Navigate to: http://jupyterhub.localhost/hub/admin
# Login with admin credentials

# Check hub configuration
kubectl exec -n jupyterhub deployment/hub -- jupyterhub --help-all

# Check active users
kubectl exec -n jupyterhub deployment/hub -- \
  python3 -c "
import requests
r = requests.get('http://localhost:8081/hub/api/users')
print(r.json())
"

# Restart hub (if needed)
kubectl rollout restart -n jupyterhub deployment/hub
```

### **User Management**
```bash
# List active user pods
kubectl get pods -n jupyterhub -l component=singleuser-server

# Check user session status
kubectl exec -n jupyterhub deployment/hub -- \
  python3 -c "
import requests
r = requests.get('http://localhost:8081/hub/api/users')
for user in r.json():
    print(f'User: {user[\"name\"]}, Server: {user.get(\"server\", \"Not running\")}')
"

# Stop user server
kubectl exec -n jupyterhub deployment/hub -- \
  python3 -c "
import requests
requests.delete('http://localhost:8081/hub/api/users/username/server')
"

# Clean up terminated user pods
kubectl delete pods -n jupyterhub -l component=singleuser-server --field-selector=status.phase=Succeeded
```

### **Notebook Environment Management**
```bash
# Check available notebook images
kubectl get pods -n jupyterhub continuous-image-puller -o yaml | grep image:

# Update notebook image
# Edit manifests/310-jupyterhub-config.yaml:
# singleuser.image.name: jupyter/pyspark-notebook
# singleuser.image.tag: "new-version"

# Apply configuration update
helm upgrade jupyterhub jupyterhub/jupyterhub \
  -f manifests/310-jupyterhub-config.yaml \
  -n jupyterhub

# Force pull new images
kubectl delete pods -n jupyterhub -l app=jupyterhub,component=continuous-image-puller
```

### **PySpark Integration Management**
```bash
# Check PySpark installation in user pod
kubectl exec -n jupyterhub <user-pod-name> -- python3 -c "import pyspark; print(pyspark.__version__)"

# Test Spark session creation
kubectl exec -n jupyterhub <user-pod-name> -- python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('test').getOrCreate()
print('✅ Spark session created successfully')
spark.stop()
"

# Check available Python packages
kubectl exec -n jupyterhub <user-pod-name> -- pip list | grep -E 'pyspark|findspark|plotly|seaborn|scikit-learn'
```

### **Service Removal**
```bash
# Remove JupyterHub service (preserves user data by default)
cd provision-host/kubernetes/10-datascience/not-in-use/
./05-remove-jupyterhub.sh rancher-desktop

# Completely remove including user data
ansible-playbook ansible/playbooks/350-remove-jupyterhub.yml \
  -e target_host=rancher-desktop
```

**Removal Process**:
- Terminates all active user sessions
- Uninstalls JupyterHub Helm release
- Waits for all pods to terminate
- Removes ingress configuration
- Preserves urbalurba-secrets and namespace structure
- Provides user data retention options and recovery instructions

## 🔧 Troubleshooting

### **Common Issues**

**Hub Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -n jupyterhub -l component=hub
kubectl logs -n jupyterhub -l component=hub

# Check secret availability
kubectl get secret -n jupyterhub urbalurba-secrets
kubectl get secret -n jupyterhub urbalurba-secrets -o jsonpath='{.data.JUPYTERHUB_AUTH_PASSWORD}' | base64 -d

# Check hub configuration
kubectl get configmap -n jupyterhub hub -o yaml
```

**Authentication Issues**:
```bash
# Check JupyterHub credentials in secrets
kubectl get secret -n jupyterhub urbalurba-secrets -o jsonpath="{.data.JUPYTERHUB_AUTH_PASSWORD}" | base64 -d

# Test authentication via hub API
kubectl exec -n jupyterhub deployment/hub -- \
  curl -X POST http://localhost:8081/hub/login \
  -d "username=admin&password=SecretPassword2"

# Check authenticator configuration
kubectl logs -n jupyterhub -l component=hub | grep -i auth
```

**User Server Startup Issues**:
```bash
# Check user pod status
kubectl get pods -n jupyterhub -l component=singleuser-server
kubectl describe pod -n jupyterhub <user-pod-name>

# Check user server logs
kubectl logs -n jupyterhub <user-pod-name>

# Check image pull status
kubectl get events -n jupyterhub --field-selector involvedObject.kind=Pod

# Check storage availability
kubectl get pvc -n jupyterhub
kubectl describe pvc -n jupyterhub <user-pvc-name>
```

**Ingress and Connectivity Issues**:
```bash
# Verify ingress configuration
kubectl describe ingress -n jupyterhub jupyterhub
kubectl get ingress -n jupyterhub jupyterhub -o yaml

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it -n jupyterhub -- \
  wget -qO- http://proxy-public:80

# Check Traefik ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup proxy-public.jupyterhub.svc.cluster.local
```

**PySpark Integration Issues**:
```bash
# Check PySpark installation
kubectl exec -n jupyterhub <user-pod-name> -- python3 -c "
try:
    import pyspark
    print(f'✅ PySpark {pyspark.__version__} installed')
except ImportError as e:
    print(f'❌ PySpark not available: {e}')
"

# Check Spark driver configuration
kubectl exec -n jupyterhub <user-pod-name> -- python3 -c "
import os
print(f'PYSPARK_PYTHON: {os.environ.get(\"PYSPARK_PYTHON\", \"Not set\")}')
print(f'PYSPARK_DRIVER_PYTHON: {os.environ.get(\"PYSPARK_DRIVER_PYTHON\", \"Not set\")}')
"

# Test Spark cluster connectivity (if Spark Operator deployed)
kubectl exec -n jupyterhub <user-pod-name> -- python3 -c "
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName('connectivity-test') \
    .config('spark.kubernetes.container.image', 'jupyter/pyspark-notebook:spark-3.5.0') \
    .getOrCreate()
print('✅ Spark session with Kubernetes backend created')
spark.stop()
"
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod -n jupyterhub

# Monitor hub performance
kubectl logs -n jupyterhub -l component=hub --tail=100 | grep -E 'ERROR|WARNING|memory|cpu'

# Check user pod resource limits
kubectl describe pod -n jupyterhub <user-pod-name> | grep -A 5 -B 5 Resources

# Monitor active sessions
kubectl exec -n jupyterhub deployment/hub -- \
  python3 -c "
import requests
r = requests.get('http://localhost:8081/hub/api/users')
active_users = [u for u in r.json() if u.get('server')]
print(f'Active sessions: {len(active_users)}')
for user in active_users:
    print(f'- {user[\"name\"]}: {user[\"server\"][\"state\"]}')
"
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **User Session Monitoring**: Monitor active sessions and resource usage
3. **Storage Monitoring**: Monitor user storage usage and PVC capacity
4. **Image Updates**: Keep notebook images updated with latest packages
5. **Secret Rotation**: Follow urbalurba-secrets rotation procedures

### **Backup Procedures**
```bash
# Export user data (requires access to persistent volumes)
kubectl get pvc -n jupyterhub
for pvc in $(kubectl get pvc -n jupyterhub -o name); do
  echo "Backing up $pvc"
  kubectl cp -n jupyterhub $(kubectl get pod -n jupyterhub -o name | head -1):$(kubectl get $pvc -o jsonpath='{.spec.volumeName}') \
    ./jupyterhub-backup-$(date +%Y%m%d)/$pvc/
done

# Export JupyterHub configuration
kubectl get configmap -n jupyterhub hub -o yaml > jupyterhub-config-backup-$(date +%Y%m%d).yaml

# Export user database (if applicable)
kubectl exec -n jupyterhub deployment/hub -- \
  python3 -c "
import sqlite3
import shutil
shutil.copy('/srv/jupyterhub/jupyterhub.sqlite', '/tmp/jupyterhub-backup.sqlite')
"
kubectl cp -n jupyterhub deployment/hub:/tmp/jupyterhub-backup.sqlite ./jupyterhub-db-backup-$(date +%Y%m%d).sqlite
```

### **Disaster Recovery**
```bash
# Restore from PVC backup
# (Requires recreation of PVCs and pod restart)
kubectl delete pvc -n jupyterhub <user-pvc-name>
kubectl apply -f <restored-pvc-manifest>

# Restore JupyterHub configuration
kubectl apply -f jupyterhub-config-backup.yaml

# Restart JupyterHub components
kubectl rollout restart -n jupyterhub deployment/hub
kubectl rollout restart -n jupyterhub deployment/proxy
```

## 🚀 Use Cases

### **Data Science Workflow**
```python
# In JupyterHub notebook
import pandas as pd
import numpy as np
from pyspark.sql import SparkSession

# Create Spark session
spark = SparkSession.builder \
    .appName("DataScienceWorkflow") \
    .getOrCreate()

# Load data
df = spark.read.csv("/path/to/data.csv", header=True, inferSchema=True)

# Data processing
df_processed = df.filter(df.value > 100) \
    .groupBy("category") \
    .agg({"value": "avg"}) \
    .orderBy("category")

# Convert to Pandas for visualization
pandas_df = df_processed.toPandas()

# Visualization with plotly
import plotly.express as px
fig = px.bar(pandas_df, x='category', y='avg(value)')
fig.show()

spark.stop()
```

### **Machine Learning Pipeline**
```python
# In JupyterHub notebook
from pyspark.ml import Pipeline
from pyspark.ml.feature import VectorAssembler, StandardScaler
from pyspark.ml.classification import RandomForestClassifier
from pyspark.ml.evaluation import BinaryClassificationEvaluator

# Load and prepare data
df = spark.read.parquet("/path/to/ml_data.parquet")

# Feature engineering
assembler = VectorAssembler(inputCols=["feature1", "feature2", "feature3"], outputCol="features")
scaler = StandardScaler(inputCol="features", outputCol="scaled_features")
rf = RandomForestClassifier(featuresCol="scaled_features", labelCol="label")

# Create pipeline
pipeline = Pipeline(stages=[assembler, scaler, rf])

# Train model
train_data, test_data = df.randomSplit([0.8, 0.2], seed=42)
model = pipeline.fit(train_data)

# Evaluate model
predictions = model.transform(test_data)
evaluator = BinaryClassificationEvaluator(labelCol="label", metricName="areaUnderROC")
auc = evaluator.evaluate(predictions)
print(f"AUC: {auc}")
```

### **Distributed Data Processing**
```python
# In JupyterHub notebook
from pyspark.sql.functions import col, count, avg, max, min
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

# Process large dataset with Spark
large_df = spark.read.option("multiline", "true") \
    .json("/path/to/large_dataset.json")

# Distributed aggregations
summary = large_df.groupBy("region") \
    .agg(
        count("*").alias("total_records"),
        avg("sales").alias("avg_sales"),
        max("sales").alias("max_sales"),
        min("sales").alias("min_sales")
    )

# Write results to distributed storage
summary.coalesce(1) \
    .write \
    .mode("overwrite") \
    .option("header", "true") \
    .csv("/path/to/output/summary")

# Show results
summary.show()
```

### **Collaborative Data Exploration**
```python
# Shared notebook accessible by multiple users
import seaborn as sns
import matplotlib.pyplot as plt

# Load shared dataset
shared_df = spark.read.table("shared_catalog.analysis_data")

# Convert to Pandas for detailed analysis
pandas_df = shared_df.sample(fraction=0.1).toPandas()

# Create visualizations
plt.figure(figsize=(12, 8))
sns.pairplot(pandas_df, hue='category')
plt.title('Data Exploration - Shared Analysis')
plt.savefig('/shared/analysis_results.png')
plt.show()

# Save insights for team
insights = pandas_df.describe()
insights.to_csv('/shared/dataset_insights.csv')
```

---

**💡 Key Insight**: JupyterHub provides an essential web-based notebook environment that enables data scientists and ML engineers to perform interactive data analysis, build machine learning models, and execute distributed data processing workflows. As Phase 2 of the Databricks replacement project, it integrates seamlessly with Spark Kubernetes Operator to provide a complete alternative to Databricks workspace functionality.