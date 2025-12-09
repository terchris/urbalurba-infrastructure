# RabbitMQ - Message Broker and Queue System

**Key Features**: Message Queuing • Pub/Sub Messaging • Routing & Exchange • Reliability & Durability • Management UI • Clustering Support • Authentication

**File**: `docs/package-queues-rabbitmq.md`
**Purpose**: Complete guide to RabbitMQ deployment and configuration in Urbalurba infrastructure
**Target Audience**: Developers, DevOps engineers, backend developers working with message queues and asynchronous systems
**Last Updated**: September 23, 2025

## 📋 Overview

RabbitMQ serves as the **primary message broker and queue system** in the Urbalurba infrastructure. It provides reliable message queuing, publish/subscribe messaging, and advanced routing capabilities for distributed and microservices architectures.

**Key Features**:
- **Message Broker**: Advanced message routing with exchanges, queues, and bindings
- **Reliability**: Message persistence, acknowledgments, and delivery guarantees
- **Management UI**: Web-based administration and monitoring interface
- **Helm-Based Deployment**: Uses Bitnami RabbitMQ chart with secure configuration
- **Secret Management**: Integrates with urbalurba-secrets for secure authentication
- **Automated Testing**: Includes comprehensive connectivity and API verification
- **Standalone Architecture**: Single-instance deployment for simplicity and resource efficiency

## 🏗️ Architecture

### **Deployment Components**
```
RabbitMQ Service Stack:
├── Helm Release (bitnami/rabbitmq)
├── StatefulSet (rabbitmq:4.1.3 container)
├── ConfigMap (RabbitMQ configuration)
├── Service (ClusterIP on port 5672 AMQP, 15672 Management)
├── PersistentVolumeClaim (8GB storage)
├── urbalurba-secrets (authentication credentials)
└── Pod (rabbitmq container with management plugin enabled)
```

### **File Structure**
```
03-queues/
├── not-in-use/
    ├── 08-setup-rabbitmq.sh       # Main deployment script
    └── 08-remove-rabbitmq.sh      # Removal script

manifests/
└── 080-rabbitmq-config.yaml      # RabbitMQ Helm configuration

ansible/playbooks/
├── 080-setup-rabbitmq.yml        # Main deployment logic
└── 080-remove-rabbitmq.yml       # Removal logic
```

## 🚀 Deployment

### **Manual Deployment**
RabbitMQ is currently in the `03-queues/not-in-use` category and can be deployed manually:

```bash
# Deploy RabbitMQ with default settings
cd provision-host/kubernetes/03-queues/not-in-use/
./08-setup-rabbitmq.sh rancher-desktop

# Deploy to specific Kubernetes context
./08-setup-rabbitmq.sh multipass-microk8s
./08-setup-rabbitmq.sh azure-aks
```

### **Prerequisites**
Before deploying RabbitMQ, ensure the required secrets are configured in `urbalurba-secrets`:

- `RABBITMQ_USERNAME`: RabbitMQ admin username
- `RABBITMQ_PASSWORD`: RabbitMQ admin password

## ⚙️ Configuration

### **RabbitMQ Configuration**
RabbitMQ uses the Bitnami RabbitMQ 4.1.3 image with authentication and management plugin enabled:

```yaml
# From manifests/080-rabbitmq-config.yaml
service:
  type: ClusterIP

replicaCount: 1  # Single instance for simplicity

auth:
  username: # Set by playbook using --set auth.username=<username>
  password: # Set by playbook using --set auth.password=<password>
  generateErlangCookie: true

plugins: "rabbitmq_management"  # Management UI enabled

architecture: standalone
```

### **Helm Configuration**
```bash
# Deployment command (from Ansible playbook)
helm upgrade --install rabbitmq bitnami/rabbitmq \
  -f manifests/080-rabbitmq-config.yaml \
  --set auth.username="$RABBITMQ_USERNAME" \
  --set auth.password="$RABBITMQ_PASSWORD"
```

### **Resource Configuration**
```yaml
# Resource limits and requests
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# Storage configuration
persistence:
  enabled: true
  size: 8Gi
  accessMode: ReadWriteOnce
```

### **Security Configuration**
```yaml
# Authentication configuration
auth:
  generateErlangCookie: true  # Prevents cookie mismatch issues

# Memory management
extraConfiguration: |
  vm_memory_high_watermark.relative = 0.4
```

## 🔍 Monitoring & Verification

### **Health Checks**
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=rabbitmq

# Check StatefulSet status
kubectl get statefulset rabbitmq

# Check service status
kubectl get svc rabbitmq

