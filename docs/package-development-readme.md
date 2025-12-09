# Development Services - Complete Development and Testing Environment

**File**: `docs/package-development-readme.md`
**Purpose**: Overview of all development and testing services in Urbalurba infrastructure
**Target Audience**: Software developers, DevOps engineers, QA engineers
**Last Updated**: December 19, 2024

## 📋 Overview

Urbalurba infrastructure provides a comprehensive development and testing environment that enables rapid software development, testing, and deployment. The development stack is designed to mirror production environments using open source software, providing a complete CI/CD pipeline from development to deployment.

**Available Development Services**:
- **ArgoCD**: GitOps continuous delivery for automated deployments
- **Development Templates**: Pre-configured application templates for multiple languages
- **DevContainer Toolbox**: Integrated development environment with language support

## 🖥️ Development Services

### **ArgoCD - GitOps Continuous Delivery** 🚀
**Status**: Optional (not-in-use) | **Port**: 80 | **Type**: Continuous Delivery

**GitOps Workflow**: Git as Single Source of Truth • Automated Sync • Multi-Cluster Support • Health Monitoring

ArgoCD provides a **declarative GitOps continuous delivery tool** for Kubernetes that automates application deployment from Git repositories, ensuring cluster state matches the desired state defined in Git.

**Key Features**:
- **GitOps Workflow**: Git as the single source of truth for deployments
- **Automated Sync**: Automatically sync applications when Git changes
- **Rollback Support**: Easy rollback to any previous Git commit
- **Multi-Cluster Support**: Manage applications across multiple clusters
- **Health Monitoring**: Real-time application health status
- **Web UI & CLI**: Both GUI and command-line interfaces

**Access Information**:
- **Web Interface**: `http://argocd.localhost`
- **Username**: `admin`
- **Password**: `SecretPassword2` (from urbalurba-secrets)
- **External Access**: `https://argocd.urbalurba.no` (when Cloudflare tunnel configured)

📚 **[Complete Documentation →](./package-development-argocd.md)**

---

### **Development Templates - Multi-Language Application Templates** 🛠️
**Status**: Active | **Type**: Development Framework

**Multi-Language Support**: TypeScript • Python • Java • C# • Go • PHP • Pre-configured CI/CD

The development templates provide **pre-configured application templates** for rapid software development across multiple programming languages, integrated with the devcontainer-toolbox project.

**Key Features**:
- **Multi-Language Support**: TypeScript, Python, Java, C#, Go, PHP
- **Pre-configured CI/CD**: GitHub Actions workflows for automated building and deployment
- **DevContainer Integration**: Seamless integration with devcontainer-toolbox
- **Kubernetes Ready**: Pre-configured Kubernetes manifests for deployment
- **Database Integration**: Built-in support for MySQL and other databases
- **Template Selection**: Easy template selection via `.devcontainer/dev/dev-template.sh`

**Supported Languages**:
- **TypeScript/Node.js**: Modern web development with Express.js
- **Python**: FastAPI and Flask web applications
- **Java**: Spring Boot enterprise applications
- **C#**: .NET Core web applications
- **Go**: High-performance web services
- **PHP**: Laravel and Symfony web applications

📚 **[Complete Documentation →](./package-development-templates.md)**

---

### **DevContainer Toolbox - Integrated Development Environment** 🧰
**Status**: Active | **Type**: Development Environment

**Language Support**: Multiple Programming Languages • Integrated Tools • Containerized Development

The devcontainer-toolbox provides a **comprehensive development environment** with support for multiple programming languages and frameworks, enabling consistent development experiences across different projects.

**Key Features**:
- **Multi-Language Support**: Python, Node.js, Java, C#, Go, PHP
- **Containerized Development**: Consistent development environment
- **Integrated Tools**: Pre-configured development tools and extensions
- **Template Integration**: Seamless integration with development templates
- **Rapid Setup**: Quick project initialization and configuration

## 🏗️ Deployment Architecture

### **Service Activation**
```
Development Service Status:
├── ArgoCD (OPTIONAL) - Located in not-in-use/ folder
├── Development Templates (ACTIVE) - Available via GitHub repository
└── DevContainer Toolbox (ACTIVE) - Integrated development environment
```

### **Access Methods**
All development interfaces use Traefik IngressRoute for DNS-based routing:
- **ArgoCD**: `http://argocd.localhost`
- **Development Templates**: Available via GitHub repository
- **DevContainer Toolbox**: Integrated in development environment

### **Authentication Models**
```
Authentication Approaches:
├── ArgoCD: urbalurba-secrets (ARGOCD_ADMIN_PASSWORD)
├── Development Templates: GitHub repository access
└── DevContainer Toolbox: Integrated authentication
```

## 🚀 Quick Start

### **Activate GitOps Continuous Delivery (ArgoCD)**
```bash
# Move from not-in-use to activate
cd provision-host/kubernetes/08-development/not-in-use/
mv 02-setup-argocd.sh ./

# Deploy ArgoCD
./02-setup-argocd.sh

# Access via browser
open http://argocd.localhost
# Login: admin / SecretPassword2
```

### **Start Development with Templates**
```bash
# Clone development templates
git clone https://github.com/terchris/urbalurba-dev-templates.git
cd urbalurba-dev-templates

# Select a template
.devcontainer/dev/dev-template.sh

# Choose your language and framework
# Start developing and push to GitHub
# ArgoCD will automatically deploy your application
```

### **Access DevContainer Toolbox**
```bash
# The devcontainer-toolbox is integrated with development templates
# No separate installation required
# Available when using development templates
```

## 🔍 Development Service Selection Guide

