# Gravitee APIM Configuration Documentation

This document provides a comprehensive technical overview of the Gravitee API Management (APIM) installation in the Kubernetes cluster.

## 1. Installation Overview

Gravitee APIM is deployed using Helm in the default namespace with all core components running in dedicated pods. The installation is based on Gravitee APIM version 4.6.6.

### Helm Release Information

```
NAME         NAMESPACE REVISION UPDATED                                STATUS  CHART               APP VERSION
gravitee-apim default    1      2025-03-19 18:05:21.740952492 +0100 CET deployed apim-4.6.6       4.6.6
```

### Component Pods

```
gravitee-apim-api-6c9685b599-2fkk8       1/1     Running   1 (7h15m ago)   21h
gravitee-apim-gateway-789bdb786b-g649f   1/1     Running   1 (7h15m ago)   21h
gravitee-apim-portal-5dfb7fd6fb-d6wtl    1/1     Running   1 (7h15m ago)   21h
gravitee-apim-ui-777b869bbf-8dhmf        1/1     Running   1 (7h15m ago)   21h
```

### Other Helm Deployments in the Cluster

The following Helm deployments exist in the same namespace as Gravitee APIM:

```
# Output from: kubectl get helm -n default
NAME         NAMESPACE REVISION UPDATED                                STATUS  CHART               APP VERSION
elasticsearch default    1      2025-03-19 17:59:22.738818446 +0100 CET deployed elasticsearch-21.4.8 8.17.3     
nginx        default    1      2025-03-19 17:52:45.576041048 +0100 CET deployed nginx-19.0.2       1.27.4     
postgresql   default    1      2025-03-19 17:55:22.001477165 +0100 CET deployed postgresql-16.5.2  17.4.0     
rabbitmq     default    1      2025-03-19 17:57:37.640287854 +0100 CET deployed rabbitmq-15.4.0    4.0.7      
redis        default    1      2025-03-19 17:56:31.653719573 +0100 CET deployed redis-20.11.3      7.4.2      
```

Of these deployments, Gravitee APIM specifically requires:
- MongoDB (for the main datastore)
- Elasticsearch (for analytics)

The others (PostgreSQL, RabbitMQ, Redis) may be used by other applications in the cluster but are not direct dependencies of Gravitee APIM.

## 2. Component Architecture

### Pod Configuration

Each component is deployed as a separate pod with specific labels and resource allocations. For example, the API component has the following configuration:

```yaml
# Output from: kubectl describe pod $(kubectl get pods -n default | grep gravitee-apim-api | head -1 | awk '{print $1}')
# This configuration is defined in the Helm chart values and templates

Labels:
  app.kubernetes.io/component: api
  app.kubernetes.io/instance: gravitee-apim
  app.kubernetes.io/name: apim
  app.kubernetes.io/version: 4.6.6
  pod-template-hash: 6c9685b599

Resources:
  Limits:
    cpu: 1
    memory: 1Gi
  Requests:
    cpu: 200m
    memory: 512Mi
```

Probes are configured for pod healthiness:
```yaml
# These probe configurations are defined in the Helm chart's deployment templates
# File path in the chart: templates/api/deployment.yaml

Liveness:   tcp-socket :http delay=30s timeout=1s period=30s #success=1 #failure=3
Readiness:  tcp-socket :http delay=30s timeout=1s period=30s #success=1 #failure=3
Startup:    tcp-socket :http delay=0s timeout=1s period=10s #success=1 #failure=30
```

### ConfigMaps

The Gravitee components use ConfigMaps for configuration:

```
# Output from: kubectl get configmaps -n default | grep gravitee
gravitee-apim-api       1      21h
gravitee-apim-gateway   1      21h
gravitee-apim-portal    5      21h
gravitee-apim-ui        4      21h
```

Each component mounts its respective ConfigMap for configuration:

```yaml
# From the pod description: kubectl describe pod gravitee-apim-api-6c9685b599-2fkk8
# These volume mounts are defined in the Helm chart's deployment templates
# File path in the chart: templates/api/deployment.yaml

Volumes:
  config:
    Type:      ConfigMap (a volume populated by a ConfigMap)
    Name:      gravitee-apim-api
    Optional:  false
```

The contents of these ConfigMaps can be viewed with:
```bash
kubectl get configmap gravitee-apim-api -n default -o yaml
kubectl get configmap gravitee-apim-gateway -n default -o yaml
```

### Service Configuration

The services are configured as ClusterIP services for internal communication:

