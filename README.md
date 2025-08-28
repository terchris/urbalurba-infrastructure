# Urbalurba Infrastructure

**A zero-friction developer platform for building, testing, and deploying modern apps—without needing to know Kubernetes, GitOps, or the cloud.**

## 🎯 What Is Urbalurba Infrastructure?

Urbalurba Infrastructure provides a complete datacenter environment on your laptop. It's a full infrastructure stack that includes all the services that cloud providers (AWS, Azure, GCP) offer—running locally on a single machine with the same configuration you'd use in production.

### The Problem It Solves

- **"It works on my machine"** syndrome - Applications behave differently in development vs production
- **Complex cloud setup** - Developers waste time configuring cloud services instead of building
- **Permission bottlenecks** - Waiting for cloud access and permissions slows development
- **Expensive development** - Cloud costs accumulate during development and testing
- **Data privacy concerns** - Sensitive data must leave your environment for cloud AI services

### The Solution

- ✅ **Identical environments** - Same infrastructure locally, in cloud, and on-premises
- ✅ **Zero cloud dependencies** during development - Full control without permissions
- ✅ **Privacy-first** - AI and all services run locally on your data
- ✅ **Cost-effective** - No cloud costs during development
- ✅ **Production-ready** - Deploy the exact same stack to any cloud provider

## 🏗️ What's Included

### Core Infrastructure
- **Kubernetes cluster** - Container orchestration (via Rancher Desktop)
- **Docker runtime** - Container execution environment
- **Provision Host** - Centralized management container with all tools needed to manage the local infrastructure

### Data Services
- **Databases** - PostgreSQL, Redis, and other data stores
- **Message queues** - Async communication between services
- **Object storage** - File and blob storage solutions

### AI & Machine Learning
- **[AI Package](doc/package-ai.md)** - ChatGPT-like system running locally
- **Private AI models** - Use AI on your sensitive documents safely
- **Local LLM execution** - Run AI models without cloud dependencies

### Development Tools
- **GitOps workflows** - Automated deployments
- **Development containers** - Consistent dev environments
- **Infrastructure as Code** - Declarative configuration management via Kubernetes manifests

## 🧠 How It Works

Urbalurba runs a local Kubernetes cluster (via Rancher Desktop) and deploys services using declarative manifests. The provision-host container is the central management environment that applies manifests, runs provisioning scripts, and provides the full toolchain for day‑to‑day operations.

- Read the full overview in [How It Works](doc/HOW_IT_WORKS.md)
- Learn more about the management environment in [Provision Host Documentation](doc/provision-host-readme.md)

## 🚀 Getting Started

See the [Installation Guide](doc/INSTALL.md) for prerequisites, the one-line installer, and options for interactive, automatic, and preview modes.

## 🎯 Use Cases

### For Developers
- Build microservices with real databases and messaging
- Test with production-like infrastructure locally
- Develop AI applications with private, local models
- No waiting for cloud access or permissions

### For DevOps Teams
- Prototype infrastructure changes safely
- Test deployment pipelines before cloud rollout
- Validate configurations in identical environments
- Reduce cloud costs during development phases

### For Organizations
- Enable "shift-left" development practices
- Maintain data privacy during development
- Accelerate development cycles
- Reduce dependency on cloud infrastructure teams

## 📁 Repository Structure

```
urbalurba-infrastructure/
├── manifests/           # Kubernetes manifests for all services
├── doc/                 # Documentation and guides
│   └── package-ai.md   # AI package setup and usage
├── install-urbalurba.sh # Main installation script
├── Brewfile            # macOS dependencies definition
└── README.md           # This file
```

## 📚 Documentation

- **[AI Package](doc/package-ai.md)** - Local ChatGPT setup and usage
- **[Manifests](manifests/)** - Kubernetes configurations for all services
- **Service Documentation** - Individual service setups and configurations
- **Deployment Guides** - Moving from local to cloud production

## 🌟 Key Benefits

1. **Rapid Development** - Everything ready out of the box
2. **True Portability** - Same environment everywhere
3. **Data Privacy** - Nothing leaves your machine
4. **Cost Effective** - No cloud charges during development
5. **Team Consistency** - Everyone uses identical environments
6. **Production Confidence** - Test with real infrastructure locally

## 🔄 Development to Production Flow

1. **Develop** - Build and test on Urbalurba Infrastructure locally
2. **Version** - Commit configurations and deployments to Git
3. **Deploy** - Apply same configs to cloud Kubernetes clusters
4. **Monitor** - Use same observability tools in production

Your application works identically everywhere because it's the same infrastructure stack.

## 🛠️ Management

The **provision-host** container includes all the tools needed to manage your local infrastructure:

- **Infrastructure configuration management** - Modify and deploy services
- **Service deployment and scaling** - Control resource allocation
- **Environment provisioning** - Set up new environments quickly
- **Local development workflows** - Integrated toolchain for development

Access the management tools through the provision-host container once the system is running.

> **Note:** For detailed instructions on how to use the provision-host management container—including how to log in, where to find setup scripts, and how to manage applications/services in your Kubernetes cluster—see [Provision Host Documentation](doc/provision-host-readme.md).

## 🔧 Architecture

Urbalurba Infrastructure uses **Infrastructure as Code** principles with Kubernetes manifests stored in the [`manifests/`](manifests/) directory. Each service is defined declaratively, making it easy to:

- **Version control** all infrastructure changes
- **Reproduce** environments exactly
- **Scale** services up or down as needed
- **Deploy** the same configuration anywhere

---

**Ready to eliminate "works on my machine" forever? Install Urbalurba Infrastructure and start building with confidence.**
