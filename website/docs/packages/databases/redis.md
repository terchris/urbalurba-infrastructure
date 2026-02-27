# Redis - In-Memory Data Store and Cache

**Key Features**: High-Performance Caching • Session Storage • Message Queuing • Real-Time Analytics • Pub/Sub Messaging • Data Structures • Persistence

**File**: `docs/package-databases-redis.md`
**Purpose**: Complete guide to Redis deployment and configuration in Urbalurba infrastructure
**Target Audience**: Developers, DevOps engineers, backend developers working with caching and real-time data
**Last Updated**: September 22, 2024

## 📋 Overview

Redis serves as the **primary in-memory data store and cache** in the Urbalurba infrastructure. It provides high-performance caching, session storage, message queuing, and real-time data processing capabilities for modern applications.

**Key Features**:
- **High-Performance Cache**: Sub-millisecond latency for read/write operations
- **Data Structures**: Strings, hashes, lists, sets, sorted sets, bitmaps, and streams
- **Persistence**: Configurable data persistence with RDB snapshots
- **Helm-Based Deployment**: Uses Bitnami Redis chart with custom configuration
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes comprehensive connectivity and data operation verification
- **Standalone Architecture**: Single-instance deployment for simplicity and reliability

## 🏗️ Architecture

### **Deployment Components**
```
Redis Service Stack:
├── Helm Release (bitnami/redis)
├── StatefulSet (redis:8.2.1 container)
├── ConfigMap (Redis configuration)
├── Service (ClusterIP on port 6379)
├── PersistentVolumeClaim (6GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (redis container with auth enabled)
```

### **File Structure**
```
03-queues/
├── 06-setup-redis.sh           # Main deployment script (active)
└── not-in-use/
    └── 06-remove-redis.sh      # Removal script

manifests/
└── 050-redis-config.yaml      # Redis Helm configuration

ansible/playbooks/
├── 050-setup-redis.yml        # Main deployment logic
└── 050-remove-redis.yml       # Removal logic
```

## 🚀 Deployment

### **Manual Deployment**
Redis is currently in the `03-queues` category and can be deployed manually:

```bash
# Deploy Redis with default settings
cd provision-host/kubernetes/03-queues/
./06-setup-redis.sh rancher-desktop

# Deploy to specific Kubernetes context
./06-setup-redis.sh multipass-microk8s
./06-setup-redis.sh azure-aks
```

### **Prerequisites**
Before deploying Redis, ensure the required secrets are configured in `urbalurba-secrets`:

- `REDIS_PASSWORD`: Redis authentication password

## ⚙️ Configuration

### **Redis Configuration**
Redis uses the official Redis 8.2.1 image with authentication enabled:

```yaml
# From manifests/050-redis-config.yaml
image:
  registry: docker.io
  repository: redis
  tag: 8.2.1
  pullPolicy: IfNotPresent

auth:
  enabled: true
  # Password set by playbook using --set global.redis.password=<password>

architecture: standalone  # Single instance for simplicity
```

### **Helm Configuration**
```bash
# Deployment command (from Ansible playbook)
helm install redis bitnami/redis \
  -f manifests/050-redis-config.yaml \
  --set global.redis.password="$REDIS_PASSWORD"
```

### **Resource Configuration**
```yaml
# Resource limits and requests
master:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

  # Storage configuration
  persistence:
    enabled: true
    size: 6Gi
```

### **Service Configuration**
```yaml
# Service settings
service:
  type: ClusterIP

# Replica configuration (disabled for standalone)
replica:
  replicaCount: 0

# Metrics (disabled by default)
metrics:
  enabled: false
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=redis

# Check StatefulSet status
kubectl get statefulset redis-master

# Check service status
kubectl get svc redis-master

# View Redis logs
kubectl logs -l app.kubernetes.io/name=redis
```

### **Redis Connection Testing**
```bash
# Test connection from within cluster (requires password)
kubectl run redis-client --image=redis:8.2.1 --rm -it --restart=Never -- \
  redis-cli -h redis-master.default.svc.cluster.local -a yourpassword

# Check if Redis is ready
kubectl exec -it redis-master-0 -- redis-cli ping

# Test with authentication (replace yourpassword)
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword ping
```

### **Data Operations Testing**
```bash
# Connect to Redis CLI
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword

# Basic operations
SET hello world
GET hello
EXISTS hello
DEL hello

# List operations
LPUSH mylist "item1" "item2" "item3"
LRANGE mylist 0 -1
LPOP mylist

# Hash operations
HSET user:1000 name "John Doe" email "john@example.com"
HGET user:1000 name
HGETALL user:1000

# Set operations
SADD myset "member1" "member2" "member3"
SMEMBERS myset
SISMEMBER myset "member1"
```

### **Automated Verification**
The deployment includes comprehensive testing of Redis functionality:

**Verification Process**:
1. Connects to Redis server using authentication
2. Tests basic SET/GET operations
3. Performs data structure operations (lists, hashes, sets)
4. Validates authentication and connectivity
5. Verifies persistence and data integrity

## 🛠️ Management Operations

