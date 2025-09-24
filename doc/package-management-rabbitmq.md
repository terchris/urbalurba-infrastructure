# RabbitMQ Management - Message Broker Administration Interface

**Web Interface**: Queue Management • Exchange Administration • User Management • Message Monitoring • Connection Tracking • Virtual Host Configuration • Performance Metrics

**File**: `doc/package-management-rabbitmq.md`
**Purpose**: Complete guide to RabbitMQ management UI usage and administration in Urbalurba infrastructure
**Target Audience**: Message queue administrators, developers working with AMQP, system architects using pub/sub patterns
**Last Updated**: September 23, 2024

## 📋 Overview

The RabbitMQ Management Interface provides a **comprehensive web-based administration console** for the RabbitMQ message broker in the Urbalurba infrastructure. This interface is automatically deployed as part of the RabbitMQ installation and offers complete management capabilities for queues, exchanges, users, and system monitoring.

**Key Features**:
- **Web-Based Interface**: Complete RabbitMQ administration via browser
- **Automatic Deployment**: Management UI included with RabbitMQ installation
- **Queue Management**: Create, monitor, and manage message queues
- **Exchange Administration**: Configure routing and message distribution
- **User & Permission Management**: Control access and virtual host permissions
- **Real-Time Monitoring**: Live message rates, connection tracking, and performance metrics
- **DNS-Based Routing**: Accessible via `rabbitmq.localhost` with multi-domain support
- **Integrated Authentication**: Uses RabbitMQ's built-in user system with urbalurba-secrets

## 🏗️ Architecture

### **Management UI Components**
```
RabbitMQ Management Stack:
├── RabbitMQ Server (with management plugin enabled)
├── Management UI (embedded web interface on port 15672)
├── Service (ClusterIP exposing AMQP 5672 and Management 15672)
├── IngressRoute (Traefik routing for rabbitmq.localhost)
├── urbalurba-secrets (administrative credentials)
└── Authentication (RabbitMQ built-in user management)
```

### **Related Infrastructure Files**
```
RabbitMQ Deployment:
├── provision-host/kubernetes/03-queues/08-setup-rabbitmq.sh  # Main deployment
├── manifests/080-rabbitmq-config.yaml                       # RabbitMQ configuration
├── manifests/081-rabbitmq-ingressroute.yaml                 # Management UI routing
├── ansible/playbooks/080-setup-rabbitmq.yml                # Deployment automation
└── doc/package-queues-rabbitmq.md                          # RabbitMQ deployment guide
```

## 🌐 Access & Authentication

### **Web Interface Access**
```bash
# Primary access via DNS routing
http://rabbitmq.localhost

# Port-forward access (alternative)
kubectl port-forward svc/rabbitmq 15672:15672
# Then access: http://localhost:15672
```

### **Login Credentials**
RabbitMQ management uses credentials configured in `urbalurba-secrets` based on the secrets-templates:

```bash
# Get RabbitMQ credentials from urbalurba-secrets
kubectl get secret urbalurba-secrets -o jsonpath='{.data.RABBITMQ_USERNAME}' | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath='{.data.RABBITMQ_PASSWORD}' | base64 -d
```

**From secrets-templates configuration:**
- **Username**: `rabbitmq-admin`
- **Password**: Uses `${DEFAULT_DATABASE_PASSWORD}` (your configured default password)

**Login Process:**
1. Navigate to `http://rabbitmq.localhost`
2. Enter username: `rabbitmq-admin`
3. Enter password: (your DEFAULT_DATABASE_PASSWORD value)
4. Click "Login" to access the management interface

## 🛠️ Management Operations

### **Queue Management**
Through RabbitMQ Management UI:

#### **Create Queues**
1. Navigate to **"Queues and Streams"** tab
2. Click **"Add a new queue"**
3. Configure queue properties:
   - **Name**: Queue identifier
   - **Durability**: Survive broker restarts
   - **Auto Delete**: Delete when unused
   - **Arguments**: Additional queue configuration
4. Click **"Add queue"**

#### **Monitor Queues**
- **Message Rates**: View publish/deliver/acknowledge rates
- **Queue Depth**: Monitor message backlog
- **Consumer Count**: Track active consumers
- **Queue Details**: Memory usage, state, and configuration

#### **Queue Operations**
```bash
# Queue management through UI:
# - Purge messages: Remove all messages from queue
# - Delete queue: Permanently remove queue
# - Publish message: Send test messages
# - Get messages: Retrieve and inspect messages
```

### **Exchange Management**
Through RabbitMQ Management UI:

#### **Create Exchanges**
1. Navigate to **"Exchanges"** tab
2. Click **"Add a new exchange"**
3. Configure exchange properties:
   - **Name**: Exchange identifier
   - **Type**: direct, topic, fanout, headers
   - **Durability**: Persist through restarts
   - **Auto Delete**: Remove when unbounded