```
# Output from: kubectl get svc -n default | grep gravitee
gravitee-apim-api         ClusterIP   10.43.177.164   <none>        83/TCP
gravitee-apim-gateway     ClusterIP   10.43.138.3     <none>        82/TCP
gravitee-apim-portal      ClusterIP   10.43.230.113   <none>        8003/TCP
gravitee-apim-ui          ClusterIP   10.43.2.156     <none>        8002/TCP
```

These service definitions are created by the Helm chart and can be found in the chart's template files:
- templates/api/service.yaml
- templates/gateway/service.yaml
- templates/portal/service.yaml
- templates/ui/service.yaml

## 3. Networking and Ingress Configuration

### Ingress Resources

The installation uses 5 separate ingress resources to handle different paths on the same host (`apim.example.com`):

1. **Management API (gravitee-apim-api-management)**:
   ```yaml
   # Output from: kubectl describe ingress -n default | grep -A20 gravitee
   # These ingress resources are defined in the Helm chart's template files
   # File path in the chart: templates/api/ingress-management.yaml
   
   Host: apim.example.com
   Path: /management
   Backend: gravitee-apim-api:83 (10.42.0.56:8083)
   Annotations: kubernetes.io/ingress.class: nginx
   ```

2. **Portal API (gravitee-apim-api-portal)**:
   ```yaml
   Host: apim.example.com
   Path: /portal
   Backend: gravitee-apim-api:83 (10.42.0.56:8083)
   Annotations: kubernetes.io/ingress.class: nginx
   ```

3. **Gateway (gravitee-apim-gateway)**:
   ```yaml
   Host: apim.example.com
   Path: /
   Backend: gravitee-apim-gateway:82 (10.42.0.54:8082)
   Annotations: kubernetes.io/ingress.class: nginx
   ```

4. **Portal UI (gravitee-apim-portal)**:
   ```yaml
   Host: apim.example.com
   Path: /
   Backend: gravitee-apim-portal:8003 (10.42.0.60:8080)
   Annotations: 
     kubernetes.io/ingress.class: nginx
     nginx.ingress.kubernetes.io/rewrite-target: /
   ```

5. **Management UI (gravitee-apim-ui)**:
   ```yaml
   Host: apim.example.com
   Path: /console(/.*)?
   Backend: gravitee-apim-ui:8002 (10.42.0.58:8080)
   Annotations: 
     kubernetes.io/ingress.class: nginx
     nginx.ingress.kubernetes.io/rewrite-target: /$1
   ```

Note: The path configurations create potential routing conflicts, especially with multiple root paths ("/"). The nginx ingress controller likely uses the first match or most specific match for routing.

## 4. Environment Configuration

The API component has the following environment variables configured:

```
# Output from: kubectl exec -it $(kubectl get pods -n default | grep gravitee-apim-api | head -1 | awk '{print $1}') -- env | sort

# Portal configuration - defined in the Helm values
portal.entrypoint=https://apim.example.com/

# Automatically injected Kubernetes service discovery env vars for all components
GRAVITEE_APIM_API_SERVICE_HOST=10.43.177.164
GRAVITEE_APIM_API_SERVICE_PORT=83
GRAVITEE_APIM_GATEWAY_SERVICE_HOST=10.43.138.3
GRAVITEE_APIM_GATEWAY_SERVICE_PORT=82
GRAVITEE_APIM_PORTAL_SERVICE_HOST=10.43.230.113
GRAVITEE_APIM_PORTAL_SERVICE_PORT=8003
GRAVITEE_APIM_UI_SERVICE_HOST=10.43.2.156
GRAVITEE_APIM_UI_SERVICE_PORT=8002

# Database service discovery - automatically injected by Kubernetes
ELASTICSEARCH_SERVICE_HOST=10.43.70.158
ELASTICSEARCH_SERVICE_PORT=9200
MONGODB_SERVICE_HOST=10.43.147.6
MONGODB_SERVICE_PORT=27017
POSTGRESQL_SERVICE_HOST=10.43.51.252
POSTGRESQL_SERVICE_PORT=5432
RABBITMQ_SERVICE_HOST=10.43.128.62
RABBITMQ_SERVICE_PORT=5672
REDIS_MASTER_SERVICE_HOST=10.43.79.100
REDIS_MASTER_SERVICE_PORT=6379
```

Custom environment variables can be defined in the Helm values file under the `api.env` section.

## 5. Authentication Configuration

The installation includes the following user accounts (as defined in the Helm values):

* **Admin User**:
  * Username: admin
  * Password: adminadmin
  * Email: admin@example.com
  * Roles: MANAGEMENT:ADMIN, PORTAL:ADMIN

* **API User**:
  * Username: api_user
  * Password: api_user
  * Email: api_user@example.com
  * First Name: API
  * Last Name: User
  * Roles: MANAGEMENT:USER, PORTAL:USER