### **When to Use ArgoCD** ✅
- **GitOps Workflow**: Prefer Git as single source of truth
- **Automated Deployments**: Need automatic sync when Git changes
- **Multi-Environment**: Managing applications across multiple clusters
- **Rollback Requirements**: Need easy rollback to previous versions
- **Team Collaboration**: Multiple developers working on same project

### **When to Use Development Templates** 🛠️
- **Rapid Prototyping**: Quick application development and testing
- **Multi-Language Development**: Working with different programming languages
- **CI/CD Integration**: Need automated building and deployment
- **Learning**: Understanding different frameworks and patterns
- **Standardization**: Consistent project structure across teams

### **When to Use DevContainer Toolbox** 🧰
- **Consistent Environment**: Need reproducible development setup
- **Language Support**: Working with multiple programming languages
- **Integrated Tools**: Pre-configured development tools and extensions
- **Containerized Development**: Prefer containerized development approach
- **Template Integration**: Using development templates effectively

## 🛠️ Development Operations

### **Common Access Patterns**
```bash
# Check ArgoCD status
kubectl get pods -n argocd
kubectl get svc -n argocd

# Verify ArgoCD accessibility
curl -H "Host: argocd.localhost" http://localhost/

# Check application deployments
kubectl get applications -n argocd
kubectl get apps -n argocd
```

### **Application Management**
```bash
# Register a new application with ArgoCD
cd /mnt/urbalurbadisk/scripts/argocd

GITHUB_USERNAME=your_username \
REPO_NAME=your_repo \
GITHUB_PAT=your_token \
./argocd-register-app.sh

# Remove an application
REPO_NAME=your_repo \
./argocd-remove-app.sh
```

### **Development Workflow**
```bash
# 1. Select development template
.devcontainer/dev/dev-template.sh

# 2. Develop your application
# Write code using the devcontainer toolbox

# 3. Push to GitHub
git add .
git commit -m "Initial commit"
git push origin main

# 4. ArgoCD automatically deploys
# Check status at http://argocd.localhost

# 5. Access your application
# Check ingress routes for your application URL
```

## 🔧 Troubleshooting

### **Common Issues**

**ArgoCD Won't Load**:
```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=argocd-server -n argocd

# Verify service endpoints
kubectl get endpoints argocd-server -n argocd

# Check IngressRoute configuration
kubectl get ingressroute argocd -n argocd
```

**Application Not Syncing**:
```bash
# Check GitHub credentials
kubectl get secret -n argocd

# Verify repository structure has Kubernetes manifests
# Check ArgoCD Application status in web UI

# View ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

**Development Template Issues**:
```bash
# Verify GitHub repository access
git clone https://github.com/terchris/urbalurba-dev-templates.git

# Check devcontainer configuration
ls -la .devcontainer/

# Verify template selection script
.devcontainer/dev/dev-template.sh
```

### **Service-Specific Troubleshooting**

**ArgoCD Issues**:
- Login failures → Verify ARGOCD_ADMIN_PASSWORD in secrets
- Application sync problems → Check GitHub credentials and repository structure
- Port forward issues → Ensure no other process is using the port

**Development Template Issues**:
- Template selection problems → Check devcontainer-toolbox installation
- CI/CD failures → Verify GitHub Actions configuration
- Deployment issues → Check Kubernetes manifests and ArgoCD configuration

**DevContainer Toolbox Issues**:
- Language support missing → Check devcontainer configuration
- Tool integration problems → Verify extension installation
- Container issues → Check Docker and devcontainer setup

## 📋 Maintenance

### **Regular Tasks**
1. **Health Monitoring**: Check ArgoCD pod and service status regularly
2. **Application Monitoring**: Monitor deployed applications and their health
3. **Template Updates**: Keep development templates up to date
4. **Security Updates**: Update container images and configurations
5. **Credential Management**: Rotate GitHub tokens and ArgoCD passwords

### **Backup Procedures**
```bash
# ArgoCD configuration backup
kubectl exec -it deployment/argocd-server -n argocd -- \
  tar -czf /tmp/argocd-backup.tar.gz /app/config
kubectl cp deployment/argocd-server:/tmp/argocd-backup.tar.gz ./argocd-backup.tar.gz

# Application definitions backup
kubectl get applications -n argocd -o yaml > argocd-applications-backup.yaml

# Development templates backup
git clone https://github.com/terchris/urbalurba-dev-templates.git
tar -czf urbalurba-dev-templates-backup.tar.gz urbalurba-dev-templates/
```

### **Service Removal**
```bash
# Remove ArgoCD
cd provision-host/kubernetes/08-development/not-in-use/
./02-remove-argocd.sh

# Remove applications
cd /mnt/urbalurbadisk/scripts/argocd
REPO_NAME=your_repo ./argocd-remove-app.sh

# Development templates and devcontainer-toolbox are external dependencies
# No removal needed from the infrastructure
```

## 🔗 Integration Points

### **Database Integration**
- **MySQL Setup**: See [MySQL Setup Documentation](./package-datascience.md#mysql-setup-documentation)
- **PostgreSQL**: Integrated with management services
- **Redis**: Available for caching and session storage

### **External Dependencies**
- **GitHub**: Required for repository access and CI/CD
- **Docker Hub**: Container image registry
- **DevContainer Toolbox**: [devcontainer-toolbox project](https://github.com/terchris/devcontainer-toolbox)
- **Development Templates**: [urbalurba-dev-templates](https://github.com/terchris/urbalurba-dev-templates)

---

**💡 Key Insight**: The development layer provides a complete CI/CD pipeline from code development to deployment, with ArgoCD handling GitOps-based continuous delivery, development templates offering multi-language application frameworks, and devcontainer-toolbox providing integrated development environments. This combination enables rapid prototyping, testing, and deployment of software applications with minimal configuration overhead.