4. Click **"Add exchange"**

#### **Binding Management**
- **Create Bindings**: Link exchanges to queues with routing keys
- **View Bindings**: Monitor routing relationships
- **Test Routing**: Publish messages to test routing logic

### **User Management**
Through RabbitMQ Management UI:

#### **Create Users**
1. Navigate to **"Admin"** → **"Users"** tab
2. Click **"Add a user"**
3. Configure user properties:
   - **Username**: User identifier
   - **Password**: User password
   - **Tags**: Admin, monitoring, policymaker, management
4. Click **"Add user"**

#### **Virtual Host Management**
1. Navigate to **"Admin"** → **"Virtual Hosts"** tab
2. Click **"Add a new virtual host"**
3. Set virtual host name and description
4. Configure user permissions for virtual host

#### **Permission Management**
- **Set Permissions**: Configure read/write/configure access
- **Virtual Host Access**: Control user access to virtual hosts
- **Policy Management**: Set queue and exchange policies

### **Monitoring & Diagnostics**

#### **Overview Dashboard**
- **Global Statistics**: Message rates, queue totals, connection counts
- **Node Information**: Memory usage, disk space, Erlang version
- **Import/Export**: Configuration backup and restore

#### **Connection Monitoring**
1. Navigate to **"Connections"** tab
2. Monitor active connections:
   - **Client Information**: IP addresses, protocols, users
   - **Channel Count**: Active channels per connection
   - **Data Rates**: Bytes in/out per connection
   - **Connection State**: Running, blocking, flow control

#### **Performance Monitoring**
```bash
# Through Management UI:
# - Message rates: Real-time publish/deliver/acknowledge rates
# - Memory usage: Per-queue and total broker memory
# - Disk usage: Message persistence and logging
# - Network I/O: Connection bandwidth utilization
```

## 🔍 Health Checks & Verification

### **Service Status Verification**
```bash
# Check RabbitMQ pod status
kubectl get pods -l app.kubernetes.io/name=rabbitmq

# Check RabbitMQ service status
kubectl get svc rabbitmq

# Check management UI routing
kubectl get ingressroute rabbitmq-management

# View RabbitMQ logs
kubectl logs -l app.kubernetes.io/name=rabbitmq
```

### **Management UI Testing**
```bash
# Test HTTP response from within cluster
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -w "HTTP_CODE:%{http_code}" http://rabbitmq:15672/

# Test DNS routing
curl -H "Host: rabbitmq.localhost" http://localhost/

# Test authentication endpoint
curl -u rabbitmq-admin:$RABBITMQ_PASSWORD http://rabbitmq.localhost/api/overview
```

### **AMQP Connectivity Testing**
```bash
# Test AMQP port connectivity
kubectl run test-pod --image=busybox --rm -it -- \
  nc -zv rabbitmq.default.svc.cluster.local 5672

# Test management API
kubectl exec -it rabbitmq-0 -- \
  rabbitmqctl status
```

## 🎯 Common Administration Tasks

### **Message Queue Workflows**

#### **Basic Pub/Sub Setup**
1. **Create Exchange**: Name: `events`, Type: `fanout`
2. **Create Queues**: `notifications`, `logging`, `analytics`
3. **Bind Queues**: Bind all queues to `events` exchange
4. **Test Publishing**: Send message to `events` exchange
5. **Verify Distribution**: Check messages appear in all queues

#### **Topic-Based Routing**
1. **Create Exchange**: Name: `logs`, Type: `topic`
2. **Create Queues**: `error.logs`, `info.logs`, `debug.logs`
3. **Bind with Patterns**:
   - `error.logs` ← `*.error.*`
   - `info.logs` ← `*.info.*`
   - `debug.logs` ← `*.debug.*`
4. **Test Routing**: Publish with routing keys like `app.error.auth`

### **User & Permission Setup**

#### **Application User Creation**
1. **Create User**: Username: `app-service`, Password: `[secure-password]`
2. **Set Tags**: `none` (no administrative access)
3. **Virtual Host**: Grant access to `/` (default vhost)
4. **Permissions**:
   - **Configure**: `app\..*` (can create resources matching pattern)
   - **Write**: `app\..*` (can publish to matching resources)
   - **Read**: `app\..*` (can consume from matching resources)

#### **Monitoring User Setup**
1. **Create User**: Username: `monitor`, Password: `[monitor-password]`
2. **Set Tags**: `monitoring` (read-only monitoring access)
3. **Virtual Host**: Grant access to `/`
4. **Permissions**: Read-only access to view statistics

### **Performance Optimization**

#### **Queue Configuration**
```bash
# Through Management UI - Queue Arguments:
# x-max-length: 10000           # Maximum queue size
# x-message-ttl: 3600000        # Message TTL (1 hour)
# x-max-priority: 10            # Priority queue support
# x-dead-letter-exchange: dlx   # Dead letter handling
```

