# Queue Services - Message Brokers and Caching Layer

**File**: `doc/package-queues-readme.md`
**Purpose**: Overview of all queue and caching services in Urbalurba infrastructure
**Target Audience**: Backend developers, DevOps engineers, system architects
**Last Updated**: September 23, 2025

## 📋 Overview

Urbalurba infrastructure provides a comprehensive suite of queue and caching services supporting various messaging patterns and performance optimization needs. From high-performance in-memory caching to reliable message brokers, the platform offers production-ready solutions for asynchronous communication, data caching, and event-driven architectures.

**Available Queue Services**:
- **Redis**: In-memory data store and cache for high-performance operations
- **RabbitMQ**: Message broker for reliable asynchronous communication

## 🚀 Queue & Cache Services

### **Redis - In-Memory Cache & Data Store** ⚡
**Status**: Active | **Port**: 6379 | **Type**: In-Memory Database/Cache

**Key Capabilities**: Sub-millisecond Latency • Data Structures • Pub/Sub • Session Storage • Rate Limiting • Persistence Options • Lua Scripting

Redis serves as the **primary caching layer** and in-memory data store with enterprise-grade features for high-performance applications. Provides essential caching capabilities for Authentik authentication and other services requiring fast data access.

**Key Features**:
- **High Performance**: Sub-millisecond latency for read/write operations
- **Data Structures**: Strings, hashes, lists, sets, sorted sets, streams
- **Authentik Integration**: Required for authentication service performance
- **Persistence Options**: RDB snapshots for data durability
- **Helm Deployment**: Bitnami Redis chart with secure configuration

📚 **[Complete Documentation →](./package-queues-redis.md)**

---

### **RabbitMQ - Message Broker** 📨
**Status**: Optional (not-in-use) | **Port**: 5672 (AMQP), 15672 (Management) | **Type**: Message Queue

**Key Capabilities**: Message Queuing • Pub/Sub • Routing • Dead Letter Queues • Message Persistence • Management UI • Clustering Support

RabbitMQ provides **reliable message broker** capabilities for asynchronous communication between services. Enables decoupled architectures with guaranteed message delivery, advanced routing, and comprehensive management tools.

**Key Features**:
- **Message Patterns**: Queuing, pub/sub, RPC, routing
- **Reliability**: Message persistence and delivery guarantees
- **Management UI**: Web-based administration interface
- **Dead Letter Queues**: Handle failed message processing
- **Security**: Centralized authentication via urbalurba-secrets

📚 **[Complete Documentation →](./package-queues-rabbitmq.md)**

## 🏗️ Deployment Architecture

### **Service Activation**
```
Queue Services Deployment Status:
├── Redis (ACTIVE) - Required for Authentik and caching
└── RabbitMQ (INACTIVE) - Located in not-in-use/ folder
```

### **Storage & Persistence**
Queue services use different persistence strategies:
- **Redis**: 6GB persistent storage with RDB snapshots
- **RabbitMQ**: 8GB persistent storage for message durability

### **Secret Management**
Authentication managed through `urbalurba-secrets`:
```
Queue Service Credentials:
├── REDIS_PASSWORD / REDIS_HOST (Redis)
└── RABBITMQ_USERNAME / RABBITMQ_PASSWORD / RABBITMQ_HOST (RabbitMQ)
```

## 🚀 Quick Start

### **Deploy Redis (Required for Authentik)**
```bash
# Automatic deployment during cluster provisioning
./provision-kubernetes.sh rancher-desktop

# Manual deployment
cd provision-host/kubernetes/03-queues/
./06-setup-redis.sh rancher-desktop
```

### **Activate RabbitMQ (Optional)**
```bash
# Deploy RabbitMQ when message broker is needed
cd provision-host/kubernetes/03-queues/not-in-use/
./08-setup-rabbitmq.sh rancher-desktop
```

## 🔍 Service Selection Guide

### **When to Use Redis** ⚡
- **Caching Layer**: Session storage, API response caching
- **Rate Limiting**: API throttling and request limiting
- **Real-time Features**: Leaderboards, counters, analytics
- **Pub/Sub**: Simple publish/subscribe messaging
- **Required for**: Authentik authentication service

### **When to Use RabbitMQ** 📨
- **Message Queuing**: Background job processing
- **Service Decoupling**: Asynchronous communication between microservices
- **Event-Driven Architecture**: Event publishing and consumption
- **Reliability Required**: Guaranteed message delivery
- **Complex Routing**: Topic-based or content-based routing

### **Redis vs RabbitMQ Decision Matrix**

| Use Case | Redis | RabbitMQ |
|----------|-------|----------|
| Session Cache | ✅ Best | ❌ Not suitable |
| API Response Cache | ✅ Best | ❌ Not suitable |
| Simple Pub/Sub | ✅ Good | ✅ Better for complex patterns |
| Job Queue | ⚠️ Basic | ✅ Best with guarantees |
| Message Routing | ❌ Limited | ✅ Advanced routing |
| Dead Letter Queue | ❌ Manual | ✅ Built-in support |
| Persistence | ⚠️ Optional | ✅ Built-in |

## 🛠️ Management Operations