# View RabbitMQ logs
kubectl logs -l app.kubernetes.io/name=rabbitmq
```

### **RabbitMQ Connection Testing**
```bash
# Access management UI (port forward required)
kubectl port-forward svc/rabbitmq 15672:15672
# Then open http://localhost:15672 in browser

# Test AMQP connectivity from within cluster
kubectl run rabbitmq-client --image=rabbitmq:4.1.3 --rm -it --restart=Never -- \
  rabbitmqctl -n rabbit@rabbitmq.default.svc.cluster.local status

# Check service endpoints
kubectl get endpoints rabbitmq
```

### **Management UI Access**

**Primary Method - Cluster Ingress (Recommended)**:
```bash
# Access via cluster ingress (no port-forward needed)
# URL: http://rabbitmq.localhost
# Username: user (from secrets)
# Password: [from secrets]
```

**Alternative Method - Port Forward**:
```bash
# Port forward for local access
kubectl port-forward svc/rabbitmq 15672:15672

# Access via browser
# URL: http://localhost:15672
# Username: user (from secrets)
# Password: [from secrets]
```

**External Access** (when configured):
- URL: `https://rabbitmq.urbalurba.no` (via Cloudflare tunnel)
- Same credentials as internal access

### **Automated Verification**
The deployment includes comprehensive testing of RabbitMQ functionality:

**Verification Process**:
1. **Two-stage pod readiness**: Waits for Running and Ready status
2. **Management API connectivity**: Tests HTTP response on port 15672
3. **Service connectivity**: Verifies internal cluster communication
4. **Authentication validation**: Confirms credentials work with management UI
5. **Port verification**: Checks AMQP (5672) and Management (15672) ports

## 🛠️ Management Operations

### **RabbitMQ Administration**
```bash
# Access RabbitMQ management CLI
kubectl exec -it rabbitmq-0 -- rabbitmqctl status

# List users
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_users

# List queues
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_queues

# List exchanges
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_exchanges

# Check cluster status
kubectl exec -it rabbitmq-0 -- rabbitmqctl cluster_status
```

### **Queue Management**
```bash
# Create a queue
kubectl exec -it rabbitmq-0 -- rabbitmqadmin declare queue name=test-queue

# Publish a message
kubectl exec -it rabbitmq-0 -- rabbitmqadmin publish exchange=amq.default routing_key=test-queue payload="Hello World"

# Get messages
kubectl exec -it rabbitmq-0 -- rabbitmqadmin get queue=test-queue

# Delete a queue
kubectl exec -it rabbitmq-0 -- rabbitmqadmin delete queue name=test-queue
```

### **User Management**
```bash
# Add a new user
kubectl exec -it rabbitmq-0 -- rabbitmqctl add_user newuser password123

# Set user permissions
kubectl exec -it rabbitmq-0 -- rabbitmqctl set_permissions -p / newuser ".*" ".*" ".*"

# Set user tags
kubectl exec -it rabbitmq-0 -- rabbitmqctl set_user_tags newuser administrator

# Delete user
kubectl exec -it rabbitmq-0 -- rabbitmqctl delete_user newuser
```

### **Service Removal**
```bash
# Remove RabbitMQ service (preserves data by default)
cd provision-host/kubernetes/03-queues/not-in-use/
./08-remove-rabbitmq.sh rancher-desktop

# Completely remove including data
ansible-playbook ansible/playbooks/080-remove-rabbitmq.yml \
  -e target_host=rancher-desktop
```

**Removal Process**:
- Uninstalls RabbitMQ Helm release
- Waits for pods to terminate
- Removes persistent volume claims and services
- Preserves urbalurba-secrets and namespace structure
- Provides data retention options and recovery instructions

## 🔧 Troubleshooting

### **Common Issues**

**Pod Won't Start**:
```bash
# Check pod events and logs
kubectl describe pod -l app.kubernetes.io/name=rabbitmq
kubectl logs -l app.kubernetes.io/name=rabbitmq

# Check Erlang cookie issues
kubectl exec -it rabbitmq-0 -- cat /opt/bitnami/rabbitmq/secrets/rabbitmq-erlang-cookie
```

**Authentication Issues**:
```bash
# Check RabbitMQ credentials in secrets
kubectl get secret urbalurba-secrets -o jsonpath="{.data.RABBITMQ_USERNAME}" | base64 -d
kubectl get secret urbalurba-secrets -o jsonpath="{.data.RABBITMQ_PASSWORD}" | base64 -d

# Test authentication via management API
kubectl exec -it rabbitmq-0 -- curl -u "rabbitmq-admin:password" http://localhost:15672/api/overview

# Check user permissions
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_user_permissions rabbitmq-admin
```

