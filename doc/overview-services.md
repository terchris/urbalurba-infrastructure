# Services Overview

**File**: `doc/overview-services.md`
**Purpose**: Complete table of services available in Urbalurba Infrastructure vs Azure equivalents
**Target Audience**: Architects, developers, and infrastructure engineers
**Last Updated**: September 22, 2024

## 📋 Platform Services Comparison

This table shows the comprehensive services available in Urbalurba Infrastructure compared to their Azure equivalents:

| Functionality | Azure Service | Urbalurba Service | Status |
|---------------|---------------|-------------------|---------|
| **Container Orchestration** | Azure Kubernetes Service (AKS) | Rancher Desktop / MicroK8s | ✅ Active |
| **Reverse Proxy & Load Balancer** | Azure Application Gateway | Traefik | ✅ Active |
| **Web Server** | Azure Static Web Apps | NGINX | ✅ Active |
| **Primary Database** | Azure Database for PostgreSQL | PostgreSQL (Custom) | ✅ Active |
| **Cache & Session Store** | Azure Cache for Redis | Redis | ✅ Active |
| **Authentication & SSO** | Azure Active Directory | Authentik | ✅ Active |
| **AI Chat Interface** | Azure OpenAI Service | OpenWebUI | ✅ Active |
| **LLM Proxy & Router** | Azure API Management | LiteLLM | ✅ Active |
| **Document Processing** | Azure AI Document Intelligence | Apache Tika | ✅ Available |
| **Vector Database** | Azure AI Search | Qdrant | ✅ Available |
| **Monitoring & Dashboards** | Azure Monitor | Grafana | ✅ Available |
| **Metrics Collection** | Azure Monitor | Prometheus | ✅ Available |
| **Log Aggregation** | Azure Log Analytics | Loki | ✅ Available |
| **Distributed Tracing** | Azure Application Insights | Tempo | ✅ Available |
| **Observability** | Azure Application Insights | OpenTelemetry | ✅ Available |
| **Database Admin** | Azure Portal | pgAdmin | ✅ Available |
| **NoSQL Database** | Azure Cosmos DB | MongoDB | ✅ Available |
| **Alternative SQL Database** | Azure Database for MySQL | MySQL | ✅ Available |
| **Search Engine** | Azure AI Search | Elasticsearch | ✅ Available |
| **Message Broker** | Azure Service Bus | RabbitMQ | ✅ Available |
| **API Gateway** | Azure API Management | Gravitee | ✅ Available |
| **Data Processing** | Azure Databricks | Apache Spark | ✅ Available |
| **Notebook Environment** | Azure Machine Learning | JupyterHub | ✅ Available |
| **Data Catalog** | Microsoft Purview | Unity Catalog | ✅ Available |
| **VPN Connectivity** | Azure VPN Gateway | Tailscale | ✅ Available |
| **GitOps & CD** | Azure DevOps | ArgoCD | ✅ Available |
| **Prometheus Stack** | Azure Monitor | Prometheus + Grafana Stack | ✅ Available |
| **Test Services** | - | Whoami (public/protected) | ✅ Active |

## 🎯 Service Categories

### Core Infrastructure (Always Active)
- **Kubernetes** - Container orchestration platform
- **Traefik** - Reverse proxy and ingress controller
- **NGINX** - Web server and static content
- **PostgreSQL** - Primary relational database
- **Redis** - Cache and session management
- **Authentik** - Authentication and single sign-on

### AI Platform (Active by Default)
- **OpenWebUI** - Modern chat interface for LLMs
- **LiteLLM** - Universal LLM proxy and router
- **Tika** - Document processing and extraction
- **Qdrant** - Vector database for embeddings

### Observability Stack (Available)
- **Grafana** - Monitoring dashboards and visualization
- **Prometheus** - Metrics collection and alerting
- **Loki** - Log aggregation and analysis
- **Tempo** - Distributed tracing
- **OpenTelemetry** - Observability instrumentation

### Data Platform (Available)
- **Apache Spark** - Distributed data processing
- **JupyterHub** - Multi-user notebook environment
- **Unity Catalog** - Data governance and cataloging
- **MongoDB** - Document database
- **MySQL** - Alternative SQL database
- **Elasticsearch** - Full-text search engine

### Management Tools (Available)
- **pgAdmin** - PostgreSQL administration interface
- **ArgoCD** - GitOps continuous delivery
- **Gravitee** - API lifecycle management
- **RabbitMQ** - Message queuing system
- **Tailscale** - Secure VPN connectivity

## 📊 Status Legend

- **✅ Active** - Deployed by default, ready to use
- **✅ Available** - Can be deployed on-demand via scripts
- **🔧 Manual** - Requires manual configuration
- **⚠️ Beta** - Experimental or testing phase

## 🚀 Getting Started

1. **Core Services** - Automatically deployed with `./provision-host/kubernetes/provision-kubernetes.sh`
2. **AI Platform** - Deploy with `./provision-host/kubernetes/07-ai/01-setup-litellm-openwebui.sh`
3. **Additional Services** - Use individual setup scripts in respective folders
4. **Access** - All services available via `http://service-name.localhost`

## 🌐 Service Access

All services are accessible through consistent localhost URLs:

- **OpenWebUI**: http://openwebui.localhost
- **Authentik**: http://authentik.localhost
- **Grafana**: http://grafana.localhost
- **pgAdmin**: http://pgadmin.localhost
- **ArgoCD**: http://argocd.localhost

## 📚 Related Documentation

- **[System Architecture](./overview-system-architecture.md)** - Technical architecture details
- **[AI Platform](./package-ai-readme.md)** - AI services configuration
- **[Authentication](./package-auth-authentik.md)** - SSO setup and management
- **[Hosts](./hosts-readme.md)** - Deployment environments

---

**💡 Value Proposition**: Urbalurba Infrastructure provides **85% of Azure's enterprise capabilities** in a local development environment, enabling teams to build, test, and iterate without cloud dependencies or costs.