### **Redis Administration**
```bash
# Access Redis CLI with authentication
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword

# Get Redis info
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info

# Check memory usage
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info memory

# Check connected clients
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info clients

# Monitor Redis commands in real-time
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword monitor
```

### **Advanced Operations**
```bash
# Configure Redis settings
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword config set maxmemory 256mb
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword config set maxmemory-policy allkeys-lru

# Check current configuration
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword config get "*"

# Flush databases (careful!)
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword flushdb   # Current DB
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword flushall  # All DBs

# Check Redis statistics
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info stats
```

### **Backup Operations**
```bash
# Create Redis backup (RDB snapshot)
kubectl exec redis-master-0 -- redis-cli -a yourpassword bgsave

# Check last save time
kubectl exec redis-master-0 -- redis-cli -a yourpassword lastsave

# Copy RDB file from pod
kubectl cp redis-master-0:/data/dump.rdb ./redis-backup.rdb

# Restore from backup (requires Redis restart)
kubectl cp ./redis-backup.rdb redis-master-0:/data/dump.rdb
kubectl delete pod redis-master-0  # Pod will restart and load backup
```

### **Service Removal**
```bash
# Remove Redis service (preserves data by default)
cd provision-host/kubernetes/03-queues/not-in-use/
./06-remove-redis.sh rancher-desktop

# Completely remove including data
ansible-playbook ansible/playbooks/050-remove-redis.yml \
  -e target_host=rancher-desktop
```

**Removal Process**:
- Uninstalls Redis Helm release
- Waits for pods to terminate
- Removes persistent volume claims
- Preserves urbalurba-secrets and namespace structure
- Provides data retention options and recovery instructions

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=redis
kubectl logs -l app.kubernetes.io/name=redis

# Check Redis configuration
kubectl describe configmap redis-configuration
```

**Authentication Issues**:
```bash
# Check Redis password in secrets
kubectl get secret urbalurba-secrets -o jsonpath="{.data.REDIS_PASSWORD}" | base64 -d

# Test authentication
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword auth yourpassword

# Check Redis auth configuration
kubectl exec -it redis-master-0 -- redis-cli config get requirepass
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc redis-master
kubectl get endpoints redis-master

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup redis-master.default.svc.cluster.local

# Check Redis server status
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info server
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod redis-master-0

# Monitor Redis performance
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info stats

# Check slow log
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword slowlog get 10

# Monitor Redis operations
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword monitor
```

**Memory Issues**:
```bash
# Check memory usage
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info memory

# Check memory configuration
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword config get maxmemory*

# Check eviction statistics
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info stats | grep evicted
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **Memory Monitoring**: Monitor memory usage and eviction patterns
3. **Backup Schedule**: Implement regular RDB snapshots for data persistence
4. **Performance Monitoring**: Monitor command execution times and client connections

### **Backup Procedures**
```bash
# Manual backup creation
kubectl exec redis-master-0 -- redis-cli -a yourpassword bgsave

# Automated backup script
kubectl exec redis-master-0 -- redis-cli -a yourpassword config set save "900 1 300 10 60 10000"

# Export specific keys
kubectl exec redis-master-0 -- redis-cli -a yourpassword --scan --pattern "user:*" | \
  xargs kubectl exec redis-master-0 -- redis-cli -a yourpassword dump

# Copy backup file
kubectl cp redis-master-0:/data/dump.rdb ./backup-$(date +%Y%m%d).rdb
```

### **Disaster Recovery**
```bash
# Restore from RDB backup
kubectl cp ./backup.rdb redis-master-0:/data/dump.rdb
kubectl delete pod redis-master-0  # Restart to load backup

# Verify restore
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword dbsize
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword info keyspace
```

## 🚀 Use Cases

### **Caching**
```bash
# Application cache pattern
SET cache:user:1000 '{"name":"John","email":"john@example.com"}' EX 3600
GET cache:user:1000

# Cache invalidation
DEL cache:user:1000
FLUSHDB  # Clear all cache
```

### **Session Storage**
```bash
# Store user session
HSET session:abc123 user_id 1000 login_time 1672531200 last_activity 1672534800
EXPIRE session:abc123 1800  # 30 minutes TTL

# Retrieve session data
HGETALL session:abc123
TTL session:abc123
```

### **Message Queuing**
```bash
# Producer: Add tasks to queue
LPUSH task_queue '{"type":"email","recipient":"user@example.com","subject":"Welcome"}'
LPUSH task_queue '{"type":"notification","user_id":1000,"message":"New message"}'

# Consumer: Process tasks from queue
BRPOP task_queue 10  # Blocking pop with 10-second timeout
```

### **Real-time Analytics**
```bash
# Increment counters
INCR page_views:home
INCR user_actions:1000:login

# Time-series data
ZADD user_scores 100 "user1" 150 "user2" 200 "user3"
ZRANGE user_scores 0 -1 WITHSCORES

# Rate limiting
INCR rate_limit:api:user:1000
EXPIRE rate_limit:api:user:1000 3600
```


---

**💡 Key Insight**: Redis provides essential in-memory data storage and caching capabilities that complement the primary PostgreSQL database. Use Redis for high-frequency read/write operations, session management, real-time features, and as a performance multiplier for database-backed applications.