**Connection Issues**:
```bash
# Verify service endpoints
kubectl describe svc rabbitmq
kubectl get endpoints rabbitmq

# Test DNS resolution
kubectl run test-pod --image=busybox --rm -it -- \
  nslookup rabbitmq.default.svc.cluster.local

# Check RabbitMQ node status
kubectl exec -it rabbitmq-0 -- rabbitmqctl node_health_check
```

**Performance Issues**:
```bash
# Check resource usage
kubectl top pod rabbitmq-0

# Monitor RabbitMQ statistics
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_queues name messages memory

# Check memory usage
kubectl exec -it rabbitmq-0 -- rabbitmqctl status | grep memory

# Monitor connections
kubectl exec -it rabbitmq-0 -- rabbitmqctl list_connections
```

**Management UI Issues**:
```bash
# Check management plugin status
kubectl exec -it rabbitmq-0 -- rabbitmq-plugins list

# Restart management plugin
kubectl exec -it rabbitmq-0 -- rabbitmq-plugins disable rabbitmq_management
kubectl exec -it rabbitmq-0 -- rabbitmq-plugins enable rabbitmq_management

# Check management UI logs
kubectl logs rabbitmq-0 | grep management
```

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check pod and service status daily
2. **Queue Monitoring**: Monitor queue lengths and message rates
3. **Backup Schedule**: Implement regular backup of queue definitions and messages
4. **Performance Monitoring**: Monitor memory usage, connection counts, and message throughput

### **Backup Procedures**
```bash
# Export queue definitions
kubectl exec rabbitmq-0 -- rabbitmqadmin export definitions.json

# Backup definitions file
kubectl cp rabbitmq-0:definitions.json ./rabbitmq-definitions-backup-$(date +%Y%m%d).json

# Export specific queue
kubectl exec rabbitmq-0 -- rabbitmqadmin export queue=myqueue queue-backup.json

# Copy persistent data (if needed)
kubectl cp rabbitmq-0:/opt/bitnami/rabbitmq/.rabbitmq/mnesia ./rabbitmq-data-backup-$(date +%Y%m%d)/
```

### **Disaster Recovery**
```bash
# Restore definitions
kubectl cp ./rabbitmq-definitions-backup.json rabbitmq-0:definitions.json
kubectl exec rabbitmq-0 -- rabbitmqadmin import definitions.json

# Restore from persistent volume backup
# (Requires pod restart after restoring PV data)
kubectl delete pod rabbitmq-0  # StatefulSet will recreate
```

## 🚀 Use Cases

### **Message Queuing**
```bash
# Create work queue
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=work_queue durable=true

# Send task to queue
kubectl exec rabbitmq-0 -- rabbitmqadmin publish exchange=amq.default routing_key=work_queue payload='{"task":"process_image","id":123}' properties='{"delivery_mode":2}'

# Consume from queue
kubectl exec rabbitmq-0 -- rabbitmqadmin get queue=work_queue count=1
```

### **Publish/Subscribe**
```bash
# Create fanout exchange
kubectl exec rabbitmq-0 -- rabbitmqadmin declare exchange name=notifications type=fanout

# Create subscriber queues
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=email_notifications
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=sms_notifications

# Bind queues to exchange
kubectl exec rabbitmq-0 -- rabbitmqadmin declare binding source=notifications destination=email_notifications
kubectl exec rabbitmq-0 -- rabbitmqadmin declare binding source=notifications destination=sms_notifications

# Publish to all subscribers
kubectl exec rabbitmq-0 -- rabbitmqadmin publish exchange=notifications routing_key="" payload='{"event":"user_registered","user_id":456}'
```

### **Request/Response**
```bash
# Create RPC queue
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=rpc_queue

# Setup reply-to queue
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=rpc_reply exclusive=true

# Send RPC request
kubectl exec rabbitmq-0 -- rabbitmqadmin publish exchange=amq.default routing_key=rpc_queue payload='{"method":"calculate","params":[1,2,3]}' properties='{"reply_to":"rpc_reply","correlation_id":"123"}'
```

### **Dead Letter Queues**
```bash
# Create main queue with DLX
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=main_queue arguments='{"x-dead-letter-exchange":"dlx","x-message-ttl":60000}'

# Create dead letter exchange and queue
kubectl exec rabbitmq-0 -- rabbitmqadmin declare exchange name=dlx type=direct
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=dead_letters
kubectl exec rabbitmq-0 -- rabbitmqadmin declare binding source=dlx destination=dead_letters routing_key=dead
```


---

**💡 Key Insight**: RabbitMQ provides essential message broker capabilities that enable reliable asynchronous communication between services. Use RabbitMQ for decoupling services, handling background tasks, implementing event-driven architectures, and ensuring message delivery guarantees in distributed systems.