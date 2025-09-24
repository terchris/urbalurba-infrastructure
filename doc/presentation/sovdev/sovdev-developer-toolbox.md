# The Developer Toolbox and how it is connected to SovDev

```mermaid
graph TB
    subgraph "Developer Machine"
        subgraph "VSCode IDE"
            VSCODE["💻 VSCode<br/>Code Editor"]
            
            subgraph "DevContainer"
                CONTAINER["🐳 DevContainer<br/>Development Environment"]
                CODE["📝 Application Code<br/>Node.js, Python, Go, etc."]
                TOOLS["🛠️ Dev Tools<br/>SDKs, CLIs, Debuggers"]
            end
        end
        
        subgraph "SovDev Cluster (devSov)"
            K8S["☸️ Kubernetes<br/>Container Orchestration"]
            TRAEFIK["🌐 Traefik<br/>Reverse Proxy"]
            POSTGRES["🐘 PostgreSQL<br/>Database"]
            REDIS["🔴 Redis<br/>Cache"]
            MONGODB["🍃 MongoDB<br/>Document DB"]
            AUTHENTIK["🔐 Authentik<br/>Authentication"]
            AI["🤖 AI Platform<br/>OpenWebUI + LiteLLM"]
            GRAFANA["📊 Grafana<br/>Monitoring"]
        end
    end
    
    %% Developer workflow connections
    VSCODE --> CONTAINER
    CONTAINER --> CODE
    CONTAINER --> TOOLS
    
    %% DevContainer to SovDev connections
    CONTAINER -.->|"Database Queries"| POSTGRES
    CONTAINER -.->|"Cache Operations"| REDIS
    CONTAINER -.->|"Document Storage"| MONGODB
    CONTAINER -.->|"Authentication"| AUTHENTIK
    CONTAINER -.->|"AI Services"| AI
    CONTAINER -.->|"Monitoring"| GRAFANA
    
    %% Internal SovDev connections
    TRAEFIK --> POSTGRES
    TRAEFIK --> REDIS
    TRAEFIK --> MONGODB
    TRAEFIK --> AUTHENTIK
    TRAEFIK --> AI
    TRAEFIK --> GRAFANA
```

## 🔧 Developer Workflow

### **Development Environment Setup**
1. **VSCode** opens the project with devcontainer configuration
2. **DevContainer** starts with all necessary development tools
3. **Application Code** runs inside the container
4. **SovDev Cluster** provides backend services

### **Service Connections**
| Service | Connection Type | Purpose | Example |
|---------|----------------|---------|---------|
| **PostgreSQL** | Database connection | Primary data storage | `postgresql://postgres:5432/mydb` |
| **Redis** | Cache connection | Session storage, caching | `redis://redis:6379` |
| **MongoDB** | Document DB | NoSQL data storage | `mongodb://mongodb:27017/mydb` |
| **Authentik** | OAuth/OIDC | User authentication | `https://authentik.localhost` |
| **AI Platform** | REST API | AI/ML services | `http://openwebui.localhost/api` |
| **Grafana** | Monitoring API | Metrics and logging | `http://grafana.localhost/api` |

### **DevContainer Configuration Example**
```json
{
  "name": "MyApp DevContainer",
  "image": "mcr.microsoft.com/devcontainers/typescript-node:18",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {}
  },
  "forwardPorts": [3000, 5432, 6379],
  "postCreateCommand": "npm install && npm run dev"
}
```

### **Environment Variables**
```bash
# Database connections
DATABASE_URL=postgresql://postgres:password@postgres.localhost:5432/mydb
REDIS_URL=redis://redis.localhost:6379
MONGODB_URL=mongodb://mongodb.localhost:27017/mydb

# Authentication
AUTHENTIK_URL=https://authentik.localhost
AUTHENTIK_CLIENT_ID=myapp
AUTHENTIK_CLIENT_SECRET=secret

# AI Services
AI_API_URL=http://openwebui.localhost/api
AI_API_KEY=your-api-key

# Monitoring
GRAFANA_URL=http://grafana.localhost
GRAFANA_API_KEY=your-grafana-key
```

## 🚀 Key Benefits

### **Isolated Development**
- DevContainer provides consistent environment
- All dependencies containerized
- Easy onboarding for new developers

### **Real Service Integration**
- Connect to actual SovDev services
- Test against production-like environment
- Validate integrations early

### **Local Development Experience**
- VSCode integration with SovDev
- Hot reloading and debugging
- Full IDE features with container benefits

### **Service Discovery**
- Services accessible via localhost subdomains
- Automatic service discovery
- Consistent naming convention

## 🔄 Development Flow

1. **Start SovDev**: `./provision-host/kubernetes/provision-kubernetes.sh`
2. **Open VSCode**: `code .` in project directory
3. **DevContainer Starts**: Automatically with all tools
4. **Connect to Services**: Application connects to SovDev services
5. **Develop & Test**: Full development experience with real backend
6. **Deploy**: Same services available in staging/production

## 💡 Value Proposition

**SovDev + DevContainer** provides developers with:
- **Real Backend Services** instead of mocks
- **Consistent Environment** across team members
- **Production Parity** from day one
- **Easy Service Integration** with localhost access
- **Full Development Experience** with VSCode + containers