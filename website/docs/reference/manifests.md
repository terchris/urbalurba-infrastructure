# Kubernetes Manifests

This folder contains the Kubernetes manifests for the applications and services that are deployed to the infrastructure.

## Manifest Organization

Manifests are organized by deployment order and functionality:

### **000-099: Core Infrastructure**
- `000-storage-class-alias.yaml` - Storage class configuration
- `001-002` - Storage testing manifests
- `010-012` - Tailscale and Traefik configuration
- `020` - Nginx configuration and ingress
- `030-039` - Observability stack (Grafana, Loki, Tempo, Prometheus, OpenTelemetry)

### **040-099: Data and Messaging**
- `040-044` - Database configurations (MongoDB, PostgreSQL, MySQL, Qdrant)
- `050` - Redis configuration
- `060` - Elasticsearch configuration
- `070-071` - Authentik identity provider and SSO
- `080` - RabbitMQ configuration
- `090` - Gravitee API management

### **200-299: AI and Development**
- `200-201` - AI persistent storage and Open WebUI
- `205` - Ollama configuration
- `208-210` - Open WebUI configuration and ingress
- `220-221` - ArgoCD and LiteLLM
- `230` - Prometheus stack

### **300-399: Data Science**
- `300` - Apache Spark configuration
- `310-311` - JupyterHub configuration and ingress
- `320-321` - Unity Catalog configuration and ingress

### **600-699: Administration**
- `640-641` - pgAdmin configuration
- `740` - pgAdmin ingress

### **700-799: Networking**
- `751-752` - Cloudflare tunnel configuration
- `net2-*` - Tailscale cluster networking

## Recent Additions

### **Authentik Identity Provider (070-071)**
- `070-authentik-config.yaml` - Helm values for Authentik deployment
- `071-authentik-ingress.yaml` - Ingress configuration for external access

**Features:**
- Single Sign-On (SSO) via OpenID Connect and SAML
- User management and directory services
- Multi-factor authentication (MFA)
- Application integration and provisioning
- Audit logging and compliance features

**Usage:**
```bash
# Deploy Authentik
helm upgrade --install authentik authentik/authentik -f manifests/070-authentik-config.yaml -n authentik

# Apply ingress
kubectl apply -f manifests/071-authentik-ingress.yaml
```

## Manifest Patterns

### **Configuration Files**
- Use numbered sequencing for deployment order
- Include comprehensive documentation headers
- Reference secrets from `urbalurba-secrets` Kubernetes secret
- Separate configuration from ingress where possible

### **Ingress Files**
- Follow the pattern: `XXX-service-ingress.yaml`
- Use Traefik ingress controller by default
- Configure for localhost testing initially
- Include TLS configuration for production use

### **Secret Management**
- All sensitive values reference `urbalurba-secrets` secret
- Secrets are managed centrally in the `topsecret/kubernetes/` directory
- Use the `update-kubernetes-secrets-v2.sh` script for deployment

## Deployment Workflow

1. **Update secrets** using the automated script
2. **Deploy configuration** with Helm or kubectl
3. **Apply ingress** for external access
4. **Verify deployment** and functionality

## Best Practices

- Always check the documentation header in each manifest
- Use consistent naming conventions
- Test manifests with `--dry-run=client` before applying
- Keep configuration and ingress manifests separate
- Document all environment-specific values