#### **Memory Management**
- **Queue Memory**: Monitor per-queue memory usage
- **Message Paging**: Configure disk paging for large queues
- **Memory Alarms**: Set memory high watermark limits
- **Disk Space**: Monitor disk space for message persistence

## 🔧 Troubleshooting

### **Common Issues**

**Cannot Access Management UI**:
```bash
# Verify RabbitMQ pod is running
kubectl describe pod -l app.kubernetes.io/name=rabbitmq

# Check management plugin status
kubectl exec -it rabbitmq-0 -- rabbitmq-plugins list

# Verify service endpoints
kubectl describe svc rabbitmq
```

**Authentication Failures**:
```bash
# Verify credentials in secrets
kubectl get secret urbalurba-secrets -o jsonpath='{.data.RABBITMQ_USERNAME}' | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath='{.data.RABBITMQ_PASSWORD}' | base64 -d

# Check RabbitMQ user list
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_users
```

**Queue Connection Issues**:
```bash
# Test AMQP connectivity
kubectl run test-pod --image=busybox --rm -it -- \
  nc -zv rabbitmq.default.svc.cluster.local 5672

# Check RabbitMQ cluster status
kubectl exec -it rabbitmq-0 -- rabbitmqctl cluster_status

# View connection logs
kubectl logs -l app.kubernetes.io/name=rabbitmq --tail=50
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod -l app.kubernetes.io/name=rabbitmq

# Monitor queue memory usage through management UI
# Navigate to Queues tab and check memory column

# Check disk space
kubectl exec -it rabbitmq-0 -- df -h
```

**DNS Resolution Issues**:
```bash
# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup rabbitmq.default.svc.cluster.local

# Verify IngressRoute configuration
kubectl describe ingressroute rabbitmq-management

# Test different domain patterns
curl -H "Host: rabbitmq.localhost" http://127.0.0.1/
```

## 📋 Maintenance & Monitoring

### **Regular Maintenance Tasks**
1. **Queue Monitoring**: Check queue depths and consumer activity
2. **Connection Tracking**: Monitor client connections and channels
3. **Memory Usage**: Track broker memory and disk utilization
4. **User Access Review**: Audit user permissions and access patterns
5. **Configuration Backup**: Export broker configuration regularly

### **Backup Procedures**
```bash
# Export RabbitMQ configuration
kubectl exec -it rabbitmq-0 -- rabbitmqctl export_definitions /tmp/definitions.json

# Copy configuration backup
kubectl cp rabbitmq-0:/tmp/definitions.json ./rabbitmq-definitions-backup.json

# Backup persistent data
kubectl exec -it rabbitmq-0 -- tar -czf /tmp/rabbitmq-data.tar.gz /bitnami/rabbitmq/mnesia
kubectl cp rabbitmq-0:/tmp/rabbitmq-data.tar.gz ./rabbitmq-data-backup.tar.gz
```

### **Performance Monitoring**
```bash
# Through Management UI:
# - Overview: Global message rates and resource usage
# - Queues: Per-queue statistics and memory usage
# - Connections: Client connection details and data rates
# - Channels: Channel-level statistics and flow control
# - Exchanges: Message routing statistics
```

### **Disaster Recovery**
```bash
# Restore configuration (after RabbitMQ restart)
kubectl cp ./rabbitmq-definitions-backup.json rabbitmq-0:/tmp/definitions.json
kubectl exec -it rabbitmq-0 -- rabbitmqctl import_definitions /tmp/definitions.json

# Restore data files (requires pod restart)
kubectl cp ./rabbitmq-data-backup.tar.gz rabbitmq-0:/tmp/rabbitmq-data.tar.gz
kubectl exec -it rabbitmq-0 -- tar -xzf /tmp/rabbitmq-data.tar.gz -C /
```

## 📚 Related Documentation

- **[package-queues-rabbitmq.md](./package-queues-rabbitmq.md)** - RabbitMQ deployment and configuration
- **[rules-ingress-traefik.md](./rules-ingress-traefik.md)** - Traefik IngressRoute configuration standards
- **[secrets-management-readme.md](./secrets-management-readme.md)** - Managing RabbitMQ credentials in urbalurba-secrets

## 🔗 External Resources

- **[RabbitMQ Management Plugin Documentation](https://www.rabbitmq.com/docs/management)** - Official management UI guide
- **[RabbitMQ Admin Guide](https://www.rabbitmq.com/docs/admin-guide)** - Administrative operations reference
- **[AMQP 0-9-1 Protocol](https://www.rabbitmq.com/docs/amqp-0-9-1-reference)** - Protocol specification and concepts

---

**💡 Key Insight**: The RabbitMQ Management Interface provides comprehensive administrative control over the message broker through an intuitive web interface. Unlike separate management tools, it's integrated directly into RabbitMQ and offers real-time monitoring, queue management, and user administration in a single interface accessible via standard cluster DNS routing.