## 6. Database Configuration

### MongoDB Settings

Gravitee is configured to use MongoDB for its primary data store:

```yaml
# From the Helm values: helm get values gravitee-apim -n default
# These settings can be configured in the values.yaml file when installing or upgrading the chart

mongo:
  auth:
    enabled: true
    password: gravitee
    username: gravitee
  dbhost: mongodb.default.svc.cluster.local
  dbname: graviteedb
  dbport: 27017
  rsEnabled: false
```

### Elasticsearch Configuration

Elasticsearch is configured for analytics storage:

```yaml
# From the Helm values: helm get values gravitee-apim -n default
# These settings can be configured in the values.yaml file when installing or upgrading the chart

es:
  enabled: false  # Not managed by the Gravitee Helm chart
  endpoints:
  - http://elasticsearch.default.svc.cluster.local:9200
  security:
    enabled: false
    password: Secretp@ssword1
    username: elastic
```

## 7. Resource Allocations

Resources are allocated differently based on component type:

**API and Gateway Components**:
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 512Mi
```

**UI Components** (Management UI and Portal):
```yaml
resources:
  limits:
    cpu: 300m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## 8. Security Configuration

### Encryption Settings

Encryption secrets are defined for sensitive data:

```yaml
properties:
  encryption:
    secret: urbalurba-encryption-1234
```

### Kubernetes Security Context

The pods run with default security contexts and service accounts:

```yaml
Service Account:  gravitee-apim-apim
```

No Persistent Volume Claims are associated with the Gravitee deployment, suggesting ephemeral storage for all components.

## 9. Accessing the Platform

### External Access

The system is configured with ingress rules for external access through the host `apim.example.com`. Access URLs:

- Management UI: https://apim.example.com/console
- Portal UI: https://apim.example.com/
- Management API: https://apim.example.com/management
- Gateway API: https://apim.example.com/
- Portal API: https://apim.example.com/portal

Note: There are potential routing conflicts with multiple components using the root path ("/").

### Port Forwarding (Development/Testing)

For local access, use the following port-forwarding commands:

```bash
# Management UI
kubectl port-forward svc/gravitee-apim-ui 8002:8002 -n default

# Developer Portal
kubectl port-forward svc/gravitee-apim-portal 8003:8003 -n default

# API Gateway
kubectl port-forward svc/gravitee-apim-gateway 82:82 -n default

# Management API
kubectl port-forward svc/gravitee-apim-api 83:83 -n default
```

## 10. Maintenance Operations

### Checking Component Status

```bash
# Get all Gravitee pods
kubectl get pods -n default | grep gravitee-apim

# Check pod details
kubectl describe pod <pod-name> -n default

# Check pod logs
kubectl logs <pod-name> -n default

# Check ConfigMap content
kubectl describe configmap gravitee-apim-api -n default
```

### Scaling Components

```bash
# Scale the API component
kubectl scale deployment gravitee-apim-api --replicas=2 -n default

# Scale the Gateway component
kubectl scale deployment gravitee-apim-gateway --replicas=2 -n default
```

### Upgrading Gravitee

```bash
# Update Helm repositories
helm repo update

# Upgrade the Gravitee installation
helm upgrade gravitee-apim graviteeio/apim -n default --reuse-values
```

### Configuration Changes

To modify the Gravitee configuration:

1. Get the current values:
   ```bash
   helm get values gravitee-apim -n default -o yaml > values.yaml
   ```

2. Edit the values.yaml file

3. Apply the changes:
   ```bash
   helm upgrade gravitee-apim graviteeio/apim -n default -f values.yaml
   ```

## 11. Troubleshooting

### Common Issues

1. **Ingress Routing Conflicts**: With multiple components sharing the same host and overlapping paths, routing issues may occur. Check the nginx ingress controller logs.

2. **Database Connectivity**: Ensure MongoDB and Elasticsearch are running and accessible from the Gravitee pods.

3. **Resource Constraints**: Monitor CPU and memory usage to ensure pods aren't being throttled.

### Checking Logs

```bash
# API logs
kubectl logs deployments/gravitee-apim-api -n default

# Gateway logs
kubectl logs deployments/gravitee-apim-gateway -n default

# Check events for issues
kubectl get events -n default | grep gravitee
```

### Component Health Checks

For direct health checks (requires access to the pods):

```bash
# Check API health
kubectl exec -it <api-pod-name> -n default -- curl -s http://localhost:8083/_node/health

# Check Gateway health
kubectl exec -it <gateway-pod-name> -n default -- curl -s http://localhost:8082/_node/health
```