### **Common Operations**
```bash
# Check service status
kubectl get pods -l app.kubernetes.io/name=redis
kubectl get pods -l app.kubernetes.io/name=rabbitmq

# View service logs
kubectl logs -l app.kubernetes.io/name=redis
kubectl logs -l app.kubernetes.io/name=rabbitmq

# Connect to services
kubectl exec -it redis-master-0 -- redis-cli -a yourpassword
kubectl exec -it rabbitmq-0 -- rabbitmqctl status
```

### **Performance Monitoring**
```bash
# Redis monitoring
kubectl exec redis-master-0 -- redis-cli -a yourpassword info stats
kubectl exec redis-master-0 -- redis-cli -a yourpassword info memory

# RabbitMQ monitoring
kubectl exec rabbitmq-0 -- rabbitmqctl list_queues name messages memory
kubectl exec rabbitmq-0 -- rabbitmqctl list_connections
```

### **Backup Procedures**
```bash
# Redis backup (RDB snapshot)
kubectl exec redis-master-0 -- redis-cli -a yourpassword bgsave
kubectl cp redis-master-0:/data/dump.rdb ./redis-backup.rdb

# RabbitMQ backup (definitions export)
kubectl exec rabbitmq-0 -- rabbitmqadmin export definitions.json
kubectl cp rabbitmq-0:definitions.json ./rabbitmq-definitions-backup.json
```

## 🔧 Troubleshooting

### **Common Issues**
- **Connection Refused**: Check service endpoints and authentication
- **Memory Issues**: Monitor memory usage and eviction policies
- **Authentication Failed**: Verify urbalurba-secrets configuration
- **Performance Degradation**: Check resource limits and persistence settings

### **Diagnostic Commands**
```bash
# Check service endpoints
kubectl get endpoints redis-master rabbitmq

# Verify storage
kubectl get pvc -l app.kubernetes.io/name=redis
kubectl get pvc -l app.kubernetes.io/name=rabbitmq

# Test Redis connectivity
kubectl run redis-test --image=redis:8.2.1 --rm -it -- \
  redis-cli -h redis-master.default.svc.cluster.local -a yourpassword ping

# Test RabbitMQ connectivity
kubectl port-forward svc/rabbitmq 15672:15672
# Then access http://localhost:15672
```

## 📋 Maintenance

### **Regular Tasks**
1. **Monitor Memory**: Check memory usage and eviction rates
2. **Backup Schedule**: Implement automated backup procedures
3. **Performance Monitoring**: Track latency and throughput metrics
4. **Security Updates**: Update container images regularly
5. **Connection Monitoring**: Track client connections and usage patterns

### **Service Removal**
```bash
# Remove services (preserves data by default)
cd provision-host/kubernetes/03-queues/not-in-use/
./06-remove-redis.sh rancher-desktop
./08-remove-rabbitmq.sh rancher-desktop
```

## 🎯 Use Case Examples

### **Redis: Session Management**
```bash
# Store user session
kubectl exec redis-master-0 -- redis-cli -a yourpassword \
  HSET session:user123 username "john" last_activity "$(date +%s)"

# Set session expiry
kubectl exec redis-master-0 -- redis-cli -a yourpassword \
  EXPIRE session:user123 1800
```

### **Redis: Rate Limiting**
```bash
# Implement rate limiting (10 requests per minute)
kubectl exec redis-master-0 -- redis-cli -a yourpassword \
  SET rate:api:user123 1 EX 60 NX

kubectl exec redis-master-0 -- redis-cli -a yourpassword \
  INCR rate:api:user123
```

### **RabbitMQ: Work Queue**
```bash
# Create work queue
kubectl exec rabbitmq-0 -- rabbitmqadmin declare queue name=task_queue durable=true

# Send task to queue
kubectl exec rabbitmq-0 -- rabbitmqadmin publish \
  exchange=amq.default routing_key=task_queue \
  payload='{"task":"process_image","id":123}'
```

### **RabbitMQ: Event Publishing**
```bash
# Create event exchange
kubectl exec rabbitmq-0 -- rabbitmqadmin declare exchange \
  name=events type=topic

# Publish event
kubectl exec rabbitmq-0 -- rabbitmqadmin publish \
  exchange=events routing_key=user.registered \
  payload='{"user_id":456,"timestamp":"2025-09-22T10:00:00Z"}'
```

## 📚 Related Documentation

- **[Redis Documentation](./package-queues-redis.md)** - In-memory cache and data store
- **[RabbitMQ Documentation](./package-queues-rabbitmq.md)** - Message broker service
- **[Authentik Documentation](./package-auth-authentik-readme.md)** - Redis dependency for authentication
- **[Secrets Management](./secrets-management-readme.md)** - Queue service credential configuration
- **[Troubleshooting Guide](./troubleshooting-readme.md)** - Queue service troubleshooting

---

**💡 Key Insight**: The queue services layer provides essential infrastructure for high-performance caching and reliable message delivery. Redis serves as the foundation for session management and caching (required for Authentik), while RabbitMQ enables sophisticated messaging patterns for event-driven architectures and service decoupling. Choose Redis for speed and simplicity, RabbitMQ for reliability and advanced routing.